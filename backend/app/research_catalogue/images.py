"""Public source image descriptors; source observations are never rewritten.

Only reviewed fixed origins are permitted. Runtime code reads metadata, never
fetches or stores image bytes. A listing photo does not confirm the current pack.
"""

import json
from pathlib import Path

from app.research_catalogue.models import ResearchImage


def load_images(path: Path) -> dict[str, ResearchImage]:
    if not path.exists():
        return {}
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 2 * 1024**2:
        raise ValueError('Image descriptors require a bounded regular source file')
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError('Duplicate image descriptor fields')
            result[key] = value
        return result
    value = json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=pairs)
    if not isinstance(value, dict) or set(value) != {'schema_version', 'images'} or value['schema_version'] != '1':
        raise ValueError('Image descriptor format is invalid')
    if not isinstance(value['images'], list) or len(value['images']) > 5000:
        raise ValueError('Image descriptor list is invalid')
    images = {}
    for item in value['images']:
        image = ResearchImage.model_validate(item)
        if image.observation_id in images:
            raise ValueError('Duplicate image observation')
        images[image.observation_id] = image
    return images
