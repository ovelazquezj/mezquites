# Cómo contribuir

Gracias por el interés. Conviene ser claros sobre en qué punto está el proyecto.

## Estado: piloto, no proyecto comunitario todavía

Es el software de un **piloto en producción** del Club Rotario Bosques Aguascalientes, con un equipo
muy pequeño. Publicamos el código para que sea **auditable y replicable**, no porque tengamos
capacidad de sostener revisión de pull requests externos.

**Por ahora no aceptamos pull requests no solicitados.** No es desinterés: es que no podemos
prometer una revisión seria y preferimos decirlo a dejar tu trabajo sin respuesta.

## Lo que sí nos sirve mucho

1. **Issues.** Errores, comportamientos raros, documentación que no se entiende. Son bienvenidos.
2. **Vulnerabilidades de seguridad.** Por correo, no por issue — ver [`SECURITY.md`](SECURITY.md).
3. **Uso del dataset.** Si usas los datos en investigación o divulgación, cuéntanos: es la mejor
   señal de que el piloto sirve. Ver [`LICENSE-DATOS.md`](LICENSE-DATOS.md).
4. **Replicarlo en tu ciudad.** El código es MIT y los runbooks de despliegue están en
   [`docs/despliegue/`](docs/despliegue/). Escríbenos y te ayudamos con lo que sepamos.

Si quieres aportar código, **escribe primero** a <contacto@rescatando-el-mezquite.org> y lo
acordamos antes de que inviertas tiempo.

## Si acordamos que sí

- **Idioma: español**, en código, documentación y mensajes de commit.
- **Commits** estilo `feat(...)` / `fix(...)` / `docs:` / `chore(...)`.
- **Toda contribución trae prueba.** Cada criterio de aceptación se rastrea en
  [`docs/cambios/TRACEABILITY.md`](docs/cambios/TRACEABILITY.md); es un requisito del proyecto, no
  una formalidad.
- **Suites verdes antes de proponer nada:**

  ```bash
  cd contract/python  && python -m pytest -q
  cd mock-validator   && python -m pytest -q
  cd backend          && python -m pytest -q     # requiere un PostGIS en contenedor
  cd mobile           && flutter test
  cd web-admin        && flutter test
  ```

- Para levantar el entorno local, ver [`docs/despliegue/QUICKSTART.md`](docs/despliegue/QUICKSTART.md).

## Límites de diseño que no se negocian

El proyecto tiene restricciones deliberadas, documentadas en
[`docs/sdd/bitacora_sdd_mezquite.md`](docs/sdd/bitacora_sdd_mezquite.md). Si una propuesta las cruza,
la vamos a rechazar aunque el código sea bueno. Las principales:

- **No promete control fitosanitario** ni reducción de infestación, ni da recomendaciones de manejo
  químico o mecánico. Es observación y concientización.
- **Participación abierta:** ninguna funcionalidad se bloquea por nivel, capacitación o
  certificación.
- **Captura solo con cámara** y su EXIF; la galería está deshabilitada a propósito.
- **PII mínima:** la persona voluntaria participa con un seudónimo; el sistema no guarda su nombre
  ni su correo.
- **Especie y nivel de afectación son autodeclarados**, nunca validados automáticamente.

## Licencias

Código **MIT** ([`LICENSE`](LICENSE)) · datos **CC BY 4.0** ([`LICENSE-DATOS.md`](LICENSE-DATOS.md)).
Al contribuir aceptas que tu aporte se publique bajo esas licencias.
