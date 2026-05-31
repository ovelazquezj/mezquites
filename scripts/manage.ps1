<#
.SYNOPSIS
    Administra el stack del proyecto del mezquite: backend (Docker Compose), web admin
    (Flutter Web/Chrome) y app movil (Flutter en emulador Android).

.DESCRIPTION
    Un solo punto de control para arrancar / detener / reiniciar / ver estatus, ya sea de
    TODO a la vez o de un componente a la vez. Es INDEPENDIENTE DE LA RUTA: se autolocaliza
    con $PSScriptRoot, asi que sigue funcionando si mueves el repo (p.ej. a C:\dev).

.PARAMETER Action
    start | stop | restart | status   (default: status)

.PARAMETER Target
    all | backend | web | mobile      (default: all)

.EXAMPLE
    .\scripts\manage.ps1 start            # arranca todo (backend -> web -> movil)
    .\scripts\manage.ps1 status           # estatus de todo
    .\scripts\manage.ps1 stop backend     # detiene solo el backend
    .\scripts\manage.ps1 restart mobile   # reinicia solo la app movil
    .\scripts\manage.ps1 stop all -KillEmulator   # detiene todo y apaga el emulador
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('start', 'stop', 'restart', 'status')]
    [string]$Action = 'status',

    [Parameter(Position = 1)]
    [ValidateSet('all', 'backend', 'web', 'mobile')]
    [string]$Target = 'all',

    [string]$ApiHost = 'localhost',      # host para el web admin (navegador -> host)
    [int]$ApiPort = 8000,
    [string]$MobileApiHost = '10.0.2.2', # 10.0.2.2 = el host visto desde el emulador Android
    [string]$Avd = '',                   # AVD a usar; vacio = el primero disponible
    [string]$Gpu = 'swiftshader_indirect', # modo GPU del emulador (confiable en cualquier maquina)
    [switch]$KillEmulator,               # en 'stop', tambien apaga el emulador
    [switch]$NoCorsFlag                  # arranca el web SIN --disable-web-security
)

$ErrorActionPreference = 'Stop'

# --------------------------------------------------------------------------------------------
# Rutas (autolocalizadas; sobreviven a mover el repo)
# --------------------------------------------------------------------------------------------
$Root      = Split-Path $PSScriptRoot -Parent
$Compose   = Join-Path $Root 'infra\compose\docker-compose.dev.yml'
$WebDir    = Join-Path $Root 'web-admin'
$MobileDir = Join-Path $Root 'mobile'
$RunDir    = Join-Path $Root '.logs'
if (-not (Test-Path $RunDir)) { New-Item -ItemType Directory -Force $RunDir | Out-Null }

$Sdk = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT }
       elseif ($env:ANDROID_HOME) { $env:ANDROID_HOME }
       else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$Adb      = Join-Path $Sdk 'platform-tools\adb.exe'
$Emulator = Join-Path $Sdk 'emulator\emulator.exe'

$WebApi    = "http://$($ApiHost):$ApiPort/api/v1"
$MobileApi = "http://$($MobileApiHost):$ApiPort/api/v1"

# --------------------------------------------------------------------------------------------
# Utilidades
# --------------------------------------------------------------------------------------------
function Info($m)  { Write-Host $m -ForegroundColor Cyan }
function Ok($m)    { Write-Host $m -ForegroundColor Green }
function Warn($m)  { Write-Host $m -ForegroundColor Yellow }
function Err($m)   { Write-Host $m -ForegroundColor Red }
function Head($m)  { Write-Host ''; Write-Host "== $m ==" -ForegroundColor Magenta }

function Have-Cmd($name) { $null -ne (Get-Command $name -ErrorAction SilentlyContinue) }

function Save-Pid($name, $id)   { "$id" | Set-Content -Encoding ascii (Join-Path $RunDir "$name.pid") }
function Remove-PidFile($name)  { Remove-Item (Join-Path $RunDir "$name.pid") -ErrorAction SilentlyContinue }
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

# Lanza un comando flutter en una VENTANA nueva de PowerShell (logs en vivo + hot reload),
# de forma robusta ante comillas usando -EncodedCommand. Devuelve el PID de la ventana.
function Start-FlutterWindow([string]$workDir, [string[]]$flutterArgs, [hashtable]$envVars) {
    $argLiteral = ($flutterArgs | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ','
    $envLines = ''
    if ($envVars) { foreach ($k in $envVars.Keys) { $envLines += "`$env:$k = '$($envVars[$k])'`n" } }
    $script = @"
Set-Location '$workDir'
$envLines
`$a = @($argLiteral)
Write-Host 'Ejecutando: flutter ' (`$a -join ' ') -ForegroundColor Cyan
& flutter @a
Write-Host ''
Write-Host '--- flutter run termino. Ventana abierta para inspeccion (cierrala cuando quieras). ---' -ForegroundColor Yellow
"@
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
    $p = Start-Process powershell -PassThru -ArgumentList '-NoExit', '-NoProfile', '-EncodedCommand', $enc
    return $p.Id
}

# --------------------------------------------------------------------------------------------
# BACKEND (Docker Compose)
# --------------------------------------------------------------------------------------------
function Start-Backend {
    Head 'Backend (Docker Compose)'
    if (-not (Have-Cmd docker)) { Err 'docker no esta en PATH. Abre Rancher Desktop.'; return }
    Info "Levantando postgres + redis + api + result-worker + mock-validator..."
    Info "(la primera vez construye imagenes; puede tardar varios minutos)"
    & docker compose -f $Compose up --build -d
    Start-Sleep -Seconds 2
    Status-Backend
}
function Stop-Backend {
    Head 'Backend (Docker Compose)'
    if (-not (Have-Cmd docker)) { Err 'docker no esta en PATH.'; return }
    & docker compose -f $Compose down
    Ok 'Backend detenido.'
}
function Status-Backend {
    Head 'Backend (Docker Compose)'
    if (-not (Have-Cmd docker)) { Warn 'docker no esta en PATH.'; return }
    & docker compose -f $Compose ps
    try {
        $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 4 "http://$($ApiHost):$ApiPort/healthz"
        Ok "healthz -> $($r.Content)   |  Swagger: http://$($ApiHost):$ApiPort/api/v1/docs"
    } catch {
        Warn 'healthz sin respuesta (backend abajo o aun iniciando).'
    }
}

# --------------------------------------------------------------------------------------------
# WEB ADMIN (Flutter Web / Chrome)
# --------------------------------------------------------------------------------------------
function Start-Web {
    Head 'Web admin (Flutter Web)'
    if (-not (Have-Cmd flutter)) { Err 'flutter no esta en PATH.'; return }
    $existing = Read-Pid 'web'
    if (Pid-Alive $existing) { Warn "Ya en ejecucion (PID $existing). Usa 'restart web' para relanzar."; return }

    $flutterArgs = @('run', '-d', 'chrome', "--dart-define=API_BASE_URL=$WebApi")
    if (-not $NoCorsFlag) {
        $chromeProfile = Join-Path $env:TEMP 'mezquite-chrome'
        New-Item -ItemType Directory -Force $chromeProfile | Out-Null
        $flutterArgs += '--web-browser-flag=--disable-web-security'
        $flutterArgs += "--web-browser-flag=--user-data-dir=$chromeProfile"
        Warn 'Se usa --disable-web-security (perfil de Chrome aparte) porque el backend aun no habilita CORS.'
    }
    $id = Start-FlutterWindow $WebDir $flutterArgs $null
    Save-Pid 'web' $id
    Ok "Web admin arrancando en una ventana nueva (PID $id). Chrome se abrira con la API en $WebApi."
}
function Stop-Web {
    Head 'Web admin (Flutter Web)'
    $id = Read-Pid 'web'
    if (Pid-Alive $id) { Stop-Tree $id; Ok "Detenido (PID $id)." } else { Warn 'No estaba en ejecucion.' }
    Remove-PidFile 'web'
}
function Status-Web {
    Head 'Web admin (Flutter Web)'
    $id = Read-Pid 'web'
    if (Pid-Alive $id) { Ok "EN EJECUCION (PID $id). API objetivo: $WebApi" }
    else { Warn 'DETENIDO.' }
}

# --------------------------------------------------------------------------------------------
# APP MOVIL (Flutter en emulador Android)
# --------------------------------------------------------------------------------------------
function Get-RunningEmulator {
    if (-not (Test-Path $Adb)) { return $null }
    foreach ($l in (& $Adb devices)) {
        if ($l -match '^(emulator-\d+)\s+device') { return $matches[1] }
    }
    return $null
}
function Wait-EmulatorBoot([int]$timeoutSec = 240) {
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $deadline) {
        $id = Get-RunningEmulator
        if ($id) {
            $bc = (& $Adb -s $id shell getprop sys.boot_completed 2>$null | Out-String).Trim()
            if ($bc -eq '1') { return $id }
        }
        Start-Sleep -Seconds 4
    }
    return $null
}
function Ensure-Emulator {
    $id = Get-RunningEmulator
    if ($id) { Ok "Emulador ya activo: $id"; return $id }
    if (-not (Test-Path $Emulator)) { throw "No se encontro emulator.exe en $Sdk" }
    $avd = $Avd
    if (-not $avd) { $avd = (& $Emulator -list-avds | Select-Object -First 1) }
    if (-not $avd) { throw 'No hay AVDs. Crea uno en Android Studio (Device Manager).' }
    Info "Lanzando emulador '$avd' (cold boot, gpu=$Gpu)..."
    $ep = Start-Process -FilePath $Emulator -PassThru -ArgumentList @(
        '-avd', $avd, '-no-snapshot-load', '-gpu', $Gpu, '-no-boot-anim'
    )
    Save-Pid 'emulator' $ep.Id
    Info 'Esperando a que Android termine de bootear (puede tardar 1-3 min)...'
    $id = Wait-EmulatorBoot 300
    if (-not $id) { throw 'El emulador no completo el arranque a tiempo.' }
    Ok "Emulador listo: $id"
    return $id
}
function Start-Mobile {
    Head 'App movil (Flutter / Android)'
    if (-not (Have-Cmd flutter)) { Err 'flutter no esta en PATH.'; return }
    if ($Root -match 'OneDrive' -or $Root.Length -gt 80) {
        Warn 'ADVERTENCIA: el repo esta en OneDrive o en una ruta larga.'
        Warn 'El build de Android puede fallar por el limite de 260 caracteres (MAX_PATH).'
        Warn 'Recomendado: mover el repo a una ruta corta como C:\dev antes de compilar el movil.'
    }
    $existing = Read-Pid 'mobile'
    if (Pid-Alive $existing) { Warn "Ya en ejecucion (PID $existing). Usa 'restart mobile' para relanzar."; return }
    $emu = Ensure-Emulator
    $flutterArgs = @('run', '-d', $emu, "--dart-define=API_BASE_URL=$MobileApi")
    $id = Start-FlutterWindow $MobileDir $flutterArgs @{ ANDROID_SDK_ROOT = $Sdk }
    Save-Pid 'mobile' $id
    Ok "App movil arrancando en una ventana nueva (PID $id). Compila e instala en $emu (API $MobileApi)."
}
function Stop-Mobile {
    Head 'App movil (Flutter / Android)'
    $id = Read-Pid 'mobile'
    if (Pid-Alive $id) { Stop-Tree $id; Ok "App detenida (PID $id)." } else { Warn 'La app no estaba en ejecucion.' }
    Remove-PidFile 'mobile'
    if ($KillEmulator) {
        $emu = Get-RunningEmulator
        if ($emu) { & $Adb -s $emu emu kill 2>$null; Ok "Emulador $emu apagado." } else { Warn 'No habia emulador activo.' }
        Remove-PidFile 'emulator'
    }
}
function Status-Mobile {
    Head 'App movil (Flutter / Android)'
    $emu = Get-RunningEmulator
    if ($emu) { Ok "Emulador: $emu (activo)" } else { Warn 'Emulador: ninguno activo.' }
    $id = Read-Pid 'mobile'
    if (Pid-Alive $id) { Ok "App: EN EJECUCION (PID $id). API objetivo: $MobileApi" } else { Warn 'App: DETENIDA.' }
}

# --------------------------------------------------------------------------------------------
# Dispatch
# --------------------------------------------------------------------------------------------
function Do-Start($t)  { switch ($t) { 'backend' { Start-Backend } 'web' { Start-Web } 'mobile' { Start-Mobile } } }
function Do-Stop($t)   { switch ($t) { 'backend' { Stop-Backend } 'web' { Stop-Web } 'mobile' { Stop-Mobile } } }
function Do-Status($t) { switch ($t) { 'backend' { Status-Backend } 'web' { Status-Web } 'mobile' { Status-Mobile } } }

Write-Host ''
Write-Host "### mezquite :: $Action :: $Target ###" -ForegroundColor White
Write-Host "repo: $Root" -ForegroundColor DarkGray

if ($Target -eq 'all') {
    switch ($Action) {
        'start'   { Do-Start 'backend'; Do-Start 'web'; Do-Start 'mobile' }
        'stop'    { Do-Stop 'web'; Do-Stop 'mobile'; Do-Stop 'backend' }
        'restart' { Do-Stop 'web'; Do-Stop 'mobile'; Do-Stop 'backend'; Do-Start 'backend'; Do-Start 'web'; Do-Start 'mobile' }
        'status'  { Do-Status 'backend'; Do-Status 'web'; Do-Status 'mobile' }
    }
} else {
    switch ($Action) {
        'start'   { Do-Start $Target }
        'stop'    { Do-Stop $Target }
        'restart' { Do-Stop $Target; Do-Start $Target }
        'status'  { Do-Status $Target }
    }
}
Write-Host ''
