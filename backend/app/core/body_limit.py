import json

from starlette.responses import JSONResponse

from app.accounts.models import MAX_BODY_BYTES
from app.core.json_numbers import checked_float, reject_constant


class RequestBodyLimit:
    """Bound actual ASGI chunks before FastAPI JSON parsing, including chunked requests."""

    def __init__(self, app, max_bytes: int = 32768):
        self.app = app
        self.max_bytes = max_bytes

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        personal = scope["path"].rstrip("/") == "/v1/account/sync"
        max_bytes = MAX_BODY_BYTES if personal else self.max_bytes
        for name, value in scope.get("headers", []):
            if name.lower() == b"content-length":
                try:
                    if int(value) > max_bytes:
                        await self.reject(scope, receive, send)
                        return
                except ValueError:
                    pass
        body = bytearray()
        while True:
            message = await receive()
            if message["type"] == "http.disconnect":
                return
            body.extend(message.get("body", b""))
            if len(body) > max_bytes:
                await self.reject(scope, receive, send)
                return
            if not message.get("more_body", False):
                break
        consumed = False
        if personal and (scope.get("query_string") or (scope["method"] == "GET" and body)):
            await JSONResponse(
                {
                    "detail": [
                        {
                            "loc": ["query" if scope.get("query_string") else "body"],
                            "type": "unexpected_input",
                            "msg": "Invalid request data",
                        }
                    ],
                    "errors_truncated": False,
                },
                status_code=422,
                headers={"Cache-Control": "no-store"},
            )(scope, receive, send)
            return

        if (
            scope["path"].rstrip("/")
            in {
                "/v1/nutrition/normalize",
                "/v1/claims/check",
                "/v1/community/contributions",
                "/v1/reports/check",
                "/v1/account/sync",
            }
            and scope["method"] == "POST"
        ):
            try:
                json.loads(body, parse_float=checked_float, parse_constant=reject_constant)
            except (json.JSONDecodeError, UnicodeDecodeError):
                pass  # Framework handles malformed JSON with its sanitized validation response.
            except (ValueError, RecursionError):
                await JSONResponse(
                    {
                        "detail": [
                            {
                                "loc": ["body"],
                                "type": "invalid_json_number",
                                "msg": "Invalid request data",
                            }
                        ],
                        "errors_truncated": False,
                    },
                    status_code=422,
                    headers={"Cache-Control": "no-store"},
                )(scope, receive, send)
                return

        async def replay():
            nonlocal consumed
            if not consumed:
                consumed = True
                return {"type": "http.request", "body": bytes(body), "more_body": False}
            return await receive()

        await self.app(scope, replay, send)

    async def reject(self, scope, receive, send):
        size = "512" if scope["path"].rstrip("/") == "/v1/account/sync" else "32"
        await JSONResponse(
            {"detail": f"Request body exceeds {size} KiB"},
            status_code=413,
            headers={"Cache-Control": "no-store"},
        )(scope, receive, send)
