# Change Requests — mezquite-software

Solicitudes de cambio **formales** para los dos cambios mayores acordados con el usuario el
**2026-06-15**. Cada CR contiene **toda la información** para ejecutarse con un **equipo de agentes
Claude Code** bajo el modelo de orquestación de [`CLAUDE.md`](../../CLAUDE.md): un **subagente por
unidad construible** (Arquitecto, Dev backend, Dev web-admin, Dev móvil, Tester/QA, Documentador); el
**orquestador secuencia, verifica los gates y corre las pruebas** antes de declarar algo hecho.

## Índice

| CR | Título | Estado | Depende de |
|---|---|---|---|
| [CR-001](CR-001-revision-humana.md) | Revisión humana en el backend (sin YOLO) | ✅ **Integrado en `main`** (163 pruebas verdes) | — |
| [CR-002](CR-002-auth-identidad-real.md) | Autenticación con identidad real (Google/Firebase + usuario/contraseña) | ✅ **Integrado en `main`** (con `MockAuthProvider`; Google real pendiente de Firebase) | CR-001 |
| [CR-003](CR-003-branding-onboarding-app.md) | Branding, splash, ícono y onboarding (apps Flutter) | ✅ **Integrado en `main`** | — |
| [CR-004](CR-004-firebase-ios-cors.md) | Cierres de producción: Google/Firebase real · iOS · CORS | **W3 (CORS) ✅ integrado**; W1 (Firebase) / W2 (iOS) **propuestos** | CR-002, CR-003 |
| [CR-005](CR-005-fe-web-voluntario.md) | FE web del voluntario (teléfono/tablet) | ✅ **Integrado en `main`** (web + branding completo; demo HTTPS por ngrok) | CR-002, CR-003, CR-004 W3 |
| [CR-006](CR-006-arco-terminos-privacidad.md) | ARCO (eliminar cuenta) + Términos y Aviso de privacidad | ✅ **Integrado en `main`** (UI web-admin + legales; texto = BORRADOR del consorcio) | CR-002 |
| [CR-007](CR-007-contenidos-aprender.md) | Contenidos de "Aprender" (texto propio + enlaces "Saber más" curados) | 🟢 **En curso** (carriles A contenido + B móvil) | — |
| [CR-008](CR-008-despliegue-azure.md) | Despliegue en **Azure** (Container Apps + PostgreSQL Flexible Server + Static Web Apps + Key Vault) + backend **Azure Blob** | 📋 **Propuesto — formalizado** (ruta de lanzamiento 10-jul) | CR-004 W1 (auth real) |

**Secuencia acordada:** **CR-001** primero (funda los roles y enmienda gates); **CR-003** en paralelo
(independiente, branding); **CR-002** al final (depende de los roles de CR-001 + Firebase externo).
Orden de **integración** recomendado: CR-001 → CR-003 → CR-002 (minimiza conflictos en archivos móviles
compartidos `app.dart`/`pubspec.yaml`/`copy.dart`).

## Cómo ejecutar un CR con el equipo de agentes

1. **Orquestador** lee el CR completo y abre la **fuente de verdad** (`bitacora_sdd_mezquite.md`) y
   `TRACEABILITY.md`.
2. Aplica la **enmienda de la bitácora** indicada en el CR (decisión humana ya autorizada) **antes**
   de tocar código, para que la fuente de verdad no contradiga la implementación.
3. Lanza **un subagente por unidad construible** en el orden de la sección *Desglose por agente* del
   CR. Cada subagente recibe: objetivo, archivos, criterios de aceptación y pruebas de su unidad.
4. Tras cada unidad, el orquestador **corre las pruebas** y **verifica los gates** listados; no avanza
   si algo falla.
5. **Documentador** actualiza `TRACEABILITY.md`, `ARCHITECTURE.md`, `QUICKSTART.md`/`docs/DESPLIEGUE.md`
   y la bitácora.
6. **Definition of Done** del CR: todas las pruebas verdes (números reales reportados), gates
   verificados, trazabilidad actualizada, bitácora enmendada.

## Convenciones (de CLAUDE.md)

- **Idioma:** español (código, docs y commits).
- **Commits:** `feat(...)`/`chore(...)`/`docs:`; terminar con
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. **No push** salvo que el usuario lo pida.
- **Gates innegociables:** se respetan los que NO cambia el CR; los que el CR enmienda se documentan
  explícitamente en la bitácora con fecha y motivo.
- **Antes de "hecho":** correr pruebas y verificar gates; reportar números reales.
