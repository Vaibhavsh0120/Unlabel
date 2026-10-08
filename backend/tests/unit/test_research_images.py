import json
from pathlib import Path

import pytest
from pydantic import ValidationError

from app.research_catalogue.images import load_images
from app.research_catalogue.models import ResearchImage
from app.research_catalogue.store import ResearchCatalogueStore


def test_image_sources_preserve_immutable_catalogue_and_checked_origin_scope():
    path = Path(__file__).parents[2] / 'app/research_catalogue/image_sources.json'
    images = load_images(path)
    store = ResearchCatalogueStore(path.parent / 'data')
    for entry, image in images.items():
        result = store.lookup(entry)
        assert result.image == image
        assert result.observation is not None
        assert result.observation.observation_id == entry
        assert result.observation.source.url == image.source_url
    assert len(images) >= 100


@pytest.mark.parametrize('change', [
    {'url': 'https://localhost/product.jpg'},
    {'url': 'https://cdn.grofers.com/product.jpg?api_key=secret'},
    {'identity_scope': 'source_barcode'},
    {'content_type': 'image/svg+xml'},
])
def test_image_descriptor_rejects_unreviewed_or_private_values(change):
    value = next(x.model_dump() for x in load_images(
        Path(__file__).parents[2] / 'app/research_catalogue/image_sources.json').values()
        if x.provider == 'retailer')
    with pytest.raises(ValidationError):
        ResearchImage.model_validate(value | change)


def test_image_source_duplicate_fields_do_not_silently_replace_metadata(tmp_path):
    path = tmp_path / 'images.json'
    path.write_text('{"schema_version":"1","images":[],"images":[]}', encoding='utf-8')
    with pytest.raises(ValueError):
        load_images(path)
    path.write_text(json.dumps({'schema_version':'1','images': []}), encoding='utf-8')
    assert load_images(path) == {}


def test_off_image_source_requires_matching_canonical_barcode_folder():
    value = next(x.model_dump() for x in load_images(
        Path(__file__).parents[2] / 'app/research_catalogue/image_sources.json').values()
        if x.provider == 'open_food_facts')
    for source in ['https://world.openfoodfacts.org/product/123',
                   'https://world.openfoodfacts.org/api/v3.6/product/8901764051258.json']:
        with pytest.raises(ValidationError):
            ResearchImage.model_validate(value | {'source_url': source})
