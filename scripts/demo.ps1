<#
.SYNOPSIS
    Administra el despliegue de DEMO del mezquite: backend (Docker Compose) + tunel ngrok
    con dominio fijo. Un solo punto de control para start / stop / restart / status / logs
    de TODO el sistema o de un componente.

.DESCRIPTION
    Pensado para exponer el backend local por HTTPS (ngrok) y que la app movil del telefono
    se conecte desde cualquier red. Es INDEPENDIENTE DE LA RUTA (se autolocaliza con
    $PSScriptRoot). Complementa a manage.ps1 (que arranca web/movil en local).

    Topologia:  telefono (APK) --HTTPS--> https://<Domain>  --ngrok-->  http://localhost:8000 (Docker)

.PARAMETER Action
    start | stop | restart | status | logs        (default: status)

.PARAMETER Target
    all | backend | ngrok | api | result-worker | mock-validator | postgres | redis
    (default: all). Para 'logs' puedes apuntar a un servicio concreto.

.PARAMETER Domain
    Dominio fijo de ngrok (default: component-embody-sympathy.ngrok-free.dev).

.PARAMETER Tail
    Numero de lineas iniciales en 'logs' (default: 80).

.PARAMETER NoFollow
    En 'logs', no seguir en vivo (vuelca y termina).

.EXAMPLE
    .\scripts\demo.ps1 start              # backend + ngrok
    .\scripts\demo.ps1 status             # estatus de todo (incl. URL publica y healthz)
    .\scripts\demo.ps1 logs api           # logs en vivo solo de la API
    .\scripts\demo.ps1 logs ngrok         # logs del tunel
    .\scripts\demo.ps1 stop               # detiene ngrok y el backend
    .\scripts\demo.ps1 restart backend    # reinicia solo el backend
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('start', 'stop', 'restart', 'status', 'logs')]
    [string]$Action = 'status',

    [Parameter(Position = 1)]
    [ValidateSet('all', 'backend', 'ngrok', 'api', 'result-worker', 'mock-validator', 'postgres', 'redis')]
    [string]$Target = 'all',

    [string]$Domain = 'component-embody-sympathy.ngrok-free.dev',
    [int]$ApiPort = 8000,
    [int]$Tail = 80,
    [switch]$NoFollow
)

$ErrorActionPreference = 'Stop'

# --------------------------------------------------------------------------------------------
# Rutas (autolocalizadas; sobreviven a mover el repo)
# --------------------------------------------------------------------------------------------
$Root    = Split-Path $PSScriptRoot -Parent
$Compose = Join-Path $Root 'infra\compose\docker-compose.dev.yml'
$RunDir  = Join-Path $Root '.logs'
if (-not (Test-Path $RunDir)) { New-Item -ItemType Directory -Force $RunDir | Out-Null }
$NgrokLog = Join-Path $RunDir 'ngrok.log'

$PublicUrl = "https://$Domain"
$ApiBase   = "$PublicUrl/api/v1"

# --------------------------------------------------------------------------------------------
# Utilidades
# --------------------------------------------------------------------------------------------
function Info($m) { Write-Host $m -ForegroundColor Cyan }
function Ok($m)   { Write-Host $m -ForegroundColor Green }
function Warn($m) { Write-Host $m -ForegroundColor Yellow }
function Err($m)  { Write-Host $m -ForegroundColor Red }
function Head($m) { Write-Host ''; Write-Host "== $m ==" -ForegroundColor Magenta }

function Have-Cmd($name) { $null -ne (Get-Command $name -ErrorAction SilentlyContinue) }

function Save-Pid($name, $id)  { "$id" | Set-Content -Encoding ascii (Join-Path $RunDir "$name.pid") }
function Remove-PidFile($name) { Remove-Item (Join-Path $RunDir "$name.pid") -ErrorAction SilentlyContinue }
function Read-Pid($name) {
    $f = Join-Path $RunDir "$name.pid"
    if (Test-Path $f) { return (Get-Content $f -Raw).Trim() }
    return $null
}
function Pid-Alive($id) {
    if (-not $id) { return $false }
    return $null -ne (Get-Process -Id ([int]$id) -ErrorAction SilentlyContinue)
}
function Stop-Tree($id) {
    if ($id -and (Pid-Alive $id)) { & taskkill /PID $id /T /F 2>$null | Out-Null }
}

# --------------------------------------------------------------------------------------------
# BACKEND (Docker Compose)
# --------------------------------------------------------------------------------------------
function Start-Backend {
    Head 'Backend (Docker Compose)'
    if (-not (Have-Cmd docker)) { Err 'docker no esta en PATH. Abre Rancher Desktop.'; return }
    Info 'Levantando postgres + redis + api + result-worker + mock-validator...'
    Info '(la primera vez construye imagenes; puede tardar varios minutos)'
    & docker compose -f $Compose up --build -d
    Start-Sleep -Seconds 2
    Status-Backend
}
function Stop-Backend {
    Head 'Backend (Docker Compose)'
    if (-not (Have-Cmd docker)) { Err 'docker no esta en PATH.'; return }
    & docker compose -f $Compose stop
    Ok 'Backend detenido (contenedores conservados; los datos persisten en los volumenes).'
}
function Status-Backend {
    Head 'Backend (Docker Compose)'
    if (-not (Have-Cmd docker)) { Warn 'docker no esta en PATH.'; return }
    & docker compose -f $Compose ps
    try {
        $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 4 "http://localhost:$ApiPort/healthz"
        Ok "healthz local -> $($r.Content)   |  Swagger: http://localhost:$ApiPort/api/v1/docs"
    } catch {
        Warn 'healthz local sin respuesta (backend abajo o aun iniciando).'
    }
}

# --------------------------------------------------------------------------------------------
# TUNEL (ngrok)
# --------------------------------------------------------------------------------------------
function Start-Ngrok {
    Head "Tunel ngrok ($Domain)"
    if (-not (Have-Cmd ngrok)) { Err 'ngrok no esta en PATH. Instala con: winget install ngrok'; return }
    $existing = Read-Pid 'ngrok'
    if (Pid-Alive $existing) { Warn "ngrok ya en ejecucion (PID $existing). Usa 'restart ngrok'."; return }

    $src = (Get-Command ngrok).Source
    # --url fija el dominio reservado; --log a archivo para que 'logs ngrok' lo siga.
    $ngrokArgs = @('http', "$ApiPort", "--url=$PublicUrl", '--log', $NgrokLog, '--log-format', 'logfmt')
    $p = Start-Process -FilePath $src -PassThru -WindowStyle Hidden -ArgumentList $ngrokArgs
    Save-Pid 'ngrok' $p.Id
    Start-Sleep -Seconds 2
    Ok "ngrok arrancado (PID $($p.Id)). URL publica: $PublicUrl"
    Info "Si falla con '--url' (ngrok viejo), usa '--domain=$Domain' en su lugar."
}
function Stop-Ngrok {
    Head 'Tunel ngrok'
    $id = Read-Pid 'ngrok'
    if (Pid-Alive $id) { Stop-Tree $id; Ok "ngrok detenido (PID $id)." } else { Warn 'ngrok no estaba en ejecucion.' }
    Remove-PidFile 'ngrok'
}
function Status-Ngrok {
    Head 'Tunel ngrok'
    $id = Read-Pid 'ngrok'
    if (-not (Pid-Alive $id)) { Warn 'ngrok DETENIDO.'; return }
    Ok "ngrok EN EJECUCION (PID $id)."
    try {
        $t = Invoke-RestMethod -TimeoutSec 4 'http://127.0.0.1:4040/api/tunnels'
        foreach ($tun in $t.tunnels) { Info "  tunel: $($tun.public_url) -> $($tun.config.addr)" }
    } catch { Warn '  (API local de ngrok :4040 sin respuesta aun)' }
    try {
        $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 8 "$PublicUrl/healthz"
        Ok "  publico healthz -> $($r.Content)"
    } catch { Warn "  publico $PublicUrl/healthz sin respuesta (revisa backend + ngrok)." }
}

# --------------------------------------------------------------------------------------------
# LOGS
# --------------------------------------------------------------------------------------------
function Logs-Ngrok {
    Head 'Logs ngrok'
    if (-not (Test-Path $NgrokLog)) { Warn "Sin archivo de log ($NgrokLog). Arranca ngrok primero."; return }
    if ($NoFollow) { Get-Content $NgrokLog -Tail $Tail }
    else { Info '(Ctrl+C para salir)'; Get-Content $NgrokLog -Tail $Tail -Wait }
}
function Logs-Backend([string]$svc) {
    Head ("Logs backend" + $(if ($svc) { " :: $svc" } else { ' (todos)' }))
    if (-not (Have-Cmd docker)) { Err 'docker no esta en PATH.'; return }
    $composeArgs = @('compose', '-f', $Compose, 'logs', '--tail', "$Tail")
    if (-not $NoFollow) { $composeArgs += '-f'; Info '(Ctrl+C para salir)' }
    if ($svc) { $composeArgs += $svc }
    & docker @composeArgs
}

# --------------------------------------------------------------------------------------------
# Dispatch
# --------------------------------------------------------------------------------------------
$backendSvcs = @('api', 'result-worker', 'mock-validator', 'postgres', 'redis')

Write-Host ''
Write-Host "### mezquite demo :: $Action :: $Target ###" -ForegroundColor White
Write-Host "repo: $Root" -ForegroundColor DarkGray
Write-Host "API publica (para el APK): $ApiBase" -ForegroundColor DarkGray

switch ($Action) {
    'start' {
        switch ($Target) {
            'all'     { Start-Backend; Start-Ngrok }
            'backend' { Start-Backend }
            'ngrok'   { Start-Ngrok }
            default   { Start-Backend }
        }
    }
    'stop' {
        switch ($Target) {
            'all'     { Stop-Ngrok; Stop-Backend }
            'backend' { Stop-Backend }
            'ngrok'   { Stop-Ngrok }
            default   { Stop-Backend }
        }
    }
    'restart' {
        switch ($Target) {
            'all'     { Stop-Ngrok; Stop-Backend; Start-Backend; Start-Ngrok }
            'backend' { Stop-Backend; Start-Backend }
            'ngrok'   { Stop-Ngrok; Start-Ngrok }
            default   { Stop-Backend; Start-Backend }
        }
    }
    'status' {
        switch ($Target) {
            'all'     { Status-Backend; Status-Ngrok }
            'backend' { Status-Backend }
            'ngrok'   { Status-Ngrok }
            default   { Status-Backend }
        }
    }
    'logs' {
        switch ($Target) {
            'all'     { Logs-Backend $null }
            'backend' { Logs-Backend $null }
            'ngrok'   { Logs-Ngrok }
            default   { if ($backendSvcs -contains $Target) { Logs-Backend $Target } else { Logs-Backend $null } }
        }
    }
}
Write-Host ''
