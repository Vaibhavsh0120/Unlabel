"""Prepare a separate developer preview with owned synthetic/public fixtures.

Build tool/visual_preview.dart into build/visual-preview first. No production
assets, user records, credentials or source SQLite files are modified.
"""
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))
from app.research_catalogue.store import ResearchCatalogueStore


def main():
    output = ROOT / "frontend/build/visual-preview/fixtures"
    output.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / "contracts/examples/label-report-v1.current.synthetic.json", output / "report.json")
    shutil.copyfile(Path(__file__).with_name("synthetic-label.png"), output / "label.png")
    label = json.loads((ROOT / "contracts/examples/ai-extraction-v1.synthetic.json").read_text(encoding="utf-8"))
    label["identity"] = {"name": "SYNTHETIC TEST OATS", "brand": "TEST BRAND", "variant": None,
                         "quantity": "300 g", "barcode": None}
    label["ingredients"] = "Whole grain oats"
    label["contains"] = "Oats"
    label["nutrition_tables"][0]["rows"] = [
        {"nutrient": nutrient, "value": value, "unit": unit, "qualifier": "exact", "printed_text": text}
        for nutrient, value, unit, text in [
            ("energy", 380, "kcal", "Energy 380 kcal"), ("protein", 12, "g", "Protein 12 g"),
            ("carbohydrates", 62, "g", "Carbohydrates 62 g"), ("sugars", 1, "g", "Total sugars 1 g"),
            ("fat", 7, "g", "Total fat 7 g"), ("sodium", 5, "mg", "Sodium 5 mg"),
        ]
    ]
    label["regions"] = [
        {"slot": slot, "label": kind, "text": text,
         "box": dict(zip(("top", "left", "bottom", "right"), box, strict=True))}
        for slot in ("front", "back") for kind, text, box in [
            ("identity", "SYNTHETIC TEST OATS", (.055, .045, .145, .58)),
            ("ingredients", "Whole grain oats", (.165, .045, .202, .55)),
            ("allergen", "Oats", (.217, .045, .255, .31)),
            ("nutrition", "Per 100 g", (.270, .045, .628, .56)),
        ]
    ]
    (output / "label.json").write_text(json.dumps(label, indent=2), encoding="utf-8")
    lookup = ResearchCatalogueStore(ROOT / "backend/app/research_catalogue/data").lookup(
        "c1f2c19a2ad83433e70de44b02519efa6474a781b88968ecbf0a9461161b8ef5")
    if lookup.status != "found":
        raise RuntimeError("Restore the public research catalogue before previewing")
    (output / "research.json").write_text(lookup.model_dump_json(indent=2), encoding="utf-8")
    print("Prepared only owned synthetic and dated public catalogue fixtures.")


if __name__ == "__main__":
    main()
