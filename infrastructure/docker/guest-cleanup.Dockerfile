FROM python:3.12-slim-bookworm@sha256:935c3c5b12357a7e10caa9c1e6ca5692344d97cf229832ef584be2cec9fc03df
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app
COPY infrastructure/docker/guest-cleanup.requirements.txt /app/requirements.txt
RUN python -m pip install --require-hashes --only-binary=:all: -r requirements.txt \
    && useradd --system --uid 10001 unlabel
COPY backend/app/selfhost/guest_cleanup.py /app/guest_cleanup.py
USER 10001:10001
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 CMD python /app/guest_cleanup.py --healthcheck
CMD ["python", "/app/guest_cleanup.py"]
