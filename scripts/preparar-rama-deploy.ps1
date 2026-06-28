#requires -Version 5.1
<#
.SYNOPSIS
  Compila los bundles Flutter Web LOCALMENTE (Windows) y publica la rama `deploy` en GitHub con
  TODO lo que la VM necesita para desplegar SIN compilar Flutter.

.DESCRIPTION
  La VM del piloto (CX22, 4 GB) no debe compilar Flutter (el build se come 2-4 GB y puede tronar).
  Por eso el build se hace AQUÍ, en tu PC, y se publica una rama `deploy` = (tu rama actual) + los
  bundles ya compilados (`mobile/build/web` y `web-admin/build/web`, normalmente ignorados por git,
  forzados con `git add -f`).

  En la VM, el agente solo hace:  git clone … && git checkout deploy   → ya tiene los bundles.
  (El `docker compose up --build` en la VM solo construye la imagen del BACKEND en Python, que sí cabe
  en 4 GB; nunca Flutter.)

.PREREQUISITOS
  - Flutter 3.27 y git en PATH.
  - Login con Google SIN Firebase (Google Identity Services): pasa el Web Client ID de OAuth
    (Google Cloud > APIs y servicios > Credenciales) con -ClientId si AuthMode=google.
  - Tu rama actual (p. ej. main) COMMITEADA Y EMPUJADA: la rama deploy se basa en ese commit.

.EXAMPLE
  .\scripts\preparar-rama-deploy.ps1 -ClientId "1234-abc.apps.googleusercontent.com"
  # build con el dominio y login Google (GIS) del piloto, publica origin/deploy

.EXAMPLE
  .\scripts\preparar-rama-deploy.ps1 -AuthMode mock
  # piloto cerrado (sin Google); no requiere Client ID
#>
[CmdletBinding()]
param(
  [string]$Dominio  = "rescatando-el-mezquite.org",
  [string]$Rama     = "deploy",
  [ValidateSet("google", "mock")] [string]$AuthMode = "google",
  [string]$ClientId = ""
)
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

function Assert($cond, $msg) { if (-not $cond) { Write-Error $msg; exit 1 } }

# 0. Validaciones -----------------------------------------------------------
Assert (Get-Command flutter -ErrorAction SilentlyContinue) "Flutter no está en PATH."
Assert (Get-Command git     -ErrorAction SilentlyContinue) "git no está en PATH."
if ($AuthMode -eq "google") {
  Assert (-not [string]::IsNullOrWhiteSpace($ClientId)) `
    "Falta -ClientId (Web Client ID de OAuth de Google Cloud, ...apps.googleusercontent.com). Pasalo, o usa -AuthMode mock."
}
$ramaActual = (git rev-parse --abbrev-ref HEAD).Trim()
Assert ($ramaActual -ne $Rama) "Estás en la rama '$Rama'. Ejecuta el script desde tu rama de trabajo (p. ej. main)."

# La rama deploy se basa en el commit actual: exige árbol limpio (los build/ están ignorados, no cuentan).
$sucio = (git status --porcelain)
Assert ([string]::IsNullOrWhiteSpace($sucio)) `
  "Hay cambios sin commitear en '$ramaActual'. Haz commit y push de tu rama ANTES de publicar deploy:`n$sucio"

Write-Host "==> Repo limpio en '$ramaActual'. Dominio=$Dominio  Auth=$AuthMode" -ForegroundColor Cyan

# 1. Compilar los dos bundles ----------------------------------------------
Write-Host "==> Compilando app del VOLUNTARIO (PWA)..." -ForegroundColor Cyan
Push-Location mobile
try {
  flutter build web --release `
    --dart-define=API_BASE_URL="https://app.$Dominio/api/v1" `
    --dart-define=AUTH_MODE=$AuthMode `
    --dart-define=GOOGLE_WEB_CLIENT_ID="$ClientId"
  Assert ($LASTEXITCODE -eq 0) "Falló el build del voluntario."
} finally { Pop-Location }

Write-Host "==> Compilando CONSOLA (web-admin)..." -ForegroundColor Cyan
Push-Location web-admin
try {
  flutter build web --release `
    --dart-define=API_BASE_URL="https://admin.$Dominio/api/v1"
  Assert ($LASTEXITCODE -eq 0) "Falló el build de la consola."
} finally { Pop-Location }

Assert (Test-Path "mobile/build/web/index.html")     "No se generó mobile/build/web."
Assert (Test-Path "web-admin/build/web/index.html")  "No se generó web-admin/build/web."

# 2. Publicar la rama deploy = (rama actual) + bundles ----------------------
Write-Host "==> Publicando la rama '$Rama' (commit actual + bundles compilados)..." -ForegroundColor Cyan
git checkout -B $Rama
git add -f mobile/build/web web-admin/build/web
git commit -m "deploy: bundles web compilados ($Dominio, auth=$AuthMode)"
git push --force origin $Rama
git checkout $ramaActual

Write-Host ""
Write-Host "[OK] Rama '$Rama' publicada en origin con los bundles ya compilados." -ForegroundColor Green
Write-Host "  En la VM, el agente hace:" -ForegroundColor Green
Write-Host "    git clone https://github.com/ovelazquezj/mezquites.git mezquite && cd mezquite" -ForegroundColor Green
Write-Host "    git checkout $Rama" -ForegroundColor Green
Write-Host "  (No se compila Flutter en la VM; ver docs/despliegue/DESPLIEGUE-AGENTE.md)" -ForegroundColor Green
