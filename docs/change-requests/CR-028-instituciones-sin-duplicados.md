# CR-028 — Una institución por nombre (antiduplicados)

**Fecha:** 2026-07-28 · **Origen:** hallazgo en producción · **Estado:** integrado (sin desplegar)

## Qué pasó

En producción convivían **dos "Global University"**: una con `estado = 'Aguascalientes'` y otra con
`estado = NULL`. No fue un descuido de quien capturó: **ninguna de las cuatro capas comprobaba si el
nombre ya existía.**

| Capa | Qué había |
|---|---|
| Base | `institution.name` es `Text` sin `UNIQUE` ni índice (migración `0001`) |
| Backend | `POST /institutions/request` y `POST /admin/institutions` insertaban a ciegas |
| Esquemas | `name: str` pelado: sin recorte, sin normalizar mayúsculas/acentos |
| App (login) | Campo de texto libre que **no** cotejaba contra el catálogo que ya tenía cargado |

La huella confirmó los dos caminos: el registro con `estado = NULL` sale del **login**
(`welcome_screen` llama a `requestInstitution(name:)` sin estado) y el que trae estado sale del
diálogo de **Cuenta** o de la consola.

### El lazo que lo hacía inevitable

`GET /institutions` lista **solo las `aprobada`**. Una institución recién solicitada es invisible en
el desplegable, así que el siguiente voluntario de esa misma universidad no la ve, la vuelve a
escribir y nace la gemela. Después el administrador aprueba las dos. **El flujo fabricaba los
duplicados**; no dependía de que alguien se equivocara.

## Qué se hizo

**Regla única de "el mismo nombre"** — igual tras quitar acentos, pasar a minúsculas, colapsar los
espacios internos y recortar los extremos. Vive en `backend/app/institution_names.py` y se comparte
con las tres capas que deben coincidir: la expresión SQL del índice, la búsqueda del backend y la
réplica en Dart (`Institution.normalizeName`).

1. **Base (última línea de defensa):** índice único `ux_institution_nombre_norm` sobre el nombre
   canónico (migración `0007`). Ni un `INSERT` directo puede duplicar. La migración **se detiene y
   enumera** los duplicados si los hubiera: fusionar exige decidir cuál sobrevive y repuntar las
   cuentas, y eso no lo debe adivinar una migración.
2. **Voluntario (`POST /institutions/request`): reusa, no rechaza.** Si el nombre ya existe, la
   cuenta queda afiliada a la institución existente y se responde **200** con `ya_existia: true`
   (crear sigue siendo 201). **Un 409 aquí estaría mal:** el catálogo público solo muestra las
   aprobadas, así que quien escribe el nombre de una institución todavía en revisión no puede
   "elegirla" de ninguna lista — rechazarlo lo dejaría sin salida y rompería el gate #3. Este reuso
   es justamente lo que cierra el lazo descrito arriba.
3. **Consola (`POST /admin/institutions`): 409** nombrando la que ya está y su situación. Aquí sí
   conviene el error: el administrador ve la lista completa —incluidas las `solicitada`— y puede
   aprobarla o editarla; un alta que "no hace nada" le ocultaría que su captura era redundante.
4. **Login (la pantalla del hallazgo):** antes de encolar el registro, coteja el nombre escrito
   contra el catálogo **que ya tiene en memoria**. Si coincide, selecciona esa institución y lo
   dice ("«X» ya está en la lista. La seleccionamos por ti."). Ningún POST de alta sale.
5. **Cuenta:** distingue "solicitud enviada" de "ya estaba registrada; quedaste afiliado a ella",
   para que nadie espere una aprobación que no va a llegar.
6. **Esquemas:** el nombre se guarda con espacios normalizados y no puede ir vacío; un `estado` en
   blanco se guarda como `NULL` (la consola manda `''` cuando lo dejas vacío, y `''` vs `NULL` era
   otra forma de que dos filas parecieran distintas).
7. **Siembra:** compara por nombre canónico. Antes usaba `one_or_none()` sobre el nombre literal, así
   que una variante capturada a mano no se reconocía **y**, si ya había dos iguales, la siembra
   reventaba con `MultipleResultsFound`.

## Criterios de aceptación

Ver la tabla en [`TRACEABILITY.md`](../cambios/TRACEABILITY.md#cr-028).

## Gates

Ninguno se enmienda. **#3 (sin gating) preservado a propósito:** al voluntario nunca se le bloquea —
si escribe un nombre existente queda afiliado a esa institución, no rechazado. **#2** intacto (el
catálogo no tiene PII). **#7:** cada criterio tiene prueba.

## Lo que este CR NO hace

- **No fusiona duplicados existentes.** Los dos "Global University" de producción se fusionaron a
  mano el 2026-07-28 (11 cuentas repuntadas a la fila con estado, la otra eliminada; respaldo
  `pg_dump` previo en la VM). La migración `0007` **fallará** en cualquier base que aún tenga
  duplicados, por diseño.
- **No agrega fusionar/renombrar/eliminar a la consola.** Hoy `/admin/institutions` solo tiene
  `GET`, `POST` y `approve`: si vuelve a colarse un duplicado —por ejemplo dos nombres realmente
  distintos para la misma escuela, que ninguna regla automática puede detectar— sigue haciendo falta
  entrar a la base. Queda como pendiente.
- **No cambia qué muestra el catálogo público** (sigue listando solo las aprobadas). El reuso del
  punto 2 neutraliza la consecuencia sin tocar esa decisión de producto.
- **No normaliza los nombres ya capturados** ("universidad británica" en minúsculas, "Instituto
  Tecnológico de Aguascalientes" sin el "(TecNM)" de la lista sembrada). Son decisiones de catálogo,
  no de software.
