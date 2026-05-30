"""La regla autoritativa §6.3: valida ⟺ es_arbol ∧ parasitos_presentes."""

import pytest

from mezquite_contract.verdict import RUIDO, VALIDA, compute_verdict


@pytest.mark.parametrize(
    "es_arbol,parasitos,esperado",
    [
        (True, True, VALIDA),
        (True, False, RUIDO),
        (False, True, RUIDO),
        (False, False, RUIDO),
    ],
)
def test_tabla_de_verdad(es_arbol, parasitos, esperado):
    assert compute_verdict(es_arbol, parasitos) == esperado
