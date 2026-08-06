# CR-035 — Sesión vencida: aviso visible y re-ingreso amable (sin perder la captura offline)

**Fecha:** 2026-08-06 · **Origen:** reporte de voluntarios (*"no podemos subir fotos"*) + diagnóstico
en producción · **Estado:** APROBADO por el usuario (2026-08-06), en construcción. Solo app del
voluntario; **sin backend, sin migración**; la consola no cambia.

---

## 1. El problema, con evidencia de producción

El token JWT del voluntario vence a los **7 días** (CR-027). Al vencer, **todo** lo autenticado
responde 401, pero la app sigue "logueada" y no dice nada. Medido en los logs del API de la VM
(2026-08-06):

| Día | `POST /observations` 201 | `POST /observations` 401 |
|---|---|---|
| 2026-08-01 … 04 | 197 · 66 · 105 · 252 | 0 · 0 · 1 · 1 |
| **2026-08-05** | 106 | **120** |
| **2026-08-06** | 11 | **18** |

El 5 de agosto los 401 explotan también en `/me/profile`, `/me/feedback` y `/me/sessions` — la firma
de un vencimiento **en lote**: los voluntarios que entraron alrededor del despliegue de CR-033/034
(29–31 jul) cumplieron sus 7 días juntos. Quien volvió a entrar con Google (7 logins el día 5) subió
sin problema. **No es almacenamiento** (volumen de datos al 1 %, 149 GB libres; healthz 200;
contenedores sanos).

### Lo que CR-031 dejó hecho — y el hueco que quedó

CR-031 ya hace lo difícil: ante un 401 el motor de subida **pausa la cola y conserva las fotos**
(AC9/AC17), y existe el texto `Copy.pendingSessionExpired`. Pero el aviso tiene tres huecos,
verificados en el código:

1. **Solo se enciende si hay fotos en la cola** — con cola vacía, `flush()` sale sin tocar la red y
   el 401 es invisible (`pending_uploader.dart`). El voluntario ve "No se pudo cargar el perfil" y
   nada más.
2. **Es un texto pasivo sin botón** — `pending_uploads_card.dart` lo pinta, pero no ofrece ninguna
   acción; el voluntario tendría que deducir que debe cerrar sesión y volver a entrar.
3. **`PendingQueueController.sesionRenovada()`** — el gancho que reanuda la cola tras el re-login —
   **existe y nadie lo llama** (`providers.dart:279`).

---

## 2. Restricción de diseño dura

**Detectar la sesión vencida NUNCA cierra la sesión ni saca al usuario de `HomeShell`.** El re-login
exige internet; un voluntario en campo sin señal debe poder seguir capturando a su cola local — es el
corazón de CR-031 y del gate #3. Por eso la respuesta es un **banner persistente con botón**, no un
logout forzado: el voluntario decide cuándo volver a entrar.

---

## 3. Diseño

### Detección reactiva (central, un solo punto)

`ApiClient` gana un callback `onSessionExpired`, invocado desde `_decode`/`_decodeList` cuando la
respuesta es **401 y había token puesto**. Como todos los endpoints (incluido el multipart de
`submitObservation` y el `postSession` del `SessionTracker`) terminan ahí, un solo cambio cubre el
uploader, el rastreador de sesión y todos los `FutureProvider` de datos. El guard `_token != null`
evita dispararlo con un login fallido desde un dispositivo limpio; un re-login fallido con token viejo
en memoria re-dispara, lo cual es idempotente e inocuo.

### Detección proactiva (sin esperar el fallo)

El backend ya emite el claim `exp` (`security.py`). La app gana `expiryFromJwt`/`tokenVencido` junto a
`accountIdFromJwt` (mismo criterio: decodifica sin verificar firma; tolerante si el claim falta) y
`HomeShell` comprueba al arrancar y al volver a primer plano. Así el aviso aparece **al abrir la app**
— típicamente en casa, con internet, donde el re-login sí es posible — y no hasta el primer intento de
subida fallido. El servidor sigue siendo la autoridad (la vía reactiva cubre cualquier desfase de
reloj).

### Estado y cableado (Riverpod, sin ciclos)

- Nuevo `sessionExpiredProvider` (`StateProvider<bool>`). Se **enciende** desde el callback del
  `ApiClient` (asignado en `apiClientProvider`, con `ref.read` diferido) y desde la comprobación
  proactiva. Se **apaga** con un `ref.listen(authProvider)` dentro de `pendingQueueProvider`:
  cualquier cambio de sesión invalida el aviso; si hay sesión nueva además llama **`sesionRenovada()`**
  (la cola reanuda sola). El logout manual también lo apaga.
- `AuthController` **no se toca**: la sesión vencida es un aviso, no un estado de auth.
- `SessionTracker` recibe un predicado `sesionVencida` y deja de enviar `POST /me/sessions` mientras
  el flag esté encendido (era la fuente más ruidosa de 401 en producción). El **primer** 401 sigue
  pasando — es un disparador reactivo válido; tras el re-login reanuda solo.

### Interfaz

- **Banner persistente** (`session_expired_banner.dart`, nuevo) arriba del contenido en las **4
  pestañas** de `HomeShell`. **No descartable** (no usa `InfoNote`: descartarlo una vez lo silenciaría
  para siempre) y no bloquea nada. Botón **"Volver a entrar"** → `push(WelcomeScreen)`; si el
  voluntario regresa sin entrar, el banner sigue; si entra, `_afterLogin` ya limpia la pila con
  `pushAndRemoveUntil(HomeShell)` y el listener apaga el aviso y reanuda la cola.
- La **tarjeta de pendientes** gana el mismo botón donde hoy hay texto pasivo.
- **SnackBar honesto en captura:** con la sesión vencida, "Guardada en tu teléfono. Vuelve a entrar
  para que se envíe." — el texto actual ("se enviará sola cuando haya internet") sería mentira.

### Textos (Copy, tono del repo: hecho + qué hacer + tranquilizador)

- Banner: *"Tu sesión expiró. Puedes seguir capturando: todo se guarda en tu teléfono. Cuando tengas
  internet, vuelve a entrar para que se envíe."*
- Botón: *"Volver a entrar"*
- SnackBar: *"Guardada en tu teléfono. Vuelve a entrar para que se envíe."*

### `isSessionExpired` — por qué SOLO 401 (y no la tabla de la consola)

La consola pregunta "¿regresar al login?" (`isAuthError = 401||403||410`) porque siempre puede: es
online. El móvil pregunta **"¿esto se cura volviendo a entrar?"**: el **403** no (el uploader ya lo
trata como `necesitaAtencion`); el **410** no (cuenta eliminada: camino propio D6 que borra la cola y
cierra sesión — decirle "vuelve a entrar" sería mentira). Nombre distinto a propósito: no es la misma
pregunta.

---

## 4. Gates

- **#3 (sin gating) — intacto y protagonista:** el aviso no bloquea capturar, navegar ni aprender;
  jamás se fuerza el logout.
- **#9 / Q5.A-D1 — intacto:** los textos nuevos hablan de **sesión y envío**, nunca de "revisión";
  hay prueba de copy que lo fija.
- **#2 (mínima PII) — intacto:** no se añade ningún dato; el claim `exp` ya viajaba en el JWT.
- **#4, #6, #7 — intactos.** Ningún gate se enmienda. Sin migración.

---

## 5. Fuera de alcance (explícito)

- **Revocación de tokens** — sigue siendo deuda de CR-027.
- **Alargar el TTL de 7 días** — relajarlo desharía el endurecimiento de CR-027; no entra.
- **"Modo re-ingreso" en WelcomeScreen** (sin dropdown de institución, solo el botón de Google) —
  mejora futura; hoy el re-login pasa por la pantalla completa, igual que todo logout→login.
- **Refresh tokens / renovación silenciosa** — cambiaría el contrato de auth (backend); otro CR.

## 6. Decisiones documentadas

- **Re-login con OTRA cuenta de Google (D8 de CR-031):** las capturas de la cuenta anterior **ni se
  suben ni se borran** (`next(accountId:)` las filtra; D1 prohíbe borrar sin confirmación del
  servidor). El contador de la tarjeta las sigue mostrando. Comportamiento aceptado bajo "un
  dispositivo, un voluntario"; se subirían si la cuenta original vuelve a entrar.
- **El tramo de tiempo del `SessionTracker` con sesión vencida se pierde** — aceptable: la sesión es
  inválida y el backend lo rechazaría igual.

---

## 7. Criterios de aceptación

| # | Criterio | Prueba prevista |
|---|---|---|
| **AC1** Un 401 en cualquier endpoint autenticado (subida, perfil, sesiones) enciende el aviso; un 401 de `/auth/google` sin token previo NO | `mobile/test/cr035_sesion_vencida_test.dart` |
| **AC2** Al abrir la app con un token restaurado ya vencido (`exp` pasado), el aviso aparece sin esperar ningún 401 | `mobile/test/cr035_ui_test.dart` |
| **AC3** El aviso es visible en las 4 pestañas, NO se puede descartar y NO impide capturar ni navegar (gate #3) | `cr035_ui_test.dart` |
| **AC4** Detectar la sesión vencida NUNCA cierra la sesión ni saca al usuario de HomeShell; la cola queda intacta | `cr035_ui_test.dart` + AC9/AC17 de CR-031 (vigentes) |
| **AC5** "Volver a entrar" abre el login; tras entrar con éxito el aviso desaparece y la cola reintenta sola (`sesionRenovada`) | `cr035_ui_test.dart` |
| **AC6** Capturar con la sesión vencida guarda en el teléfono y el mensaje lo dice ("vuelve a entrar"), no promete envío automático | `cr035_ui_test.dart` |
| **AC7** La tarjeta de pendientes ofrece "Volver a entrar" cuando la sesión venció | `cr035_ui_test.dart` |
| **AC8** Cerrar sesión manualmente apaga el aviso | `cr035_ui_test.dart` |
| **AC9** Con la sesión vencida no se envían más `POST /me/sessions`; tras re-entrar se reanudan | `cr035_sesion_vencida_test.dart` |
| **AC10** Ningún texto nuevo de sesión/subida menciona "revisión" (gate #9) | prueba de copy en `cr035_ui_test.dart` |
| **AC11** Re-login con OTRA cuenta: las capturas de la cuenta anterior ni se suben ni se borran (D8/D1) | AC10 de CR-031 (aislamiento por cuenta) + §6 |

---

## 8. Despliegue

Solo el **bundle del voluntario** (runbook de CR-033/034): build LOCAL con defines de prod → rama
`deploy` → `scp` + `rsync` en el lugar + respaldo `.bak-cr035-*` + `restart caddy` (en la VM, TODO
`docker compose` con `--env-file .env.prod`). Backend y consola intactos. Verificación: hash servido
== VM == local (curl `--resolve` desde la VM), healthz 200, textos nuevos en el bundle; en los días
siguientes, que los 401 de `/observations` bajen y aparezcan re-logins (`/auth/google` 200).

**Efecto inmediato esperado:** los voluntarios hoy bloqueados abren la app, la comprobación proactiva
del `exp` enciende el banner sin esperar ningún fallo, tocan "Volver a entrar" y su cola pendiente se
sube sola.
