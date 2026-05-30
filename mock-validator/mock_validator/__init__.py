"""mock-validator — Worker que cumple el contrato §6 mientras el sistema YOLO real no existe.

Consume jobs de ``JOBS_STREAM`` (§6.2), evalúa la imagen según un *modo* configurable
(``fijo`` | ``aleatorio`` | ``regla``), simula latencia de procesamiento, y publica el
resultado en ``RESULTS_STREAM`` (§6.3) con ``model_version="mock"``.

El paso **mock → validador real** (§6.5 / Q5.A-D2) NO toca al backend ni a los clientes: solo
cambia qué proceso consume ``JOBS_STREAM``. Este worker existe para probar la integración
extremo a extremo contra esa misma frontera.
"""

from .config import Config
from .worker import MockValidator

__all__ = ["Config", "MockValidator"]
