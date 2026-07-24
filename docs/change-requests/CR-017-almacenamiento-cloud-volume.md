# CR-017 — Imágenes y base de datos en el Cloud Volume (bind durable y configurable)

| Campo | Valor |
|---|---|
| **ID** | CR-017 |
| **Fecha** | 2026-06-28 |
| **Estado** | ✅ **Integrado en `main`** + aplicado en la VM del piloto |
| **Alcance** | `infra/compose/` · `docs/despliegue/` · operación en la VM |
| **Depende de** | CR-014 (despliegue en un solo servidor) |
| **Ejecución** | Directo sobre `main`, por el orquestador |

## 1. Problema

El `docker-compose.prod.yml` montaba las imágenes (`api → /data/storage`) y la base de datos
(`postgres → /var/lib/postgresql/data`) en **volúmenes nombrados de Docker**, que viven en
`/var/lib/docker` del **disco raíz** de la VM (en el piloto, un CX22 con un disco chico). Con ~57 k fotos
previstas para el resto de 2026 (~171 GB) eso **saturaría el disco raíz**. La VM tiene un **Cloud Volume**
de Hetzner (157 GB) montado en `/mnt/HC_Volume_106165488`, que es el lugar correcto para esos datos.

El parche inicial (bind directo editado a mano en la VM) **se perdía en cada redeploy** porque el
`git archive` de la rama `deploy` pisa el `docker-compose.prod.yml`. Hacía falta una solución **durable y
versionada**.

## 2. Decisiones del usuario (2026-06-28)
1. Mover **las imágenes** al Cloud Volume.
2. Mover **también la base de datos (`pgdata`)** al Cloud Volume (durabilidad + snapshots/backup).
3. Documentarlo como **CR separado** (CR-017).

## 3. Qué se hizo
| Pieza | Detalle |
|---|---|
| `docker-compose.prod.yml` | Montajes **parametrizados**: `- ${OBSDATA_HOST_DIR:-obsdata}:/data/storage` y `- ${PGDATA_HOST_DIR:-pgdata}:/var/lib/postgresql/data`. Sin variables ⇒ volúmenes nombrados (dev); con ruta ⇒ bind al Cloud Volume (prod). |
| `.env.prod.example` | Nuevas variables `OBSDATA_HOST_DIR` / `PGDATA_HOST_DIR` con guía (vacías = named volume). |
| Runbooks | `DESPLIEGUE-HETZNER.md §5.2`, `DESPLIEGUE-SERVIDOR-UNICO.md`: documentan las variables, exigen **`--env-file infra/compose/.env.prod`** (para que la interpolación tome los valores) y **quitan** el paso manual de re-bind tras cada deploy. Incluyen el procedimiento de **migración** de datos existentes (con el stack detenido, `cp -a` del contenido de los volúmenes nombrados). |
| VM del piloto | `.env.prod` con `OBSDATA_HOST_DIR=/mnt/HC_Volume_106165488/obsdata` y `PGDATA_HOST_DIR=/mnt/HC_Volume_106165488/pgdata`; `pgdata` migrado (preservando el admin sembrado); stack levantado con `--env-file`. |

## 4. Gates
- **Gate #6 (paridad de entornos / storage conmutable por config):** **reforzado** — la ruta de
  almacenamiento es ahora configuración, no código; dev usa volúmenes nombrados sin tocar nada.
- **Gate #5 (obfuscación) / gate #2 (sin PII):** sin cambios — solo cambia *dónde* se guardan los
  bytes, no qué se guarda ni cómo se sirve (el EXIF-GPS se sigue saneando al servir a revisión).
- Resto de gates: sin cambios.

## 5. Verificación
- En la VM: una captura real aterriza en `/mnt/HC_Volume_106165488/obsdata`; `df -h` del volumen crece;
  la base responde con el admin previo tras la migración de `pgdata`.

## 6. Notas
- El *spool* temporal de subida multipart usa `/tmp` del disco raíz de forma **transitoria** (se borra
  al terminar el request); no acumula. Si se quisiera cero uso del raíz en subidas, se fijaría `TMPDIR`
  del contenedor `api` al volumen (no necesario hoy).
- `caddy_data`/`caddy_config` (certificados TLS) se quedan en el disco raíz (tamaño ínfimo).
