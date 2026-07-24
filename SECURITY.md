# Política de seguridad

Este repositorio sostiene un **servicio en producción** con voluntarios reales:
`app.rescatando-el-mezquite.org` (app del voluntario) y `admin.rescatando-el-mezquite.org` (consola).
Si encuentras una vulnerabilidad, nos interesa saberlo.

## Cómo reportar

Escribe a **<contacto@rescatando-el-mezquite.org>** con el asunto `[seguridad]`.

**No abras un issue público** para vulnerabilidades: usa el correo y danos tiempo de corregir antes
de divulgar.

Incluye lo que puedas de esto:

- Qué componente afecta (API, app del voluntario, consola, infraestructura).
- Pasos para reproducirlo.
- Qué se puede lograr con ello (leer datos ajenos, escalar rol, escribir sin permiso…).
- Tu preferencia de crédito: si quieres que te acreditemos al publicar la corrección, dínoslo.

## Qué esperar

Es un proyecto de voluntariado, no una empresa con equipo de guardia. Nos comprometemos a lo que
podemos cumplir:

| | |
|---|---|
| Primer acuse de recibo | dentro de **5 días hábiles** |
| Evaluación y plan | dentro de **15 días hábiles** |
| Programa de recompensas | **no tenemos**; solo agradecimiento y crédito público |

## Alcance

**Sí nos interesa:** salto de autenticación o de rol, acceso a observaciones o cuentas ajenas,
inyección SQL, XSS, exposición de credenciales, fallas en la carga de imágenes, cualquier vía para
alterar o borrar datos de voluntarios.

**Esto NO es una vulnerabilidad — no lo reportes como tal:**

- **La ubicación de los árboles es pública por diseño.** Es una decisión de gobernanza del Club,
  documentada en [`docs/change-requests/CR-025-ubicacion-exacta-publica.md`](docs/change-requests/CR-025-ubicacion-exacta-publica.md).
  Que `GET /public/observations` devuelva coordenadas es el comportamiento buscado.
- Los valores en `infra/k8s/base/secret.example.yaml` y `infra/compose/docker-compose.dev.yml` son
  **placeholders de desarrollo**, no credenciales de producción.
- El *Web Client ID* de Google es público por diseño: viaja en el bundle web y lo protege la lista
  de orígenes autorizados.

## Por favor, no hagas esto

- **No escanees automáticamente** producción ni le lances pruebas de carga o denegación de servicio.
- **No subas observaciones de prueba** al sistema en vivo: contaminan un dataset científico que usan
  personas reales. Levanta el entorno local (ver [`docs/despliegue/QUICKSTART.md`](docs/despliegue/QUICKSTART.md)).
- **No accedas a datos de voluntarios** más allá de lo mínimo para demostrar el problema, y no los
  conserves ni los publiques.
