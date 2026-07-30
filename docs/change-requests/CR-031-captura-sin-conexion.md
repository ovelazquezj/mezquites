# CR-031 — Captura sin conexión y subida diferida (y fin del fallo silencioso)

**Fecha:** 2026-07-29 · **Origen:** (a) hallazgo de la investigación de CR-030; (b) petición del
usuario: *"la app debe poder capturar sin conexión y subir las pendientes cuando haya internet"* ·
**Estado:** PROPUESTO — **las 9 decisiones humanas están resueltas** (§10, §12); listo para construir.
Sin código aún.

---

## 1. Por qué un solo CR y no dos

El fallo destapado y la función pedida son **la misma pieza de software**. Hoy no existe un almacén
de capturas en el dispositivo: la "cola" es una lista en memoria que nadie lee. Arreglar el fallo
silencioso *bien* exige construir ese almacén con reintentos; capturar sin conexión es ese mismo
almacén más los disparadores de red y el texto adecuado. Hacerlo en dos CR obligaría a construir la
cola dos veces.

Se organiza en **cuatro paquetes** (§4) con un orden de despliegue obligatorio (§7).

---

## 2. Lo que hay hoy (verificado en el código)

| Hecho | Dónde |
|---|---|
| El SnackBar **"Observación registrada y aceptada"** se muestra **antes** de que el POST responda | `mobile/lib/src/ui/screens/capture_screen.dart:56-58` |
| El error del POST se descarta: `.catchError((_) {})` | `capture_screen.dart:52-54` |
| La cola de pendientes es **solo memoria** (`StateNotifier`, sin persistencia) | `mobile/lib/src/state/providers.dart:151-163` |
| **Ningún widget lee la cola** — el `pendingQueueProvider` solo se escribe | únicos usos: `capture_screen.dart:46,50` |
| La cola guarda **etiquetas, no la imagen** — aunque sobreviviera, no habría qué subir | `models.dart::MineObservation` |
| El **401 no se maneja en ninguna parte**: con el token vencido (TTL 7 días, CR-027) la app sigue "logueada" y descarta cada captura | `api_client.dart:45-59` (lanza `ApiException` genérica); `AuthController` no la escucha |
| La sesión persistida no guarda vencimiento | `services/session_store.dart` |
| No hay dependencia de almacenamiento de blobs ni de detección de red | `pubspec.yaml` (solo `shared_preferences`) |

**Consecuencia:** una captura tomada sin red **se pierde**, y el voluntario ve un mensaje de éxito.
Al cerrar la app, cualquier pendiente desaparece.

**Lo que los datos de producción SÍ dicen (CR-030):** no hay evidencia de un corte sistemático —
subidas con 19–23 s de retraso, 0 filas sin imagen. **Pero por diseño este fallo no deja rastro en la
base**, así que la ausencia de evidencia no es evidencia de ausencia: exactamente por eso hay que
cerrarlo.

---

## 3. Lo que se pide

1. **Que la app no mienta.** Nada se declara registrado hasta que el servidor lo confirme.
2. **Que capture sin conexión.** La foto y sus etiquetas se guardan en el dispositivo.
3. **Que suba sola al recuperar internet**, sin que el voluntario tenga que recordar nada.
4. **Que se vea qué falta por subir**, con opción de reintentar a mano.
5. **Que reintentar no duplique mezquites** en el mapa público.

---

## 4. Diseño propuesto

### W1 — Backend: submit idempotente (migración `0008`)

**El riesgo que obliga a esto:** si el POST llega al servidor, se guarda, y la respuesta se pierde en
el camino (red de campo), el reintento crearía **una segunda observación del mismo árbol**. Con
`assign_tree` creando siempre un árbol nuevo (CR-022), eso serían **dos mezquites** en el mapa
público. Es el mismo tipo de daño que CR-028 combatió con instituciones duplicadas, pero peor: sin
un nombre que delate la copia, nadie las volvería a unir.

- El cliente genera un **`client_capture_id`** (UUID v4) **en el momento de capturar** y lo manda en
  el `payload`. El id es de la captura, no del intento: todos los reintentos llevan el mismo.
- Columna `observation.client_capture_id UUID NULL` + **índice único** `(account_id,
  client_capture_id)` — parcial (`WHERE client_capture_id IS NOT NULL`) para no chocar con las 167
  filas históricas ni con clientes viejos que no lo manden.
- `POST /observations`: si ese par ya existe, **no inserta**; responde **200** con
  `ya_existia: true` y el `observation_id` original. Primera vez sigue siendo **201**.
  Es el mismo criterio ya establecido en el repo: `ya_existia` (CR-028) y `sin_cambio` (CR-029) —
  no castigar un reintento legítimo, pero tampoco ensuciar el dato.
- **Scoping por cuenta** (y no global) para que un id de otra cuenta no pueda reclamarse.
- Campo **opcional**: un cliente anterior a este CR sigue funcionando igual (sin idempotencia).

**Además (por D9, ver §12):** `get_current_user` responde **410 Gone** —y no 401— cuando el token es
válido pero la cuenta ya no existe (cancelación ARCO, CR-006). Es lo que permite a la app distinguir
"vuelve a entrar" (conservar la cola) de "esta cuenta se eliminó" (borrarla). `get_current_user_optional`
no cambia. La consola suma el 410 a `isAuthError`.

### W2 — App: almacén persistente de capturas

Una interfaz `PendingCaptureStore` con **dos implementaciones por import condicional**, igual que ya
se hace con `capture_pane_io.dart` / `capture_pane_web.dart`:

| | Metadatos | Imagen |
|---|---|---|
| **Móvil nativo** | índice JSON en `shared_preferences` | JPEG en `getApplicationDocumentsDirectory()/pendientes/<id>.jpg` (**requiere `path_provider`**) |
| **Web / PWA (producción)** | **IndexedDB** | **IndexedDB**, bytes binarios (`Uint8List`) |

- **Nada de base64:** infla ~33 % y `localStorage` (donde vive `shared_preferences` en web) tope
  ~5 MB — bastarían unas pocas fotos para llenarlo (ver §11 para el peso real medido).
- **Paquete para web:** se recomienda **`idb_shim`** en vez de escribir a mano el wrapper de
  callbacks de IndexedDB. Alternativa: `sembast`+`sembast_web` (misma API en ambas plataformas, pero
  guarda binarios como base64 → descartado por el punto anterior).
- **`navigator.storage.persist()`** en web: sin eso el navegador puede **desalojar** IndexedDB bajo
  presión de almacenamiento y las capturas pendientes se irían sin aviso.
- Cada ítem guarda: `client_capture_id`, `account_id` (dueño), etiquetas, lat/lon, **`captured_at`
  original** (nunca la hora de subida), estado, nº de intentos, último error.
- **Cada ítem registra de quién es.** El backend atribuye la observación **al token que la sube**
  (`user.account_id` en `routers/observations.py`), así que la cola guarda la cuenta dueña.
  **D8 resuelto (2026-07-29): un dispositivo, un voluntario** — nadie más inicia sesión en ese
  teléfono. Por tanto el `account_id` se guarda como **sello de procedencia** (y para detectar una
  incongruencia si algún día ocurriera), pero **no hace falta filtrar la cola al leer** ni resolver
  conflictos entre cuentas. Si la cola tuviera un ítem de otra cuenta, se trata como anomalía: no se
  sube y se reporta, nunca se atribuye al usuario en sesión.

### W3 — App: motor de subida (el que arregla el fallo)

- **Serie, FIFO por `captured_at`** — una a la vez, para no saturar el enlace de un teléfono en campo.
- **Disparadores:** arranque/restauración de sesión · tras cada captura · al volver a primer plano
  (el lifecycle ya está enganchado por `SessionTracker`, CR-010) · evento `online` del navegador /
  `connectivity_plus` en nativo · botón manual "Subir ahora".
- **La red se comprueba intentando**, no preguntando: `onLine` y `connectivity_plus` dicen que hay
  *radio*, no que haya *internet* (el caso clásico del wifi cautivo). Son solo la señal para
  despertar al motor; la verdad es si el POST entra.
- **Reintento con backoff** 5 s → 15 s → 1 min → 5 min → 15 min (tope), con jitter.
- **Clasificación de errores** — es lo que hoy no existe:
  - *reintentable*: sin red, timeout, 5xx, 429 → vuelve a la cola;
  - *permanente*: 422 (payload inválido) → se marca **"necesita atención"** y **no se borra**;
  - **401**: se **pausa la cola** y se pide volver a entrar. **Nunca se borra la cola por un 401** —
    perder capturas por un token vencido sería el mismo bug con otro disfraz.
- **Nada se borra automáticamente.** Al éxito (201, o 200 con `ya_existia`) se borra el ítem y su
  imagen del dispositivo, y solo entonces.

### W4 — App: interfaz honesta

- **Se retira el mensaje que miente.** Dos textos distintos según lo que pasó de verdad:
  - guardada sin conexión → *"Guardada en tu teléfono. Se subirá cuando haya internet."*
  - subida confirmada por el servidor → *"Observación registrada."*
- **Indicador visible de pendientes** ("Por subir: N") con **"Subir ahora"**. **Sin lista por foto**
  (D5): el contador incluye TODO lo que falta, incluidas las que necesitan atención, así que el
  número nunca miente.
- **Consecuencia de D5 + D1 que hay que cubrir:** si una captura queda en "necesita atención" (un 422,
  que solo puede venir de un defecto nuestro: el payload lo arma la propia app) y nada se borra solo,
  el voluntario **no tendría forma de actuar sobre ella** sin una lista. Salida sin construir pantalla
  nueva: **la pantalla "Reportar un problema"** (CR-019, ya existe y ya manda diagnóstico sin PII)
  incluirá el **nº de pendientes y el último error**. Así una cola atascada llega al equipo por un
  camino que ya está hecho, en vez de quedarse muda en el teléfono.
- ⚠️ **Riesgo de texto que hay que resolver, no ignorar:** tras CR-030 el voluntario ya lee
  *"en revisión"*. Ahora aparecería *"pendiente de subir"*. Son **tres estados distintos** y hay que
  nombrarlos de forma que no se confundan:
  **(1) en tu teléfono** → **(2) subida, en revisión** → **(3) confirmada**.
  Que "pendiente" no se lea nunca como estado de validación es **gate #9 / Q5.A-D1**.

---

## 5. Gates

- **#4 (solo cámara, sin galería) — intacto:** la cola solo puede contener lo que produjo la cámara
  en esa sesión; no se añade ninguna ruta de importación de archivos. `captured_at` y el EXIF se
  conservan tal como se capturaron: subir más tarde no reescribe cuándo se tomó la foto.
- **#9 / Q5.A-D1 — intacto pero en riesgo de redacción:** ver §4-W4. "Pendiente de subir" es estado
  de **transporte**, no de validación.
- **#2 (mínima PII) — intacto:** en el dispositivo queda la foto y las coordenadas del propio
  voluntario. No se añade ningún dato personal. La cola se guarda ligada al `account_id`
  seudonimizado.
- **#3 (sin gating) — intacto:** nada se bloquea; capturar sin conexión **amplía** el acceso.
- **#6 (paridad de entornos) — intacto:** el almacén es local por definición; sin nube.
- **#7 (trazabilidad):** cada AC de §8 con su prueba.
- **#1 — intacto.** Nada de control fitosanitario.
- **Ningún gate se enmienda.** Única migración: `0008` (columna + índice único parcial).

---

## 6. Fuera de alcance (dicho explícitamente para no prometerlo)

- **Mapa offline.** `heat_map_screen.dart` usa `flutter_map` con `TileLayer` de OSM **sin proveedor de
  caché configurado**, así que sin internet no hay de dónde traer los tiles. Cuánto alcance a mostrar
  el navegador con su propia caché HTTP **no está medido**; no se promete nada. Solo la **captura**
  entra en el alcance de este CR.
- **Primer inicio de sesión offline.** Entrar con Google exige internet. La captura sin conexión
  funciona para un voluntario **que ya inició sesión antes** en ese dispositivo.
- **Revocación de tokens** — sigue siendo deuda de CR-027.
- **Reintento entre dispositivos.** La cola es local; si el teléfono se pierde, las pendientes se van
  con él.

---

## 7. Orden de despliegue (obligatorio)

1. **Primero W1 (backend con idempotencia).**
2. **Después la app** (W2–W4).

**No es una preferencia:** si la app empieza a reintentar contra un backend sin
`client_capture_id`, el primer reintento sobre una respuesta perdida **crea un mezquite duplicado**
en el mapa público. El backend es compatible hacia atrás (campo opcional), así que desplegarlo antes
no rompe nada de lo que hoy está instalado.

---

## 8. Criterios de aceptación

| # | Criterio | Prueba prevista |
|---|---|---|
| **AC1** El mismo `client_capture_id` dos veces crea **una** observación; la 2ª responde 200 + `ya_existia` | `backend/tests/test_cr031_idempotencia.py` |
| **AC2** El índice único es por cuenta: el mismo id en otra cuenta sí crea observación | misma |
| **AC3** Un submit **sin** `client_capture_id` sigue funcionando (cliente viejo) y no choca con otro igual | misma |
| **AC4** La migración `0008` aplica sobre las 167 filas existentes sin tocarlas | prueba de migración |
| **AC5** Una captura sin red **sobrevive al cierre de la app** | prueba del store (ambas implementaciones) |
| **AC6** Al recuperar red, las pendientes se suben **en orden de captura** y se borran del dispositivo | prueba del uploader con cliente HTTP simulado |
| **AC7** `captured_at` que llega al servidor es el de la **captura**, no el de la subida | misma |
| **AC8** Un 5xx/timeout reintenta con backoff; un 422 marca "necesita atención" **sin borrar** | misma |
| **AC9** Un **401 pausa la cola, NO la borra**, y tras volver a entrar la subida se reanuda | prueba del uploader + `AuthController` |
| **AC10** La cola está aislada por cuenta: otro voluntario en el mismo teléfono no sube lo ajeno | prueba del store |
| **AC11** **Ningún** mensaje declara "registrada" antes de la respuesta del servidor | prueba de widget de captura |
| **AC12** El contador de pendientes es visible y "Subir ahora" fuerza el intento | prueba de widget |
| **AC13** El texto distingue los tres estados sin mezclar transporte con revisión (gate #9) | prueba de copy |
| **AC14** Respuesta perdida (POST 201 que el cliente nunca recibe) → el reintento **no duplica** | prueba de integración del ciclo completo |
| **AC15** La PWA **abre sin conexión** (service worker) | verificación manual + nota en el runbook |
| **AC16** Un token válido de una cuenta **eliminada** responde **410**; sin token sigue siendo **401** (D9) | `backend/tests/test_cr031_410_cuenta_eliminada.py` |
| **AC17** Ante **410** la app **borra** la cola local; ante **401** la **conserva** y pide volver a entrar | prueba del uploader (los dos caminos, explícitamente contrastados) |
| **AC18** La consola trata el **410** como error de autenticación (vuelve al login, no error genérico) | `web-admin/test/` (`isAuthError`) |
| **AC19** Al pasar de **50** pendientes hay aviso, y capturar **sigue siendo posible** (gate #3) | prueba de widget |
| **AC20** Cerrar sesión con pendientes **advierte, permite salir y conserva la cola** | prueba de widget + store |
| **AC21** El diagnóstico de "Reportar un problema" incluye nº de pendientes y último error | prueba de widget (CR-019 ampliado) |

---

## 9. Dependencias nuevas

**Añadidas:** `path_provider` (imagen en disco, nativo) · `idb_shim` (IndexedDB en web).

**Descartadas, y por qué:**

- **`connectivity_plus`** — no se añadió. En **web**, que es la plataforma de producción, el evento
  `online` de la ventana da la misma señal y `package:web` ya era dependencia (CR-016). En **nativo**
  la subida se dispara al abrir la app, al volver a primer plano, tras cada captura, con el botón
  "Subir ahora" y por la escalera de espera del motor. **Costo asumido:** en nativo, con la app
  abierta y sin tocarla, recuperar la señal puede tardar hasta el siguiente reintento programado
  (tope 15 min) en vez de ser inmediato. Además `connectivity_plus` solo informa del **estado de la
  interfaz**, no de que haya internet (wifi cautivo), así que tampoco evitaría el intento fallido.
- **`uuid`** — el UUID v4 se genera con `Random.secure()` en 12 líneas, fijando versión y variante.

---

## 10. Decisiones humanas pendientes (requieren tu instrucción)

| # | Decisión | Recomendación |
|---|---|---|
| **D1** | Una captura que falla indefinidamente: ¿se purga alguna vez? | ✅ **RESUELTO (2026-07-29): NUNCA borrar automáticamente.** Se queda en el dispositivo marcada como "necesita atención" y solo el voluntario puede descartarla. El motor de subida no tiene ninguna ruta de borrado por tiempo ni por nº de intentos |
| **D2** | Tope de la cola / presupuesto de almacenamiento y qué pasa al llegar | ✅ **RESUELTO (2026-07-29): avisar, JAMÁS impedir capturar** (gate #3). Aviso a las **50** pendientes y más insistente a las **150** (~10 MB / ~30 MB con la mediana medida de §11). Los umbrales viven en un solo sitio y son ajustables. **No** se degrada la calidad de la foto: es lo que revisa la consola |
| **D3** | Cerrar sesión con pendientes | ✅ **RESUELTO (2026-07-29): advertir y dejar salir.** Aviso "tienes N sin subir; se quedarán guardadas y se enviarán cuando vuelvas a entrar", y la cola **sobrevive** al cierre de sesión (por D8, al volver es la misma cuenta). **No** se bloquea la salida ni se intenta subir antes de salir: sin señal ambas cosas atraparían al voluntario |
| **D4** | Pedir almacenamiento persistente en web (`storage.persist()`) | ✅ **RESUELTO (2026-07-29): sí, al iniciar sesión.** Si el navegador lo niega, la app **no falla**: sigue funcionando en modo "mejor esfuerzo" (queda registrado para el diagnóstico de "Reportar un problema") |
| **D5** | ¿Lista por foto o solo el contador? | ✅ **RESUELTO (2026-07-29): solo el contador** ("Por subir: N") + botón "Subir ahora". Sin lista por foto ni miniaturas. Menos superficie de texto que pueda confundirse con estado de revisión (gate #9) |
| **D6** | Cancelación ARCO de una cuenta con cola local en el dispositivo | ✅ **RESUELTO (2026-07-29): borrar la cola local al detectar la baja.** No se intenta subir antes (sería añadir datos a nombre de una cuenta cancelada). **Requiere que el backend distinga "cuenta eliminada" de "token vencido"** — ver §12 |
| **D7** | ¿Se sube con datos móviles o solo con wifi? | ✅ **RESUELTO (2026-07-29): subir siempre**, sin distinguir el tipo de red. Con la mediana de 200 KB (§11), 30 capturas ≈ 6 MB. **No** habrá interruptor de "solo wifi" ni pantalla de ajustes para esto |
| **D8** | ¿Puede usarse más de una cuenta en el mismo dispositivo? | ✅ **RESUELTO (2026-07-29): un dispositivo, un voluntario.** La cola no necesita filtrado por cuenta al leer; el `account_id` queda como sello de procedencia. Un ítem de otra cuenta se trataría como anomalía (no se sube, se reporta) |
| **D9** | ¿Cómo distingue la app "sesión vencida" de "cuenta eliminada", si hoy ambas son 401? | ✅ **RESUELTO (2026-07-29): 410 Gone** para la cuenta eliminada; el 401 se reserva a token vencido/ausente. Detalle e impacto verificado en **§12** (incluye un ajuste de una línea en la consola) |

**Estado: las 9 decisiones están resueltas.** No queda ninguna pregunta abierta para empezar a
construir.

---

## 12. Conflicto detectado al resolver D6: el 401 es ambiguo

Las decisiones D6 y la regla del 401 (§4-W3) piden lo **contrario** ante la misma respuesta HTTP:

| Situación | Qué debe hacer la app |
|---|---|
| Token vencido (TTL 7 días, CR-027) | **Pausar** la cola, pedir volver a entrar, **NO borrar nada** |
| Cuenta eliminada (ARCO, CR-006) | **Borrar** la cola local (D6) |

Y hoy **las dos son 401**, distinguibles solo por el texto en español del `detail`:

- `deps.py:46-50` → `401 "token inválido"`
- `deps.py:51-53` → `401 "cuenta no existe"` (la cuenta ya no está en la base)

Ramificar sobre una cadena de texto en español es frágil: cualquier reescritura del mensaje
—o una traducción— convertiría "token vencido" en "borra las capturas del voluntario". Hace falta una
señal legible por máquina.

### ✅ D9 RESUELTO (2026-07-29): **410 Gone** cuando la cuenta ya no existe

```
Token vencido/inválido  ->  401   { detail: "token inválido" }     app: pausa la cola, pide re-login
Cuenta eliminada        ->  410   { detail: "cuenta eliminada" }   app: borra la cola local (D6)
```

Se eligió el código de estado y no un campo en el cuerpo para no convertir `detail` en objeto (hoy es
texto) y para que la app ramifique con un número.

**Impacto verificado antes de decidir** (no estimado):

- `get_current_user` y `get_current_user_optional` (`deps.py:51-53`, `74-77`) son los **dos** únicos
  puntos donde se detecta la cuenta ausente. El segundo devuelve `None` (auth opcional, CR-019) y
  **no cambia**: seguir tratando al usuario como anónimo es lo correcto ahí.
- **Ninguna prueba del backend afirma el comportamiento del token de una cuenta borrada.** Todas las
  aserciones de `401` existentes son del caso "sin token", que **no cambia**. Se revisó también
  `test_account_deletion.py`: no ejercita el token de la cuenta eliminada.
- ⚠️ **La consola necesita un ajuste de una línea:** `web-admin/.../api_exception.dart:11` define
  `isAuthError => statusCode == 401 || statusCode == 403`. Sin añadir el 410, a un usuario de consola
  cuya cuenta se eliminara le saldría un error genérico en vez de volver al login. **Este CR toca, por
  tanto, también `web-admin`** — un cambio pequeño, pero hay que decirlo.

---

## 11. Datos de producción medidos (no estimados)

Medido el **2026-07-29 ~18:35 h (America/Mexico_City)** sobre `/data/storage` y la base de la VM:

| Dato | Valor |
|---|---|
| Observaciones en `observation` | **331** |
| Archivos JPEG en storage | **331** (uno por observación; 0 huérfanos, 0 directorios con más de un archivo) |
| Peso total | **103 MB** |
| **Mediana por foto** | **200 KB** |
| Promedio por foto | ~318 KB |
| Mínimo / máximo | **46 KB** / **5.5 MB** |

**Por qué importa:** una estimación previa de "~3 MB por foto" era **errónea por un factor de ~10**.
Con la mediana real, 50 capturas pendientes ocupan ~16 MB y no hay presión de almacenamiento que
justifique retener trabajo del voluntario ni esperar wifi (D2, D7).

⚠️ **Hallazgo aparte, del mismo muestreo:** en la revisión de CR-030 (mismo día, ~15:20 h) había
**167** observaciones; seis horas después hay **331** — **164 capturas nuevas en una tarde**, la última
a las 18:30 h. Las cifras por voluntario de CR-030 son una **fotografía de ese momento**, no un estado
permanente. Consecuencia operativa: **244 de 331 están sin revisar** (`aceptada`), así que la brecha
que CR-030 explica en pantalla se está ensanchando — y el mapa público, que desde CR-026 solo muestra
`confirmada`, va quedando muy por detrás de lo capturado.
