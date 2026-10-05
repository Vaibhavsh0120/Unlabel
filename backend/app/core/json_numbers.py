from decimal import Decimal, DecimalException
from math import isfinite


def checked_float(token: str) -> float:
    """Refuse JSON numbers that silently lose decimal digits or collapse to zero."""
    if len(token) > 64:
        raise ValueError("Unsupported JSON number precision")
    value = float(token)
    try:
        faithful = isfinite(value) and Decimal(token) == Decimal(str(value))
    except DecimalException:
        faithful = False
    if not faithful:
        raise ValueError("Unsupported JSON number precision")
    return value


def reject_constant(token: str):
    raise ValueError("Nonfinite JSON constants are unsupported")
