"""Explicit operator-only synthetic account smoke check; no email or public observations."""

import argparse
import os
import secrets
import sys
import time
from urllib.parse import urlsplit
from uuid import UUID, uuid4

import httpx
import jwt


class CheckFailed(Exception):
    pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-synthetic-production-check", action="store_true")
    args = parser.parse_args()
    if not args.allow_synthetic_production_check:
        parser.error("Explicit synthetic production-check authorization is required.")
    identity_url = os.environ["UNLABEL_IDENTITY_URL"]
    location = urlsplit(identity_url)
    if (
        location.hostname not in {"unlabel-identity", "wxoirker1joatdn3vienao9q"}
        or location.scheme != "http" or location.port != 9999
        or location.username or location.password or location.query or location.fragment
        or location.path not in {"", "/"}
    ):
        raise CheckFailed("private_identity_destination")
    now = int(time.time())
    admin = jwt.encode(
        {"role": "service_role", "iat": now, "exp": now + 180},
        os.environ["UNLABEL_IDENTITY_JWT_SECRET"], algorithm="HS256",
    )
    identities = set()
    accounts = []
    step = "initialize"
    passed = []

    def check(condition, label):
        if not condition:
            raise CheckFailed(label)
        passed.append(label)

    with (
        httpx.Client(base_url=identity_url, timeout=10, trust_env=False,
                     follow_redirects=False) as identity,
        httpx.Client(base_url="https://unlabel.duckdns.org", timeout=15, trust_env=False,
                     follow_redirects=False) as api,
    ):
        def bearer(token):
            return {"Authorization": "Bearer " + token}

        def create_account():
            email = "cutover-" + uuid4().hex + "@synthetic.example.invalid"
            password = secrets.token_urlsafe(24) + "Aa1!"
            response = identity.post("/admin/users", headers=bearer(admin), json={
                "email": email, "password": password, "email_confirm": True,
            })
            check(response.status_code in {200, 201}, "synthetic_identity_created")
            uid = str(UUID(response.json()["id"]))
            identities.add(uid)
            response = api.post("/auth/v1/token?grant_type=password",
                                json={"email": email, "password": password})
            check(response.status_code == 200, "password_login")
            session = response.json()
            check(session["user"]["id"] == uid and not session["user"]["is_anonymous"],
                  "password_owner")
            accounts.append((uid, session["access_token"]))
            wrong = api.post("/auth/v1/token?grant_type=password",
                             json={"email": email, "password": password + "wrong"})
            check(wrong.status_code == 400, "incorrect_password_denied")
            return uid, session

        try:
            step = "guest"
            response = api.post("/auth/v1/signup", json={})
            check(response.status_code == 200, "guest_signup")
            guest = response.json()
            guest_id = str(UUID(guest["user"]["id"]))
            identities.add(guest_id)
            check(guest["user"]["is_anonymous"] is True, "guest_identity")
            denied = api.get("/v1/account/profile", headers=bearer(guest["access_token"]))
            check(denied.status_code == 401, "guest_profile_denied")
            response = api.post("/auth/v1/token?grant_type=refresh_token",
                                json={"refresh_token": guest["refresh_token"]})
            check(response.status_code == 200, "guest_refresh")
            renewed = response.json()
            check(renewed["user"]["id"] == guest_id, "guest_uid_preserved")
            response = api.post("/auth/v1/logout?scope=local", headers=bearer(renewed["access_token"]))
            check(response.status_code == 204, "guest_logout")
            response = api.post("/auth/v1/token?grant_type=refresh_token",
                                json={"refresh_token": renewed["refresh_token"]})
            check(response.status_code == 400, "guest_refresh_revoked")

            step = "owner_profile"
            uid, owner = create_account()
            headers = bearer(owner["access_token"])
            response = api.get("/v1/account/profile", headers=headers)
            check(response.status_code == 200 and response.json()["revision"] == 0,
                  "empty_private_profile")
            response = api.put("/v1/account/profile", headers=headers, json={
                "expected_revision": 0, "display_name": "Synthetic acceptance only", "gender": "female",
            })
            check(response.status_code == 200 and response.json()["revision"] == 1,
                  "profile_write")
            response = api.put("/v1/account/profile", headers=headers, json={"expected_revision": 0})
            check(response.status_code == 409, "profile_conflict_denied")

            step = "owner_isolation"
            _, other = create_account()
            response = api.get("/v1/account/profile", headers=bearer(other["access_token"]))
            check(response.status_code == 200 and response.json()["revision"] == 0,
                  "profiles_isolated")
            response = api.get("/v1/account/sync", headers=headers)
            check(response.status_code == 200, "private_library_read")

            step = "recent_owner_deletion"
            response = api.delete("/v1/account/sync", headers=headers)
            check(response.status_code in {200, 204}, "private_account_deletion")
            check(identity.get("/admin/users/" + uid, headers=bearer(admin)).status_code == 404,
                  "identity_deleted_with_private_data")
            identities.discard(uid)
            response = api.get("/v1/account/profile", headers=headers)
            check(response.status_code == 401, "deleted_owner_cannot_read_profile")
        finally:
            cleanup_failed = False
            # Delete only UUIDs returned for identities created by this invocation.
            for uid, token in accounts:
                if uid in identities:
                    try:
                        response = api.delete("/v1/account/sync", headers=bearer(token))
                        cleanup_failed |= response.status_code not in {200, 204, 401}
                    except httpx.HTTPError:
                        cleanup_failed = True
            for uid in identities:
                try:
                    response = identity.delete("/admin/users/" + uid, headers=bearer(admin))
                    cleanup_failed |= response.status_code not in {200, 204, 404}
                except httpx.HTTPError:
                    cleanup_failed = True
            print("Synthetic checks passed: " + ", ".join(passed), flush=True)
            print("Last check group: " + step, flush=True)
            if cleanup_failed:
                raise CheckFailed("synthetic_cleanup")
    print("Synthetic account smoke check completed. No email, Google consent or device claim.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        # Never print exception bodies, JWTs, passwords, provider replies or DSNs.
        label = str(error) if isinstance(error, CheckFailed) else type(error).__name__
        print("Synthetic account check failed: " + label, file=sys.stderr)
        raise SystemExit(1) from None
