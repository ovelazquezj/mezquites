# Requisitos de infraestructura — Azure (QA y Producción)

> **Audiencia:** equipo de infraestructura del patrocinador.
> **Propósito:** crear/aprovisionar los **recursos de Azure** para los entornos **QA** y **Producción** del
> software de ciencia ciudadana del mezquite (Club Rotario Bosques Aguascalientes).
> **Qué NO es:** este documento **no** despliega la aplicación; es el **spec de los assets a crear**. El
> despliegue del código (build de imagen, migraciones, publicación de las web) lo ejecuta el equipo de
> desarrollo **después**, cuando los assets existan y por orden explícita. Diseño y justificación:
> [`docs/change-requests/CR-008-despliegue-azure.md`](change-requests/CR-008-despliegue-azure.md);
> runbook de despliegue: [`docs/DESPLIEGUE.md`](DESPLIEGUE.md).

Última actualización: 2026-06-17.

---

## 1. Arquitectura (gestionada, **sin Kubernetes**)

```
  Navegador (voluntario)            Navegador (operador/consola)
        │  HTTPS                            │  HTTPS
        ▼                                   ▼
  Static Web App  (web voluntario)    Static Web App  (web-admin)
        │                                   │
        └──────────────► CORS ◄─────────────┘
                          │  HTTPS
                          ▼
              Azure Container Apps  ── API FastAPI (HTTPS, autoescala)
                          │
        ┌─────────────────┼───────────────────────────┐
        ▼                 ▼                             ▼
 PostgreSQL Flexible   Blob Storage (imágenes)     Key Vault (secretos)
 Server + PostGIS      contenedor privado + SAS    (Managed Identity)
```

- **API**: contenedor FastAPI en **Azure Container Apps** (ingress externo HTTPS). Aplica las **migraciones
  Alembic al arrancar** (`alembic upgrade head`); requiere DB accesible con **PostGIS**.
- **Web**: dos apps Flutter Web estáticas (**voluntario** y **web-admin**) en **Static Web Apps**.
- **Datos**: **PostgreSQL Flexible Server** con **PostGIS**. **Imágenes**: **Azure Blob Storage**.
- **Secretos**: **Key Vault** (idealmente vía **Managed Identity**, sin cadenas de conexión en texto).
- **Registro de imágenes**: **Azure Container Registry (ACR)**.
- **Observabilidad**: **Log Analytics** + **Application Insights**.

> **No se despliegan** los servicios `result-worker` ni `mock-validator` del `docker-compose` de dev: la
> frontera de validación automática (YOLO/cola §6) está **inactiva** (decisión CR-001). Solo se despliega
> la **API**. El broker/cola queda en `memory` (sin Redis) salvo que se reactive esa frontera (ver §6).

---

## 2. Recursos a crear (por entorno: QA y Prod)

Crear **dos** de cada uno (un Resource Group por entorno). SKUs **sugeridos**; el patrocinador/infra los
confirma según cuota y costo.

| # | Recurso | Servicio Azure | SKU sugerido QA | SKU sugerido Prod | Notas |
|---|---|---|---|---|---|
| 1 | Resource Group | Resource Group | `rg-mezquite-qa` | `rg-mezquite-prod` | uno por entorno |
| 2 | Registro de imágenes | Container Registry (ACR) | `Basic` (puede ser **compartido** entre QA/Prod) | `Standard` | guarda la imagen `mezquite/backend` |
| 3 | Entorno de contenedores | Container Apps Environment | Consumo | Consumo (o Dedicated) | integra Log Analytics |
| 4 | **API** | Container App | 0.5 vCPU / 1 GiB, **min 0–1** | 1 vCPU / 2 GiB, **min 1** (evitar cold start) | ingress **externo HTTPS**; identidad administrada; vars desde Key Vault |
| 5 | **Base de datos** | PostgreSQL **Flexible Server** | `Burstable B1ms`, 32 GB | `General Purpose D2ds_v5`, 128 GB + HA zona | PG 16; **PostGIS**; SSL obligatorio; backups |
| 6 | **Imágenes** | Storage Account + contenedor Blob | `Standard_LRS` | `Standard_ZRS` | contenedor **privado** `observations`; acceso por **SAS**/Managed Identity |
| 7 | **Secretos** | Key Vault | `Standard` | `Standard` (purge protection ON) | RBAC; acceso por Managed Identity |
| 8 | Web voluntario | Static Web App | `Free`/`Standard` | `Standard` | build Flutter Web |
| 9 | Web-admin | Static Web App | `Free`/`Standard` | `Standard` | build Flutter Web |
| 10 | Logs | Log Analytics Workspace | PerGB | PerGB | destino de logs de Container Apps |
| 11 | Métricas/trazas | Application Insights | — | — | conectado al workspace |
| 12 | *(Opcional)* Caché/cola | Azure Cache for Redis | — | `Basic C0` **solo si** se activa la cola §6 | hoy **no requerido** (broker = memory) |
| 13 | *(Recomendado)* Identidad | Managed Identity (system-assigned en la Container App) | — | — | RBAC a Key Vault (Secrets User) y Blob (Storage Blob Data Contributor) |

### Convención de nombres sugerida
`rg-mezquite-{qa|prod}` · ACR `crmezquite` (compartido) · `cae-mezquite-{env}` · `ca-mezquite-api-{env}` ·
`psql-mezquite-{env}` · Storage `stmezquite{env}` (3–24, minúsculas) · `kv-mezquite-{env}` ·
`swa-mezquite-voluntario-{env}` · `swa-mezquite-admin-{env}` · `log-mezquite-{env}` · `appi-mezquite-{env}`.

---

## 3. Base de datos (PostgreSQL Flexible Server + PostGIS)

- **Versión:** PostgreSQL 16.
- **PostGIS (obligatorio):** habilitar la extensión en el server parameter **`azure.extensions = POSTGIS`**
  (allowlist) y luego, una vez creada la base, ejecutar `CREATE EXTENSION IF NOT EXISTS postgis;`
  (y `pgcrypto`). Sin PostGIS la app **no arranca** (la geo y las migraciones lo requieren).
- **Base de datos:** crear una DB llamada `mezquite`.
- **Conexión:** SSL **obligatorio** (`sslmode=require`). La app se conecta con el driver `psycopg` (v3):
  cadena `postgresql+psycopg://USUARIO:CONTRASEÑA@psql-mezquite-{env}.postgres.database.azure.com:5432/mezquite?sslmode=require`.
- **Red:** QA puede usar reglas de firewall (permitir el Container Apps Environment). **Prod**: preferir
  **acceso privado** (VNet/Private Endpoint) entre la API y la DB.
- **Migraciones:** las aplica la API al arrancar (`alembic upgrade head`); idempotentes. No requiere job aparte.
- **Backups/retención:** según política del patrocinador (sugerido: 7 días QA, 30 días Prod + geo-redundante).

---

## 4. Almacenamiento de imágenes (Azure Blob)

- **Cuenta** + **contenedor privado** `observations`. La base de datos guarda **solo la clave** del objeto,
  nunca el binario.
- **Acceso (elige uno):**
  - **Recomendado (Prod):** **Managed Identity** de la Container App con rol *Storage Blob Data Contributor*;
    sin cadena de conexión en variables.
  - **Simple (QA):** **cadena de conexión** en Key Vault (`AZURE_STORAGE_CONNECTION_STRING`).
- Las URLs de imagen se sirven con **SAS** (URL firmada temporal); TTL configurable (`AZURE_SAS_TTL`, def. 3600 s).
- **Privacidad/Gate #5:** las imágenes pueden contener **GPS en EXIF**; la API ya **sanea el GPS** al servir
  imágenes a la consola (salvo a `aliado_firmante`). El contenedor debe ser **privado** (nunca acceso anónimo).
- **Retención:** opcional, lifecycle según política (el dato ecológico se conserva; ver aviso de privacidad).

> El código del backend nativo de Azure Blob (`STORAGE_BACKEND=azure_blob`) corresponde a **CR-008 §3.1** y
> **aún no está implementado** — no bloquea la creación del recurso; infra puede crear la cuenta/contenedor ya.

---

## 5. API — Container App: variables de entorno

La API lee su configuración por **variables de entorno** (Pydantic settings; nombres exactos abajo). Marca
🔒 = **secreto** (Key Vault → referenciado como *secret* de la Container App). Sin marca = configuración plana.

| Variable | 🔒 | QA | Prod | Notas |
|---|:--:|---|---|---|
| `DATABASE_URL` | 🔒 | cadena al server QA | cadena al server Prod | incluye contraseña → secreto; `sslmode=require` |
| `STORAGE_BACKEND` | | `azure_blob` | `azure_blob` | (dev/test usan `local`) |
| `AZURE_STORAGE_ACCOUNT` | | `stmezquiteqa` | `stmezquiteprod` | nombre de la cuenta |
| `AZURE_STORAGE_CONTAINER` | | `observations` | `observations` | |
| `AZURE_STORAGE_CONNECTION_STRING` | 🔒 | (si no se usa Managed Identity) | (preferir MI) | alternativa a MI |
| `AZURE_SAS_TTL` | | `3600` | `3600` | segundos de validez de la URL firmada |
| `BROKER` | | `memory` | `memory` | `redis` solo si se reactiva la cola §6 |
| `REDIS_URL` | 🔒 | — | — | solo si `BROKER=redis` |
| `AUTH_SECRET` | 🔒 | aleatorio ≥32 bytes | aleatorio ≥32 bytes | firma de JWT (sin PII) |
| `AUTH_PROVIDER` | | `mock` (QA interno) / `firebase` | `firebase` | público **requiere** `firebase` (CR-004 W1) |
| `FIREBASE_PROJECT_ID` | | proyecto QA | proyecto Prod | verificación del ID token de Google |
| `GOOGLE_OAUTH_AUDIENCE` | | (opcional) | (opcional) | si el `aud` difiere del project id |
| `CORS_ENV` | | `prod` | `prod` | fuera de dev: solo orígenes explícitos |
| `CORS_ALLOW_ORIGINS` | | `https://<web-voluntario-qa>,https://<web-admin-qa>` | dominios Prod | coma-separado; **nunca** `*` |
| `OBFUSCATION_GRID_M` | | `300` | `300` | gate #5 (celda pública mínima) |
| `SMTP_HOST` | 🔒 | host SMTP | host SMTP | reset de contraseña del administrador |
| `SMTP_PORT` | | `587` | `587` | |
| `SMTP_USER` | 🔒 | usuario | usuario | |
| `SMTP_PASSWORD` | 🔒 | contraseña | contraseña | |
| `SMTP_FROM` | | `no-reply@<dominio>` | `no-reply@<dominio>` | |
| `BOOTSTRAP_ADMIN_USERNAME` | 🔒 | usuario admin inicial | usuario admin inicial | siembra el 1er admin (una vez) |
| `BOOTSTRAP_ADMIN_PASSWORD` | 🔒 | contraseña inicial | contraseña inicial | cambiar tras el primer ingreso |
| `BOOTSTRAP_ADMIN_EMAIL` | 🔒 | correo del admin | correo del admin | único rol con email (gate #2) |

> Si se usa **Managed Identity** para Blob y Key Vault, **no** hace falta `AZURE_STORAGE_CONNECTION_STRING`.
> Sugerencia: cargar **todos** los 🔒 como *secrets* de la Container App **referenciados desde Key Vault**.

---

## 6. Broker / cola (§6) — hoy NO requerido

Tras CR-001 el envío de observaciones **no encola** nada (la validación automática se retiró). Por eso
`BROKER=memory` y **no se necesita Redis** para el lanzamiento. Solo crear **Azure Cache for Redis** y poner
`BROKER=redis` + `REDIS_URL` **si** en el futuro se reactiva la frontera de validación §6.

---

## 7. Web (Static Web Apps)

- Dos apps: **voluntario** y **web-admin**. Se publican los **builds de Flutter Web** (artefactos estáticos).
- **URL de API en tiempo de build** (la define el equipo de desarrollo al compilar, no es config de runtime):
  `flutter build web --dart-define=API_BASE_URL=https://<api-container-app-{env}>/api/v1`.
- **Dominios + TLS:** asignar dominios y certificados gestionados (ver §8). Los dominios de las web deben
  coincidir con `CORS_ALLOW_ORIGINS` de la API.
- La **app del voluntario** requiere **HTTPS** (contexto seguro) para cámara y geolocalización del navegador
  — Static Web Apps ya sirve por HTTPS, así que queda cubierto.

---

## 8. Red, dominios y seguridad

- **HTTPS en todo:** API (Container Apps) y web (Static Web Apps) exponen HTTPS con certificado gestionado.
- **Dominios** (placeholders; el patrocinador confirma el dominio raíz):

  | Componente | QA | Prod |
  |---|---|---|
  | API | `api-qa.<dominio>` | `api.<dominio>` |
  | Web voluntario | `app-qa.<dominio>` | `app.<dominio>` |
  | Web-admin | `admin-qa.<dominio>` | `admin.<dominio>` |

- **CORS:** la API solo acepta los orígenes de `CORS_ALLOW_ORIGINS` (los dominios de las dos web). Nunca `*`.
- **Secretos:** **solo** en Key Vault; nada en el repositorio. Acceso por **Managed Identity** con RBAC.
- **Prod:** preferir **acceso privado** API↔DB (VNet/Private Endpoint) y *purge protection* en Key Vault.
- **PII (gate #2):** la plataforma minimiza PII (handle seudónimo; solo el administrador tiene email). No se
  requieren controles de datos personales más allá de proteger los secretos y los backups de la DB.

---

## 9. Observabilidad

- **Log Analytics Workspace** por entorno; la Container App envía logs ahí.
- **Application Insights** conectado para métricas/trazas de la API.
- Health endpoint para sondas/monitoreo: **`GET https://<api>/healthz`** → `{"status":"ok"}`.

---

## 10. Prerrequisitos externos a Azure (los provee el patrocinador/equipo)

1. **Suscripción Azure** + permisos para crear los recursos de §2.
2. **Dominio(s)** y acceso al DNS para los registros de §8.
3. **Proyecto Firebase / Google Cloud** (auth real, **CR-004 W1**) con *Sign in with Google* habilitado y los
   dominios de las web autorizados. **Sin esto, el público no puede autenticarse** (el `mock` no es para Prod).
4. **Proveedor SMTP** (para el reset de contraseña del administrador). Opcional: si no hay SMTP, el reset
   degrada a "lo hace el administrador" (no bloquea el arranque).
5. **Aviso de privacidad** publicado (requisito de la pantalla de consentimiento de Google).

---

## 11. Checklist de aprovisionamiento (por entorno)

1. [ ] Crear **Resource Group**.
2. [ ] Crear **ACR** (o reutilizar el compartido) y dar *pull* a la Container App.
3. [ ] Crear **PostgreSQL Flexible Server** (PG 16) → allowlist **`azure.extensions=POSTGIS`** → DB `mezquite`
       → `CREATE EXTENSION postgis; CREATE EXTENSION pgcrypto;` → SSL on → regla de red a la API.
4. [ ] Crear **Storage Account** + contenedor privado `observations`.
5. [ ] Crear **Key Vault**; cargar los secretos 🔒 de §5.
6. [ ] Crear **Container Apps Environment** (+ Log Analytics) y **Application Insights**.
7. [ ] Crear la **Container App** de la API con **Managed Identity**; dar RBAC a Key Vault (*Secrets User*) y
       Blob (*Storage Blob Data Contributor*); configurar ingress externo HTTPS y las variables de §5.
8. [ ] Crear las **dos Static Web Apps** (voluntario, admin).
9. [ ] Configurar **dominios + TLS** (§8) y alinear `CORS_ALLOW_ORIGINS`.
10. [ ] *(Solo si se reactiva §6)* Crear **Azure Cache for Redis** y setear `BROKER=redis`/`REDIS_URL`.
11. [ ] Entregar al equipo de desarrollo: nombres de recursos, endpoints, e identidad/credenciales mínimas
        para el despliegue del código (build→ACR, deploy de la API y publicación de las web).

> Tras crear los assets, el **despliegue del código** sigue el runbook de
> [`docs/DESPLIEGUE.md`](DESPLIEGUE.md) (build/push de imagen, arranque con migraciones, bootstrap del
> administrador, publicación de las web y smoke test) — **a ejecutar por orden del equipo**.

---

## 12. Diferencias QA ↔ Producción (resumen)

| Aspecto | QA | Producción |
|---|---|---|
| Auth | `mock` (interno) o `firebase` (QA) | **`firebase`** obligatorio |
| API min replicas | 0–1 (acepta cold start) | ≥1 |
| DB | Burstable, sin HA | General Purpose + HA + backups extendidos |
| Storage redundancia | LRS | ZRS (o GRS) |
| Red API↔DB | firewall | **privada** (VNet/Private Endpoint) |
| Key Vault | Standard | Standard + *purge protection* |
| Redis | no | solo si se activa §6 |

---

*Referencias:* [`CR-008`](change-requests/CR-008-despliegue-azure.md) (diseño y justificación) ·
[`DESPLIEGUE.md`](DESPLIEGUE.md) (runbook de despliegue del código) · `backend/app/config.py` (fuente de
verdad de las variables). Los SKUs y dominios son **sugerencias**; el patrocinador/infra los confirma.
