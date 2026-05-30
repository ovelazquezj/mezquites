"""Versionado del contrato §6.4.

``SCHEMA_VERSION`` viaja en cada mensaje. Los cambios de esquema se versionan y deben ser
compatibles hacia atrás. El backend y el validador comparan esta constante con el campo
``schema_version`` de cada mensaje recibido.
"""

SCHEMA_VERSION = "1.0"
