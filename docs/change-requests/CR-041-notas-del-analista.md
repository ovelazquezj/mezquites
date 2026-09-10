# CR-041 — Notas escritas sobre una observación (el analista por fin puede anotar)

**Estado:** PROPUESTO (2026-09-10) · **Alcance:** backend + consola · **Con migración (0010)**
**Origen:** petición específica del usuario: *"un analista también pueda hacer observaciones"*,
aclarada como **dejar notas escritas sobre una captura, sin cambiar su estado de revisión**.

---

## 1. El problema

### 1.1 El analista no puede ni abrir el detalle

La bitácora sella al `analista` como **solo lectura**: monitorea, no emite veredicto. La consola
llevó eso más lejos de lo que decía la decisión: el menú **Revisión** se muestra solo a quien
**puede emitir veredicto**, y el analista no puede. Como el diálogo con la fotografía, las etiquetas
de captura y el historial **solo se abre desde esa pantalla**, el analista nunca lo ve.

El backend, en cambio, **sí lo autoriza**: la cola, el detalle y la imagen aceptan al analista
(`REVIEW_ROLES`), y el propio diálogo ya esconde los tres botones de veredicto a quien no puede
emitirlo. La pantalla está preparada para un lector sin voto desde CR-001. **Lo único que sobra es
el candado del menú.**

Lo que el analista sí ve hoy —Monitor, Datos, panel de ubicación exacta— no tiene renglones
clicables ni fotografía. Puede contar observaciones; no puede mirarlas.

### 1.2 Las notas ya existen, pero van pegadas a un veredicto

`human_review.nota` existe desde CR-001, la consola la escribe y la muestra en el historial, y **en
producción hay 1 891 notas sobre 6 367 filas de revisión**: la función está viva y en uso.

Pero la nota **no es independiente**. Se escribe en la misma fila que el veredicto, por el único
endpoint que la acepta (`POST /review/observations/{id}/verdict`), restringido a evaluador y
administrador. **Sin veredicto no hay nota.**

De ahí que la petición no se resuelva abriendo el menú y ya: para dejar una nota, el analista
tendría que emitir un veredicto. Eso lo convertiría en revisor con voto, contra su rol sellado, y no
sería inocuo: desde CR-026 el veredicto decide qué aparece en el mapa público, cuánto suma el
voluntario y qué insignias gana. **Una anotación no puede tener ese efecto.**

---

## 2. Diseño

### 2.1 Tabla nueva `observation_note` (migración 0010)

| columna | tipo | nota |
|---|---|---|
| `id` | uuid PK | |
| `observation_id` | uuid FK → `observation.id`, NOT NULL | |
| `author_account_id` | uuid FK → `account.id`, NOT NULL | autoría (séptima FK a `account`) |
| `texto` | text NOT NULL | CHECK: no vacío, ≤ 2 000 caracteres |
| `created_at` | timestamptz NOT NULL | `now()` |

Índice `observation_note_obs_idx (observation_id, created_at)`.

**Por qué tabla nueva y no reutilizar `human_review`:** esa tabla exige `veredicto` NOT NULL con un
CHECK de tres valores. Colar notas sin veredicto obligaría a relajar el CHECK y a inventar un
veredicto falso, y **contaminaría el contador del Monitor** ("Veredictos emitidos"), que CR-029
acaba de dejar honesto tras el incidente de las re-revisiones. Separar las tablas deja el log de
veredictos exactamente como está.

**Append-only** (mismo criterio que `human_review`, gate #7): no hay endpoint de edición ni de
borrado. Lo escrito queda, con su autor y su fecha.

### 2.2 Backend

- **`POST /review/observations/{id}/notas`** — roles `REVIEW_ROLES` (evaluador, analista,
  administrador). Cuerpo `{"texto": "..."}`. Responde 201 con la nota creada.
  **No toca `observation.estado_revision`.** Ese es el punto entero del CR.
- **`GET /review/observations/{id}`** (detalle, ya existe) gana `notas: [{texto, autor_handle,
  created_at}]`, de la más antigua a la más reciente, igual que el historial.
- **ARCO:** `observation_note.author_account_id` es la **séptima** FK a `account`. CR-040 acaba de
  arreglar las otras seis; esta se repunta a la cuenta centinela en la misma transacción. Sin eso,
  eliminar a un analista que dejó notas fallaría por FK con un 500.

### 2.3 Consola

- El menú **Revisión** pasa a gatearse por `canReview` (que ya incluye al analista) en lugar de
  `canEmitVerdict`. Una línea en `home_shell.dart`. Los botones de veredicto siguen gateados por
  `canEmitVerdict` dentro del diálogo, que ya estaba escrito así.
- En el diálogo de detalle, sección **"Notas"**: las notas existentes con autor y fecha, y un campo
  para añadir una, con su botón. Visible para los tres roles de revisión.
- **El campo de nota junto al veredicto se conserva.** Es del evaluador y viaja con su decisión;
  quitarlo tiraría un flujo que ya usan (1 891 notas).
- Aviso corto junto al campo: **no escribas datos personales de nadie**.

---

## 3. Gates

- **#2 (mínima PII) — el punto delicado.** El texto es libre y lo escribe personal de consola, así
  que *podría* contener datos personales de un tercero. No hay forma de validarlo automáticamente
  sin censurar. Mitigación: aviso explícito en el campo, y **las notas no salen de la consola** —
  ni al público, ni al panel restringido, ni a las dos descargas CSV (verificado: hoy `nota` no
  aparece en ninguno de esos tres routers). Se cierra por procedimiento, no por software.
- **#9 (público = confirmada) — intacto y con prueba.** Escribir una nota **no** cambia
  `estado_revision`, así que no mueve el mapa público, ni los conteos, ni los puntos, ni la
  insignia del voluntario. Es la diferencia entera entre este CR y darle voto al analista.
- **#7 (trazabilidad) — reforzado.** Append-only, con autor y fecha. Cada criterio con prueba.
- **#1 (frontera) — riesgo residual anotado.** Nada en el software promete control fitosanitario,
  pero una nota libre podría contener una recomendación química escrita por una persona. Es el
  mismo riesgo que ya corre `human_review.nota` desde CR-001, y se atiende igual: por acuerdo con
  el Club, no por filtro.
- **#3 (sin gating) — intacto.** El voluntario no ve las notas y nada se le bloquea.
- **#4, #6 — no se tocan.** La app del voluntario no cambia.

Ninguna decisión sellada se enmienda. El analista **sigue siendo solo lectura en cuanto al
veredicto**: anotar no es decidir.

---

## 4. Fuera de alcance (explícito)

- **Editar o borrar notas.** Append-only, como el log de revisión.
- **Que el analista emita veredicto.** Sigue sin voto, por diseño.
- **Que el voluntario vea las notas.** Sería devolverle retroalimentación escrita sobre su captura:
  otro CR, con su propia discusión de tono y de gate #9.
- **Notas en las descargas CSV.** Quedarían fuera de la consola, justo lo que evita el riesgo de PII.
- **Avisos o correos al escribir una nota.**

---

## 5. Criterios de aceptación

| # | Criterio | Prueba |
|---|---|---|
| **AC1** El analista ve "Revisión" en el menú | consola |
| **AC2** El analista abre el detalle y ve fotografía, datos de captura e historial | consola |
| **AC3** El analista **no** ve los botones de veredicto | consola |
| **AC4** El analista escribe una nota y queda con su autoría y su fecha | backend + consola |
| **AC5** Escribir una nota **no** cambia `estado_revision` (gate #9) | backend |
| **AC6** Evaluador y administrador también pueden escribir notas | backend |
| **AC7** Un rol sin revisión recibe 403; sin token, 401 | backend |
| **AC8** Las notas salen en el detalle para los tres roles, de la más antigua a la más reciente | backend + consola |
| **AC9** Nota vacía o de solo espacios → 422; más de 2 000 caracteres → 422 | backend |
| **AC10** No existe endpoint para editar ni borrar notas (append-only) | backend |
| **AC11** Las notas no aparecen en `/public/*`, ni en el panel restringido, ni en las dos descargas CSV | backend |
| **AC12** ARCO: al eliminar a la cuenta autora, sus notas **se conservan** y quedan a nombre de la cuenta centinela | backend |
| **AC13** El campo lleva el aviso de no escribir datos personales | consola |

---

## 6. Decisiones que necesito de ti

1. **¿Quién escribe notas?** Recomiendo los tres roles de revisión. Dejarlo solo en el analista
   sería raro: el evaluador ya escribe notas hoy, junto a su veredicto.
2. **¿Quién las lee?** Recomiendo los mismos tres, y nadie más.
3. **¿Se pueden borrar?** Recomiendo que no, append-only. Si alguien escribe algo indebido, se
   corrige con otra nota, como en el log de revisión.
4. **Límite de longitud:** propongo 2 000 caracteres.

---

## 7. Despliegue

Backend (con **migración 0010**) + bundle de la **consola**. La app del voluntario **no cambia**,
así que su bundle no se toca. Orden obligado: backend primero, consola después. Respaldo `pg_dump`
previo, y las trampas vigentes del runbook: `--env-file .env.prod` en todo `docker compose`,
`rsync -a --delete` en el lugar, y verificación del hash **desde la propia VM**.
