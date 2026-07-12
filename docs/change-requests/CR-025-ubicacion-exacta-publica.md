# CR-025 — Ubicación EXACTA pública (retira la obfuscación del gate #5)

- **Fecha:** 2026-07-12
- **Estado:** ✅ Integrado en `main`
- **Autoriza:** el usuario (orquestador humano), por **decisión de gobernanza del Club Rotario Bosques
  Aguascalientes**.
- **Depende de:** CR-009 (mapa de calor público), CR-023 (ubicación exacta en la consola).
- **Enmienda de gates:** **retira la parte pública del gate #5** (obfuscación). Ver bitácora (gate #5,
  Q5.B-D1 y la salvaguarda EXIF de CR-001).

## 1. Objetivo

Que la plataforma **guarde y presente la ubicación exacta** del mezquite en **todas** las vistas —la app
del voluntario (móvil y web) y la consola de administración—, retirando la obfuscación a celda de ~300 m
que hasta ahora aplicaba a las vistas públicas.

El almacenamiento ya era exacto (`geom` exacto en la DB); este CR actúa sobre la **capa de presentación**
y los **textos/documentos**. No hay migración de datos.

## 2. Alcance de la decisión

- **Vista pública** (app del voluntario móvil/web y `GET /public/*`): pasa a mostrar la **ubicación
  exacta** del árbol. Se **conserva el mapa de calor** y se **añaden pines exactos** por árbol mediante un
  toggle *calor ⇄ exacto* (default calor).
- **Consola de administración:** se **conserva** el toggle *calor ⇄ exacto*; el modo exacto se abre a
  **todos** los roles de consola (se añade `evaluador` a `EXACT_LOCATION_ROLES`) y se retira el marco de
  "uso interno para reportes / no publicar sin obfuscar".
- **Código de obfuscación (no se elimina):** `geo.obfuscate_to_grid` se conserva **solo** como *binning*
  del mapa de calor (agregación de densidad/severidad); `app/exif.py`/`strip_gps` deja de aplicarse al
  servir la imagen de revisión y queda **ocioso**. Ninguna función se borra.
- **Legales:** el punto 5 del Aviso de privacidad y de los Términos (y sus páginas HTML públicas) se
  actualiza para reflejar que las vistas públicas muestran la ubicación registrada del árbol. **Texto
  re-aprobado por el Club.**

## 3. Fuera de alcance / notas

- No se toca la captura (ya guarda EXIF/GPS exacto), ni la autenticación, ni los roles salvo el ajuste de
  `EXACT_LOCATION_ROLES`.
- **Nota de gobernanza:** exponer públicamente la ubicación exacta es, en la práctica, **irreversible** una
  vez publicada (los datos exactos quedan expuestos e indexables). La decisión es consciente y autorizada.

## 4. Desglose por unidad construible

- **Dev backend:** `routers/public.py` (público exacto; grid = binning), `models.py`
  (`EXACT_LOCATION_ROLES` += `evaluador`), `routers/restricted.py` (reencuadre), `routers/analytics.py`
  (CSV exacto), `routers/review.py`/`exif.py` (retira `strip_gps`), `geo.py`/`config.py` (reencuadre),
  pruebas.
- **Dev móvil / web-voluntario:** `heat_map_screen.dart` (toggle + pines exactos), API/estado/modelo
  (`publicObservations`), `copy.dart` (textos sin "~300 m/aproximada"), pruebas.
- **Dev web-admin:** `map_screen.dart` (toggle para todos, sin banner de uso interno), `session.dart`
  (getters ampliados), `restricted_dashboard_screen.dart`/`public_dashboard_screen.dart`, `copy.dart`,
  pruebas.
- **Documentador (orquestador):** bitácora (enmienda), `ARCHITECTURE.md`, `TRACEABILITY.md`,
  `postgis-model.md`, `docs/legal/*` + `infra/compose/legal/*`, README, CLAUDE.md.

## 5. Criterios de aceptación

Ver la sección **CR-025** en [`TRACEABILITY.md`](../cambios/TRACEABILITY.md) (AC1–AC8). Definition of Done:
todas las suites verdes con números reales reportados, gates verificados, trazabilidad y bitácora
actualizadas, legales sincronizados md↔html.

## 6. Despliegue

Es **piloto vivo** en la VM Hetzner. Requiere recompilar los bundles Flutter **localmente**, publicar la
rama `deploy` y subirlos a la VM (scp/rsync + `docker compose` para el backend y `restart caddy` para el
estático y las páginas legales). **No se despliega sin orden explícita del usuario.**
