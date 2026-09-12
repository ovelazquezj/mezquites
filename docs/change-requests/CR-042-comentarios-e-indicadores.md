# CR-042 — Comentarios en la revisión, e indicadores organizacionales que no se pierden

**Estado:** integrado (2026-09-12) · **Alcance:** backend + consola · **Con migración (0011)**
**Origen:** dos reportes del usuario usando la consola, ambos sobre pantallas que CR-041 acababa de
tocar o que llevaban tiempo a medias.

---

## Parte A — La ventana de revisión tenía dos cajas de texto que parecían la misma

### El problema

En el detalle de una observación conviven dos zonas de texto:

- el **campo pequeño** "Nota (opcional)", dentro del bloque de votar. Su texto viaja pegado al
  veredicto y se guarda con él. Lo ve quien puede emitir veredicto;
- el **área grande** que añadió CR-041: lista de lo escrito, campo, aviso de datos personales y
  botón, sin efecto sobre el estado de la observación.

El usuario reportó "dos áreas de notas, debiendo ser solo una". La primera lectura fue que sobraba
una. **Era una lectura equivocada, y el usuario la corrigió:** no sobra ninguna, son de dos personas
distintas. Lo que fallaba era el nombre. Ambas se llamaban *nota*, así que quien veía las dos no
tenía forma de saber para qué servía cada una.

Y había un segundo malentendido, este de mi parte, que hubo que deshacer sobre el código: **no era
"la del evaluador y la del analista"**. El área grande la escribían los **tres** roles de revisión, y
el campo pequeño lo ve **quien vota**, que incluye al administrador. El analista veía **una** sola
caja; el evaluador y el administrador veían **dos**.

### La decisión

1. El área grande se renombra a **Comentarios**, no a "Observaciones": en este software una
   *observación* es el registro de un mezquite, y la pantalla se llama "Revisión de observaciones".
   Un botón "Agregar observación" ahí dentro se habría leído como "agregar un árbol".
2. **Escribir** comentarios es del **analista** y del **administrador**.
3. El **evaluador los LEE** pero no escribe. Se decidió así porque el comentario suele ser justo el
   contexto que ayuda a decidir el veredicto: esconderlo a quien decide habría sido peor que el
   problema original.
4. El campo pequeño **no se toca**: ni el nombre, ni el lugar, ni los roles.

### Quién ve qué, después del cambio

| | Evaluador | Analista | Administrador |
|---|---|---|---|
| Fotografía, datos de captura e historial | Sí | Sí | Sí |
| Comentarios: **leer** | Sí | Sí | Sí |
| Comentarios: **escribir** | **No** | Sí | Sí |
| Campo "Nota (opcional)" | Sí | No | Sí |
| Botones de veredicto | Sí | No | Sí |

El backend acompaña a la pantalla: escribir un comentario pasa a exigir analista o administrador, y
el evaluador recibe 403. La **lectura** sigue abierta a los tres, así que el detalle le sigue
entregando los comentarios. Esconderlo solo en el cliente habría dejado el permiso real abierto.

Las `Key`s internas de los widgets **no se renombran**. Son identificadores de prueba, no texto para
nadie; cambiarlas habría sido ruido con riesgo y sin beneficio.

---

## Parte B — Los indicadores organizacionales desaparecían, y el panel contaba de menos

### El problema

El usuario reportó que tras registrar un indicador, salir de la sección y volver, los indicadores ya
no estaban; y que de los tres casilleros del formulario solo el primero se entendía. Al revisarlo
aparecieron **tres** fallas, y la peor no era la reportada.

**1. Desaparecían porque nadie los leía nunca.** La pantalla guardaba una lista local titulada
"Capturados en esta sesión". **No existía ningún endpoint para consultarlos:** la consola sabía
escribirlos y no sabía leerlos. Al cambiar de sección la pantalla se destruye y la lista se va con
ella. Los datos sí estaban guardados.

**2. El panel público contaba de menos. Verificado en producción.** La agregación armaba un
diccionario por indicador con `{key: value}`, **sin `GROUP BY` ni `SUM`**, así que dos registros de
la misma clave se pisaban y solo sobrevivía el último.

| Menciones en medios | |
|---|---|
| Registradas | 2 |
| Publicadas en el panel | 1 |

La prueba que existía registraba **un** renglón por clave, y por eso nunca lo detectó.

**3. El campo "Estado" pedía la entidad federativa y se usaba como descripción.** Es un filtro
geográfico, hermano de `municipio` y las claves INEGI, pero en la pantalla era texto libre rotulado
"Estado (opcional)". En producción quedó así:

```
eventos_w3            1   "Visita Rotaract Ejecutivo"
menciones_mediaticas  1   "Preseentacion del protgrama ... radio BI"
```

Consecuencia: esos registros quedaban fuera de cualquier vista filtrada por entidad. Y no había
ningún campo para lo que el usuario de verdad necesitaba escribir, que es **qué pasó**.

### La decisión

- La entidad **se queda**, pero como **lista desplegable con las 32 entidades más "Otro"**, no como
  texto libre. El catálogo ya existe y ya está cargado en producción, así que no hace falta nada
  nuevo para alimentarlo.
- Se añade **descripción** ("¿Qué pasó?"), que es donde debía ir lo que se estaba tecleando en la
  entidad.
- Se puede **editar y borrar** un indicador registrado.
- El panel público **suma** todos los registros de una misma clave. Dos menciones son dos eventos que
  ocurrieron, no una corrección del anterior.
- Los **tres registros de producción se borran** y el usuario los recaptura con el formulario nuevo,
  porque no hay forma de saber si están bien capturados.

### El formulario

| # | Casillero | Nota |
|---|---|---|
| 1 | **Indicador** | la lista que ya existía |
| 2 | **Cantidad** | valor 1 por defecto, con ayuda de qué se está contando |
| 3 | **¿Qué pasó?** | descripción libre, opcional |
| 4 | **Entidad** | desplegable: 32 entidades + "Otro", obligatorio |

La entidad es obligatoria precisamente porque "Otro" ya cubre lo que no encaja en un estado: así
ningún registro se queda fuera de los filtros por venir vacío.

"Capturados en esta sesión" se reemplaza por la lista real traída del servidor, con fecha,
descripción y entidad de cada registro, y el total por indicador.

**Gate #1 (U1) intacto:** estos indicadores siguen sin umbrales, metas ni semáforos. Solo registro y
seguimiento.

### Una diferencia deliberada con los comentarios

Los indicadores **se editan y se borran**; los comentarios de revisión **no**. No es una
inconsistencia: un comentario es un registro histórico de lo que alguien observó en su momento, y un
indicador es un dato de gestión capturado a mano que puede traer una errata. Cosas distintas,
comportamientos distintos.

---

## Criterios de aceptación

| # | Criterio | Prueba |
|---|---|---|
| **AC1** El evaluador **no** puede escribir comentarios | `test_cr041_notas.py` (403, y sin fila escrita) |
| **AC2** El evaluador **sí lee** los comentarios que escribe el analista | ídem |
| **AC3** Analista y administrador siguen escribiendo | ídem |
| **AC4** En pantalla, el evaluador ve la lista pero no el campo ni el botón | `widget_cr041_notas_test.dart` |
| **AC5** El campo "Nota (opcional)" y los botones de veredicto siguen igual | ídem |
| **AC6** Los textos dicen Comentario, y los viejos ya no aparecen | ídem |
| **AC7** El panel público **suma** los registros de una misma clave | `test_cr042_indicadores.py` |
| **AC8** El filtro por entidad del panel sigue funcionando | ídem |
| **AC9** Listar, editar y borrar un indicador; 404 con id inexistente | ídem |
| **AC10** Entidad ausente o vacía al registrar → 422 | ídem |
| **AC11** Sin token 401; rol ajeno 403 en los cuatro endpoints | ídem |
| **AC12** La pantalla **carga la lista del servidor al abrir** | `widget_cr042_indicadores_test.dart` |
| **AC13** Registrar manda los cuatro datos y recarga la lista | ídem |
| **AC14** Sin entidad seleccionada no se puede registrar | ídem |
| **AC15** La entidad ofrece las 32 del catálogo más "Otro" | ídem |
| **AC16** El total por indicador suma varios renglones | ídem |
| **AC17** Editar y borrar solo actúan tras confirmar | ídem |
| **AC18** El aviso de que no hay metas ni semáforos sigue ahí (gate #1) | ídem |

**706 pruebas verdes** (21 contrato · 9 mock · **288** backend · 205 móvil · **183** consola),
2026-09-12. Delta: 20 de backend en indicadores, 1 en comentarios, 25 de consola.

### Dos verificaciones que valen más que el número

- **La migración se probó a mano contra un PostGIS real**, porque el `conftest` crea el esquema con
  `create_all` y **nunca ejecuta alembic**: una suite verde no dice nada de producción. Se
  comprobaron `upgrade`, `downgrade` y `upgrade` otra vez, y se compararon columnas e índices contra
  una base espejo hecha con `create_all`. Idénticos.
- **La prueba de la suma no es vacua.** Se revirtió el arreglo a propósito y cuatro pruebas
  fallaron, entre ellas la central con el mismo síntoma de producción: dos registros de valor uno
  publicándose como uno.

---

## Despliegue

### Lo que salió mal en este despliegue, y cómo se cerró

El despliegue se dio por bueno verificando el **hash de lo que el servidor entrega**, y se reportó
como si eso significara que el usuario ya lo veía. **No es lo mismo, y el usuario siguió viendo la
consola anterior.**

La causa no estaba en el código ni en el servidor, sino en el `Caddyfile`: los bloques de SPA **no
mandaban ningún encabezado de caché**, solo `etag` y `last-modified`. Sin una instrucción explícita
el navegador aplica caché heurística y puede no volver a preguntar durante horas. Encima, ambas apps
son PWA con *service worker*, que añade una segunda copia.

**Arreglo (2026-09-12):** `Cache-Control: no-cache` en los dos bloques de SPA. No significa "no
guardes", sino "guarda pero **revalida** antes de usar": con el `etag` que Caddy ya emitía, una
recarga sin cambios responde **304 sin cuerpo** (verificado: 0 bytes descargados). Se aplica a
**todos** los archivos del SPA porque Flutter Web **no** pone el hash del contenido en el nombre:
`main.dart.js`, `flutter_bootstrap.js` y los de `assets/` cambian en cada build conservando la URL.
Es la misma lección de CR-024 con los íconos de la PWA.

**No afecta el uso sin conexión** (CR-031, AC15): la PWA sirve desde el almacén del *service worker*
y la cola de capturas vive en IndexedDB. Ninguno de los dos es la caché HTTP.

La API y las páginas legales no se tocaron (van por otros bloques del `Caddyfile`).

**Regla que queda:** un despliegue de consola o app **no está verificado** con el hash del origen.
Hace falta comprobarlo desde un navegador limpio, o dejar dicho explícitamente que falta ese paso.

---

Backend con **migración 0011** + bundle de la **consola**. La app del voluntario **no cambia**, así
que su bundle no se toca y su caché no se invalida. Orden: respaldo, backend, verificación, consola.
Al final, borrado de los tres registros con respaldo previo y guarda que aborte si la sentencia
afecta un número distinto de tres.
