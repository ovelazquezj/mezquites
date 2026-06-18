# Documentación — Mezquite

Índice de la documentación del proyecto. La portada general está en el [`README.md`](../README.md) raíz.

## Estructura

| Carpeta | Contenido |
|---|---|
| [`sdd/`](sdd/) | **Fuente de verdad**: bitácora de la especificación dirigida por decisiones (SDD). Sellada. |
| [`arquitectura/`](arquitectura/) | Arquitectura del software (`ARCHITECTURE.md`) y diseño de autenticación (`auth.md`). |
| [`despliegue/`](despliegue/) | Runbooks: `QUICKSTART.md`, `DESPLIEGUE.md` (K8s/Azure), `DESPLIEGUE-SERVIDOR-UNICO.md`, `INFRAESTRUCTURA-AZURE.md`. |
| [`cambios/`](cambios/) | Trazabilidad (`TRACEABILITY.md`): criterio de aceptación → prueba. |
| [`change-requests/`](change-requests/README.md) | Solicitudes de cambio formales (CR-001 … CR-014). |
| [`proyecto/`](proyecto/) | Documentos del proyecto: propuesta, protocolo de campo, presentación. |
| [`referencias/`](referencias/) | Bibliografía (`.bib`). |
| [`data-model/`](data-model/) | Modelo de datos PostGIS. |
| [`design-system/`](design-system/) | Tokens de diseño (fuente única de estilo, copiada a los clientes). |
| [`adr/`](adr/) | Architecture Decision Records. |
| [`learning/`](learning/) | Contenidos de "Aprender" (fuente, copiada a los assets de la app). |
| [`legal/`](legal/) | Términos y Aviso de privacidad (borrador). |

## Atajos

- **¿De dónde salen las decisiones?** → [`sdd/bitacora_sdd_mezquite.md`](sdd/bitacora_sdd_mezquite.md)
- **¿Cómo está construido?** → [`arquitectura/ARCHITECTURE.md`](arquitectura/ARCHITECTURE.md)
- **¿Cómo lo levanto/despliego?** → [`despliegue/QUICKSTART.md`](despliegue/QUICKSTART.md) · [`despliegue/DESPLIEGUE-SERVIDOR-UNICO.md`](despliegue/DESPLIEGUE-SERVIDOR-UNICO.md)
- **¿Qué se ha cambiado y por qué?** → [`change-requests/`](change-requests/README.md)
- **¿Qué prueba cubre cada criterio?** → [`cambios/TRACEABILITY.md`](cambios/TRACEABILITY.md)
