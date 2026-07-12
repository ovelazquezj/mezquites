# Mezquite — Software de ciencia ciudadana

Plataforma del piloto de **ciencia ciudadana del mezquite** (*Prosopis laevigata*) y sus parásitos
visibles (paxtle y cúscuta). Permite a personas voluntarias **documentar** el estado de los árboles
con foto + ubicación, y al equipo del **Club Rotario Bosques Aguascalientes** revisar, agregar y
publicar el dato ecológico abierto. Plataforma de referencia: **eBird** (participación abierta, sin
certificación ni gating).

**Estado:** `beta-2606` · **303 pruebas verdes** (21 contrato · 9 mock · 136 backend · 62 móvil · 75 web-admin).

## Qué es y qué no es

- **Es** una plataforma de **concientización y observación** ciudadana: registro abierto, sin
  certificación, dataset de acceso abierto con caveat de origen ciudadano.
- **No** promete control fitosanitario, reducción medible de infestación, ni recomendaciones de manejo
  químico/mecánico (límite de alcance del proyecto).
- **Identidad con PII mínima:** el voluntario entra con Google y solo se guarda un identificador opaco
  (sin nombre ni correo); únicamente el rol administrador conserva correo (para recuperar acceso).
- Las vistas públicas muestran la **ubicación exacta** del árbol (junto a un mapa de calor agregado).

## Componentes

| Componente | Tecnología | Qué hace |
|---|---|---|
| **App del voluntario** | Flutter (móvil **y** web) | captura con cámara + EXIF, mapa de calor público, "Aprender", perfil/evidencia |
| **Consola (web-admin)** | Flutter Web | revisión humana de observaciones, datos/CSV, mapa, instituciones, indicadores |
| **Backend** | FastAPI + PostgreSQL/PostGIS | API REST, auth por roles, agregación (mapa de calor), analítica |
| **Frontera de validación §6** | contrato + mock (cola) | integración con un validador de imágenes externo (YOLO) — **hoy inactiva**, conservada para reactivar |

## Arranque rápido

```bash
# Pruebas de la frontera (sin Redis)
cd contract/python && python -m pytest -q
cd ../../mock-validator && python -m pytest -q

# Stack de desarrollo (sin nube): PostGIS + Redis + API
docker compose -f infra/compose/docker-compose.dev.yml up --build -d
curl http://localhost:8000/healthz          # -> {"status":"ok"}
```

- Runbook paso a paso (levantar y revisar las dos UIs): [`docs/despliegue/QUICKSTART.md`](docs/despliegue/QUICKSTART.md).
- **Despliegue en un solo servidor** (cloud o propio, con Docker + Caddy/TLS): [`docs/despliegue/DESPLIEGUE-SERVIDOR-UNICO.md`](docs/despliegue/DESPLIEGUE-SERVIDOR-UNICO.md).
- Despliegue gestionado (K8s / Azure): [`docs/despliegue/DESPLIEGUE.md`](docs/despliegue/DESPLIEGUE.md).

## Estructura del repositorio

| Carpeta | Qué es |
|---|---|
| [`contract/`](contract/README.md) | `mezquite_contract` — frontera §6 (schemas, modelos, broker conmutable) |
| [`mock-validator/`](mock-validator/README.md) | Worker que cumple §6 mientras no exista el YOLO real |
| [`backend/`](backend/README.md) | FastAPI + PostGIS: API, auth por roles, agregación (mapa de calor), analítica |
| [`mobile/`](mobile/) | App Flutter del voluntario (móvil + web) |
| [`web-admin/`](web-admin/) | Consola del Club (Flutter Web) |
| [`infra/`](infra/) | Compose (dev + prod single-host) + manifiestos K8s |
| [`scripts/`](scripts/README.md) | Administración del stack (PowerShell) |
| [`docs/`](docs/README.md) | Toda la documentación (ver índice) |

## Documentación

- **Fuente de verdad (SDD):** [`docs/sdd/bitacora_sdd_mezquite.md`](docs/sdd/bitacora_sdd_mezquite.md) — decisiones selladas; no se reabren.
- **Arquitectura:** [`docs/arquitectura/ARCHITECTURE.md`](docs/arquitectura/ARCHITECTURE.md).
- **Trazabilidad** (criterio de aceptación → prueba): [`docs/cambios/TRACEABILITY.md`](docs/cambios/TRACEABILITY.md).
- **Solicitudes de cambio (CR):** [`docs/change-requests/`](docs/change-requests/README.md).
- Índice completo: [`docs/README.md`](docs/README.md).

## Principios innegociables (gates)

Límite de alcance (sin control fitosanitario) · PII mínima (identidad opaca; solo admin con correo) ·
sin gating (todo abierto desde el día 1) · captura solo con cámara nativa + EXIF · **ubicación pública
exacta** (con mapa de calor agregado) · paridad de entornos (DB/storage/broker conmutables por config, dev/QA sin nube) ·
trazabilidad (cada criterio con prueba) · revisión **humana** de la calidad (sin validación automática).

## Cómo correr las pruebas

```bash
cd contract/python && python -m pytest -q
cd mock-validator   && python -m pytest -q
cd backend          && python -m pytest -q     # usa un PostGIS en contenedor
cd mobile           && flutter test
cd web-admin        && flutter test
```

## Convenciones

- Idioma del repo: **español** (código, documentación y commits).
- Commits estilo `feat(...)` / `fix(...)` / `docs:` / `chore(...)`.

## Licencia

**MIT** — © 2026 **Club Rotario Bosques Aguascalientes** (titular). Autoría: **Omar Velázquez**
<ovelazquezj@gmail.com>. Ver [`LICENSE`](LICENSE).
