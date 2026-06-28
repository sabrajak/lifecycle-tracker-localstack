# Local integration stack for app-lifecycle-tracking

Docker Compose environment for end-to-end testing of the **app-lifecycle-tracking** library (`cxp-app-lifecycle-tracking-lib`) using the three companion apps in this repo.

| Service | Path | Role |
|---------|------|------|
| **lifecycle-tracker-demo-app** | `../lifecycle-tracker-demo-app/` | Producers — runs example scripts |
| **lifecycle-tracker-monitor-app** | `../lifecycle-tracker-monitor-app/` | `ApplicationLifecycleMonitor` consumer |
| **lifecycle-tracker-callback-consumer** | `../lifecycle-tracker-callback-consumer/` | `AppLifecycleCallbackHandler` consumer |

## What this stack provides

| Component | Purpose |
|-----------|---------|
| **PostgreSQL** | Lifecycle storage (`audit_job_trail` table, schema matches lib README §8) |
| **Kafka + Zookeeper** | Default queue backend (`lifecycle-tracking-queue`, `callback-queue` topics) |
| **LocalStack** | AWS emulation for **DynamoDB** and **SQS** when testing alternate backends |
| **kafka-ui** | Optional UI at http://localhost:8080 |

### Default configuration

All three app containers are pre-wired with:

| Variable | Value | Notes |
|----------|-------|-------|
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

## Quick start

All commands below run from **`Lifecycle-Tracker/lifecycle-tracker-localstack/`**.

### 1. Build app images

**From JFrog** (requires `ARTIFACTORY_USER` / `ARTIFACTORY_API_KEY` in the same shell):

```bash
docker compose build lifecycle-tracker-callback-consumer lifecycle-tracker-monitor-app lifecycle-tracker-demo-app
```

**From local `cxp-app-lifecycle-tracking-lib`** (no JFrog — shared `lifecycle-lib` stage in `Dockerfile.app` is built once and cached across all three app images):

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
|---------|-------|
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
|---------|------------------|---------------|
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

1. Set on all three app services in `docker-compose.yml` (or via `.env` overrides):

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

## Local development without Docker

Start infrastructure only, then run apps on the host:

```bash
# Infra only
docker compose up -d localstack postgres zookeeper kafka kafka-init

# Export env (host → localhost ports)
export APP_LIFECYCLE_DB_TYPE=postgres
export APP_LIFECYCLE_TRACKING_QUEUE_TYPE=kafka
export APP_LIFECYCLE_CALLBACK_HANDLER_ENABLED=false   # producers
export PG_HOST=localhost PG_PORT=5432 PG_USER=postgres PG_PASSWORD=postgres PG_DATABASE=pin PG_SSLMODE=disable
export KAFKA_BOOTSTRAP_SERVERS=localhost:29092
export AWS_REGION=us-west-2 AWS_ENVIRONMENT=localstack AWS_ENDPOINT_URL=http://localhost:4566
export AWS_ACCESS_KEY_ID=accesskey AWS_SECRET_ACCESS_KEY=secretkey

# Terminal 1 — monitor
cd ../lifecycle-tracker-monitor-app && poetry install && poetry run monitor-consumer-example

# Terminal 2 — callbacks (handler enabled)
cd ../lifecycle-tracker-callback-consumer
export APP_LIFECYCLE_CALLBACK_HANDLER_ENABLED=true
poetry install && poetry run lifecycle-tracker-callback-consumer-example

# Terminal 3 — producer
cd ../lifecycle-tracker-demo-app && poetry install
python -m examples.basic_example
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Build fails on `poetry install` | Missing Artifactory creds | `export ARTIFACTORY_USER` and `ARTIFACTORY_API_KEY` in the same terminal before `docker compose build` |
| Producer succeeds, parent never completes | Monitor not running or Kafka topic race | `docker compose ps`; ensure `kafka-init` completed; check monitor logs |
| Callbacks not firing | Handler disabled on wrong service | Callback-consumer must have `APP_LIFECYCLE_CALLBACK_HANDLER_ENABLED=true`; producers should have `false` |
| Postgres insert errors | Stale volume with old schema | `docker compose down -v` and restart (schema uses `track_datetime` column per lib spec) |
| SQS `Queue does not exist` | Queue not in `init-sqs.sh` for that `app_name` | Add queue or use Kafka default |

## Related documentation

- Library API and configuration: `../cxp-app-lifecycle-tracking-lib/README.md`
- Producer app: `../lifecycle-tracker-demo-app/README.md`
- Monitor consumer: `../lifecycle-tracker-monitor-app/README.md`
- Callback consumer: `../lifecycle-tracker-callback-consumer/README.md`
