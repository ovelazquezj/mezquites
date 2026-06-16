# CR-008 — Despliegue en Azure (Container Apps) + backend de almacenamiento Azure Blob

| Campo | Valor |
|---|---|
| **ID** | CR-008 |
| **Título** | Despliegue productivo en **Azure** (Container Apps + PostgreSQL Flexible Server + Static Web Apps + Key Vault) y **backend de almacenamiento Azure Blob** |
| **Fecha** | 2026-06-16 |
| **Estado** | **Propuesto — formalizado** (ejecutar tras integrar CR-007; auth real requiere CR-004 W1) |
| **Prioridad** | **Alta** — ruta de lanzamiento (meta **2026-07-10**) |
| **Depende de** | CR-004 **W3** (CORS, ✅) · CR-004 **W1** (Firebase/Google real) para auth pública |
| **Alcance** | Infra Azure + 1 cambio de **backend** (storage). Sin cambios de cliente salvo la **URL de API** del build. |

---

## 1. Contexto y decisiones

Materializa **H6 = Azure** (servidores del patrocinador) como **ruta de lanzamiento**. Decisiones del
usuario: **(1)** Azure por **Container Apps** (gestionado, **sin K8s**); **(2)** **backend nativo de
Azure Blob** (opción B) en `StorageProvider`; **(3)** formalizar CR + runbook (`docs/DESPLIEGUE.md`).

> **Nota sobre contexto seguro:** en Azure la web (Static Web Apps) y la API (Container Apps) van
> **ambas por HTTPS**, así que **NO** se necesita el truco de "un solo origen" (proxy+ngrok); basta
> **CORS** (CR-004 W3) apuntando al dominio del front. Cámara/geolocalización del navegador funcionan.

## 2. Gates (no se enmienda ninguno)
- **Gate #6 (paridad):** el storage sigue **conmutable por config** — se añade `azure_blob` a
  `local | s3 | azure_blob`; dev/QA local intacto. La selección es por variable, no por código de app.
- **Gate #2 (secretos):** todos los secretos viven en **Key Vault**, nunca en git.
- **Gate #5 (obfuscación) / #8 / #1:** sin cambios (lógica de dominio intacta).

## 3. Diseño técnico

### 3.1 Backend — storage Azure Blob (opción B, código)
- `backend/app/storage.py`: nueva clase **`AzureBlobStorage`** (SDK `azure-storage-blob`), seleccionable
  con `STORAGE_BACKEND=azure_blob`. Implementa `put(key, bytes, content_type)`, `get`/`open`, y `url(key)`
  por **SAS** (URL firmada temporal, equivalente al presigned de S3). La DB sigue guardando **solo la
  clave** (gate: nunca el binario).
- `backend/app/config.py`: `azure_storage_account`, `azure_storage_container`, `azure_storage_connection_string`
  (o cuenta+credencial vía Key Vault/Managed Identity), `azure_sas_ttl`.
- `backend/pyproject.toml`: dependencia `azure-storage-blob`.
- **Pruebas:** unidad de `AzureBlobStorage` con un doble/fake del cliente Blob (sin red), y selección por
  config (`STORAGE_BACKEND=azure_blob`); los tests existentes siguen en `local`.

### 3.2 Infra Azure (gestionada, sin K8s)
| Recurso | Servicio | Notas |
|---|---|---|
| Registro de imágenes | **Azure Container Registry (ACR)** | publica `mezquite/backend` |
| API | **Azure Container Apps** | ingress **externo HTTPS**, env desde Key Vault, escala (incl. a 0); migraciones Alembic en el arranque (CMD actual) |
| DB | **Azure Database for PostgreSQL – Flexible Server** | PostGIS preinstalado → allowlist `azure.extensions=POSTGIS` + `CREATE EXTENSION postgis` |
| Imágenes | **Azure Blob Storage** (cuenta + contenedor) | usado por el backend `azure_blob` (SAS) |
| Web (voluntario + admin) | **Azure Static Web Apps** (2 apps, o 1 con rutas) | builds Flutter Web por HTTPS |
| Secretos | **Azure Key Vault** | `AUTH_SECRET`, DB, `AZURE_STORAGE_*`, `SMTP_*`, Firebase |

### 3.3 Config por entorno (Container Apps)
`STORAGE_BACKEND=azure_blob` · `DATABASE_URL=…flexible-server…` · `BROKER=memory` (o Azure Cache/Redis si
se requiere; hoy el submit no encola) · `AUTH_PROVIDER=firebase` (requiere **CR-004 W1**; mock no es para
producción) · `CORS_ALLOW_ORIGINS=https://<web-voluntario>,https://<web-admin>` (CR-004 W3).

### 3.4 Cliente (web)
`flutter build web --dart-define=API_BASE_URL=https://<api-container-app>/api/v1` para **voluntario** y
**admin**; se publican en Static Web Apps. Sin más cambios de cliente.

## 4. Runbook (resumen; detalle paso a paso en `docs/DESPLIEGUE.md` §Azure)
1. **Provisión** (una vez): Resource Group · ACR · Flexible Server (PostGIS allowlisted) · Storage Account+contenedor · Key Vault · Container Apps Environment · Static Web Apps.
2. **Backend Azure Blob** (CR §3.1) + `pyproject` + pruebas → verde.
3. **Build/push** imagen a ACR; `az containerapp up/create` con ingress externo + secretos de Key Vault.
4. **Migraciones** corren al arrancar (initContainer/CMD `alembic upgrade head`). **Bootstrap admin** por CLI (`python -m backend.app.bootstrap`).
5. **Web**: build (voluntario + admin) con la URL de la API → deploy a Static Web Apps.
6. **CORS**: `CORS_ALLOW_ORIGINS` = dominios de las web apps. **Firebase real** (CR-004 W1) + dominios autorizados.
7. **Smoke**: `https://<api>/healthz` ok · registro/login · captura+envío (cámara/geo HTTPS) · revisión humana · dashboards.

## 5. Desglose por agente (al ejecutar)
| # | Agente | Unidad | Archivos |
|---|---|---|---|
| G0 | Arquitecto | confirmar Key Vault/Managed Identity vs connection string; SAS TTL | — |
| G1 | Dev backend | `AzureBlobStorage` + config + `pyproject` + pruebas | `backend/app/storage.py`, `config.py`, `pyproject.toml`, `backend/tests/` |
| G2 | DevOps/ops (con el operador) | ACR · Container Apps · Flexible Server · Static Web Apps · Key Vault | infra/scripts (no toca código de app) |
| G3 | Documentador | runbook Azure en `docs/DESPLIEGUE.md` + secretos por entorno | docs |

## 6. Prerrequisitos del usuario (bloqueantes; el código G1 se hace sin ellos)
Suscripción **Azure** (patrocinador) + permisos · nombres de RG/ACR/cuenta/Key Vault · **dominios** · y para
auth pública el **proyecto Firebase** (CR-004 W1) + dominios autorizados + aviso de privacidad.

## 7. Criterios de aceptación
- AC1: `STORAGE_BACKEND=azure_blob` sube y sirve imágenes (SAS); dev sigue en `local` verde (gate #6).
- AC2: La API corre en Container Apps con **HTTPS** y migraciones aplicadas; `healthz` ok.
- AC3: DB Flexible Server con **PostGIS** activo (geo funciona).
- AC4: Web (voluntario + admin) servidas por HTTPS; **captura con cámara/geo** funciona (contexto seguro); CORS por dominio.
- AC5: Secretos **solo** en Key Vault (nada en git). Pruebas backend verdes con números reales.

## 8. Riesgos
- **Azure Blob ≠ S3**: por eso opción B (backend nativo). El `s3` previo queda disponible para otros proveedores (gate #6).
- **Auth real** depende de CR-004 W1 (Firebase) — no lanzar al público con mock.
- **Costos / cuotas** del patrocinador — confirmar SKU (Flexible Server, Container Apps, Static Web Apps).

## 9. Definition of Done
Backend `azure_blob` con pruebas verdes (dev `local` intacto); API en Container Apps con HTTPS + PostGIS +
migraciones; web por HTTPS con captura funcional; CORS por dominio; secretos en Key Vault; runbook en
`docs/DESPLIEGUE.md`. No enmienda gates.
