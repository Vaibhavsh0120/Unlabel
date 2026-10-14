"""Synthetic, local-only Firestore rules checks; no production account or data.

Start the Firestore emulator with firebase/firestore.rules on port 8187, then
run this file. FIRESTORE_EMULATOR_HOST may select another local emulator port.
"""

import base64
import json
import os
import unittest
import urllib.error
import urllib.request
import uuid
from urllib.parse import urlsplit


class ProfileMediaRulesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        host = os.environ.get("FIRESTORE_EMULATOR_HOST", "127.0.0.1:8187")
        parsed = urlsplit("http://" + host)
        if (
            parsed.hostname not in {"127.0.0.1", "localhost"}
            or parsed.port is None
            or parsed.username is not None
            or parsed.password is not None
            or parsed.path
            or parsed.query
            or parsed.fragment
        ):
            raise RuntimeError("Rules tests require a local emulator")
        cls.origin = f"http://{host}"
        cls.project = "demo-unlabel-profile"
        cls.uid = f"synthetic-{uuid.uuid4().hex}"

    def request(self, path, *, uid=None, provider="password", body=None, method=None, admin=False):
        headers = {"Content-Type": "application/json"}
        if admin:
            # The emulator UI uses this local-only fake administrative token.
            # setUpClass restricts every request to the loopback demo project.
            headers["Authorization"] = "Bearer owner"
        elif uid is not None:
            def encoded(value):
                return base64.urlsafe_b64encode(json.dumps(value).encode()).decode().rstrip("=")

            token = ".".join([
                encoded({"alg": "none", "typ": "JWT"}),
                encoded({"sub": uid, "user_id": uid, "aud": self.project,
                         "iss": f"https://securetoken.google.com/{self.project}",
                         "iat": 1, "exp": 9999999999,
                         "firebase": {"sign_in_provider": provider}}),
                "",
            ])
            headers["Authorization"] = f"Bearer {token}"
        request = urllib.request.Request(
            self.origin + path, headers=headers,
            data=None if body is None else json.dumps(body).encode(), method=method,
        )
        try:
            with urllib.request.urlopen(request, timeout=10) as response:
                return response.status, json.loads(response.read())
        except urllib.error.HTTPError as error:
            return error.code, json.loads(error.read())

    def document(self, *, database="unlabel", collection="profile_media", uid=None):
        return f"projects/{self.project}/databases/{database}/documents/{collection}/{uid or self.uid}"

    def commit(self, fields=None, *, auth_uid=None, provider="password", database="unlabel", collection="profile_media", transforms=True):
        data = {"schema": {"integerValue": "1"}, "gender": {"stringValue": "female"},
                "source": {"stringValue": "defaultAvatar"}}
        data.update(fields or {})
        write = {"update": {"name": self.document(database=database, collection=collection), "fields": data}}
        if transforms:
            write["updateTransforms"] = [{"fieldPath": "updated_at", "setToServerValue": "REQUEST_TIME"}]
        return self.request(f"/v1/projects/{self.project}/databases/{database}/documents:commit",
                            uid=auth_uid or self.uid, provider=provider, body={"writes": [write]})

    def test_owner_can_write_read_and_delete_own_profile(self):
        self.assertEqual(self.commit()[0], 200)
        self.assertEqual(self.request("/v1/" + self.document(), uid=self.uid)[0], 200)
        self.assertEqual(self.request("/v1/" + self.document(), uid=self.uid, method="DELETE")[0], 200)

    def test_deletion_marker_blocks_old_owner_and_remains_machine_only(self):
        # Keep this deleted identity isolated from the other emulator tests.
        self.uid = f"synthetic-deleted-{uuid.uuid4().hex}"
        self.assertEqual(self.commit()[0], 200)
        marker = self.document(collection="profile_deletions")
        self.assertEqual(self.request("/v1/" + marker, admin=True, method="PATCH", body={
            "fields": {"schema": {"integerValue": "1"}}
        })[0], 200)
        self.assertEqual(self.request("/v1/" + self.document(), uid=self.uid)[0], 403)
        self.assertEqual(self.commit()[0], 403)
        self.assertEqual(self.request("/v1/" + self.document(), uid=self.uid, method="DELETE")[0], 403)
        self.assertEqual(self.request("/v1/" + marker, uid=self.uid)[0], 403)
        self.assertEqual(self.request("/v1/" + marker, uid=self.uid, method="DELETE")[0], 403)
        self.assertEqual(self.commit(collection="profile_deletions")[0], 403)
        self.assertEqual(self.request(
            f"/v1/projects/{self.project}/databases/unlabel/documents/profile_deletions",
            uid=self.uid,
        )[0], 403)
        self.assertEqual(self.request(
            f"/v1/projects/{self.project}/databases/unlabel/documents:commit",
            admin=True, body={"writes": [{"delete": self.document()}]},
        )[0], 200)
        self.assertEqual(self.commit()[0], 403)  # A late create cannot resurrect media.
        self.uid = f"synthetic-other-{uuid.uuid4().hex}"
        self.assertEqual(self.commit()[0], 200)

    def test_other_users_and_anonymous_cannot_read_write(self):
        self.assertEqual(self.commit()[0], 200)
        self.assertEqual(self.commit(auth_uid="another-user")[0], 403)
        self.assertEqual(self.commit(provider="anonymous")[0], 403)
        self.assertEqual(self.request("/v1/" + self.document(), uid="another-user")[0], 403)
        self.assertEqual(self.request("/v1/" + self.document(), uid=self.uid, provider="anonymous")[0], 403)
        self.assertEqual(self.request("/v1/" + self.document())[0], 403)

    def test_list_and_other_databases_collections_remain_denied(self):
        self.assertEqual(self.request(f"/v1/projects/{self.project}/databases/unlabel/documents/profile_media", uid=self.uid)[0], 403)
        self.assertEqual(self.commit(database="(default)")[0], 403)
        self.assertEqual(self.commit(collection="private_profiles")[0], 403)

    def test_schema_gender_content_type_timestamp_and_unknown_fields(self):
        for fields in [
            {"schema": {"integerValue": "2"}},
            {"gender": {"stringValue": "inferred"}},
            {"source": {"stringValue": "custom"}},
            {"private_scan": {"stringValue": "forbidden"}},
            {"avatar_png": {"bytesValue": base64.b64encode(b"x" * 24).decode()}},
        ]:
            self.assertEqual(self.commit(fields)[0], 403)
        self.assertEqual(self.commit({"updated_at": {"timestampValue": "2000-01-01T00:00:00Z"}}, transforms=False)[0], 403)

    def test_thumbnail_size_and_type_are_enforced(self):
        def photo(size, content_type="image/png"):
            return {"source": {"stringValue": "custom"},
                    "avatar_png": {"bytesValue": base64.b64encode(b"x" * size).decode()},
                    "content_type": {"stringValue": content_type}}

        self.assertEqual(self.commit(photo(98304))[0], 200)
        self.assertEqual(self.commit(photo(98305))[0], 403)
        self.assertEqual(self.commit(photo(23))[0], 403)
        self.assertEqual(self.commit(photo(24, "image/jpeg"))[0], 403)


if __name__ == "__main__":
    unittest.main()
