FROM python:3.12-slim-bookworm@sha256:935c3c5b12357a7e10caa9c1e6ca5692344d97cf229832ef584be2cec9fc03df AS runtime
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app/backend
COPY infrastructure/docker/runtime.requirements.txt /tmp/requirements.txt
COPY infrastructure/docker/build-tools.requirements.txt /tmp/build-tools.txt
# http-ece is pure Python and published only as source. All other runtime packages
# must resolve to verified wheels. Build tools are removed in the same layer.
RUN python -m pip install --require-hashes --only-binary=:all: -r /tmp/build-tools.txt \
    && python -m pip install --require-hashes --only-binary=:all: --no-binary=http-ece \
        --no-build-isolation -r /tmp/requirements.txt \
    && python -m pip uninstall --yes setuptools \
    && python -m pip check \
    && rm /tmp/build-tools.txt /tmp/requirements.txt \
    && useradd --system --uid 10001 unlabel
COPY backend/pyproject.toml ./pyproject.toml
COPY backend/app ./app
COPY data/knowledge /app/data/knowledge
RUN python -c "from pathlib import Path; from app.claims.bundle import build_knowledge_bundle; build_knowledge_bundle(Path('/app/data/knowledge'),Path('/app/backend/app/claims/data'))"
USER 10001:10001

FROM runtime AS notification-worker
HEALTHCHECK --interval=30s --timeout=15s --start-period=45s --retries=3 CMD python -m app.selfhost.worker worker --healthcheck
CMD ["python", "-m", "app.selfhost.worker", "worker"]

FROM runtime AS reminder-scheduler
HEALTHCHECK --interval=30s --timeout=15s --start-period=45s --retries=3 CMD python -m app.selfhost.worker scheduler --healthcheck
CMD ["python", "-m", "app.selfhost.worker", "scheduler"]

FROM runtime AS api
EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health/live',timeout=3)"
CMD ["python", "-m", "uvicorn", "app.selfhost.entrypoint:create_platform_app", "--factory", "--host", "0.0.0.0", "--port", "8000", "--no-access-log", "--limit-concurrency", "64", "--timeout-keep-alive", "5"]
