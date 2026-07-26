# CR-026 — Participación válida, sin horas, y mapas solo de observaciones confirmadas

- **Fecha:** 2026-07-25
- **Estado:** ✅ Integrado en `main`
- **Origen:** **solicitud de las universidades participantes**, transmitida por el usuario
  (orquestador humano) tras revisar cómo la plataforma reporta la participación de sus estudiantes.
- **Depende de:** CR-001 (revisión humana), CR-010 #7 (sesiones/evidencia), CR-022 (1 foto = 1 árbol),
  CR-025 (ubicación exacta pública).
- **Enmienda de gates:** **enmienda el gate #9** (criterio del dataset público). Ver bitácora.

## 1. Qué pidieron las universidades y por qué

Dos objeciones, ambas sobre la **validez de lo que la plataforma afirma**:

1. **Las horas no miden lo que dicen medir.** `SessionTracker` cuenta el tiempo con la app en primer
   plano: el teléfono en el bolsillo mientras se camina entre mezquites **no** cuenta, y leer
   "Aprender" sentado en casa **sí**. Presentar eso como "Horas de participación" en un comprobante
   induce a error a quien lo evalúa.
2. **Contar fotos no es contar aportaciones.** El contador subía con cada captura, incluso si la foto
   no era un mezquite o no era un árbol. Una participación que se mide por volumen de fotos premia lo
   contrario de lo que el proyecto necesita.

## 2. Decisión

| # | Cambio | Decisión |
|---|---|---|
| 1 | **Horas fuera del UI** | Se retira "Horas de participación" de la pantalla del voluntario. **Se sigue capturando y almacenando** (`participation_session`, `POST /me/sessions`, campo `horas_totales` en la respuesta): es dato de análisis, no evidencia de campo. |
| 2 | **Observaciones válidas** | "Observaciones registradas" → **"Observaciones válidas registradas"**: solo `estado_revision = 'confirmada'`. |
| 3 | **Conteos e insignias** | Lifelist, conteo del perfil, insignias y etiqueta de identidad L3 pasan a contar confirmadas. |
| 4 | **Puntos** | Los puntos **solo cuentan cuando la observación está confirmada**. |
| 5 | **Reporte por día** | Nuevo `GET /admin/analytics/participation.csv`: por día × voluntario, sesiones y horas frente al desglose de revisión. |
| 6 | **Mapas** | Los mapas y los indicadores públicos muestran **solo confirmadas**. |

**Criterio de "válida" = `confirmada`, no "no-rechazada".** Es la decisión de fondo. El criterio de
CR-001 (`<> 'rechazada'`) no resolvía el problema planteado: una foto de cualquier cosa seguía
contando y publicándose hasta que alguien la rechazara activamente. Con `confirmada`, el valor por
defecto es *no contar* y la revisión humana es lo que habilita.

### 2.1 Los puntos se filtran al leer, no se otorgan al confirmar

Dos formas de implementar el punto 4. Se eligió la segunda:

- *Otorgar al confirmar* (mover el `INSERT` al veredicto) obligaría a escribir lógica de revocación:
  CR-010 permite devolver una observación de `confirmada` a `aceptada`, y el rechazo tendría que
  descontar.
- **Filtrar al leer** (elegida): `points_ledger` sigue registrando al subir —bitácora cruda,
  append-only— y `account_points` suma con `JOIN observation ... WHERE estado_revision = 'confirmada'`.
  Si un veredicto se revierte, el total se ajusta solo. Mismo efecto visible, sin datos perdidos ni
  filas de compensación.

Este es el mismo principio que gobierna todo el CR, y lo fijó el usuario al descartar re-derivar el
periodo de actividad: **el dato se captura crudo; lo que cambia es qué se presenta.**

## 3. Enmienda al gate #9 (dataset público)

> ⚠️ **Enmienda a una decisión sellada, autorizada por el usuario el 2026-07-25**, en la misma línea en
> que CR-001, CR-022 y CR-025 enmendaron gates sellados. La decisión original no se borra.

| | Antes (CR-001) | Ahora (CR-026) |
|---|---|---|
| Dataset público | `estado_revision <> 'rechazada'` | `estado_revision = 'confirmada'` |
| Qué implicaba | Se publicaba lo que nadie había revisado | Solo se publica lo revisado y confirmado |

**Alcance:** `GET /public/observations`, `GET /public/grid`, `GET /public/indicators`, y por herencia
el mapa de calor y los pines exactos del móvil y de la consola.

**Consecuencia operativa asumida:** el mapa público refleja el **ritmo de revisión de la consola**, no
el de captura. Si nadie revisa, el mapa se ve vacío hacia afuera. Es una dependencia nueva del piloto
y queda asentada aquí como tal.

**Lo que NO cambia:** la observación sigue **naciendo `aceptada`** — el aporte se acepta al subir, no
se le pide al voluntario esperar aprobación para participar (gate #3 intacto: nada se bloquea).

## 4. La consola conserva todos los estados (G1)

`/restricted/observations` gana el filtro opcional `estado_revision`; **omitirlo devuelve todo**. El
mapa de la consola arranca en *Confirmadas (lo que ve el público)* pero ofrece *Pendientes de
revisión*, *Rechazadas* y *Todas*. Restringir la consola a confirmadas le escondería al evaluador
justo la cola que le toca revisar.

## 5. El reporte de participación (F)

`GET /admin/analytics/participation.csv` — una fila por **(día × voluntario)**:

`fecha · handle · institucion · sesiones · horas · obs_total · obs_aceptadas · obs_confirmadas · obs_rechazadas`

- **Huso horario:** el día se agrupa en **`America/Mexico_City`** (configurable,
  `Settings.report_timezone`). Las marcas se guardan en UTC; agrupar en UTC correría al día siguiente
  toda la actividad vespertina mexicana.
- **`FULL OUTER JOIN`** entre sesiones y observaciones: hay días con sesión y sin capturas (abrió la
  app y no subió nada) y días con capturas cuya sesión no llegó a registrarse (el envío es
  fire-and-forget). Perder cualquiera de los dos lados falsearía la comparación.
- **Gate #2:** solo el `handle` seudónimo; nunca correo ni nombre.
- La consola advierte, junto al botón, que **las horas miden tiempo con la app abierta**, para que
  quien lea el reporte no las tome como constancia de campo. Es la misma razón que motivó el punto 1.

## 6. Texto público del `CAVEAT`

Decía *"Datos de origen ciudadano, **sin validación por expertos**; especie y nivel autodeclarados"*.
Con este CR lo publicado **sí** pasó por revisión humana, así que la frase quedaba inexacta. Nuevo
texto:

> Datos de origen ciudadano; solo se publican las observaciones revisadas y confirmadas por el equipo
> del Club. La especie y el nivel de infestación son autodeclarados por quien observa, sin validación
> por expertos.

Conserva la parte que sigue siendo cierta (gate #8: especie y nivel **autodeclarados**, nunca
validados) y corrige la que dejó de serlo. **Pendiente de tu visto bueno**: es texto público.

## 7. Fuera de alcance

- No se toca la captura, la autenticación, los roles ni la obfuscación (el binning del calor sigue
  igual).
- No hay migración: `estado_revision` ya existía con los tres valores.
- El voluntario **no** ve el resultado individual de una foto (Q5.A-D1 intacto): el resumen sigue
  siendo agregado y ahora nombra explícitamente las que **siguen en revisión**, para que la brecha
  entre subidas y válidas no se lea como un rechazo.

## 8. Desglose por unidad construible

- **Backend:** `gamification.py` (contadores confirmados, puntos por JOIN, rankings reescritos),
  `routers/me.py` (evidencia + perfil + feedback), `routers/public.py` (gate #9), `indicators.py`
  (G2 + caveat), `routers/analytics.py` (participation.csv), `routers/restricted.py` (filtro),
  `routers/review.py` (refresca L3 al emitir veredicto), `config.py` (`report_timezone`),
  `seed_demo.py`, `schemas.py`.
- **Móvil:** `evidence_screen.dart`, `profile_screen.dart`, `copy.dart`, `models.dart`.
- **Web-admin:** `map_screen.dart` (filtro G1), `data_screen.dart` (2º CSV), `api_client.dart`,
  `copy.dart`.
- **Documentador:** este CR, `TRACEABILITY.md`, bitácora (enmienda gate #9), `CLAUDE.md`.

## 9. Efecto colateral corregido

Al reescribir la consulta de rankings apareció un **error preexistente**: `observation` y
`points_ledger` se unían en el mismo `JOIN`, de modo que cada fila del ledger se repetía una vez por
observación y `sum(points)` salía **multiplicado por el número de observaciones** de la cuenta. La
nueva versión agrega en subconsultas por cuenta y ya no infla. No estaba en el encargo, pero dejar una
suma sabidamente incorrecta en las líneas que había que reescribir habría sido peor.

## 10. Criterios de aceptación

Ver la sección **CR-026** en [`TRACEABILITY.md`](../cambios/TRACEABILITY.md). Definition of Done: todas
las suites verdes con números reales, gates verificados, trazabilidad y bitácora actualizadas.
