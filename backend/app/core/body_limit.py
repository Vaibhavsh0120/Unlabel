import json

from starlette.responses import JSONResponse

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
        for name, value in scope.get("headers", []):
            if name.lower() == b"content-length":
                try:
                    if int(value) > self.max_bytes:
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
            if len(body) > self.max_bytes:
                await self.reject(scope, receive, send)
                return
            if not message.get("more_body", False):
                break
        consumed = False

        if (
            scope["path"].rstrip("/")
            in {"/v1/nutrition/normalize", "/v1/claims/check", "/v1/community/contributions"}
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
        await JSONResponse(
            {"detail": "Request body exceeds 32 KiB"},
            status_code=413,
            headers={"Cache-Control": "no-store"},
        )(scope, receive, send)
