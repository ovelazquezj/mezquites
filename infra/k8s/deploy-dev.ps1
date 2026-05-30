# Despliegue DEV en clúster K8s local (Rancher Desktop / minikube), SIN NUBE (gate #6, T5).
# UN SOLO COMANDO (Windows / Rancher Desktop): construye las imágenes y aplica el overlay dev.
#
#   ./infra/k8s/deploy-dev.ps1
#
# Requisitos: clúster local activo (kubectl get nodes), Docker/nerdctl para construir.
$ErrorActionPreference = "Stop"

# Raíz del repo = dos niveles arriba de este script (infra/k8s/).
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $Root

Write-Host "==> Construyendo imágenes (contexto = $Root)"
docker build -f backend/Dockerfile        -t mezquite/backend:dev        .
if ($LASTEXITCODE -ne 0) { throw "build backend falló" }
docker build -f mock-validator/Dockerfile -t mezquite/mock-validator:dev .
if ($LASTEXITCODE -ne 0) { throw "build mock-validator falló" }

Write-Host "==> Aplicando overlay dev (kubectl apply -k)"
kubectl apply -k infra/k8s/overlays/dev
if ($LASTEXITCODE -ne 0) { throw "kubectl apply falló" }

Write-Host "==> Esperando a que la API esté lista"
kubectl -n mezquite-dev rollout status deploy/api --timeout=180s

Write-Host @"
==> Listo.
   API por NodePort:   http://<nodeIP>:30080/healthz   (nodeIP = kubectl get nodes -o wide)
   o por port-forward: kubectl -n mezquite-dev port-forward svc/api 8000:8000
                       luego http://localhost:8000/healthz
   OpenAPI:            http://localhost:8000/api/v1/openapi.json
"@
