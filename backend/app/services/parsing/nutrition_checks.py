"""Shared conservative impossible-quantity guard; no health thresholds."""

from app.schemas.nutrition import NutrientName, NutritionSnapshot


def quantities_need_review(snapshot: NutritionSnapshot) -> bool:
    """Only impossible same-context amounts; no dietary health thresholds."""
    pairs: tuple[tuple[NutrientName, NutrientName], ...] = (
        ("added_sugars", "sugars"),
        ("saturated_fat", "fat"),
    )
    for table in snapshot.tables:
        basis = table.normalized_basis
        if basis.kind == "quantity" and basis.unit == "g" and basis.amount == 100:
            if any(
                cell.unit == "g" and cell.value is not None and cell.value > 100
                for cell in table.nutrients.values()
            ):
                return True
        for subset, total in pairs:
            left, right = table.nutrients[subset], table.nutrients[total]
            if left.value is not None and right.value is not None and left.value > right.value:
                # Rounding can explain small printed discrepancies, so retain
                # the transcription and request correction rather than reject it.
                return True
    return False
