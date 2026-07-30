# CR-030 — Números reales para el voluntario

**Fecha:** 2026-07-29 · **Origen:** voluntarios reportan que "la app solo deja registrar 20
mezquites" · **Estado:** integrado

---

## 1. El síntoma y lo que realmente pasaba

Varios voluntarios reportaron que la app **solo les permite registrar 20 observaciones**. Se revisó
la base de **producción** antes de tocar código. El registro **no tiene ningún tope**.

> **Las cifras de abajo son una fotografía del 2026-07-29 ~15:20 h (America/Mexico_City)**, no un
> estado permanente: seis horas después había **331** observaciones (164 capturas nuevas esa misma
> tarde). Ver §11 de CR-031 para el muestreo posterior.

| handle | subidas reales | perfil "válidas" | puntos | "de tus últimas N" |
|---|---|---|---|---|
| obs-4JCM4Q | **37** | 37 | 555 | **20** |
| obs-VDMTJK | **31** | 3 | 45 | **20** |
| obs-GVFRFU | **29** | 2 | 30 | **20** |
| obs-3XDAFB | **27** | 2 | 30 | **20** |
| obs-CMVPR8 | **22** | 2 | 30 | **20** |
| obs-2W4CQU | 13 | 12 | 180 | 13 |

Una sola cuenta subió **37 observaciones en 47 minutos** (28-jul, 12:07–12:54). Las 167 filas de
`observation` tienen imagen (0 sin `image_ref`, 167 claves distintas) y el retraso entre la captura
y el `created_at` del servidor es de **19–23 s de promedio, 109 s el máximo**: las subidas entraban
en tiempo real y nada se quedó atorado.

**El 20 estaba hardcodeado, pero en el texto, no en el registro.** `feedback_window: int = 20`
(`backend/app/config.py`) era el `LIMIT` de la consulta de `GET /me/feedback`, y ese endpoint
produce la frase de **Perfil → "Tu aporte"**:

> "De tus últimas **20** observaciones, X ya están confirmadas y Y siguen en revisión."

La frase **se congela en 20** para cualquiera que pase de 20 y muestra el total real por debajo de
ese umbral. Por eso el hallazgo era invisible desde una cuenta con 13 capturas: su frase decía 13.

El caso más confuso era `obs-4JCM4Q`, que leía en la **misma pantalla** "Observaciones válidas: 37"
(tarjeta *Tu actividad*) y "De tus últimas **20** observaciones, 20 ya están confirmadas" (tarjeta
*Tu aporte*, inmediatamente debajo). Dos cifras contradictorias a dos centímetros.

### 1-bis. El agravante que no es el 20

De las 167 observaciones, **102 seguían en `aceptada`** (sin revisar). Desde CR-026 los contadores
del voluntario cuentan **solo `confirmada`**, así que quien subió 31 leía "Observaciones válidas: 3"
y 45 puntos en vez de 465. Ese voluntario también reporta que "no le registró". El criterio de
CR-026 **no se reabre** (es petición de las universidades, gate #9): lo que se corrige es que el
total subido **nunca aparecía en ninguna parte de Perfil**, así que la única lectura posible era
"se perdieron".

---

## 2. Qué cambia

**Principio:** el voluntario ve **el número real de lo que subió**, junto al de lo confirmado, y la
brecha entre ambos se explica como cola de revisión.

### Backend

1. **`GET /me/feedback` — se retira la ventana.** El resumen se calcula sobre **todas** las
   observaciones de la cuenta, no sobre las últimas N. `feedback_window` **se elimina** de la
   configuración: era la causa del reporte y no tenía razón de existir (nadie la sobrescribía en
   producción; se verificó el entorno del contenedor `api`).
2. **Mensaje nuevo:** *"Subiste N observaciones. M están confirmadas y K siguen en revisión."*
   Sigue siendo **agregado** (gate Q5.A-D1: nunca dice qué foto).
3. **`en_revision` viaja explícito** en `/me/feedback`, `/me/profile` y `/me/evidence`. Antes la app
   lo deducía restando `totales − confirmadas`, resta que **contaba las rechazadas como "en
   revisión"** (bug menor, ver §4).
4. **`total_uploaded` nuevo en `/me/profile`.** `total_observations` **no se toca**: sigue siendo el
   conteo de confirmadas que alimenta insignias y etiqueta L3 (CR-026).
5. **`account_review_counts()`** en `gamification.py`: los cuatro conteos (total, confirmada,
   aceptada, rechazada) en **una sola consulta** agregada, en vez de tres `count(*)` sueltos.

### App del voluntario

6. **Perfil → "Tu actividad"** pasa a mostrar **"Observaciones subidas"** (el total real) junto a
   **"Confirmadas por revisión"**, con una nota que explica la diferencia cuando hay algo en cola.
7. **Perfil → "Tu aporte"** deja de decir 20: pinta el mensaje del servidor, ya corregido.
8. **Mi participación** gana el StatTile **"Observaciones subidas"** y su nota de pendientes usa el
   `en_revision` del servidor.

### Compatibilidad con bundles en caché

El campo `window` **se conserva en la respuesta** (deprecado, ahora igual al total) para que una PWA
con bundle viejo en caché no reviente al parsear. Como el `message` lo arma el **servidor**, esos
clientes viejos **ven el texto corregido en cuanto se despliega el backend**, sin reinstalar nada.

---

## 3. Lo que NO cambia (decisiones respetadas)

- **Gate #9 / CR-026 intacto:** conteos "válidos", insignias, etiqueta L3, puntos, mapas públicos e
  indicadores siguen contando **solo `confirmada`**. Este CR **añade** el dato crudo al lado; no
  redefine qué es válido.
- **Gate Q5.A-D1 intacto:** el resumen sigue siendo agregado.
- **Las rechazadas no se le muestran al voluntario** (decisión del usuario, 2026-07-29). El mensaje
  nombra confirmadas y en revisión; el total subido se presenta como cifra aparte. Consecuencia
  asumida: para quien tenga rechazos, confirmadas + en revisión **no suman** el total subido, y esa
  diferencia no se explica en pantalla.
- **Ningún gate se enmienda. Sin migración de esquema** (no se toca ninguna tabla).

---

## 4. Bug menor corregido de paso

En *Mi participación*, `pendientes = capturasTotales − capturas` (`models.dart`) contaba las
**rechazadas** como "siguen en revisión". Con 13 subidas / 12 confirmadas / 1 rechazada, la app
decía *"Subiste 13 en total; 1 siguen en revisión"* cuando esa 1 estaba rechazada. Ahora usa el
`en_revision` del servidor.

---

## 5. Lo que este CR NO arregla (deuda anotada)

Durante la investigación salió un problema **independiente y más grave**, que se deja fuera a
propósito para no mezclar alcances:

- **El envío es *fire-and-forget* y falla en silencio.** `capture_screen.dart` muestra "Observación
  registrada y aceptada" **antes** de que el POST responda, y `.catchError((_) {})` se traga el
  error. La `PendingQueue` existe pero es **solo en memoria**, **ningún widget la pinta** y **no hay
  reintento**; la app tampoco maneja el **401** de un token vencido (TTL 7 días, CR-027), así que
  una sesión muerta descarta cada captura sin avisar.
- **No hay almacenamiento sin conexión:** una captura tomada sin red se pierde y el usuario ve un
  mensaje de éxito.

Los datos de producción **no muestran evidencia de un corte sistemático** (subidas en tiempo real,
0 observaciones sin imagen), pero por diseño ese fallo no deja rastro en la base. Amerita su propio
CR.

---

## 6. Criterios de aceptación

| # | Criterio | Prueba |
|---|---|---|
| AC-1 | `/me/feedback` considera **todas** las observaciones, no 20 | `test_cr030_numeros_reales.py::test_feedback_sin_ventana_de_20` |
| AC-2 | El mensaje nunca dice "20" por tope y nombra el total real | `test_cr030_numeros_reales.py::test_feedback_mensaje_usa_total_real` |
| AC-3 | El mensaje sigue siendo agregado y no nombra rechazos | `test_rankings_profile.py::test_feedback_is_aggregate_not_individual` |
| AC-4 | `/me/profile` expone `total_uploaded` sin alterar `total_observations` | `test_cr030_numeros_reales.py::test_profile_expone_subidas_sin_tocar_confirmadas` |
| AC-5 | `en_revision` excluye rechazadas en profile y evidence | `test_cr030_numeros_reales.py::test_en_revision_excluye_rechazadas` |
| AC-6 | Perfil muestra subidas y confirmadas por separado | `cr030_numeros_reales_test.dart::perfil muestra subidas y confirmadas` |
| AC-7 | Mi participación no cuenta rechazadas como "en revisión" | `cr030_numeros_reales_test.dart::mi participación usa en_revision` |
| AC-8 | El modelo tolera un backend sin los campos nuevos | `cr030_numeros_reales_test.dart::modelos toleran respuesta antigua` |
