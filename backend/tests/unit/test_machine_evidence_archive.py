import copy

import pytest
from app.community.store import FirestoreContributionStore
from app.selfhost.evidence_worker import archive_machine_observation
from pymongo.errors import DuplicateKeyError
from tests.unit.test_community_store import MemoryFirestore
from tests.unit.test_machine_observations import share


class Collection:
    def __init__(self):
        self.documents = {}

    def insert_one(self, value):
        if value["_id"] in self.documents:
            raise DuplicateKeyError("duplicate")
        self.documents[value["_id"]] = value

    def find_one(self, query):
        return self.documents.get(query["_id"])


def test_machine_archive_keeps_separate_public_facts_and_verifies_replay():
    database = MemoryFirestore()
    # The same transactional selection adapter also owns machine publication.
    result = share(FirestoreContributionStore(database))
    record = database.documents["unlabel_machine_observations/" + result.observation_id]
    archive = Collection()
    archive_machine_observation(archive, result.observation_id, record)
    archive_machine_observation(archive, result.observation_id, record)
    saved = archive.documents[result.observation_id]
    assert saved["observation"]["evidence"] == "machine_extracted_unverified"
    assert "data_base64" not in repr(saved) and "owner" not in repr(saved)
    bad = copy.deepcopy(record)
    bad["payload_json"] += " "
    with pytest.raises(ValueError):
        archive_machine_observation(archive, result.observation_id, bad)
    archive.documents[result.observation_id] = {"changed": True}
    with pytest.raises(ValueError):
        archive_machine_observation(archive, result.observation_id, record)
