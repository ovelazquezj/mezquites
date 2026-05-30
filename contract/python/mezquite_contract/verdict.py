"""Regla de etiquetado autoritativa (§6.3).

    valida ⟺ es_arbol == True ∧ parasitos_presentes == True
    cualquier otro caso ⟹ ruido

Esta regla es **autoritativa en el backend**: el backend NUNCA confía ciegamente en el campo
``veredicto`` del mensaje de resultado; lo recomputa con esta función a partir de los dos
hechos binarios. El mock y el validador real rellenan ``veredicto`` con esta misma función
por consistencia, pero la autoridad es del backend (ver ``models.ValidationResult``).
"""

VALIDA = "valida"
RUIDO = "ruido"


def compute_verdict(es_arbol: bool, parasitos_presentes: bool) -> str:
    """Devuelve ``"valida"`` o ``"ruido"`` aplicando la regla autoritativa §6.3."""
    return VALIDA if (es_arbol and parasitos_presentes) else RUIDO
