"""Nombres canónicos de canales de la frontera §6.1.

El transporte de referencia son **Redis Streams** con *consumer groups* (ver ``broker``),
pero estos nombres son parte del contrato: cualquier transporte conmutable debe usarlos.

Topología:

    backend ──XADD──▶ [JOBS_STREAM] ──XREADGROUP(VALIDATOR_GROUP)──▶ validador|mock
    validador|mock ──XADD──▶ [RESULTS_STREAM] ──XREADGROUP(BACKEND_GROUP)──▶ backend

El paso **mock → validador real** no cambia ningún nombre aquí: solo cambia *qué worker*
consume ``JOBS_STREAM`` y produce en ``RESULTS_STREAM``.
"""

#: Cola de jobs de validación (backend produce, validador/mock consume).
JOBS_STREAM = "mezquite:validation_jobs"

#: Cola de resultados de validación (validador/mock produce, backend consume).
RESULTS_STREAM = "mezquite:validation_results"

#: Consumer group con el que el validador (mock o real) lee los jobs.
VALIDATOR_GROUP = "validators"

#: Consumer group con el que el backend lee los resultados.
BACKEND_GROUP = "backend"
