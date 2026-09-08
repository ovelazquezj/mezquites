# CR-037 — La foto se ve antes de enviarla (miniatura, lupa y repetir)

**Estado:** integrado (2026-09-08) · **Alcance:** app del voluntario · **Sin backend, sin migración**

---

## 1. El problema

Reporte del usuario tras revisar observaciones en la consola: una parte importante de las fotos se
rechaza por problemas evidentes de la propia imagen (encuadre, "solo tronco", desenfoque), y el
voluntario **no tiene manera de darse cuenta**.

Al leer el código, el hueco resultó mayor que el reportado. No es solo que falte un paso de
confirmación entre la cámara y el formulario:

- `capture_pane_web.dart` llama `onCaptured(result)` en cuanto el canvas exporta el JPEG, y
  `capture_screen.dart` pinta el formulario **de inmediato**. No hay paso intermedio.
- `observation_form.dart` **nunca renderizaba la imagen**: solo la pasaba al `ObservationDraft`.
- Ninguna otra pantalla del voluntario la muestra tampoco.

Es decir: **el voluntario nunca veía la fotografía que acababa de tomar** — ni antes, ni durante la
captura de datos, ni después de enviarla. El primer humano en mirarla era quien revisaba en la
consola, con la observación ya registrada. Eso explica por qué el problema llegó a casi 6 000
capturas sin que nadie lo reportara desde el campo: no había nada que reportar, no se veía.

**Un motivo de rechazo se vuelve accionable solo si quien puede corregirlo lo ve a tiempo.**

---

## 2. Diseño

Una sola tarjeta al **principio** del formulario (la foto es el sujeto de todo lo que viene debajo):

- **Miniatura** de 112 px de lado con insignia de lupa.
- **Visor a pantalla completa** al tocarla: pellizco para acercar (hasta 8×), doble toque para
  alternar encuadre completo ⇄ 2.5×, y botón de cerrar.
- **"Repetir foto"**: vuelve a la cámara conservando las etiquetas ya declaradas.

### `BoxFit.contain`, nunca `cover`

Recortar una foto que el voluntario está **a punto de juzgar** puede esconder justo lo que la
invalida. Además, la proporción del cuadro (apaisado o vertical) solo se lee de un vistazo si se
respeta. Es el mismo criterio que el fix de CR-032 tomó para las ilustraciones de Aprender.

### Alto fijo — no es cosmético

Un `Image` sin alto explícito toma sus dimensiones intrínsecas, que valen **0 hasta que la imagen se
decodifica**: queda en el árbol y es invisible. Este proyecto ya se tropezó **dos veces** con eso —
CR-029 (la foto de revisión de la consola, por eso su área es de 280 px fijos) y el fix de CR-032
(las ilustraciones medían `Size(1048, 0)`). El recuadro mide igual con la imagen cargada, cargando o
ilegible, y **la prueba lo afirma midiendo** (`tester.getSize`), no comprobando que el widget exista
— que fue exactamente la aserción que faltó en CR-032.

### Una sola ruta de imagen, con la rama nativa aislada

La captura llega por **bytes** (web) o por **ruta** (nativo), y `Image.file` necesita `dart:io`, que
no existe en web. Se resuelve con import condicional (`captura_imagen.dart`), el mismo patrón que ya
usan `capture_pane.dart` y `capture_service.dart`.

> Corrige un detalle del plan aprobado, que anticipaba resolver ambas ramas a bytes y usar solo
> `Image.memory`. Hacerlo exigiría leer el archivo de forma síncrona en el hilo de la UI (hasta 11 MB)
> o meter un `FutureBuilder`; `Image.file` ya resuelve la lectura por su cuenta y es más simple. El
> resultado visible es idéntico.

### Dónde viven las etiquetas (y por qué se movieron)

"Repetir foto" desmonta el formulario —vuelve la cámara— y con él se iría su `State`. Para que
repetir cambie **solo la foto**, las 5 etiquetas autodeclaradas se agrupan en un valor
(`EtiquetasCaptura`) que guarda **`CaptureScreen`** y devuelve al formulario cuando se vuelve a
montar. El formulario sigue siendo dueño de su estado mientras está montado (para poder probarlo
suelto, sin `ProviderScope`) y solo lo **espeja** hacia arriba con `onEtiquetasChanged`.

Las etiquetas **se limpian al registrar**: lo siguiente que se capture ya es otro árbol, y
conservarlas se las heredaría en silencio.

| | **Repetir foto** (este CR) | **Descartar** (CR-039, pendiente) |
|---|---|---|
| Intención | mismo árbol, mejor foto | este árbol no va |
| Se pierde | solo la foto | foto + etiquetas |
| Confirmación | no (barato de deshacer) | sí |

---

## 3. Gates

- **#4 (solo cámara) — intacto y protagonista:** "Repetir foto" reabre el **mismo panel de captura**;
  no se añade ninguna acción de galería. Hay prueba que busca "galería/galeria/álbum/carrete" en la
  pantalla y en el bundle compilado: **0 ocurrencias**.
- **#9 (sin estado de validación individual) — intacto:** los textos hablan de la **foto** (mirarla,
  ampliarla, repetirla), nunca de su suerte en revisión. Prueba de copy incluida.
- **#3 (sin gating) — intacto:** ampliar trabaja sobre la imagen que ya está en el dispositivo, sin
  pedir nada a la red; funciona igual capturando sin señal.
- **#2, #6, #7 — intactos.** Ninguno se enmienda. Sin migración.

---

## 4. Fuera de alcance (explícito)

- **Orientación de la foto (era CR-038):** el usuario decidió omitirlo tras revisar el diseño — al ver
  la miniatura el voluntario se da cuenta de que no puede enviarla así. Queda una salvedad anotada: en
  el camino de respaldo (`image_picker`, cuando `getUserMedia` falla) el JPEG **sí** trae etiqueta
  EXIF `Orientation`, y no se verificó si Flutter Web la honra al pintar. Si la honra, esa minoría de
  fotos se vería bien en la miniatura y de lado en la consola — el único caso en que el preview no
  avisa. No se midió qué tan frecuente es ese camino.
- **Descartar la captura completa** — es CR-039, con su propia decisión abierta.
- **Reparar las ~6 000 fotos ya capturadas** — descartado explícitamente por el usuario.
- **Mostrarle al voluntario sus fotos ya enviadas** — otra pantalla, otro CR.

---

## 5. Criterios de aceptación

| # | Criterio | Prueba |
|---|---|---|
| **AC1** El formulario muestra la foto capturada | `cr037_preview_foto_test.dart` |
| **AC2** La miniatura tiene alto **real > 0** aunque la imagen no se pueda decodificar | ídem (`tester.getSize`, no `findsOneWidget`) |
| **AC3** Tocar la miniatura abre el visor a pantalla completa con zoom | ídem |
| **AC4** El visor se cierra y devuelve al formulario | ídem |
| **AC5** "Repetir foto" avisa a la pantalla; sin callback no hay botón pero la foto se sigue viendo | ídem |
| **AC6** El formulario arranca con las etiquetas sembradas y espeja cada cambio hacia arriba | ídem |
| **AC7** Repetir la foto **conserva** las etiquetas del mismo árbol y **no encola nada** | ídem (ciclo completo en `CaptureScreen`) |
| **AC8** Tras registrar, el árbol siguiente empieza **en blanco** | ídem |
| **AC9** Gate #4: ninguna acción de galería en la pantalla ni en el bundle | ídem + verificación sobre `main.dart.js` |
| **AC10** Gate #9: la tarjeta de la foto no insinúa ningún veredicto | prueba de copy |

**195 pruebas móviles verdes** (183 previas + 12 nuevas), 2026-09-08. `backend`, `web-admin`,
`contract` y `mock-validator` no se tocan en este CR y no se re-corrieron.

---

## 6. Despliegue

Solo el **bundle del voluntario** (runbook de CR-033/034/035): build LOCAL con los defines de prod →
rama `deploy` → `scp` del tar → `rsync -a --delete` **en el lugar** → `restart caddy`, con respaldo
`*/build/web.bak-cr037-*`. Consola y backend intactos.

Dos trampas ya conocidas que aplican aquí:

- `git checkout deploy` **sobrescribe los `build/web` recién compilados** con los del commit anterior
  de esa rama (CR-036): hay que reponerlos antes de `git add -f`.
- En la VM, **todo** `docker compose` lleva `--env-file .env.prod`, y el compose vive en
  `/opt/mezquite/infra/compose/`.

**Verificación prevista:** hash servido == disco VM == build local (curl `--resolve` **desde la VM**;
descargar `main.dart.js` desde la máquina local se trunca), `/healthz` 200 en ambos dominios, y los
textos nuevos presentes en lo servido.

**Efecto esperado:** el voluntario ve lo que capturó antes de enviarlo. Esto no ataca un único motivo
de rechazo sino **todos los que son visibles en la imagen** — que en CR-036 fueron el motivo dominante
(15 de 20 rechazos de aquel grupo: *"solo tronco"*).
