# CR-006 — Cumplimiento de datos: ARCO (eliminación) + Términos y Aviso de privacidad

| Campo | Valor |
|---|---|
| **ID** | CR-006 |
| **Título** | Derecho ARCO de **Cancelación** (eliminar cuenta, anonimizando datos) + páginas de **Términos y Condiciones** y **Aviso de privacidad** |
| **Fecha** | 2026-06-16 |
| **Estado** | **Aprobado — en ejecución (Carril B)** |
| **Prioridad** | **Alta** — compliance para el lanzamiento web (2026-07-10) |
| **Depende de** | CR-002 (identidad real) |
| **Alcance** | Backend (eliminación/anonimización) + web-admin (UI ARCO) + contenido legal (Términos/Aviso) y su despliegue en app/web. |

---

## 1. Contexto

CR-002 introdujo **identidad real** (Google en la app; usuario/contraseña en backend). Eso activa
obligaciones de protección de datos (**LFPDPPP**, derechos **ARCO**) y la necesidad de publicar
**Términos y Condiciones** y **Aviso de privacidad** antes del lanzamiento. Este CR cubre el mínimo
para compliance al lanzar.

## 2. Decisiones tomadas (del usuario)

1. **Solo Cancelación** (eliminar cuenta) por ahora; Acceso (exportar) y Rectificación después.
2. Al eliminar, **anonimizar** las observaciones (se **conserva el dato ecológico**, se quita el
   vínculo a la persona); **no** se borran las observaciones.
3. Lo **ejecuta el `administrador`** desde la **web-admin** (no auto-servicio del usuario, por ahora).
4. **Crear** la página de **Términos y Condiciones** y el **Aviso de privacidad** (compliance de una vez).

## 3. Gates

**No enmienda gates.** Refuerza el **gate #2** (tras eliminar no queda PII de esa persona) y usa el
**gate #7** (la eliminación queda **auditada**, sin PII). Autorización estricta: **solo `administrador`**.

## 4. Diseño técnico

### 4.1 Backend — eliminación + anonimización
- **`DELETE /admin/accounts/{id}`** (o `/admin/users/{id}`), **solo `administrador`** (`require_role`).
- Al ejecutar:
  - **Anonimiza las observaciones** del usuario: el `handle` denormalizado pasa a un valor anónimo
    (p. ej. `anonimo`) y el vínculo a la persona se rompe (repuntar `account_id` a una **cuenta
    centinela "eliminada"** o equivalente; conservar geom/etiquetas/estado_revision intactos para el
    dataset).
  - **Elimina la identidad**: `provider_subject`, `username`, `password_hash`, `email`, `recovery_hash`
    y la fila de `account` (o se marca eliminada sin PII). `points_ledger` se conserva o anonimiza.
  - **Auditoría (gate #7):** registrar el evento de eliminación **sin PII** (id de cuenta, quién la
    ejecutó, fecha; nunca el email/sub).
- **Invariantes:** el dataset público (`/public/observations`) sigue funcionando tras anonimizar; no se
  rompen FKs; no reaparece PII.

### 4.2 Web-admin — UI ARCO
- Pantalla **ARCO / Eliminar cuenta** (solo `administrador`): buscar cuenta → **Eliminar** con
  **confirmación** (y campo de motivo) → muestra resultado. Nav role-gated.

### 4.3 Contenido legal — Términos y Aviso de privacidad
- **Redactar en español** (borrador) acorde a LFPDPPP, cubriendo: **datos que se recaban** (voluntario:
  solo el `id` opaco del proveedor — sin email/nombre; backend: `username`, y `email` solo del
  administrador), **finalidad** (ciencia ciudadana del mezquite), **no venta/no cesión indebida**,
  **derechos ARCO y cómo ejercerlos** (hoy: vía el consorcio/administrador), **conservación**,
  **obfuscación de ubicación** (gate #5) y **contacto**.
- **Dónde vive:** fuente en `docs/legal/terminos.md` y `docs/legal/aviso-privacidad.md`; **se muestran
  y enlazan** en la app/web del voluntario (en el "Entrar con Google" / Ayuda) y en la web-admin.
- ⚠️ **Borrador sujeto a revisión legal/humana.** Cierra el pendiente *"texto final del disclaimer/
  aviso"* de la bitácora **solo** cuando el consorcio lo apruebe; el equipo entrega un borrador sólido,
  **no** asesoría legal.

## 5. Desglose por agente

| # | Agente | Unidad | Archivos | Pruebas |
|---|---|---|---|---|
| F0 | Arquitecto | Estrategia de anonimización (centinela vs. nullable) sin romper FK/dataset | — | — |
| F1 | Dev backend | `DELETE` cuenta + anonimización + auditoría + router en `main.py` | `backend/app/routers/*`, `models.py`, `main.py`, migración si aplica | borrado anonimiza; authz; dataset intacto |
| F2 | Dev web-admin | Pantalla ARCO (buscar → eliminar) + nav | `web-admin/lib/src/screens/*`, `api_client.dart` | widget test; solo admin |
| F3 | Documentador | Términos + Aviso (borrador) + enlace en app/web y web-admin | `docs/legal/*.md`, pantallas/enlaces | contenido accesible; marcado borrador |
| F4 | Tester/QA | Pruebas + trazabilidad | `backend/tests/*`, `web-admin/test/*`, `TRACEABILITY.md` | suite verde |

## 6. Criterios de aceptación

- AC1: El `administrador` elimina una cuenta desde la web-admin → la **identidad desaparece** (sin
  `email`/`sub`/`username`), las **observaciones quedan anonimizadas** y **siguen** en el dataset
  público. *(test backend)*
- AC2: Un rol no-administrador recibe **403** al intentar eliminar. *(test backend)*
- AC3: La eliminación queda **auditada sin PII** (gate #7). *(test backend)*
- AC4: **Términos** y **Aviso de privacidad** están redactados (borrador) y **accesibles/enlazados** en
  la app/web del voluntario y en la web-admin.
- AC5: `gate #2` se mantiene (no reaparece PII); `flutter analyze` y suites verdes.

## 7. Riesgos
- **Romper el dataset o FKs** al anonimizar → AC1 lo cubre; usar centinela/transacción.
- **Texto legal sin validar** → entregado como **borrador**; la aprobación final es del consorcio.

## 8. Definition of Done
Eliminación admin con anonimización + auditoría (AC1–AC3); Términos/Aviso accesibles (AC4); gate #2/#7
respetados; pruebas verdes con números reales. No enmienda gates.
