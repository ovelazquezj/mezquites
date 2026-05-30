"""mezquite_contract — Frontera de integración con el sistema de validación de imágenes.

Fuente de verdad: §6 de `bitacora_sdd_mezquite.md`. Este paquete es importado tanto por
el backend (productor de jobs / consumidor de resultados) como por el validador real y el
mock (consumidor de jobs / productor de resultados), de modo que **ambos lados hablan
exactamente el mismo protocolo de cable y no pueden divergir**.

Lo que vive aquí (la frontera inmutable §6):
- Esquemas JSON canónicos del job y del resultado (``schemas/``).
- Modelos tipados (``models``) para construir/validar mensajes.
- La regla autoritativa de veredicto (``verdict``): valida ⟺ es_arbol ∧ parasitos_presentes.
- Los nombres canónicos de canales/streams (``channels``).
- Un ``MessageBroker`` conmutable (``broker``: Redis Streams en nube, en-memoria para dev/QA
  y pruebas) — transporte de referencia, intercambiable sin tocar el protocolo.

Lo que NO vive aquí: especie (mezquite) ni nivel de infestación G4. La validación automática
se limita a *es-árbol* + *presencia-de-parásitos* (gate de alcance, Q5.A-D1).
"""

from .version import SCHEMA_VERSION
from .verdict import RUIDO, VALIDA, compute_verdict
from .models import Scores, ValidationJob, ValidationResult
from . import channels

__all__ = [
    "SCHEMA_VERSION",
    "VALIDA",
    "RUIDO",
    "compute_verdict",
    "Scores",
    "ValidationJob",
    "ValidationResult",
    "channels",
]
