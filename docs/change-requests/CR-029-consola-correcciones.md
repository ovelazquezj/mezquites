# CR-029 — Correcciones de la consola: contador del Monitor, edición de instituciones y zoom

**Fecha:** 2026-07-28 · **Origen:** tres hallazgos del usuario usando la consola · **Estado:** integrado

Tres asuntos independientes que comparten pantalla (la consola del Club) y se atienden en un lote.

---

## 1. El contador del Monitor no cuadraba (BUG)

**Síntoma reportado:** el Monitor de revisión muestra **58 observaciones** pero **61 "Revisiones
registradas"**.

**Lo que se encontró.** Las dos tarjetas miden cosas distintas: una cuenta filas de `observation`,
la otra filas de `human_review`, que es el **log append-only con una fila por veredicto emitido**
(gate #7). Que 61 > 58 es aritméticamente posible en cuanto una observación se revisa más de una vez.

Pero los datos de producción mostraron que esas 3 de más **no eran revisiones legítimas**:

| | |
|---|---|
| Observaciones | 58 |
| Observaciones con ≥1 revisión | 58 (todas) |
| Filas en `human_review` | 61 |
| Revisiones huérfanas | **0** |
| Observaciones revisadas de más | **2** — una `confirmada → confirmada → confirmada`, otra `confirmada → confirmada` |

Son **el mismo veredicto grabado otra vez**, no un cambio de opinión. La causa son dos huecos que se
suman:

- los tres botones de veredicto están **siempre habilitados**, sin importar el estado actual
  (`review_screen.dart`), así que se puede "Confirmar" una observación ya confirmada;
- el backend **añade una fila al log sin comprobar si el veredicto cambia algo** (`review.py`).

**Solución.**

1. **Backend — veredicto idempotente:** si el veredicto recibido es igual al `estado_revision`
   actual, **no se escribe en el log**; responde 200 con `sin_cambio=true` y un mensaje que dice que
   ya estaba en ese estado. Se eligió no-op y no un 409 por el mismo criterio que CR-028: no castigar
   el clic del revisor, pero tampoco ensuciar el dato. **Gate #7 intacto:** el log sigue siendo
   append-only — negarse a escribir de más no es reescribir historia.
2. **Consola — el botón del estado actual no se ofrece:** el veredicto que ya corresponde aparece
   deshabilitado y marcado como el estado vigente, así que el clic redundante ni siquiera se plantea.
3. **Monitor legible:** nueva tarjeta **"Observaciones revisadas"** (distintas, no eventos) y la otra
   pasa a llamarse **"Veredictos emitidos (incluye re-revisiones)"**. Dos números que miden cosas
   distintas dejan de parecer una contradicción.

**Limpieza del dato existente (autorizada por el usuario):** se borran las **3 filas redundantes**
—las repeticiones—, conservando **la primera de cada observación**, que es la que efectivamente
produjo el cambio de estado. Las primeras observaciones del piloto fueron de prueba, y el usuario
autorizó expresamente la limpieza. No se toca ninguna otra fila del log.

---

## 2. Editar una institución ya registrada

**Faltante:** `/admin/institutions` solo tenía `GET`, `POST` y `approve`. No había forma de corregir
un nombre mal escrito sin entrar a la base — la deuda que CR-028 dejó anotada.

**Solución.** `PATCH /admin/institutions/{id}` con `name` y/o `estado` opcionales, y en la consola un
botón **"Editar"** por renglón que abre un diálogo precargado.

- **Respeta el índice único de CR-028:** renombrar a un nombre que ya usa **otra** institución
  responde **409** nombrándola. La comprobación excluye la propia fila (renombrar
  "Universidad X" → "universidad x" es legítimo: es la misma institución cambiando de escritura).
- **NO cambia el `status`** (decisión del usuario). Degradar una `aprobada` la sacaría del catálogo
  con voluntarios ya afiliados; para aprobar sigue estando el botón "Aprobar", en un solo sentido.
- **Renombrar no repunta nada:** las cuentas cuelgan del `id`, no del nombre, así que el cambio se
  refleja de inmediato en rankings, catálogo y perfiles sin migrar datos.

---

## 3. Zoom en la imagen de revisión

**Faltante:** la foto se pintaba como miniatura fija (`Image.memory` con `height: 280`), sin zoom de
ningún tipo, lo que impedía juzgar detalle fino (parásitos, daño) al revisar.

**Solución.** Clic en la foto → visor a pantalla completa con `InteractiveViewer`: arrastrar, zoom
hasta 8×, doble clic para acercar/alejar, botones **+ / − / restablecer** y cierre con × o `Esc`.

**Sin backend.** Los bytes en resolución completa **ya están en el navegador** (`reviewImageBytes`
los descarga con el header de autorización). El zoom es puramente cliente: no hay peticiones nuevas
ni se toca el endpoint de imagen ni su RBAC. Los botones explícitos no son adorno — el zoom por rueda
del ratón se comporta distinto según navegador y trackpad, y el revisor no debería depender de eso.

---

## Criterios de aceptación

Ver la tabla en [`TRACEABILITY.md`](../cambios/TRACEABILITY.md#cr-029).

## Gates

Ninguno se enmienda. **#7 reforzado:** el log de revisión deja de acumular entradas que no
corresponden a un cambio real. **#2 intacto:** nada de esto toca datos personales — la edición de
instituciones es catálogo y el visor no envía nada.
