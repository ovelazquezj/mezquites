# CR-039 — Descartar la captura sin enviarla

**Estado:** integrado (2026-09-08) · **Alcance:** app del voluntario · **Sin backend, sin migración**

---

## 1. El problema

Reportado por el usuario junto con CR-037: *"no hay una opción para cancelar la captura de un árbol
una vez que el observador ya está capturando los datos, por lo cual si fue una captura errónea el
observador se ve obligado a terminar la captura y enviar la foto errónea"*.

Confirmado en el código: `ObservationForm` tenía **un solo botón** (`submit_observation`), y
`CaptureScreen` solo limpiaba la captura dentro de `_submit`, ya con la observación encolada. La
pantalla es una pestaña de `HomeShell`, así que tampoco hay flecha de retroceso. **La única forma de
salir del formulario era enviarlo.**

### La salida accidental (y por qué era peor que no tener ninguna)

Existía una escapatoria, pero por accidente: `home_shell.dart:109` monta las pantallas con
`_screens[_index]` —una lista simple, **no** un `IndexedStack`—, así que cambiar de pestaña destruía
el estado de `CaptureScreen` y **tiraba la foto y las etiquetas en silencio**.

Ningún voluntario iba a descubrir eso, y quien tropezara con ello no podía distinguirlo de un fallo.
Con un "Descartar" que sí pregunta, esa pérdida callada resulta **más** desconcertante, no menos: dos
gestos con el mismo efecto destructivo, uno confirmado y el otro mudo. Por eso ambas cosas se cierran
en el mismo CR.

---

## 2. Diseño

### Descartar

Botón **"Descartar"** junto a la foto (bajo "Repetir foto"), con **diálogo de confirmación**. Al
confirmar: se vacían foto y etiquetas, se vuelve a la cámara y un SnackBar dice *"Captura descartada.
No se envió nada."*

El aviso **distingue dos casos**, porque prometer que se pierden datos que aún no existen es
simplemente falso:

- recién tomada la foto ⇒ *"Se perderá la fotografía que acabas de tomar."*
- con algo declarado ⇒ *"Se perderán la fotografía y los datos que llevas de este árbol."*

Ocurre **siempre antes de enviar**: no se ha tocado la cola de CR-031 ni el servidor, así que
descartar es solo olvidar. No hay nada que deshacer en ninguna parte, y por eso este CR no necesita
endpoint de borrado ni roza el log append-only de revisión ni la historia ARCO.

| | **Repetir foto** (CR-037) | **Descartar** (este CR) |
|---|---|---|
| Intención | mismo árbol, mejor foto | este árbol no va |
| Se pierde | solo la foto | foto + etiquetas |
| Confirmación | no (barato de deshacer) | **sí** |

### La captura sobrevive al cambio de pestaña — y por qué NO con `IndexedStack`

La solución evidente era cambiar `_screens[_index]` por un `IndexedStack` en `HomeShell`. **Se
descartó tras mirar qué hacen las otras pestañas**, no por gusto:

`IndexedStack` mantiene montadas las 4 pestañas a la vez. Y `HeatMapScreen` observa
`publicObservationsProvider` —que desde CR-034 **pagina el dataset confirmado entero**—, más
`publicGridProvider`, `publicIndicatorsProvider` y los tiles de `tile.openstreetmap.org`;
`ProfileScreen` observa `profileProvider` y `feedbackProvider`. Montarlas al arrancar dispararía toda
esa red **al abrir la app**, para cualquier voluntario, incluido el que solo va a tomar una foto en el
campo con datos móviles. Habríamos cambiado un bug de estado por un coste de datos en cada arranque.

La alternativa cuesta lo mismo y no toca ninguna otra pestaña: **subir la captura a un provider**.
`capturaEnCursoProvider` (un `StateProvider<CapturaEnCurso>` en `providers.dart`, junto al resto)
guarda foto + etiquetas por encima del ciclo de vida del widget. `HomeShell` **no se modifica**:
`CaptureScreen` se sigue destruyendo al cambiar de pestaña, y lo que sobrevive es el estado.

Eso también deja los tres caminos de salida del formulario en un solo sitio y explícitos:

- **repetir** → `sinFoto()` (suelta la foto, conserva las etiquetas)
- **descartar** → `const CapturaEnCurso()` (vacía todo)
- **registrar** → `const CapturaEnCurso()` (vacía todo y encola)

### Se retira un seam de producción

`CaptureScreen(initialShot:)` existía **solo para pruebas** (`@visibleForTesting`, introducido en
CR-035). Con el provider ya no hace falta: las pruebas siembran estado real de la app con
`capturaEnCursoProvider.overrideWith(...)`. Es un seam mejor —prueba lo que corre en producción— y
deja un parámetro menos en el widget. Se actualizaron sus 3 usos (`cr035_ui_test`, `cr037`).

---

## 3. Gates

- **#3 (sin gating) — intacto:** descartar no bloquea nada; tras hacerlo se puede capturar de
  inmediato, y hay prueba de ello. La confirmación es un diálogo, no una compuerta.
- **#4 (solo cámara) — intacto:** descartar devuelve al mismo panel de captura. Sin galería.
- **#9 — intacto:** los textos hablan de la captura y del envío, nunca de revisión. Prueba de copy.
- **#7 (trazabilidad):** cada criterio con prueba.
- **#2, #6 — intactos.** Ninguno se enmienda. Sin migración.

---

## 4. Fuera de alcance (explícito)

- **Borrar algo ya enviado.** Este CR es solo antes del envío, por decisión del usuario. Un borrado
  posterior necesitaría endpoint de borrado y tocaría el log append-only de `human_review` y la
  historia ARCO — otro CR, con otras consecuencias.
- **Deshacer un descarte.** Se confirma antes justamente para no necesitar deshacer después.
- **`IndexedStack` en `HomeShell`** — descartado con motivo medido (§2). Si algún día se quisiera
  precargar pestañas, tendría que ir con carga diferida por pestaña, no montándolas todas.

---

## 5. Criterios de aceptación

| # | Criterio | Prueba |
|---|---|---|
| **AC1** El formulario ofrece "Descartar" | `cr039_descartar_test.dart` |
| **AC2** Descartar **no actúa** sin confirmar: sale el diálogo y la captura sigue intacta | ídem |
| **AC3** Cancelar conserva foto y etiquetas | ídem |
| **AC4** Confirmar vacía foto **y** etiquetas, vuelve a la cámara y avisa; el árbol siguiente arranca en blanco | ídem |
| **AC5** Descartar **no encola ni envía nada** (`store.count() == 0`) | ídem |
| **AC6** El aviso distingue "solo la foto" de "foto y datos" | ídem |
| **AC7** Ir a otra pestaña y volver **conserva** foto y etiquetas (la regresión que cierra el CR) | ídem, sobre `HomeShell` real |
| **AC8** Lo descartado **no resucita** al volver a la pestaña | ídem |
| **AC9** Gate #3: tras descartar se puede capturar de inmediato | ídem |
| **AC10** Gate #9: los textos de descarte no insinúan veredicto | prueba de copy |

**Nota sobre AC7:** `home_shell.dart` **no se modificó** en este CR (verificable en el diff), así que
la pantalla se sigue destruyendo al cambiar de pestaña. Lo que hace pasar la prueba es el provider, y
la aserción fuerte es que el **submit sigue habilitado**: las etiquetas las puso la interacción del
test, no el override, así que solo sobreviven si el estado sobrevivió de verdad.

**606 pruebas verdes** (21 contrato · 9 mock · 235 backend · **205** móvil · 136 consola), 2026-09-08.
Delta: +10 móviles.

---

## 6. Despliegue

Solo el **bundle del voluntario**, junto con CR-037 (mismo runbook de CR-033/034/035): build LOCAL con
los defines de prod → rama `deploy` → `scp` del tar → `rsync -a --delete` **en el lugar** →
`restart caddy`, con respaldo `*/build/web.bak-cr039-*`. Consola y backend intactos.

Trampas vigentes: `git checkout deploy` **pisa los `build/web` recién compilados** (CR-036), y en la VM
**todo** `docker compose` lleva `--env-file .env.prod` desde `/opt/mezquite/infra/compose/`.

Verificado ya en local: el **build web de producción compila** y sirve los textos nuevos (la rama web
del import condicional no la compila `flutter test`, que corre sobre la rama io). Ojo al verificar por
`grep`: dart2js **escapa los acentos**, así que "Sí, descartar" aparece como `S\xed, descartar`.
