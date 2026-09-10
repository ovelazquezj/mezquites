# CR-040 — Administrar cuentas desde la consola (eliminar y cambiar de rol)

**Estado:** integrado (2026-09-10) · **Alcance:** backend + consola · **Sin migración**

**Origen:** el usuario intentó eliminar por sí mismo una cuenta de administrador desde la consola y
no pudo, y reportó además que *"no hay forma de realizar cambios a los permisos de usuario, para
cambiar por ejemplo el rol"*.

---

## 1. El diagnóstico

Se revisó **producción antes de tocar código**. No era un problema de permisos.

### 1.1 La cuenta era inencontrable, no inaccesible

La pantalla ARCO dice *"Buscar por usuario o handle"*, pero el backend filtraba **solo por
`handle`**. Y el handle de un usuario de consola es autogenerado (`obs-LVSDJW`) y **no se muestra en
ninguna pantalla**: la lista de "Usuarios del equipo" enseña el `username`, que es con lo que esa
persona entra.

Lo confirma el log de la API de ese mismo día:

```
GET /api/v1/admin/accounts?handle=kari&limit=50  →  200 OK   (lista vacía)
```

Doscientos: la autorización estaba bien. Simplemente no había ninguna fila que devolver, y sin fila
no hay `id`, y sin `id` no hay `DELETE` posible. **La pantalla prometía una búsqueda que el servidor
no hacía.**

### 1.2 El cambio de rol estaba construido y desconectado

`PATCH /admin/users/{id}` existe desde CR-002 y acepta un rol nuevo. El cliente Dart tiene
`patchUserRole`. **Ninguna pantalla lo llamaba**: código muerto durante casi tres meses. Verificado
también contra el bundle desplegado, donde *"Cambiar rol"* aparece **cero** veces.

La pantalla de usuarios ofrecía una sola acción por renglón: restablecer la contraseña.

### 1.3 El bug latente que nadie había disparado todavía

Al leer el borrado ARCO apareció algo que el reporte no mencionaba. El endpoint repuntaba a la
cuenta centinela las observaciones, el ledger de puntos y las revisiones, pero **no**
`participation_session` ni `problem_report`, que también apuntan a `account` sin `ON DELETE`.

`participation_session.account_id` es **NOT NULL**. Como la app registra sesiones automáticamente
desde CR-010, **casi cualquier voluntario tiene filas ahí**: eliminar su cuenta habría reventado con
un error de llave foránea y un 500, justo en el flujo de una solicitud ARCO, que es de las pocas
cosas de este sistema con un plazo legal detrás.

No se vio en la eliminación manual de esa cuenta de administrador porque tenía **cero filas en las
seis tablas**.

Durante la implementación apareció una séptima ruta del mismo problema:
`account_deletion.executed_by_account_id`. Un administrador que ya hubiera ejecutado cancelaciones
no podía ser eliminado — exactamente el flujo que este CR habilita.

---

## 2. Diseño

### 2.1 Backend

- **Búsqueda por handle O username.** `GET /admin/accounts` filtra con `ILIKE` sobre ambos y acepta
  `q` como alias de `handle`. La respuesta gana `username`, para que la consola pueda mostrar un
  nombre reconocible.
- **ARCO repunta las seis llaves foráneas** a `account`, en la misma transacción: observaciones (con
  handle anónimo), puntos, revisiones, sesiones de participación, reportes de problema (con handle
  anónimo, conservando el diagnóstico técnico) y auditorías ejecutadas.
  En `account_deletion` se anonimiza **quién ejecutó**, nunca **qué se eliminó**: `deleted_account_id`
  no es llave foránea y no se toca, así que el registro histórico sobrevive intacto (gate #7). Es el
  mismo criterio que ya se aplicaba al revisor en el log de revisión.
- **Cuenta de administrador principal protegida.** Es la que coincide con `BOOTSTRAP_ADMIN_USERNAME`.
  No se elimina y no cambia de rol. Si la variable no está configurada, **no hay cuenta protegida**:
  blindar la cuenta equivocada sería peor que no blindar ninguna.
- **Dos frenos en el cambio de rol:** nadie cambia su **propio** rol, y la cuenta principal no cambia
  de rol. Sin esto, un administrador podía degradarse a analista o degradar al último administrador
  y **dejar el sistema sin nadie que pueda crear administradores desde la API**: la única salida
  sería entrar al servidor a correr el bootstrap a mano.
- Las respuestas exponen `protected` para que la consola no ofrezca acciones que el backend va a
  rechazar.

### 2.2 Consola

- **Usuarios del equipo**, por renglón: selector de rol y botón de eliminar, además del
  restablecimiento de contraseña que ya había. Ambos con confirmación. El aviso de que se pierde el
  correo de recuperación sale **solo cuando de verdad aplica**: baja desde administrador y la cuenta
  tiene correo.
- Las dos acciones quedan **deshabilitadas** sobre la propia cuenta y sobre la principal, con una
  marca visible en el renglón.
- **Eliminar cuenta:** los resultados muestran el nombre de usuario como título y el handle debajo,
  para que un usuario de consola sea por fin distinguible.
- El diálogo de confirmación con motivo se extrajo a un widget compartido, con prefijo de claves,
  para que las dos pantallas usen el mismo sin que la pantalla ARCO cambie de comportamiento.

---

## 3. Gates

- **#2 (mínima PII) — intacto.** Ninguna pantalla ni respuesta expone un correo; solo la señal de si
  la cuenta tiene uno. El `username` de las cuentas de consola no es PII nueva: CR-002 ya lo define
  como identidad real por diseño para los roles de backend. Hay prueba de que ninguna respuesta
  incluye `email`.
- **#7 (trazabilidad) — reforzado.** La auditoría de cancelación sigue siendo append-only y conserva
  qué se eliminó. Cada criterio de aceptación tiene prueba.
- **#3 (sin gating) — intacto.** Nada de esto toca al voluntario.
- **#1, #4, #6, #9 — no se tocan.** La app del voluntario no cambia. Sin migración.

Ninguna decisión sellada se enmienda.

---

## 4. Fuera de alcance (explícito)

- **Fusionar instituciones duplicadas.** Sigue siendo deuda abierta desde CR-028.
- **Revocación de tokens.** Un usuario degradado de rol conserva su token hasta que vence, con el
  rol anterior en los claims. Deuda de CR-027, que este CR no cierra y sí vuelve más visible.
- **Reactivar o suspender cuentas sin eliminarlas.** El esquema no tiene un campo de estado.
- **Que el administrador vea el correo de otro administrador.** Contra el gate #2.

---

## 5. Criterios de aceptación

| # | Criterio | Prueba |
|---|---|---|
| **AC1** La búsqueda encuentra por nombre de usuario parcial | `test_cr040_admin_cuentas.py` |
| **AC2** La búsqueda por handle sigue funcionando, y el alias `q` también | ídem |
| **AC3** La respuesta trae `username` y `protected` | ídem |
| **AC4** ARCO sobre una cuenta con filas en las seis tablas: la identidad desaparece y las seis quedan a nombre de la centinela | ídem |
| **AC5** El reporte de problema conserva el diagnóstico y pierde el vínculo con la persona | ídem |
| **AC6** Un administrador puede eliminar a otro administrador que ya ejecutó cancelaciones | ídem |
| **AC7** Eliminar la cuenta principal se rechaza | ídem |
| **AC8** Sin `BOOTSTRAP_ADMIN_USERNAME`, ninguna cuenta queda protegida | ídem |
| **AC9** Cambiar el propio rol se rechaza | ídem |
| **AC10** Cambiar el rol de la cuenta principal se rechaza | ídem |
| **AC11** Bajar de administrador limpia el correo | ídem |
| **AC12** Ninguna respuesta expone un correo (gate #2) | ídem |
| **AC13** El selector de rol envía el cambio solo tras confirmar, y nada si se cancela | `widget_users_test.dart` |
| **AC14** El borrado envía el motivo solo tras confirmar, y nada si se cancela | ídem |
| **AC15** Las dos acciones quedan deshabilitadas sobre la propia cuenta y la principal | ídem |
| **AC16** Los resultados de "Eliminar cuenta" muestran el nombre de usuario | `widget_accounts_test.dart` |
| **AC17** Un JSON sin los campos nuevos no rompe la consola | ambas |

**628 pruebas verdes** (21 contrato · 9 mock · **248** backend · 205 móvil · **145** consola),
2026-09-10. Delta: 13 de backend y 9 de consola.

---

## 6. Nota operativa

La cuenta de administrador que originó el reporte se eliminó **a mano en la base**, antes de este CR,
con respaldo previo y una guarda que abortaba si la sentencia afectaba algo distinto de una fila. No
tenía actividad en ninguna de las seis tablas, así que no hizo falta anonimizar nada. Con este CR,
ese mismo caso ya se resuelve desde la consola.

---

## 7. Despliegue

Backend + bundle de la **consola**. La app del voluntario **no cambia**, así que su bundle no se
toca y su caché no se invalida sin motivo. Sin migración: alembic sigue en `0009`.

Trampas vigentes del runbook: `--env-file .env.prod` en todo `docker compose` de la VM,
`rsync -a --delete` **en el lugar**, `git checkout deploy` pisa los `build/web` recién compilados, y
la verificación del hash se hace **desde la propia VM**, no desde la máquina local.
