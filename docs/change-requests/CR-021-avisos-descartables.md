# CR-021 — `InfoNote` colapsable / descartable

| Campo | Valor |
|---|---|
| **ID** | CR-021 |
| **Fecha** | 2026-06-28 |
| **Estado** | ✅ Implementado en `main` (local), pendiente de desplegar |
| **Alcance** | `mobile/` |
| **Relación** | Mejora de UX sobre el widget `InfoNote` (usado en toda la app del voluntario) |
| **Ejecución** | Directo sobre `main`, por el orquestador |

## 1. Contexto

Los avisos informativos (las tarjetas verdes `InfoNote`) quedaban **fijos** en pantalla. Tras leerlos una
vez, seguían ocupando espacio en cada visita, sin forma de ocultarlos.

## 2. Decisión del usuario (2026-06-28)

Permitir **descartar** los avisos informativos, recordando el descarte entre sesiones, sin que cerrarlos
bloquee ninguna función.

## 3. Qué se hizo

| Pieza | Detalle |
|---|---|
| `InfoNote` → `StatefulWidget` | Se agregó un botón **"X"** (key `info_note_dismiss`) que oculta el aviso. |
| Persistencia del descarte | Se **recuerda** entre sesiones vía `SharedPreferences` (y `localStorage` en web). Acceso **defensivo** con `try/catch` para no romper pruebas/entornos sin el plugin. |
| Identificador | Por `id` opcional, o **derivado del texto** del aviso si no se da `id`. |
| Aplicación | Los **12 usos** quedan `dismissible: true` por defecto. Algunos avisos clave se dejan **fijos** con `dismissible: false` (p. ej. la intro de "Reportar un problema", CR-019). |
| Archivo | `mobile/lib/src/ui/widgets/common.dart` (`InfoNote`). |

## 4. Gates

- **Gate #3 (sin gating):** **intacto** — el aviso es **informativo**; cerrarlo **no bloquea** ni
  condiciona ninguna acción.
- **Gate #2 (sin PII):** **intacto** — el descarte guarda solo una bandera por `id`/texto, sin datos de
  usuario.
- Resto de gates: sin cambios.

## 5. Pruebas / verificación

- **3** pruebas nuevas (móvil): el botón oculta el aviso, el descarte persiste, y un aviso `dismissible:
  false` no muestra la "X".
- Suite móvil completa verde tras el cambio (66).

## 6. Notas

- El acceso defensivo a `SharedPreferences`/`localStorage` evita fallos en la VM de pruebas (sin plugin)
  y en navegadores con almacenamiento restringido.
