# Local integration stack for app-lifecycle-tracking

Docker Compose environment for end-to-end testing of the **app-lifecycle-tracking** library (`cxp-app-lifecycle-tracking-lib`) using the three companion apps in this repo.

| Service | Path | Role |
| --- | --- | --- |
| **lifecycle-tracker-demo-app** | `../lifecycle-tracker-demo-app/` | Producers — runs example scripts |
| **lifecycle-tracker-monitor-app** | `../lifecycle-tracker-monitor-app/` | `ApplicationLifecycleMonitor` consumer |
| **lifecycle-tracker-callback-consumer** | `../lifecycle-tracker-callback-consumer/` | `AppLifecycleCallbackHandler` consumer |

## Table of contents

- [What this stack provides](#what-this-stack-provides)
- [Prerequisites](#prerequisites)
- [Quick start (Docker — full stack)](#quick-start-docker--full-stack)
- [Architecture](#architecture)
- [Example guide](#example-guide)
- [Switching backends](#switching-backends)
- [Run lib examples on the host (infra only)](#run-lib-examples-on-the-host-infra-only)
- [Troubleshooting](#troubleshooting)
- [Related documentation](#related-documentation)

## What this stack provides

| Component | Purpose |
| --- | --- |
| **PostgreSQL** | Lifecycle storage (`audit_job_trail` table, schema matches lib README §8) |
| **Kafka + Zookeeper** | Default queue backend (`lifecycle-tracking-queue`, `callback-queue` topics) |
| **LocalStack** | AWS emulation for **DynamoDB** and **SQS** when testing alternate backends |
| **kafka-ui** | Optional UI at [http://localhost:8080](http://localhost:8080) |

### Default configuration

All three app containers are pre-wired with:

| Variable | Value | Notes |
| --- | --- | --- |
| `APP_LIFECYCLE_DB_TYPE` | `postgres` | Table `audit_job_trail` created on first Postgres start |
| `APP_LIFECYCLE_TRACKING_QUEUE_TYPE` | `kafka` | Switch to `sqs` to use LocalStack queues instead |
| `APP_LIFECYCLE_CALLBACK_HANDLER_ENABLED` | `false` on demo/monitor, `true` on callback-consumer | Matches README §6.2 split deployment |
| `PG_*` | `postgres` service / database `pin` | See `docker-compose.yml` |
| `KAFKA_BOOTSTRAP_SERVERS` | `kafka:9092` | Topics created by `kafka-init` |

Producers publish lifecycle events and callback messages. The monitor auto-completes parents after `track_children(...)`. The callback consumer runs registered handlers for matching `app_name` values.

## Prerequisites

1. **Docker Desktop** (or Docker Engine + Compose v2)
2. **JFrog Artifactory credentials** — export in the **same terminal session** before `docker compose build` or `docker compose up` (required to pull `app-lifecycle-tracking` during image build):

```bash
export ARTIFACTORY_USER=your-jfrog-username
export ARTIFACTORY_API_KEY=your-jfrog-api-key-or-token

test -n "$ARTIFACTORY_USER" && test -n "$ARTIFACTORY_API_KEY" && echo "Artifactory env: OK"
```

You may add those `export` lines to your shell profile (e.g. `~/.zshrc.local`) so they are set automatically — do not put them in `.env`.

## Quick start (Docker — full stack)

All commands below run from `Lifecycle-Tracker/lifecycle-tracker-localstack/`.

### 1. Build app images

**From JFrog** (requires `ARTIFACTORY_USER` / `ARTIFACTORY_API_KEY` in the same shell):

```bash
docker compose build lifecycle-tracker-callback-consumer lifecycle-tracker-monitor-app lifecycle-tracker-demo-app
```

**From local** `cxp-app-lifecycle-tracking-lib` (no JFrog — shared `lifecycle-lib` stage in `Dockerfile.app` is built once and cached across all three app images):

```bash
docker compose -f docker-compose.yml -f docker-compose.local-lib.yml build \
  lifecycle-tracker-callback-consumer lifecycle-tracker-monitor-app lifecycle-tracker-demo-app
```

Use the same `-f docker-compose.local-lib.yml` flag for `up`, `exec`, and `down`.

### 2. Start the stack

```bash
docker compose up -d
```

Wait until consumers are healthy:

```bash
docker compose ps
```

Expected:

| Service | State |
| --- | --- |
| `lifecycle-tracker-callback-consumer` | healthy |
| `lifecycle-tracker-monitor-app` | healthy |
| `lifecycle-tracker-demo-app` | running (idle) |
| `postgres`, `kafka`, `localstack` | healthy / running |

### 3. Run an example producer

Run `docker compose exec` from the **host** in `lifecycle-tracker-localstack/` (not from inside a container):

```bash
# Basic lifecycle + parent/child tracking
docker compose exec lifecycle-tracker-demo-app python -m examples.basic_example

# Monitor / video pipeline (parent auto-complete)
docker compose exec lifecycle-tracker-demo-app python -m examples.monitor_producer_example

# Callback scenarios (handlers in callback-consumer)
docker compose exec lifecycle-tracker-demo-app python -m examples.callback_producer_example

# Advanced patterns (retry, workflow statuses, deep hierarchy)
docker compose exec lifecycle-tracker-demo-app python -m examples.advanced_example

# Multi-app handler — PIN, SWC, FBA (Example 6 in callback_producer_example)
# Or run only Example 6:
# docker compose exec lifecycle-tracker-demo-app python -c \
#   "from examples.callback_producer_example import multi_app_handler_producer_example; multi_app_handler_producer_example()"

# Curated demo showcase (4 scenarios)
docker compose exec lifecycle-tracker-demo-app python -m demo.demo_showcase
```

### 4. Watch consumer output

```bash
docker logs -f lifecycle-tracker-monitor-app
docker logs -f lifecycle-tracker-callback-consumer
```

### 5. Tear down

```bash
docker compose down        # keep volumes (Postgres data persists)
docker compose down -v     # wipe Postgres volume
```

## Architecture

```
┌─────────────────────────────┐
│ lifecycle-tracker-demo-app  │  producers (exec python -m examples.*)
└──────────────┬──────────────┘
               │ writes track logs
               ▼
        ┌──────────────┐     ┌──────────────────────────────────┐
        │  PostgreSQL  │     │  Kafka (default) or LocalStack   │
        │ audit_job_   │     │  SQS                             │
        │ trail        │     │  • lifecycle-tracking-queue      │
        └──────────────┘     │  • callback-queue                │
               ▲               └───────────┬──────────────────────┘
               │                           │
               │              ┌────────────┴────────────┐
               │              ▼                         ▼
               │   lifecycle-tracker-monitor-app   lifecycle-tracker-callback-consumer
               │   ApplicationLifecycleMonitor     AppLifecycleCallbackHandler
               │   (track_children / parent done)  (APP_LIFECYCLE_CALLBACK_HANDLER_ENABLED=true)
               └──────────────────────────────────────────────────────────────────────────
```

See also: `../cxp-app-lifecycle-tracking-lib/docs/lifecycle-tracker-distributed-design.drawio`

## Example guide

| Example | Producer command | What to check |
| --- | --- | --- |
| Basic | `python -m examples.basic_example` | Postgres rows; monitor logs for Example 4 (`track_children`) |
| Monitor | `python -m examples.monitor_producer_example` | Monitor logs — parent completion |
| Callbacks | `python -m examples.callback_producer_example` | Callback-consumer logs — examples 1–6 (`[CALLBACK]`, `[MULTI-APP]` for PIN/SWC/FBA) |
| Distributed (5a) | included in `callback_producer_example` | `my-service` — `[CALLBACK]` + `[ALERT]` on fail |
| Advanced | `python -m examples.advanced_example` | Postgres rows — retry, workflow statuses, deep hierarchy (no callbacks) |
| Multi-app handler | `callback_producer_example` Example 6 (`multi_app_handler_producer_example()`) | Callback-consumer `[MULTI-APP]` logs for `PIN`, `SWC`, `FBA` |
| Demo showcase | `python -m demo.demo_showcase` | All three services |

Per-example detail: `../lifecycle-tracker-demo-app/src/examples/README.md`

**Canonical source:** `../cxp-app-lifecycle-tracking-lib/examples/` — mirrors in demo-app, callback-consumer, and monitor-app. After editing lib examples, run `python3 lifecycle-tracker-demo-app/scripts/sync_example_mirrors.py`. See `../lifecycle-tracker-demo-app/examples/README.md` for the full index.

## Switching backends

### Kafka (default)

No changes needed. Topics `lifecycle-tracking-queue` and `callback-queue` are created automatically by the `kafka-init` service.

### PostgreSQL → DynamoDB

1. Set on all three app services in `docker-compose.yml`:

   ```yaml
   APP_LIFECYCLE_DB_TYPE=dynamodb
   ```

2. Restart the stack. LocalStack creates the `audit_job_trail` DynamoDB table via `scripts/aws/init-dynamodb.sh` on first boot.
3. Wipe Postgres volume if switching back: `docker compose down -v`

### Kafka → SQS

1. Set on all three app services:

   ```yaml
   APP_LIFECYCLE_TRACKING_QUEUE_TYPE=sqs
   ```

2. Ensure LocalStack is running (it always is in this compose file). SQS queues are created from `scripts/aws/init-sqs.sh` — one `callback-queue-<app_name>` queue per example `app_name`, plus shared `lifecycle-tracking-queue`.
3. Rebuild and restart:

   ```bash
   docker compose up -d --force-recreate lifecycle-tracker-demo-app lifecycle-tracker-monitor-app lifecycle-tracker-callback-consumer
   ```

## Run lib examples on the host (infra only)

Run example scripts directly from **`cxp-app-lifecycle-tracking-lib`** against Docker infrastructure only — no companion app containers required.

### When you need a separate terminal

| Scenario | Separate consumer terminal? | Why |
| --- | --- | --- |
| Postgres tracking only (`basic_example` Ex 1–3, `advanced_example`) | **No** | Writes go straight to Postgres |
| Parent auto-complete (`track_children`) | **Yes** | Monitor must consume `lifecycle-tracking-queue` |
| Callback handlers (`callback_producer_example`) | **Yes** | Handlers must consume `callback-queue` |

Producer scripts exit successfully even without a consumer; you only miss queue-driven side effects (parent completion, callback logs).

### Which lib consumer to run

| Producer (run in terminal 2) | Consumer (run in terminal 1, blocks) |
| --- | --- |
| `basic_example` Ex 4 (`track_children`) | `python -m examples.monitor_consumer_example` |
| `monitor_producer_example` | `python -m examples.monitor_consumer_example` |
| `callback_producer_example` | `python -m examples.callback_consumer_example` |

For `basic_example` only, you can run the monitor in the same repo without a second script:

```bash
poetry run python -m examples.basic_example monitor   # blocks; listens on lifecycle queue
```

### 1. Start infrastructure

From `lifecycle-tracker-localstack/`:

```bash
docker compose up -d localstack postgres zookeeper kafka kafka-init
```

Wait until `kafka-init` completes and Postgres is healthy (`docker compose ps`).

### 2. Install the library

Requires **Python ≥ 3.13** and [Poetry](https://python-poetry.org/):

```bash
cd ../cxp-app-lifecycle-tracking-lib
poetry install
```

### 3. Set host environment variables

Containers use internal DNS; your shell uses `localhost`. Export these in **every** terminal where you run examples or consumers:

```bash
export APP_LIFECYCLE_DB_TYPE=postgres
export APP_LIFECYCLE_TRACKING_QUEUE_TYPE=kafka
export APP_LIFECYCLE_CALLBACK_THREAD_POOL_SIZE=5

export PG_HOST=localhost
export PG_PORT=5432
export PG_USER=postgres
export PG_PASSWORD=postgres
export PG_DATABASE=pin
export PG_SSLMODE=disable

export KAFKA_BOOTSTRAP_SERVERS=localhost:29092
export PYTHONPATH=.
```

| In Docker Compose | On host |
| --- | --- |
| `PG_HOST=postgres` | `PG_HOST=localhost` |
| `KAFKA_BOOTSTRAP_SERVERS=kafka:9092` | `KAFKA_BOOTSTRAP_SERVERS=localhost:29092` |
| `AWS_ENDPOINT_URL=http://localstack:4566` | `AWS_ENDPOINT_URL=http://localhost:4566` (only if using DynamoDB/SQS) |

The `audit_job_trail` table is created automatically on first Postgres container start (`scripts/db/init-postgres.sql`).

### 4. Run producers

From `cxp-app-lifecycle-tracking-lib/` (with env vars above):

```bash
# Basic — Ex 1–4 (Ex 4 needs monitor consumer or `basic_example monitor`)
poetry run python -m examples.basic_example

# Monitor / video pipeline (needs monitor_consumer_example in another terminal)
poetry run python -m examples.monitor_producer_example

# Callback scenarios (needs callback_consumer_example in another terminal)
poetry run python -m examples.callback_producer_example

# Advanced — retry, workflow statuses, ETL hierarchy (Postgres only)
poetry run python -m examples.advanced_example
```

### 5. Example workflow (monitor + producer)

**Terminal 1** — start the monitor consumer first (blocks):

```bash
cd cxp-app-lifecycle-tracking-lib
# … export env vars and PYTHONPATH=.
poetry run python -m examples.monitor_consumer_example
```

**Terminal 2** — run the producer:

```bash
cd cxp-app-lifecycle-tracking-lib
# … same env vars and PYTHONPATH=.
poetry run python -m examples.monitor_producer_example
```

### 6. Verify in Postgres (optional)

```bash
docker exec -it postgres psql -U postgres -d pin -c \
  "SELECT track_id, track_status FROM audit_job_trail WHERE status_type='TERMINAL' ORDER BY created_at DESC LIMIT 5;"
```

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Build fails on `poetry install` | Missing Artifactory creds | `export ARTIFACTORY_USER` and `ARTIFACTORY_API_KEY` in the same terminal before `docker compose build` |
| Producer succeeds, parent never completes | Monitor not running or Kafka topic race | Ensure `kafka-init` completed; start `monitor_consumer_example` (host) or monitor container (Docker) |
| Callbacks not firing | No callback consumer listening | Start `callback_consumer_example` (host) or callback-consumer container (Docker) |
| `ModuleNotFoundError: examples` | Missing `PYTHONPATH` | `export PYTHONPATH=.` from `cxp-app-lifecycle-tracking-lib/` |
| Postgres insert errors | Stale volume with old schema | `docker compose down -v` and restart (schema uses `track_datetime` column per lib spec) |
| SQS `Queue does not exist` | Queue not in `init-sqs.sh` for that `app_name` | Add queue or use Kafka default |

## Related documentation

- Library API and configuration: `../cxp-app-lifecycle-tracking-lib/README.md`
- Lib examples (canonical): `../cxp-app-lifecycle-tracking-lib/examples/`
- Producer app: `../lifecycle-tracker-demo-app/README.md`
- Monitor consumer: `../lifecycle-tracker-monitor-app/README.md`
- Callback consumer: `../lifecycle-tracker-callback-consumer/README.md`
