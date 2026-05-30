#!/usr/bin/env bash
# Despliegue DEV en clúster K8s local (Rancher Desktop / minikube), SIN NUBE (gate #6, T5).
# UN SOLO COMANDO: construye las imágenes (contexto = raíz del repo) y aplica el overlay dev.
#
#   ./infra/k8s/deploy-dev.sh
#
# Requisitos: un clúster local activo (kubectl get nodes), Docker/nerdctl para construir.
set -euo pipefail

# Raíz del repo = dos niveles arriba de este script (infra/k8s/).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

echo "==> Construyendo imágenes (contexto = $ROOT)"
docker build -f backend/Dockerfile        -t mezquite/backend:dev        .
docker build -f mock-validator/Dockerfile -t mezquite/mock-validator:dev .

echo "==> Aplicando overlay dev (kubectl apply -k)"
kubectl apply -k infra/k8s/overlays/dev

echo "==> Esperando a que la API esté lista"
kubectl -n mezquite-dev rollout status deploy/api --timeout=180s

cat <<'EOF'
==> Listo.
   API por NodePort:   http://<nodeIP>:30080/healthz   (nodeIP = kubectl get nodes -o wide)
   o por port-forward: kubectl -n mezquite-dev port-forward svc/api 8000:8000
                       luego http://localhost:8000/healthz
   OpenAPI:            http://localhost:8000/api/v1/openapi.json
EOF
