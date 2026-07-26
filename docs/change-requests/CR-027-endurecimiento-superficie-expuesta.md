# CR-027 — Endurecimiento de la superficie expuesta del backend

- **Fecha:** 2026-07-25
- **Estado:** ✅ Integrado en `main`
- **Origen:** auditoría de "¿todas las peticiones al API están autenticadas por token?" (pregunta del
  usuario, 2026-07-25). Se revisaron los 14 routers endpoint por endpoint.
- **Enmienda de gates:** ninguna. Refuerza el gate #2 y el modelo de roles existente.

## 1. Resultado de la auditoría

La mayoría del API sí exige token. Tres categorías:

**Sin token por diseño (correcto):** `/public/observations`, `/public/grid`, `/public/indicators` (el
mapa público sin login, CR-009), `GET /institutions`, los `/auth/*` y `/healthz`.

**Auth opcional por diseño:** `POST /problem-reports` (`get_current_user_optional`) — para poder
reportar un problema antes de entrar (CR-019).

**Todo lo demás exige token:** `/me/*`, `/observations/*`, `/review/*`, `/restricted/*`, `/admin/*`,
`/gamification/*`. Ninguno quedó sin `Depends`.

Se encontraron **dos huecos** y una mitigación pendiente.

## 2. `GET /files/{key}` servía las fotos sin autenticación

`main.py` montaba una ruta que sirve las imágenes desde el filesystem **sin ninguna dependencia de
autenticación**. No era solo dev: producción corre con `STORAGE_BACKEND=local` y el `Caddyfile`
proxyaba `/files/*` en **ambos** dominios, así que estaba publicada por HTTPS.

**Por qué importa:**

- **Control de acceso incoherente.** `/review/observations/{id}/image` está restringido por rol
  (`_image_role`); los mismos bytes salían por `/files/...` sin rol alguno.
- **Sin caducidad ni revocación.** El código imita el patrón de URLs prefirmadas de S3 pero sin la
  parte que las hace seguras: no expiran. Y `delete_account` (ARCO) anonimiza observaciones y borra la
  identidad, pero **no toca los archivos**: una URL filtrada seguiría viva.
- **Atenuante real:** la clave es `observations/<uuid>/<8 hex>` y ningún endpoint público devuelve el
  `observation_id`, así que no es enumerable. Funciona como URL-capacidad, no como agujero abierto.

**Arreglo (dos medidas independientes a propósito):**

1. El `Caddyfile` **ya no proxya `/files/*`** en ninguno de los dos dominios. Como el contenedor `api`
   solo publica `127.0.0.1:8000`, con esto deja de ser alcanzable desde fuera del host.
2. El backend **solo monta la ruta en dev** (`storage_backend == 'local' and is_dev`).

Ningún cliente la usaba: se buscó `/files` en todo el código Dart y no hay una sola referencia — las
dos apps piden las imágenes por el endpoint autenticado.

## 3. `AUTH_SECRET` podía quedarse en el valor por defecto

`config.py` traía `auth_secret = "dev-insecure-secret-change-me"`. `.env.prod.example` pedía generar
uno (`openssl rand -hex 32`), pero **nada obligaba**: un despliegue que olvidara la variable arrancaba
sin protestar. Con un secreto que está en el repo público, cualquiera puede firmarse un JWT con
`role: administrador` — el rol se lee de la DB (`deps.py`), pero el `sub` del token elige la cuenta.

**Arreglo:** `Settings.validate_for_environment()`, invocada en `create_app()`, **rechaza el arranque**
fuera de dev si el secreto sigue siendo el default. Un olvido silencioso pasa a ser un error ruidoso.

## 4. TTL del token: 30 días → 7

No hay lista de revocación: cerrar sesión no invalida el token del lado del servidor, así que uno
filtrado sirve hasta que expira. Acortar la ventana es la mitigación disponible sin construir
revocación. **No resuelve el problema de fondo**; queda anotado como deuda.

## 5. Lo que se revisó y está bien

- El **rol se lee de la base, no del token** (`deps.py`): degradar a un usuario surte efecto inmediato
  aunque su token siga vigente. Es la decisión correcta y se conserva.
- La DB **no** se expone fuera del host (sin `ports` en compose) y `api` solo escucha en localhost.
- CORS por entorno, nunca `*` con credenciales (CR-004 W3).

## 6. Deuda anotada (no incluida)

- **Sin revocación de tokens.** Un logout no invalida nada del lado del servidor. Requeriría una lista
  de revocación o tokens de vida corta + refresh.
- **Las imágenes no se borran en la cancelación ARCO.** Hoy se anonimiza la observación pero el archivo
  permanece. Con `/files` cerrado el riesgo baja mucho, pero conviene decidir si el borrado ARCO debe
  alcanzar también la fotografía.

## 7. Criterios de aceptación

Ver la sección **CR-027** en [`TRACEABILITY.md`](../cambios/TRACEABILITY.md).
