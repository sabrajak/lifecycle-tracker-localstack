# Shared app image recipe for demo / monitor / callback-consumer.
# Set APP_DIR at build time (see docker-compose.yml).
#
# Local lib: build target `with-lib` — the lifecycle-lib stage is cached across
# all three app images so the lib is compiled only once per build session.

# ---------------------------------------------------------------------------
# Stage 1: install cxp-app-lifecycle-tracking-lib (shared cache across apps)
# ---------------------------------------------------------------------------
FROM python:3.13-slim AS lifecycle-lib

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN pip install poetry

WORKDIR /cxp-app-lifecycle-tracking-lib
COPY cxp-app-lifecycle-tracking-lib/ ./

RUN poetry config virtualenvs.create false && \
    poetry install --no-interaction --no-ansi --only main

# ---------------------------------------------------------------------------
# Stage 2a: app on top of pre-built local lib
# ---------------------------------------------------------------------------
FROM lifecycle-lib AS with-lib

ARG APP_DIR

WORKDIR /app

COPY ${APP_DIR}/pyproject.toml ${APP_DIR}/poetry.lock ${APP_DIR}/README.md ./
COPY ${APP_DIR}/src ./src

RUN sed -i 's|app-lifecycle-tracking = {version = "0.0.15", source = "cx-platform-pypi"}|app-lifecycle-tracking = {path = "/cxp-app-lifecycle-tracking-lib", develop = true}|' pyproject.toml && \
    rm -f poetry.lock && \
    poetry install --no-interaction --no-ansi

# ---------------------------------------------------------------------------
# Stage 2b: app with JFrog-pulled lib (default production path)
# ---------------------------------------------------------------------------
FROM python:3.13-slim AS without-lib

ARG APP_DIR
ARG ARTIFACTORY_USER
ARG ARTIFACTORY_API_KEY

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && pip install poetry

COPY ${APP_DIR}/pyproject.toml ${APP_DIR}/poetry.lock ${APP_DIR}/README.md ./
COPY ${APP_DIR}/src ./src

RUN if [ -z "$ARTIFACTORY_USER" ] || [ -z "$ARTIFACTORY_API_KEY" ]; then \
      echo "ERROR: ARTIFACTORY_USER and ARTIFACTORY_API_KEY build args are required." >&2; \
      echo "  export ARTIFACTORY_USER=... ARTIFACTORY_API_KEY=... && docker compose build" >&2; \
      echo "  Or use local lib: docker compose -f docker-compose.yml -f docker-compose.local-lib.yml build" >&2; \
      exit 1; \
    fi && \
    poetry config virtualenvs.create false && \
    poetry config http-basic.cx-platform-pypi "$ARTIFACTORY_USER" "$ARTIFACTORY_API_KEY" && \
    poetry install --no-interaction --no-ansi
