<#
.SYNOPSIS
    Controlador de la app del mezquite (FRONT + BACK) para demos y pruebas:
    start / stop / restart / status / logs de TODO o de un componente.

.DESCRIPTION
    Componentes:
      backend  Docker Compose (postgres + redis + api).            -> http://localhost:<ApiPort>
      web      App del VOLUNTARIO (Flutter Web) servida por un reverse-proxy
               (web + API en un solo origen) en <ProxyPort>, para tunelar por HTTPS.
      tunnel   Túnel ngrok HTTPS -> proxy (un solo origen).          -> https://<Domain>
      admin    Web-admin del consorcio (Flutter Web) estática.       -> http://localhost:<AdminPort>

    La web del voluntario se ABRE por el túnel HTTPS (https://<Domain>): así la cámara y la
    geolocalización del navegador funcionan (requieren contexto seguro). El web-admin se abre en
    localhost (consola del operador). Independiente de la ruta ($PSScriptRoot). PIDs/logs en .logs\.

.PARAMETER Action   start | stop | restart | status | logs        (def: status)
.PARAMETER Target   all | backend | web | tunnel | admin           (def: all)
.PARAMETER Domain   Dominio fijo de ngrok (def: component-embody-sympathy.ngrok-free.dev)
.PARAMETER Build    Reconstruye el build web aunque ya exista (web/admin).
.PARAMETER NoFollow En 'logs', vuelca y termina (no sigue en vivo).

.EXAMPLE
    .\scripts\appctl.ps1 start            # backend + web + túnel + admin
    .\scripts\appctl.ps1 status           # estado + URLs (pública y local)
    .\scripts\appctl.ps1 logs web         # logs del proxy de la web del voluntario
    .\scripts\appctl.ps1 restart web -Build   # reconstruye y reinicia la web
    .\scripts\appctl.ps1 stop             # detiene todo (los datos del backend persisten)
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][ValidateSet('start', 'stop', 'restart', 'status', 'logs')]
    [string]$Action = 'status',
    [Parameter(Position = 1)][ValidateSet('all', 'backend', 'web', 'tunnel', 'admin')]
    [string]$Target = 'all',
    [string]$Domain = 'component-embody-sympathy.ngrok-free.dev',
    [int]$ApiPort = 8000,
    [int]$ProxyPort = 8080,
    [int]$AdminPort = 5001,
    [int]$Tail = 80,
    [switch]$Build,
    [switch]$NoFollow
)
$ErrorActionPreference = 'Continue'

# --- Rutas (autolocalizadas) ---
$Root      = Split-Path $PSScriptRoot -Parent
$Compose   = Join-Path $Root 'infra\compose\docker-compose.dev.yml'
$MobileDir = Join-Path $Root 'mobile'
$AdminDir  = Join-Path $Root 'web-admin'
$Proxy     = Join-Path $PSScriptRoot 'web_proxy.py'
$RunDir    = Join-Path $Root '.logs'
if (-not (Test-Path $RunDir)) { New-Item -ItemType Directory -Force $RunDir | Out-Null }

$PublicUrl    = "https://$Domain"
$WebApiBase   = "$PublicUrl/api/v1"
$AdminApiBase = "http://localhost:$ApiPort/api/v1"

# --- Utilidades ---
function Info($m) { Write-Host $m -ForegroundColor Cyan }
function Ok($m)   { Write-Host $m -ForegroundColor Green }
function Warn($m) { Write-Host $m -ForegroundColor Yellow }
function Err($m)  { Write-Host $m -ForegroundColor Red }
function Head($m) { Write-Host ''; Write-Host "== $m ==" -ForegroundColor Magenta }
function Have($n) { $null -ne (Get-Command $n -ErrorAction SilentlyContinue) }
function Save-Pid($n, $id) { "$id" | Set-Content -Encoding ascii (Join-Path $RunDir "$n.pid") }
function Read-Pid($n) { $f = Join-Path $RunDir "$n.pid"; if (Test-Path $f) { (Get-Content $f -Raw).Trim() } }
function Rm-Pid($n) { Remove-Item (Join-Path $RunDir "$n.pid") -ErrorAction SilentlyContinue }
function Alive($id) { if ($id) { $null -ne (Get-Process -Id ([int]$id) -ErrorAction SilentlyContinue) } else { $false } }
function Kill-Tree($id) { if (Alive $id) { & taskkill /PID $id /T /F 2>$null | Out-Null } }

function Build-Web($dir, $apiBase, $label) {
    if ((-not $Build) -and (Test-Path (Join-Path $dir 'build\web\index.html'))) {
        Info "${label}: uso el build web existente (usa -Build para reconstruir)."
        return
    }
    Info "${label}: flutter build web (API_BASE_URL=$apiBase)... (~1 min)"
    Push-Location $dir
    try { & flutter build web --dart-define="API_BASE_URL=$apiBase" | Out-Null }
    finally { Pop-Location }
}

function Start-Bg($name, $file, $argList, $env) {
    foreach ($k in $env.Keys) { Set-Item -Path "Env:$k" -Value $env[$k] }
    $out = Join-Path $RunDir "$name.log"
    $p = Start-Process -FilePath $file -ArgumentList $argList -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput $out -RedirectStandardError (Join-Path $RunDir "$name.err.log")
    Save-Pid $name $p.Id
    return $p.Id
}

# --- BACKEND ---
function Start-Backend {
    Head 'Backend (Docker Compose)'
    if (-not (Have docker)) { Err 'docker no está en PATH. Abre Rancher Desktop.'; return }
    Info 'postgres + redis + api (la 1ª vez construye imágenes)...'
    & docker compose -f $Compose up --build -d
    Status-Backend
}
function Stop-Backend {
    Head 'Backend'; if (Have docker) { & docker compose -f $Compose stop; Ok 'Backend detenido (datos persisten).' }
}
function Status-Backend {
    Head 'Backend'; if (-not (Have docker)) { Warn 'docker no está en PATH.'; return }
    & docker compose -f $Compose ps
    try { $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 4 "http://localhost:$ApiPort/healthz"
          Ok "healthz -> $($r.Content)  |  Swagger: http://localhost:$ApiPort/api/v1/docs" }
    catch { Warn 'healthz sin respuesta (backend abajo o iniciando).' }
}
function Logs-Backend { Head 'Logs backend'; if (Have docker) { $a = @('compose','-f',$Compose,'logs','--tail',"$Tail"); if (-not $NoFollow) { $a += '-f' }; & docker @a } }

# --- WEB (voluntario) ---
function Start-Web {
    Head "Web del voluntario (proxy :$ProxyPort)"
    if (-not (Have flutter)) { Err 'flutter no está en PATH.'; return }
    Build-Web $MobileDir $WebApiBase 'web'
    if (Alive (Read-Pid 'web')) { Warn "web ya en ejecución. Usa 'restart web'."; return }
    $id = Start-Bg 'web' 'python' @("$Proxy") @{ PROXY_PORT = "$ProxyPort"; WEB_ROOT = (Join-Path $MobileDir 'build\web'); BACKEND_URL = "http://localhost:$ApiPort" }
    Ok "web sirviendo en :$ProxyPort (PID $id). Ábrela por el túnel: $PublicUrl"
}
function Stop-Web { Head 'Web del voluntario'; $id = Read-Pid 'web'; if (Alive $id) { Kill-Tree $id; Ok "web detenida (PID $id)." } else { Warn 'web no estaba en ejecución.' }; Rm-Pid 'web' }
function Status-Web {
    Head 'Web del voluntario'; $id = Read-Pid 'web'
    if (-not (Alive $id)) { Warn 'web DETENIDA.'; return }
    Ok "web EN EJECUCIÓN (PID $id) — local http://localhost:$ProxyPort ; pública $PublicUrl"
}
function Logs-Web { Head 'Logs web'; $f = Join-Path $RunDir 'web.log'; if (Test-Path $f) { if ($NoFollow) { Get-Content $f -Tail $Tail } else { Info '(Ctrl+C para salir)'; Get-Content $f -Tail $Tail -Wait } } else { Warn 'sin log (arranca la web primero).' } }

# --- TUNNEL (ngrok -> proxy) ---
function Start-Tunnel {
    Head "Túnel ngrok ($Domain) -> :$ProxyPort"
    if (-not (Have ngrok)) { Err 'ngrok no está en PATH (winget install ngrok).'; return }
    if (Alive (Read-Pid 'tunnel')) { Warn "túnel ya en ejecución. Usa 'restart tunnel'."; return }
    $src = (Get-Command ngrok).Source
    $a = @('http', "$ProxyPort", "--url=$PublicUrl", '--log', (Join-Path $RunDir 'tunnel.log'), '--log-format', 'logfmt')
    $p = Start-Process -FilePath $src -PassThru -WindowStyle Hidden -ArgumentList $a
    Save-Pid 'tunnel' $p.Id
    Ok "túnel arrancado (PID $($p.Id)). URL pública: $PublicUrl"
}
function Stop-Tunnel { Head 'Túnel ngrok'; $id = Read-Pid 'tunnel'; if (Alive $id) { Kill-Tree $id; Ok "túnel detenido (PID $id)." } else { Warn 'túnel no estaba en ejecución.' }; Rm-Pid 'tunnel' }
function Status-Tunnel {
    Head 'Túnel ngrok'; $id = Read-Pid 'tunnel'
    if (-not (Alive $id)) { Warn 'túnel DETENIDO.'; return }
    Ok "túnel EN EJECUCIÓN (PID $id) -> $PublicUrl"
    try { $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 8 -Headers @{ 'ngrok-skip-browser-warning' = 'true' } "$PublicUrl/healthz"
          Ok "  público healthz -> $($r.Content)" } catch { Warn "  $PublicUrl/healthz sin respuesta (revisa web + backend)." }
}
function Logs-Tunnel { Head 'Logs túnel'; $f = Join-Path $RunDir 'tunnel.log'; if (Test-Path $f) { if ($NoFollow) { Get-Content $f -Tail $Tail } else { Info '(Ctrl+C para salir)'; Get-Content $f -Tail $Tail -Wait } } else { Warn 'sin log (arranca el túnel primero).' } }

# --- ADMIN (web-admin) ---
function Start-Admin {
    Head "Web-admin (estático :$AdminPort)"
    if (-not (Have flutter)) { Err 'flutter no está en PATH.'; return }
    Build-Web $AdminDir $AdminApiBase 'admin'
    if (Alive (Read-Pid 'admin')) { Warn "admin ya en ejecución. Usa 'restart admin'."; return }
    $root = Join-Path $AdminDir 'build\web'
    $id = Start-Bg 'admin' 'python' @('-m', 'http.server', "$AdminPort", '--directory', $root, '--bind', '0.0.0.0') @{}
    Ok "web-admin en http://localhost:$AdminPort (PID $id). Login: usuario/contraseña del admin (bootstrap)."
}
function Stop-Admin { Head 'Web-admin'; $id = Read-Pid 'admin'; if (Alive $id) { Kill-Tree $id; Ok "web-admin detenido (PID $id)." } else { Warn 'web-admin no estaba en ejecución.' }; Rm-Pid 'admin' }
function Status-Admin { Head 'Web-admin'; $id = Read-Pid 'admin'; if (Alive $id) { Ok "web-admin EN EJECUCIÓN (PID $id) -> http://localhost:$AdminPort" } else { Warn 'web-admin DETENIDO.' } }
function Logs-Admin { Head 'Logs web-admin'; $f = Join-Path $RunDir 'admin.log'; if (Test-Path $f) { if ($NoFollow) { Get-Content $f -Tail $Tail } else { Info '(Ctrl+C para salir)'; Get-Content $f -Tail $Tail -Wait } } else { Warn 'sin log (arranca el admin primero).' } }

# --- Dispatch ---
Write-Host ''
Write-Host "### mezquite appctl :: $Action :: $Target ###" -ForegroundColor White
Write-Host "repo: $Root" -ForegroundColor DarkGray
Write-Host "web pública (voluntario): $PublicUrl   |   web-admin: http://localhost:$AdminPort" -ForegroundColor DarkGray

switch ($Action) {
    'start'   { switch ($Target) { 'all' { Start-Backend; Start-Web; Start-Tunnel; Start-Admin } 'backend' { Start-Backend } 'web' { Start-Web } 'tunnel' { Start-Tunnel } 'admin' { Start-Admin } } }
    'stop'    { switch ($Target) { 'all' { Stop-Tunnel; Stop-Web; Stop-Admin; Stop-Backend } 'backend' { Stop-Backend } 'web' { Stop-Web } 'tunnel' { Stop-Tunnel } 'admin' { Stop-Admin } } }
    'restart' { switch ($Target) { 'all' { Stop-Tunnel; Stop-Web; Stop-Admin; Stop-Backend; Start-Backend; Start-Web; Start-Tunnel; Start-Admin } 'backend' { Stop-Backend; Start-Backend } 'web' { Stop-Web; Start-Web } 'tunnel' { Stop-Tunnel; Start-Tunnel } 'admin' { Stop-Admin; Start-Admin } } }
    'status'  { switch ($Target) { 'all' { Status-Backend; Status-Web; Status-Tunnel; Status-Admin } 'backend' { Status-Backend } 'web' { Status-Web } 'tunnel' { Status-Tunnel } 'admin' { Status-Admin } } }
    'logs'    { switch ($Target) { 'backend' { Logs-Backend } 'web' { Logs-Web } 'tunnel' { Logs-Tunnel } 'admin' { Logs-Admin } default { Logs-Backend } } }
}
Write-Host ''
