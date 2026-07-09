# Snowflake Example (Vulcan)

This folder is a runnable Vulcan example project targeting **Snowflake**. It uses:

- **Postgres** as the Vulcan state store (local container: `statestore`)
- **MinIO** as the local object store (local container: `minio`)
- Optional local services: **Vulcan API**, **Transpiler**, **GraphQL**

## Prerequisites

- Docker + Docker Compose (`docker compose`)
- A Snowflake account + credentials

## 1) Configure Snowflake credentials

Create a `.env` file in this directory (`vulcan-examples/snowflake/.env`) with:

```bash
SNOWFLAKE_ACCOUNT=...
SNOWFLAKE_USER=...
SNOWFLAKE_PASSWORD=...
SNOWFLAKE_WAREHOUSE=...
SNOWFLAKE_DATABASE=...
SNOWFLAKE_ROLE=...

# (optional) pin the docker image tag used by docker compose
VERSION=0.228.0-spark-01
```

These env vars are referenced by `config.yaml`.

## 2) Start local infra (Postgres + MinIO)

From this folder:

```bash
cd /Users/shreyasikarwar/Desktop/DataOs-Research/Vulcan/vulcan-examples/snowflake
```

Create the shared Docker network (one-time):

```bash
docker network create vulcan || true
```

Bring up infra:

```bash
docker compose -f docker/docker-compose.infra.yml up -d
```

## 3) Start Vulcan services (API + Transpiler + GraphQL)

```bash
VERSION=${VERSION:-0.228.0-spark-01} docker compose -f docker/docker-compose.vulcan.yml up -d
```

## 4) Use the Vulcan CLI via Docker (recommended)

Define an alias (loads `.env`, mounts the project, and sets the working directory):

```bash
alias vulcan='docker run -it --network=vulcan --rm -v "$PWD":/workspace -w /workspace --env-file .env tmdcio/vulcan:0.228.0-spark-01 vulcan'
```

Verify the project:

```bash
vulcan info
```

## Useful commands

- Check containers:

```bash
docker compose -f docker/docker-compose.infra.yml ps
docker compose -f docker/docker-compose.vulcan.yml ps
```

- Stop everything:

```bash
docker compose -f docker/docker-compose.vulcan.yml down
docker compose -f docker/docker-compose.infra.yml down
```

## Notes

- The compose files assume an **external** Docker network named `vulcan`.
- If `vulcan info` says it can’t connect to the state store, make sure `statestore` is healthy and that you started infra first.

