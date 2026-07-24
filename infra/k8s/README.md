# Despliegue Kubernetes (`infra/k8s/`)

Manifiestos **kustomize** (base + overlays) para el proyecto del mezquite. Espejan la topología ya
definida en [`infra/compose/docker-compose.dev.yml`](../compose/docker-compose.dev.yml) y la
sección §9 de [`ARCHITECTURE.md`](../../docs/arquitectura/ARCHITECTURE.md). Arquitectura **centralizada RC1** (Q8-D1):
una sola instancia lógica; los estados son **filtros geográficos en datos**, NO namespaces ni
instancias por estado.

## Árbol

```
infra/k8s/
├── README.md
├── deploy-dev.sh            # despliegue dev en UN comando (Linux/macOS)
├── deploy-dev.ps1           # despliegue dev en UN comando (Windows / Rancher Desktop)
├── base/                    # manifiestos de TODOS los componentes (T5: la base parametriza stg/prod)
│   ├── kustomization.yaml
│   ├── namespace.yaml       # namespace `mezquite` (los overlays fijan su propio namespace)
│   ├── config.yaml          # ConfigMap (no secretos): BROKER, REDIS_URL, STORAGE_*, DATABASE_URL host
│   ├── secret.example.yaml  # Secret: AUTH_SECRET + credenciales DB (PLACEHOLDERS de dev, nunca prod)
│   ├── redis.yaml           # Deployment + Service (redis:7-alpine), probe redis-cli ping
│   ├── postgres.yaml        # StatefulSet + PVC + Service (postgis/postgis:16-3.4), probe pg_isready
│   ├── api.yaml             # Deployment + Service (FastAPI 8000) + PVC obsdata
│   │                        #   initContainers: wait-postgres + migrate (alembic upgrade head)
│   ├── result-worker.yaml   # Deployment SIN Service (python -m backend.result_worker)
│   └── mock-validator.yaml  # Deployment + Service AISLADO (frontera §6, swappable; gate #10)
└── overlays/
    ├── dev/                 # Rancher Desktop / minikube, SIN NUBE (gate #6)
    │   ├── kustomization.yaml
    │   └── api-nodeport.yaml # acceso a la API por NodePort 30080
    ├── stg/                 # nube: STORAGE_BACKEND=s3, DB/redis gestionados, validador real
    │   ├── kustomization.yaml
    │   ├── managed-endpoints.yaml   # ExternalName placeholders (H6)
    │   ├── scale-zero-postgres.yaml # postgres in-cluster → 0 réplicas
    │   ├── scale-zero-redis.yaml    # redis in-cluster → 0 réplicas
    │   ├── replicas-stg.yaml        # api/worker con más réplicas
    │   └── mock-to-real.yaml        # SWAP frontera §6 (gate #10)
    └── prod/                # idéntico en forma a stg; namespace/tags/réplicas distintos
        └── (mismos archivos que stg)
```

## Componentes (espejan el compose)

| Componente | Recurso K8s | Imagen | Notas |
|---|---|---|---|
| api | Deployment + Service (8000) | `mezquite/backend` | migración Alembic = **initContainer** `migrate` antes de uvicorn |
| result-worker | Deployment (sin Service) | `mezquite/backend` | `python -m backend.result_worker` |
| mock-validator | Deployment + Service | `mezquite/mock-validator` | **frontera §6**, aislado y sustituible (gate #10) |
| postgres | StatefulSet + PVC + Service | `postgis/postgis:16-3.4` | PVC `pgdata` (2Gi) para `/var/lib/postgresql/data` |
| redis | Deployment + Service | `redis:7-alpine` | sin persistencia (la cola es transitoria) |

Config/secretos: `api` y `result-worker` leen el **mismo** `ConfigMap` (`mezquite-config`) y `Secret`
(`mezquite-secret`) vía `envFrom`. El mock lee `mezquite-mock-config`. Probes: `redis-cli ping`,
`pg_isready`, y `/healthz` (HTTP, sin tocar DB) para la API.

## Dev: levantar con UN SOLO comando (T5, gate #6)

Requiere un clúster local activo (`kubectl get nodes`) — Rancher Desktop ya lo provee.

```bash
# Opción A: el script (construye imágenes + aplica overlay + espera readiness)
./infra/k8s/deploy-dev.sh           # Linux/macOS
./infra/k8s/deploy-dev.ps1          # Windows / Rancher Desktop

# Opción B: a mano (si las imágenes :dev ya existen en el runtime del clúster)
kubectl apply -k infra/k8s/overlays/dev
```

El overlay dev corre **sin nube** (gate #6): `STORAGE_BACKEND=local` con PVC, y redis + postgis
**dentro del clúster**. Acceso a la API:

```bash
# NodePort
http://<nodeIP>:30080/healthz          # nodeIP = kubectl get nodes -o wide
# o port-forward
kubectl -n mezquite-dev port-forward svc/api 8000:8000
http://localhost:8000/api/v1/openapi.json
```

> **Imágenes y Rancher Desktop:** con backend Docker (moby) las imágenes `:dev` que construyes son
> visibles para el clúster. Con backend **containerd**, construye dentro del namespace del clúster:
> `nerdctl --namespace k8s.io build -f backend/Dockerfile -t mezquite/backend:dev .` (idem mock).
> Las imágenes son `imagePullPolicy` por defecto (`IfNotPresent` para tags no-`latest`), así que no
> intenta tirar de un registry remoto.

> **PVC `obsdata` (RWO):** `api` y `result-worker` comparten el PVC del storage local. En dev (un
> nodo) ambos pods caben en el mismo nodo, así que `ReadWriteOnce` basta. En stg/prod el storage es
> S3 y el PVC queda ocioso (sin contención multi-nodo).

## stg / prod: los MISMOS manifiestos, parametrizados (T5)

Los overlays **no duplican** recursos: aplican `kustomize` sobre la misma base. Cambios por entorno:

| Parámetro | dev | stg / prod |
|---|---|---|
| namespace | `mezquite-dev` | `mezquite-stg` / `mezquite-prod` |
| `STORAGE_BACKEND` | `local` (+PVC) | `s3` (object storage S3-compatible) |
| DB / Redis | in-cluster | **gestionados** vía `ExternalName` (placeholders, H6) |
| postgres/redis in-cluster | 1 réplica | **0 réplicas** (se usan los gestionados) |
| réplicas api/worker | 1 | 2 (stg) / 3 (prod) |
| validador | `mock-validator` | **validador real** (swap, gate #10) |

```bash
kubectl kustomize infra/k8s/overlays/stg     # render
kubectl kustomize infra/k8s/overlays/prod
```

### H6 (decisión humana pendiente): proveedor cloud

No se inventa proveedor. Los endpoints gestionados son **placeholders** parametrizables:

- `overlays/{stg,prod}/managed-endpoints.yaml` — `ExternalName` (`postgres-managed`, `redis-managed`).
  El operador sustituye `externalName` por el hostname real (RDS/CloudSQL, ElastiCache/MemoryStore…).
  `DATABASE_URL`/`REDIS_URL` NO cambian al elegir proveedor: solo cambia el `externalName`.
- `S3_*` (bucket/endpoint/region) — placeholders en el `configMapGenerator` del overlay.
- `mezquite-secret` — en stg/prod **no se versiona**; provéelo como Secret externo (gestor de secretos).

## Frontera §6 — swap mock → validador real (gate #10)

El [`mock-validator`](base/mock-validator.yaml) es un Deployment **aislado**. Pasar al validador real
= **sustituir SOLO ese Deployment**, sin tocar `api`, `result-worker` ni clientes (mismo Redis,
mismos streams `validation_jobs`/`validation_results`, mismo contrato §6). En los overlays cloud el
swap es declarativo:

- `images:` repunta la imagen a `mezquite-validacion-yolo` (otro repo; tag placeholder hasta H6).
- `mock-to-real.yaml` anula el `command` del mock (la imagen real usa su propio entrypoint).

El veredicto sigue recomputándose **autoritativo en el backend** (gate #9), así que el validador real
no requiere confianza extra: solo cumplir el contrato §6.

## Validación realizada

```bash
kubectl kustomize infra/k8s/overlays/{dev,stg,prod}        # render limpio (487/490/490 líneas)
kubectl apply -k infra/k8s/overlays/dev --dry-run=client   # 15 recursos OK
kubectl apply -k infra/k8s/overlays/dev --dry-run=server   # 15 recursos OK contra k3s v1.30
```
