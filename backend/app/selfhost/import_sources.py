"""Import committed source artifacts directly. No SQLite database is created or read."""

import gzip
import hashlib
import json
import re
from datetime import UTC, datetime

from psycopg.types.json import Jsonb
from pymongo.errors import BulkWriteError

from app.catalogue.facts import project_facts
from app.catalogue.importer import _bounded_product
from app.catalogue.models import BARCODE_PATTERN, Manifest
from app.catalogue.search import identity_tokens
from app.core.json_numbers import checked_float, reject_constant
from app.research_catalogue.images import load_images
from app.research_catalogue.models import ResearchObservation
from app.research_catalogue.store import _tokens
from app.selfhost.catalogue import canonical


def checked_source(source, metadata):
    if source.is_symlink() or not source.is_file():
        raise ValueError("Source must be a regular committed artifact")
    compressed = source.read_bytes()
    if (
        len(compressed) != metadata["compressed_bytes"]
        or hashlib.sha256(compressed).hexdigest() != metadata["compressed_sha256"]
    ):
        raise ValueError("Compressed source failed receipt verification")
    with gzip.open(source, "rb") as stream:
        decoded = stream.read(metadata["decoded_bytes"] + 1)
    if (
        len(decoded) != metadata["decoded_bytes"]
        or hashlib.sha256(decoded).hexdigest() != metadata["decoded_sha256"]
    ):
        raise ValueError("Decoded source failed receipt verification")
    return decoded


def append_documents(collection, documents):
    if not documents:
        return
    try:
        collection.insert_many(documents, ordered=False)
    except BulkWriteError as error:
        if error.details.get("writeConcernErrors") or any(
            item["code"] != 11000 for item in error.details.get("writeErrors", [])
        ):
            raise ValueError("Immutable evidence insertion failed") from None
    expected = {item["_id"]: item["content_sha256"] for item in documents}
    found = {
        item["_id"]: item["content_sha256"]
        for item in collection.find({"_id": {"$in": list(expected)}}, {"content_sha256": 1})
    }
    if found != expected:
        raise ValueError("Existing evidence disagrees with source content hashes")


def import_bulk(connection, mongo, root):
    directory = root / "data/catalogue"
    metadata = json.loads((directory / "bundle.json").read_text())
    decoded = checked_source(directory / metadata["source_file"], metadata)
    sha = metadata["decoded_sha256"]
    counts = dict(
        rows_read=0,
        india_rows=0,
        indexed_products=0,
        unsupported_barcodes=0,
        missing_name=0,
        missing_ingredients=0,
    )
    products = []
    evidence = []
    mongo.source_observations.create_index([("bundle_sha256", 1), ("row", 1)], unique=True)
    for number, line in enumerate(decoded.splitlines(), 1):
        if len(line) > 512 * 1024:
            raise ValueError("Source row exceeds its byte budget")
        raw = json.loads(line, parse_float=checked_float, parse_constant=reject_constant)
        counts["rows_read"] += 1
        if "en:india" not in raw.get("countries_tags", []):
            continue
        counts["india_rows"] += 1
        evidence.append(
            {
                "_id": f"{sha}:{number}",
                "bundle_sha256": sha,
                "row": number,
                "content_sha256": hashlib.sha256(canonical(raw)).hexdigest(),
                "payload": raw,
            }
        )
        if len(evidence) >= 500:
            append_documents(mongo.source_observations, evidence)
            evidence = []
        code = raw.get("code")
        if not isinstance(code, str) or not re.fullmatch(BARCODE_PATTERN, code):
            counts["unsupported_barcodes"] += 1
            continue
        product, warnings = _bounded_product(raw, code)
        facts, fact_warnings = project_facts(raw, code)
        tokens = list(identity_tokens([product.name, product.brands, product.quantity_text]))
        products.append(
            (
                code,
                sha,
                f"off:{sha}:{code}",
                Jsonb({"product": product.model_dump(mode="json"), "warnings": warnings}),
                Jsonb({"details": facts.model_dump(mode="json"), "warnings": fact_warnings}),
                " ".join(tokens),
                tokens,
            )
        )
        counts["indexed_products"] += 1
        counts["missing_name"] += product.name is None
        counts["missing_ingredients"] += product.ingredients_text is None
    append_documents(mongo.source_observations, evidence)
    if (
        counts["rows_read"] != metadata["expected_input_rows"]
        or counts["indexed_products"] != metadata["indexed_products"]
    ):
        raise ValueError("Source projection counts differ from the committed receipt")
    if len({row[0] for row in products}) != len(products):
        raise ValueError("Duplicate exact barcode in source")
    manifest = Manifest(
        snapshot_id="off-" + sha[:24],
        source_url=metadata["source_url"],
        source_sha256=sha,
        source_format="off_jsonl",
        coverage=metadata["coverage"],
        exported_at=datetime.fromisoformat(metadata["exported_at"]),
        indexed_at=datetime.now(UTC),
        **counts,
    )
    with connection.transaction():
        connection.execute("SELECT pg_advisory_xact_lock(842317225)")
        connection.execute(
            """INSERT INTO catalogue.source_bundles
            (sha256,source_url,exported_at,indexed_products,license_id,receipt) VALUES(%s,%s,%s,%s,%s,%s)
            ON CONFLICT(sha256) DO NOTHING""",
            (
                sha,
                manifest.source_url,
                manifest.exported_at,
                len(products),
                "ODbL-1.0",
                Jsonb(manifest.model_dump(mode="json")),
            ),
        )
        connection.execute(
            "CREATE TEMP TABLE import_products (LIKE catalogue.products INCLUDING DEFAULTS) ON COMMIT DROP"
        )
        with (
            connection.cursor().copy("""COPY import_products
            (barcode,bundle_sha256,source_id,identity,facts,normalized_identity,search_tokens) FROM STDIN""") as copy
        ):
            for product in products:
                copy.write_row(product)
        connection.execute("""INSERT INTO catalogue.products
            (barcode,bundle_sha256,source_id,identity,facts,normalized_identity,search_tokens)
            SELECT barcode,bundle_sha256,source_id,identity,facts,normalized_identity,search_tokens
            FROM import_products ON CONFLICT(barcode) DO UPDATE SET
            bundle_sha256=excluded.bundle_sha256, source_id=excluded.source_id,
            identity=excluded.identity,facts=excluded.facts,
            normalized_identity=excluded.normalized_identity,search_tokens=excluded.search_tokens""")
        mismatches = connection.execute("""SELECT count(*) FROM import_products i
            LEFT JOIN catalogue.products p USING(barcode)
            WHERE p.barcode IS NULL OR p.identity<>i.identity OR p.facts<>i.facts
                OR p.search_tokens<>i.search_tokens OR p.bundle_sha256<>i.bundle_sha256""").fetchone()[
            0
        ]
        if mismatches:
            raise ValueError("Stored catalogue differs from its direct source projection")
        connection.execute(
            """INSERT INTO catalogue.active_snapshot(singleton,bundle_sha256) VALUES(true,%s)
            ON CONFLICT(singleton) DO UPDATE SET bundle_sha256=excluded.bundle_sha256""",
            (sha,),
        )
    return counts


def import_research(connection, mongo, root):
    directory = root / "data/catalogue/popular-india-v1"
    metadata = json.loads((directory / "manifest.json").read_text())
    decoded = checked_source(directory / metadata["dataset_file"], metadata)
    rows = []
    for line in decoded.splitlines():
        raw = json.loads(line)
        observation = ResearchObservation.model_validate(raw)
        barcode = observation.identity.barcode
        groups = metadata.get("barcode_groups", {}).get(barcode, {})
        conflicts = groups.get("conflict_fields", [])
        rows.append(
            {
                "_id": observation.observation_id,
                "observation": raw,
                "content_sha256": hashlib.sha256(canonical(raw)).hexdigest(),
                "tokens": list(_tokens(observation)),
                "name_sort": (observation.identity.name or "").casefold(),
                "eligible_barcode": barcode
                if observation.eligibility == "exact_sku" and not conflicts
                else None,
                "conflict_fields": conflicts,
            }
        )
    if len(rows) != metadata["observation_count"] or len({row["_id"] for row in rows}) != len(rows):
        raise ValueError("Research count differs from its immutable receipt")
    mongo.research_observations.create_index("eligible_barcode")
    mongo.research_observations.create_index("tokens")
    mongo.research_observations.create_index([("name_sort", 1), ("_id", 1)])
    append_documents(mongo.research_observations, rows)
    images = load_images(root / "backend/app/research_catalogue/image_sources.json")
    with connection.transaction():
        connection.execute(
            """INSERT INTO catalogue.research_datasets(sha256,receipt)
            VALUES(%s,%s) ON CONFLICT(sha256) DO NOTHING""",
            (metadata["decoded_sha256"], Jsonb(metadata)),
        )
        for row in rows:
            connection.execute(
                """INSERT INTO catalogue.research_search
                (entry_id,dataset_sha256,eligible_barcode,name_sort,tokens,conflict_fields)
                VALUES(%s,%s,%s,%s,%s,%s) ON CONFLICT(dataset_sha256,entry_id) DO UPDATE SET
                eligible_barcode=excluded.eligible_barcode,name_sort=excluded.name_sort,
                tokens=excluded.tokens,conflict_fields=excluded.conflict_fields""",
                (
                    row["_id"],
                    metadata["decoded_sha256"],
                    row["eligible_barcode"],
                    row["name_sort"],
                    row["tokens"],
                    row["conflict_fields"],
                ),
            )
        connection.execute(
            """INSERT INTO catalogue.dataset_receipts(dataset_id,source_sha256,item_count,receipt)
            VALUES('research-v1',%s,%s,%s) ON CONFLICT(dataset_id) DO UPDATE SET
            source_sha256=excluded.source_sha256,item_count=excluded.item_count,receipt=excluded.receipt""",
            (metadata["decoded_sha256"], len(rows), Jsonb(metadata)),
        )
        for entry_id, image in images.items():
            connection.execute(
                """INSERT INTO catalogue.image_descriptors
                (descriptor_id,url,source_reference,retrieved_at) VALUES(%s,%s,%s,%s)
                ON CONFLICT(descriptor_id) DO NOTHING""",
                (entry_id, image.url, Jsonb(image.model_dump(mode="json")), image.retrieved_at),
            )
        if connection.execute("SELECT count(*) FROM catalogue.image_descriptors").fetchone()[
            0
        ] != len(images):
            raise ValueError("Separate image descriptor count differs from its source")
    return {"observations": len(rows), "image_descriptors": len(images)}
