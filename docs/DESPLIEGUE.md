# Guía de despliegue — Dev · QA · Producción

Cómo **preparar y levantar** los tres entornos del proyecto del mezquite. El principio rector es el
**gate #6 (paridad de entornos):** todo recurso con dependencia de infraestructura (base de datos,
storage, broker) se selecciona **por configuración**, nunca por código. Cambiar de entorno = cambiar
variables y manifiestos, no fuente.

> **Nomenclatura:** en el repo los overlays de Kubernetes se llaman `dev`, `stg`, `prod`.
> En esta guía **QA = `stg`** (staging). Si prefieres renombrarlo a `qa`, es un cambio mecánico de
> kustomize; pídelo y lo aplico.

> **Fuente de verdad de infra:** [`infra/k8s/README.md`](../infra/k8s/README.md) y
> [`ARCHITECTURE.md`](../ARCHITECTURE.md) §9. Esta guía es el runbook operativo de alto nivel.

---

## 1. Los tres entornos de un vistazo

| | **Dev** (local + servicios) | **QA** (nube) = overlay `stg` | **Producción** = overlay `prod` |
|---|---|---|---|
| Dónde corre | Tu máquina (Docker/Rancher o k3s local) | Clúster Kubernetes en nube | Clúster Kubernetes en nube |
| Nube | **No** (gate #6) | **Sí** | **Sí** |
| Storage | `local` (filesystem + PVC) | `s3` (object storage S3-compat) | `s3` |
| Base de datos | PostGIS **in-cluster**/contenedor | PostGIS **gestionado** (H6) | PostGIS **gestionado** (H6) |
| Redis | in-cluster/contenedor | **gestionado** (H6) | **gestionado** (H6) |
| Réplicas api/worker | 1 | 2 | 3 |
| Namespace | `mezquite-dev` | `mezquite-stg` | `mezquite-prod` |
| Secretos | placeholders en git | **Secret externo** (no versionado) | **Secret externo** (no versionado) |
| Validador de imágenes | mock (inactivo, ver §6) | — (inactivo, ver §6) | — (inactivo, ver §6) |

**H6** = *decisión humana pendiente: proveedor cloud.* La infra **no inventa proveedor**: usa
**placeholders** (`ExternalName`, `S3_*`) que el operador sustituye. Da igual AWS/GCP/Azure: solo
cambian los endpoints y el gestor de secretos, **no** los manifiestos ni el código.

---

## 2. Configuración conmutable (el corazón del gate #6)

Toda la diferencia entre entornos vive en estas variables (ver
[`backend/app/config.py`](../backend/app/config.py)):

| Variable | Dev | QA / Prod | Para qué |
|---|---|---|---|
| `DATABASE_URL` | `…@postgres:5432/mezquite` (in-cluster) | `…@postgres-managed:5432/…` (gestionada) | PostgreSQL **+ PostGIS** |
| `STORAGE_BACKEND` | `local` | `s3` | dónde viven las imágenes (la DB solo guarda la clave) |
| `STORAGE_LOCAL_DIR` | `/data/storage` (PVC) | — | raíz del filesystem local |
| `S3_BUCKET` / `S3_REGION` / `S3_ENDPOINT_URL` | — | valores reales (H6) | object storage |
| `S3_ACCESS_KEY` / `S3_SECRET_KEY` | — | **secreto** (H6) | credenciales S3 |
| `BROKER` | `memory` o `redis` | `redis` | cola §6 (transitoria) |
| `REDIS_URL` | `redis://redis:6379/0` | `redis://redis-managed:6379/0` | broker gestionado |
| `AUTH_SECRET` | placeholder inseguro | **secreto rotado** | firma de tokens JWT |

`api` y `result-worker` leen el **mismo** `ConfigMap` (`mezquite-config`, no secreto) y `Secret`
(`mezquite-secret`) por `envFrom`.

---

## 3. Dev — local + servicios

Dos formas; elige según lo que quieras probar.

### 3.A — Docker Compose (la más simple, recomendada para el día a día)

```powershell
docker compose -f infra/compose/docker-compose.dev.yml up --build -d
docker compose -f infra/compose/docker-compose.dev.yml ps      # 3 servicios arriba
curl.exe http://localhost:8000/healthz                          # -> {"status":"ok"}
```

Levanta el **núcleo**: `postgres` (PostGIS), `redis`, `api`. La API aplica las migraciones Alembic al
arrancar (incluida `0002_revision_humana`). **CR-001 (revisión humana):** `result-worker` y
`mock-validator` ya **no arrancan por defecto** (la frontera §6/YOLO quedó inactiva); viven tras el
perfil `yolo` por si se reactiva a futuro:

```powershell
# Solo si quieres levantar la frontera §6 (hoy ociosa):
docker compose -f infra/compose/docker-compose.dev.yml --profile yolo up --build -d
```

**Detalle completo (poblar datos, revisar UIs):** [`QUICKSTART.md`](../QUICKSTART.md).

> Para probar en un **teléfono real** por HTTPS, usa `scripts\demo.ps1` (túnel ngrok) — ver el
> QUICKSTART, Parte 4-bis.

### 3.B — Kubernetes local (mismos manifiestos que QA/Prod, sin nube)

Requiere un clúster local activo (Rancher Desktop lo provee: `kubectl get nodes`).

```powershell
.\infra\k8s\deploy-dev.ps1                 # construye imágenes :dev, aplica overlay dev, espera readiness
# o, si las imágenes :dev ya existen:
kubectl apply -k infra/k8s/overlays/dev
kubectl -n mezquite-dev port-forward svc/api 8000:8000
```

Corre **sin nube** (gate #6): `STORAGE_BACKEND=local` con PVC, y redis + postgis **dentro** del
clúster. Acceso por NodePort `30080` o `port-forward`.

> **Rancher Desktop con backend containerd:** construye las imágenes dentro del namespace del clúster
> `nerdctl --namespace k8s.io build -f backend/Dockerfile -t mezquite/backend:dev .` (ídem mock).

**Requisitos Dev:** Docker (Rancher Desktop) · `kubectl` · (para los clientes) Flutter 3.27 + Android
SDK · Python 3.13 para correr pruebas.

---

## 4. QA (nube) — overlay `stg`

QA es la **primera vez que tocamos nube**. Aquí se materializa **H6**.

### 4.1 Provisiona la infraestructura gestionada (una vez)

| Recurso | Qué necesitas | Ejemplos por proveedor |
|---|---|---|
| **Registro de contenedores** | Para publicar `mezquite/backend:stg` | ECR (AWS) · Artifact Registry (GCP) · ACR (Azure) |
| **PostgreSQL + PostGIS** | Instancia gestionada con la **extensión PostGIS** habilitada | RDS PostgreSQL + PostGIS · Cloud SQL + PostGIS · Azure DB for PostgreSQL |
| **Redis** | Instancia gestionada | ElastiCache · Memorystore · Azure Cache |
| **Object storage** | Bucket S3-compatible + credenciales | S3 · GCS (modo S3) · Azure Blob (vía gateway S3) |
| **Gestor de secretos** | Para el `Secret` externo (no versionado) | Secrets Manager · Secret Manager · Key Vault |
| **Clúster Kubernetes** | Para aplicar los overlays | EKS · GKE · AKS |
| **Ingress + TLS + DNS** | Exponer la API por HTTPS | Ingress NGINX/ALB + cert-manager/ACM |

### 4.2 Construye y publica las imágenes

```bash
docker build -f backend/Dockerfile -t <REGISTRY>/mezquite/backend:stg .
docker push <REGISTRY>/mezquite/backend:stg
```

### 4.3 Rellena los placeholders del overlay (H6)

- `infra/k8s/overlays/stg/managed-endpoints.yaml` → sustituye `externalName` por el hostname real de
  la DB y de Redis gestionados.
- `infra/k8s/overlays/stg/kustomization.yaml` → `S3_BUCKET`, `S3_REGION`, `S3_ENDPOINT_URL` reales y
  el `newName/newTag` de la imagen apuntando a tu registry.

### 4.4 Crea el `Secret` externo (NO se versiona en git)

```bash
kubectl -n mezquite-stg create secret generic mezquite-secret \
  --from-literal=AUTH_SECRET="$(openssl rand -hex 32)" \
  --from-literal=POSTGRES_USER=... --from-literal=POSTGRES_PASSWORD=... \
  --from-literal=S3_ACCESS_KEY=... --from-literal=S3_SECRET_KEY=...
```

> En producción real, provee el `Secret` desde el **gestor de secretos** (External Secrets Operator,
> CSI driver, etc.), no a mano.

### 4.5 Aplica y verifica

```bash
kubectl kustomize infra/k8s/overlays/stg            # revisa el render antes de aplicar
kubectl apply -k infra/k8s/overlays/stg
kubectl -n mezquite-stg get pods                    # api/worker Ready; pg/redis in-cluster a 0
kubectl -n mezquite-stg logs deploy/api -c migrate  # migraciones Alembic OK (initContainer)
curl https://<tu-dominio-qa>/healthz                # -> {"status":"ok"}
```

Las migraciones corren solas como **initContainer** `migrate` (`alembic upgrade head`) antes de
uvicorn. `postgres`/`redis` in-cluster quedan a **0 réplicas** (se usan los gestionados).

---

## 5. Producción — overlay `prod`

**Idéntico en forma a QA**, con diferencias de escala y disciplina:

| Aspecto | QA (`stg`) | Producción (`prod`) |
|---|---|---|
| Réplicas api/worker | 2 | 3 |
| Tags de imagen | `:stg` | `:prod` (inmutables/versionadas) |
| Namespace | `mezquite-stg` | `mezquite-prod` |
| Secretos | gestor de secretos | gestor de secretos + **rotación** |
| Datos | desechables | **backups** + plan de restauración |
| Observabilidad | básica | logs + métricas + alertas |

Mismo procedimiento que §4 cambiando `stg`→`prod`. **Antes del primer despliegue productivo**, cierra
los pendientes de la §7.

---

## 6. Cambios en camino que afectan el despliegue

> Estos cambios están **acordados pero aún no implementados**. Los anoto aquí para que la guía esté
> lista cuando aterricen.

- **Sin validador ML/YOLO (revisión humana):** la observación se **acepta por defecto** y la revisión
  es humana desde la UI del backend. En consecuencia, `result-worker` y `mock-validator` quedan
  **inactivos**: en QA/Prod **no** se hace el swap a YOLO; se escalan a 0 o se quitan del overlay.
  El contrato §6 y el mock se conservan en el repo, dormidos, por si se reactiva ML a futuro.
- **Auth con identidad real (gate #2 enmendado):**
  - **App (voluntarios):** *Sign in with Google* vía **Firebase Auth**. Se requiere un **proyecto
    Firebase** (Google Cloud — esto define H6 al menos para auth), su `google-services.json` en el
    build móvil, y que el backend **verifique el ID token**. Nuevos parámetros de config/secreto para
    la verificación (p. ej. `GOOGLE_OAUTH_AUDIENCE` / credenciales Firebase Admin).
  - **Backend (administrador/evaluador/analista):** **usuario + contraseña** (hashing argon2/bcrypt).
    Solo el **administrador** guarda email para **reset por correo** → en QA/Prod hace falta **SMTP**
    (variables `SMTP_*` como secreto). El primer administrador se crea por **config/CLI** (bootstrap).
  - **Proveedor de auth conmutable** (gate #6): un **mock** de auth en dev/QA-test para no depender de
    Google offline; real en producción.
  - **Legal/operativo (no software):** **aviso de privacidad** publicado + **borrado de datos**
    (exigidos por Google/Play y por la LFPDPPP). Sin esto la app no puede salir de modo desarrollo.

---

## 7. Checklist "antes de producción"

- [ ] **H6 resuelto:** proveedor cloud elegido; endpoints gestionados (DB/Redis/S3) reales.
- [ ] **Secretos fuera de git:** `AUTH_SECRET` rotado; credenciales DB/S3/SMTP desde gestor de secretos.
- [ ] **PostGIS habilitado** en la DB gestionada (extensión instalada).
- [ ] **TLS/HTTPS** en el ingress + dominio.
- [ ] **CORS habilitado** en el backend (hoy el web admin usa un workaround de Chrome — *arreglo
      diferido*).
- [ ] **Registro restringido a `voluntario`** + bootstrap de admin por config/CLI (cierra el hueco del
      gate #5 — *arreglo diferido*, parte del plan de auth).
- [ ] **Aviso de privacidad + borrado de datos** publicados (requisito de la auth con identidad real).
- [ ] **Backups** de la DB y plan de restauración probado.
- [ ] **Smoke test** `register → submit → revisión humana → dashboard` en el entorno destino.

---

## 8. Referencias

- [`infra/k8s/README.md`](../infra/k8s/README.md) — detalle de manifiestos, overlays y el swap §6.
- [`infra/compose/docker-compose.dev.yml`](../infra/compose/docker-compose.dev.yml) — stack local.
- [`QUICKSTART.md`](../QUICKSTART.md) — arrancar y revisar las UIs paso a paso.
- [`backend/app/config.py`](../backend/app/config.py) — todas las variables conmutables.
- [`ARCHITECTURE.md`](../ARCHITECTURE.md) — arquitectura y §9 de despliegue.
