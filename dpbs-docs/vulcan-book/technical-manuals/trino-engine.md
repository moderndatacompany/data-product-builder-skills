---
description: >-
  A Trino engine manual for DataOS Vulcan setup, development, deployment,
  operations, performance, and troubleshooting.
---

# Trino Engine

|                               |                                                  |
| ----------------------------- | ------------------------------------------------ |
| **Template version**          | 1.0                                              |
| **Engine**                    | Trino (DataOS Minerva / managed `vulcan-trino`)  |
| **Tested Vulcan image**       | `tmdcio/vulcan-trino:0.228.1.24-beta1`           |
| **Tested Trino server image** | `tmdcio/trino:5.1.2-dev` (managed cluster)       |
| **Tested DataOS release**     | Validated on a Trino-capable DataOS compute pool |
| **Last updated**              | June 2026                                        |

***

## How to use this manual

Use this manual as the working reference for building and running a Trino-backed Data Product in DataOS. It assumes you already know the basics of Data Products and Vulcan. The structure stays consistent across engine manuals — only the Trino-specific content changes.

Trino on Vulcan comes in **two deployment shapes**, and most of this manual applies to both — read section 1.1 first to know which one you are on:

* **Managed Trino** (`engine: trino` + a `spec.trino` block) — Vulcan's `vulcan-trino` stack provisions and owns a Trino coordinator + workers for you, and generates catalogs from your depots.
* **External / Minerva Trino** — you connect to an existing DataOS Minerva (Trino) cluster over its endpoint. Vulcan does not manage the cluster.

Use the path below that matches your role.

**If you are a data engineer setting up Vulcan on Trino for the first time:** section 1: Snapshot → section 2: Prerequisites (including pre-flight checklist) → section 3: LDK setup → section 10: Deployment recipes → section 7: Operational boundaries

**If you are a DP developer building or debugging a Data Product on Trino:** section 1: Snapshot → section 4: Vulcan on Trino → section 9: Failure modes & troubleshooting

This manual is link-heavy by design. Every concept that already has a canonical page is summarised in one or two lines and linked. Section 11 is the full outbound link map.

***

## Section 1: Snapshot

This section is the fast path. If you only need the essentials, start here. It gives you the supported versions, key limits, runtime expectations, and the defaults you can rely on.

### 1.1: Two deployment shapes

|                        | Managed Trino                                            | External / Minerva Trino                         |
| ---------------------- | -------------------------------------------------------- | ------------------------------------------------ |
| Resource type          | `vulcan-trino`                                           | `vulcan`                                         |
| Cluster ownership      | Vulcan stack provisions coordinator + workers            | Pre-existing DataOS Minerva cluster              |
| `spec.trino` block     | Required (drives catalogs, sizing, server config)        | Not used                                         |
| Gateway connection     | `no-auth`, `http`, `host: <resource>-trino`, port `8080` | `basic`/JWT, `https`, host + password via secret |
| Catalogs               | Generated from `spec.depots[]`                           | Already mounted on the cluster                   |
| Materialization target | First depot's catalog (the default gateway catalog)      | The configured gateway catalog                   |
| Best for               | Self-contained, federated DP that owns its compute       | Sharing one large central Trino cluster          |

Both shapes use the **same** model/semantic/metric/DQ code. Only `config.yaml`, the deploy resource, and connection secrets differ.

### 1.2: Architecture

A managed Trino Data Product is rendered by the domain into four cooperating resources:

```
vulcan-trino resource
├── <name>-trino           (service)  → Trino coordinator (replicas: 1)
├── <name>-trino-workers   (service)  → Trino workers (spec.trino.workers.replicas, default 2)
├── <name>-plan            (workflow) → vulcan migrate + plan --auto-apply (waits for cluster ready)
└── <name>-run             (workflow) → vulcan run (scheduled; depends on plan)
```

The plan/run pods carry a **trino-ready init container** — a Vulcan readiness gate that blocks until the coordinator answers `SELECT 1` and the **configured** worker count is `active` before Vulcan starts. (Trino itself can run with fewer workers; this gate is a Vulcan operational rule, not a Trino requirement.)

<figure><img src="../../../.gitbook/assets/Architecture-diagram.png" alt=""><figcaption></figcaption></figure>

### 1.3: Version compatibility matrix

| Vulcan image                           | Trino server image           | DataOS compute     | Storage / sources                    | Status            |
| -------------------------------------- | ---------------------------- | ------------------ | ------------------------------------ | ----------------- |
| `tmdcio/vulcan-trino:0.228.1.24-beta1` | `tmdcio/trino:5.1.2-dev`     | Trino-capable pool | Iceberg (ABFSS), Postgres, Snowflake | ✅ Tested          |
| same                                   | `tmdcio/trino:5.0.7-exp.104` | local Docker       | local Iceberg/Postgres               | ✅ Local dev       |
| Earlier `0.228.1.x` builds             | —                            | —                  | —                                    | ⬜ Add when tested |

> Databricks, Delta Lake, BigQuery and MSSQL/MySQL connector templates exist in the stack but were **not** fully validated in the reference tenant — treat them as ⬜ until you test them on your depots.

### 1.4: Engine facts

| Item                          | Value                                                                                          |
| ----------------------------- | ---------------------------------------------------------------------------------------------- |
| Engine adapter type           | `trino`                                                                                        |
| Model dialect                 | `trino`                                                                                        |
| Support level                 | GA for federated read + Iceberg materialization                                                |
| Tested Vulcan image           | `tmdcio/vulcan-trino:0.228.1.24-beta1`                                                         |
| Serving images                | `tmdcio/vulcan-graphql:0.228.1.24-beta1`, `tmdcio/mysql-wire:0.0.9-beta1`                      |
| Trino server image (managed)  | `tmdcio/trino:5.1.2-dev`                                                                       |
| Stack                         | `vulcan+trino:1.0`                                                                             |
| Federated sources (validated) | Iceberg lakehouse, Postgres, Snowflake                                                         |
| Quality file format           | `kind: dq` YAML with `rules:` (Soda) + model `assertions`/`profiles` + standalone `AUDIT(...)` |
| Semantic model format         | `kind: semantic` YAML with dimensions, measures, joins, segments                               |
| Business metric format        | `kind: metric`, `name`, `measure`, `ts`, `granularity`                                         |
| Supported model kinds         | VIEW, FULL, SEED, INCREMENTAL\_BY\_TIME\_RANGE, INCREMENTAL\_BY\_PARTITION                     |
| Local state store             | DuckDB in local `config.yaml`                                                                  |
| Required platform dependency  | Tenant-level `vulcan-trino` stack + `vulcan+trino:1.0`                                         |
| Dependency / plugin loading   | JARs in `dependencies/java/<plugin>/` → `/usr/lib/trino/plugin/`                               |
| Identifier casing rule        | **lowercase** identifiers (Trino default); quote with `"` only when needed                     |
| Timestamp rule                | Prefer `TIMESTAMP(6)` for Iceberg-backed columns; match the precision your catalog expects     |

### 1.5: SLOs

With the configuration in this manual, the engine delivers:

* **Stable scheduled plan/run** — the workflow runs on its cron, plans, materialises, and serves once the cluster is up and sources are reachable.
* **Reliable cluster formation** — the coordinator and workers come up and register with the JVM heap sized to the pod limit (section 7.1).
* **Correct federated reads** across all mounted catalogs when external models / fully-qualified names are declared.
* **API availability** matching the deployed DataOS service for REST, GraphQL, and MySQL-wire endpoints.

> Trino is an MPP query engine, not a storage engine. Performance is shaped by source latency, federation width (how many catalogs a query spans), and shuffle/exchange size — not by row count alone. Size from sections 6, 7, and 10.

***

## Section 2: Prerequisites

What must be in place before you write a single line of Vulcan code: DataOS platform resources, depots/catalogs, cluster identity, and your local Python version.

### 2.1: Platform & source permissions

Three roles are required. Each has a distinct scope.

| Role                    | Who holds it                    | Purpose                                                                                                                                                             |
| ----------------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Admin role**          | DataOS / platform SRE           | Installs the `vulcan-trino` stack, provisions the compute pool, creates depots, and the tenant `vulcan-state-connection` / `vulcan-object-store-connection` secrets |
| **Vulcan service role** | The `runAsUser` in the resource | Runs the coordinator/workers and the plan/run workflows; reads source catalogs and writes the materialization catalog                                               |
| **Consumer role**       | BI users, endpoint consumers    | Read-only access to Data Product tables via Vulcan API endpoints                                                                                                    |

**Platform prerequisites (request from your DataOS SRE team):**

| Requirement                                    | Notes                                                                                                                                 |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Trino-capable compute pool                     | Verify with `dataos-ctl resource -t compute get -a`; set `spec.compute` to this pool name                                             |
| Tenant-level `vulcan-trino` stack              | Provides the runtime image, serving sidecars, catalog templating, and the per-role Trino config rendering                             |
| Depots for every source you read               | One depot per source system (Iceberg lakehouse, Postgres, Snowflake, …); each becomes a Trino catalog                                 |
| A materialization depot                        | The **first** depot in `spec.depots[]` is the default catalog where FULL/INCREMENTAL models land — make it a writable lakehouse depot |
| Tenant `vulcan-state-connection` secret        | External Postgres for Vulcan plan/interval state                                                                                      |
| Tenant `vulcan-object-store-connection` secret | S3 bucket for Vulcan artifacts / result spooling                                                                                      |
| Git-sync secret                                | Used by the resource to pull model code (`spec.repo.secret`)                                                                          |

**Minimum source grants by connector:**

```
Iceberg lakehouse:  rw on the lakehouse depot; storage creds (S3 access/secret, ABFSS account key, or GCS json key) live on the depot
Postgres:           a read (or rw) role on the target database; credentials on the depot
Snowflake:          a role/warehouse with USAGE + SELECT; user/password or key-pair on the depot secret
BigQuery:           a service account JSON key with dataset read; on the depot secret
```

For the full permissions reference, see [Trino](../configurations/engines/trino/).

### 2.2: DataOS permissions

| Permission                         | What it unlocks                                | Who to request from                 |
| ---------------------------------- | ---------------------------------------------- | ----------------------------------- |
| `roles:id:data-dev` or equivalent  | Create and apply the Trino + Vulcan resources  | DataOS operator / admin             |
| Access to the target workspace     | Apply secrets, depots, and the domain resource | DataOS operator                     |
| `depot:rw:<materialization-depot>` | Write model output to the default catalog      | DataOS operator                     |
| `depot:r:<source-depot>`           | Read each federated source catalog             | DataOS operator                     |
| Git repository access              | Vulcan pulls model code via git-sync           | Your VCS admin (Bitbucket / GitHub) |

> **Check your access** before starting. Run `dataos-ctl get depot` — every depot you intend to mount as a catalog should appear in the output.

### 2.3: Python version

| Requirement                      | Version          |
| -------------------------------- | ---------------- |
| Python (local development)       | **3.10**         |
| Python (runtime in Vulcan image) | Managed by image |

```bash
python --version   # must be 3.10.x
```

> Python is required only for the local Vulcan CLI; the runtime version inside the image is managed for you.

### 2.4: Pre-flight checklist

#### Engine setup checklist

**Trino / source side**

* [ ] Trino-capable compute pool exists; name noted for `spec.compute`
* [ ] Tenant-level `vulcan-trino` stack is installed (`vulcan+trino:1.0`)
* [ ] One depot exists per source system you will federate
* [ ] The **first** depot in `spec.depots[]` is a writable lakehouse depot (materialization target)
* [ ] Source credentials are stored on each depot/secret — never in project code
* [ ] Tenant `vulcan-state-connection` (Postgres) and `vulcan-object-store-connection` (S3) secrets exist
* [ ] Git-sync secret exists and matches `spec.repo.secret`

**Local development**

* [ ] Local Trino cluster starts (coordinator + workers) via Docker compose
* [ ] Vulcan wheel matches the deployed `vulcan-trino` image line
* [ ] Local `config.yaml` points to the local coordinator and a DuckDB state DB
* [ ] `vulcan plan` and at least one representative `vulcan run` succeed locally

**DataOS production**

* [ ] Resource has `type: vulcan-trino` and `spec.engine: trino`
* [ ] `spec.trino.coordinator` and `spec.trino.workers` JVM heap set with `-Xmx` sized to the pod memory limit (`4G` is the validated reference value) — see section 7.1
* [ ] `spec.trino.workers.replicas` set to the intended worker count
* [ ] If overriding `configProperties`, role lines included and discovery/shared-secret **not** duplicated (section 4.1)
* [ ] `node.environment` identical on coordinator and workers; `node.id` **not** set on workers
* [ ] `timezone: UTC`; `endOn` ≥ 1–2 years out; `concurrencyPolicy: Forbid`
* [ ] API replicas and resources sized separately from the cluster

#### Before you ship- checklist (DP developer)

* [ ] All identifiers are **lowercase**; cross-catalog names fully qualified (`catalog.schema.table`)
* [ ] Iceberg-backed timestamp columns use the precision the catalog expects (`TIMESTAMP(6)` preferred)
* [ ] Time-range incrementals filter with `>= @start_dt AND < @end_dt`; `time_column` is set
* [ ] External / cross-catalog sources declared in `external_models.yaml` where the linter cannot resolve them
* [ ] `kind: dq` and `AUDIT(...)` SQL use fully qualified catalog names
* [ ] `endOn` set and reviewed in the resource schedule

***

## Section 3: Local Development Kit (LDK)

Step-by-step setup to run Vulcan locally against Trino. Complete section 2 before starting here.

### 3.1: Install Vulcan

Vulcan is distributed as a Python wheel (`.whl`) and installed directly via `pip`.

```bash
pip install vulcan_trino-<version>-py3-none-any.whl
vulcan --version   # verify after install
```

Get the latest `.whl` for the Trino engine from your DataOS distribution channel, matching the deployed `tmdcio/vulcan-trino` image line.

### 3.2: Set up a local Trino cluster

Local development runs a real Trino coordinator + workers in Docker. A minimal compose stack:

```yaml
services:
  trino-coordinator:
    image: docker.io/tmdcio/trino:5.0.7-exp.104
    platform: linux/amd64
    hostname: trino-coordinator
    ports:
      - "18080:8080"
    volumes:
      - ./trino/coordinator/etc:/usr/trino/etc:ro
  trino-worker-1:
    image: docker.io/tmdcio/trino:5.0.7-exp.104
    platform: linux/amd64
    hostname: trino-worker-1
    volumes:
      - ./trino/worker/etc:/usr/trino/etc:ro
    depends_on: [trino-coordinator]
```

```bash
docker compose -f trino/cluster/docker-compose.yml up -d
docker exec -i trino-coordinator trino --execute "SELECT 1"
```

Mount your catalog `.properties` files under `coordinator/etc/catalog` and `worker/etc/catalog` to test source connectivity locally.

### 3.3: Configure config.yaml

Minimum Trino connection config (local, with DuckDB state):

```yaml
gateways:
  default:
    connection:
      type: trino
      host: localhost
      port: 18080
      user: trino
      catalog: lakehouse          # default catalog where models materialize
      http_scheme: http
      method: no-auth             # TLS verify is irrelevant over plain http
    state_connection:
      type: duckdb                # local dev only
      database: ./.state/local.db

default_gateway: default

model_defaults:
  dialect: trino
  start: 2026-06-01
  cron: "@daily"

linter:
  enabled: true
  rules:
    - ambiguousorinvalidcolumn
    - invalidselectstarexpansion
    - noambiguousprojections

ignore_patterns:
  - "*-deploy.yaml"             # never let the deploy manifest be parsed as a model
```

{% hint style="info" %}
`ignore_patterns` matters. The Trino server deploy manifest lives inside the project; add it to `ignore_patterns` so Vulcan never tries to parse it as a model.
{% endhint %}

In **production** the gateway connection is templated from environment variables that the stack injects (`TRINO_HOST`, `TRINO_PORT`, `TRINO_USER`, `TRINO_CATALOG`, `TRINO_HTTP_SCHEME`, `TRINO_METHOD`). See section 3.5.

### 3.4: Validate your connection

```bash
vulcan migrate        # initialises Vulcan state (DuckDB local / Postgres prod)
vulcan plan           # dry-run against the local Trino cluster — should succeed with no errors
vulcan run            # executes one representative model window end-to-end
```

If `vulcan plan` succeeds, your local setup is complete. Common failures at this step are covered in section 9 (F1–F5).

### 3.5: DataOS production deployment

Production deployment follows this order for apply— each step depends on the previous:

```
Source depots → Materialization (lakehouse) depot → Git secret + tenant state/object-store secrets → config.yaml → vulcan-trino resource
```

| Manifest                         | Purpose                                                                     | Key fields                                                                                     |
| -------------------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Source depots                    | One per federated source                                                    | `name`, `spec.type`, source credentials, `purpose: rw`/`r`                                     |
| Lakehouse depot (first)          | Default catalog for materialized models                                     | lakehouse `storageType` (`abfss`/`s3`/`gcs`) + creds                                           |
| `secret-git-sync.yaml`           | Repo credentials for git-sync                                               | `GITSYNC_USERNAME`, `GITSYNC_PASSWORD`                                                         |
| Tenant secrets                   | `vulcan-state-connection` (Postgres), `vulcan-object-store-connection` (S3) | provisioned once per tenant by SRE                                                             |
| `config.yaml`                    | Project config + gateway templated from env                                 | `engine: trino`, env-var connection, `model_defaults`                                          |
| Deploy resource (`vulcan-trino`) | Cluster + workflows + API + schedule                                        | `spec.engine: trino`, `spec.compute`, `spec.depots`, `spec.trino`, `spec.workflow`, `spec.api` |

A managed Trino resource looks like this (trimmed):

```yaml
version: v1alpha
type: vulcan-trino
name: managed-trino-dp2
owner: rohitrajtmdcio
spec:
  runAsUser: "rohitrajtmdcio"
  compute: <trino-compute-pool>
  engine: trino
  repo:
    url: https://bitbucket.org/rubik_/vulcan-examples
    syncFlags: ["--ref=rohit-examples", "--submodules=off"]
    baseDir: vulcan-examples/trino/managed-trino
    secret: engineering:git-sync-rr
  depots:
    - dataos://abfsslhdepot?purpose=rw     # FIRST = default catalog + materialization target
    - dataos://arabledepot?purpose=rw      # Postgres source
    - dataos://snowflakevulcan?purpose=rw  # Snowflake source
  trino:
    overideCatalogConfig:
      - name: abfsslhdepot
        properties:
          iceberg.max-partitions-per-writer: 100
    coordinator:
      trinoServerConfig:
        jvmConfig: |
          -server
          -Xmx4G
          -XX:+UseG1GC
          -XX:G1HeapRegionSize=32M
        logProperties: |
          io.trino=INFO
    workers:
      replicas: 1
      trinoServerConfig:
        jvmConfig: |
          -server
          -Xmx4G
          -XX:+UseG1GC
        logProperties: |
          io.trino=INFO
  workflow:
    schedule:
      crons: ["0 */6 * * *"]
      endOn: "2027-01-01T00:00:00-00:00"
      timezone: "UTC"
      concurrencyPolicy: Forbid
    resource:
      request: { cpu: "1000m", memory: "2Gi" }
      limit:   { cpu: "2000m", memory: "4Gi" }
    plan:
      command: [vulcan]
      arguments: ["--log-to-stdout", "plan", "--auto-apply"]
    run:
      command: [vulcan]
      arguments: ["--log-to-stdout", "run"]
  api:
    replicas: 1
    resource:
      request: { cpu: "1000m", memory: "2Gi" }
      limit:   { cpu: "2000m", memory: "4Gi" }
```

{% hint style="info" %}
Why order matters. The stack generates each catalog `.properties` from a depot that must already exist; the plan/run workflows can only sync code once the Git secret exists; and the plan pod **waits for the coordinator + workers to be active** before it starts. A depot name mismatch in `spec.depots[]` passes `apply` but fails at every run.
{% endhint %}

Reference configurations for all manifests: section 10.

### 3.6: Hello-world starter

Minimum-viable Data Product on Trino. Requires the local Trino cluster from section 3.2.

**`models/view/customers.sql`** — federated staging VIEW:

```sql
MODEL (
  name lakehouse.staging.customers,
  kind VIEW,
  grain customer_id,
  columns (
    customer_id BIGINT,
    name VARCHAR,
    email VARCHAR,
    region VARCHAR
  )
);
SELECT customer_id, name, email, region
FROM abfsslhdepot.azure_spark_dp_bronze.customers;
```

**`models/full/customers_full.sql`** — materialize into the default catalog:

```sql
MODEL (
  name lakehouse.gold.customers_full,
  kind FULL,
  grain customer_id,
  assertions (
    unique_values(columns := customer_id),
    not_null(columns := (customer_id, name))
  ),
  columns (
    customer_id BIGINT,
    name VARCHAR,
    email VARCHAR,
    region VARCHAR
  )
);
SELECT customer_id, name, email, region
FROM lakehouse.staging.customers;
```

**`models/semantics/customers.yml`**

```yaml
kind: semantic
name: customers
depends_on: lakehouse.gold.customers_full
dimensions:
  - customer_id
  - region
measures:
  - name: total_customers
    type: count_distinct
    expression: "{customers.customer_id}"
```

**`metrics/daily_customers.yml`**

```yaml
kind: metric
name: daily_customers
measure: customers.total_customers
granularity: day
```

Run `vulcan plan` : you should see `lakehouse.gold.customers_full` staged. Run `vulcan run` to materialise. Call the REST endpoint to confirm end-to-end.

***

## Section 4: Vulcan on Trino

What changes when Trino is the engine — federation, materialization target, runtime ownership, and what doesn't work. For general Vulcan concepts and syntax, see the canonical docs linked in each sub-section.

> **Architectural constraints on Trino:**
>
> * Trino is a compute/query engine and does **not** provide its own storage layer. Persisted tables are stored in external systems (Iceberg, Hive, Delta Lake, …); materialized models land in the **first depot's catalog**, so pick that depot deliberately.
> * On managed Trino the `vulcan-trino` stack owns cluster identity: it auto-injects `discovery.uri` and `internal-communication.shared-secret`. Overriding `configProperties` **replaces** the default block — you must re-supply role lines and must not duplicate the injected lines.
> * `node.environment` must be identical on coordinator and workers (a mismatch prevents the cluster forming). `node.id` must **not** be set on workers (it would duplicate across replicas).
> * If the JVM heap is left unmanaged, the effective heap can exceed the container memory limit and workers OOM/fail to register; explicitly set `-Xmx` (section 7.1).
> * Fault-tolerant execution (`retry-policy=TASK/QUERY`) is available in Trino but requires an exchange manager that is **not** enabled in the reference deployment.

**Not supported / not validated on Trino via Vulcan**

| Feature                                        | Status                                                                                | Alternative                                                                         |
| ---------------------------------------------- | ------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Trino cluster autoscaling                      | Accepted in spec but **not rendered**                                                 | Set a fixed `spec.trino.workers.replicas`; resize and re-apply                      |
| Fault-tolerant retries (`retry-policy`)        | Available in Trino, but not enabled in the reference deployment (no exchange manager) | Keep `retry-policy=NONE`, or configure an exchange manager; rely on workflow re-run |
| Databricks / Delta / BigQuery / MSSQL catalogs | Templates exist, not validated in reference tenant                                    | Test on your own depot before relying on it                                         |
| SCD Type 2 / unique-key MERGE                  | Not exercised in reference projects                                                   | Use FULL or partition/time-range incrementals; validate Iceberg MERGE separately    |
| Sub-second serving on a cold cluster           | Floor is cluster start + worker registration                                          | Keep the cluster warm; pre-aggregate hot marts                                      |

### 4.1: Cluster configuration (managed Trino)

Per-role server config is set under `spec.trino.coordinator.trinoServerConfig` and `spec.trino.workers.trinoServerConfig`. Each accepts the **full file contents** for `jvmConfig`, `configProperties`, `nodeProperties`, and `logProperties`.

> **Scope of this section.** Only the **default property files the stack renders** — plus the one validated change (`-Xmx4G` in `jvmConfig`) — are documented here. These are the configurations that are known to work. Trino exposes many more tuning properties (memory caps, query timeouts, scheduler tuning, fault tolerance); they are **not** part of the validated default set, so they are intentionally left out — add them only after you test them on your own cluster.

The five server-side files the stack generates per role are below. Unless you have a reason to override, **ship the defaults** — they form a working cluster.

#### 4.1.1: `jvm.config`

Stack default (coordinator and worker):

```properties
-server
-XX:+UseG1GC
-XX:G1HeapRegionSize=32M
-XX:+UseGCOverheadLimit
-XX:+ExplicitGCInvokesConcurrent
-XX:+HeapDumpOnOutOfMemoryError
-Djdk.attach.allowAttachSelf=true
--enable-native-access=ALL-UNNAMED
--add-opens=java.base/java.nio=ALL-UNNAMED
--sun-misc-unsafe-memory-access=allow
```

{% hint style="warning" %}
The one change you must make: set `-Xmx` to fit the worker memory limit. If heap is left unmanaged, the effective heap can exceed the container limit and workers OOM/fail to register (section 7.1, F1). `4G` is the validated value for the reference deployment's `4Gi` pod limit — size yours to your own limit.
{% endhint %}

```yaml
# validated working jvmConfig for the reference deployment (both roles)
jvmConfig: |
  -server
  -Xmx4G
  -XX:+UseG1GC
  -XX:G1HeapRegionSize=32M
  -XX:+UseGCOverheadLimit
  -XX:+ExplicitGCInvokesConcurrent
  -XX:+HeapDumpOnOutOfMemoryError
  -Djdk.attach.allowAttachSelf=true
  --enable-native-access=ALL-UNNAMED
  --add-opens=java.base/java.nio=ALL-UNNAMED
  --sun-misc-unsafe-memory-access=allow
```

#### 4.1.2: `config.properties`

Stack default — **coordinator**:

```properties
coordinator=true
node-scheduler.include-coordinator=false
http-server.http.port=8080
discovery.uri=http://<name>-trino.<namespace>.svc.cluster.local:8080
internal-communication.shared-secret=dataos_trino_internal_shared_secret_<name>_cluster
```

Stack default — **worker**:

```properties
coordinator=false
http-server.http.port=8080
discovery.uri=http://<name>-trino.<namespace>.svc.cluster.local:8080
internal-communication.shared-secret=dataos_trino_internal_shared_secret_<name>_cluster
```

This default is the validated, working `config.properties`. **Leave `configProperties` unset to use it.**

**The override rule (only if you must set `configProperties`).** When you supply `configProperties`, the stack still prepends the two cluster-identity lines automatically:

```properties
discovery.uri=http://<name>-trino.<namespace>.svc.cluster.local:8080
internal-communication.shared-secret=dataos_trino_internal_shared_secret_<name>_cluster
```

The platform default block is **replaced, not merged**, so you must re-supply the role lines yourself — and **do not** duplicate the two injected lines:

```yaml
# coordinator — explicit baseline equivalent to the default
configProperties: |
  coordinator=true
  node-scheduler.include-coordinator=false
  http-server.http.port=8080
```

```yaml
# worker — explicit baseline equivalent to the default
configProperties: |
  coordinator=false
  http-server.http.port=8080
```

#### 4.1.3: `log.properties`

Stack default (coordinator and worker) — validated:

```properties
io.trino=INFO
```

#### 4.1.4: `node.properties`

Stack default (coordinator and worker):

```properties
node.data-dir=/data/trino
node.environment=dataos
# node.id is auto-generated per pod when omitted
```

`node.environment` must be **identical** on coordinator and workers, or the cluster will not form. (The `vulcan-trino` stack normalises `node.environment` to lowercase/alphanumerics at startup, so keep it to simple lowercase names.) **Never set `node.id` on workers** — it is shared across replicas and would collide; the startup auto-generates a unique `node.id` per pod.

#### 4.1.5: Cluster-identity guard rails — do not change these

| Line                                     | Why                                                                                             |
| ---------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `discovery.uri`                          | Stack-injected; wrong value breaks cluster membership                                           |
| `internal-communication.shared-secret`   | Stack-injected; mismatch blocks inter-node RPC                                                  |
| `coordinator=true` on a worker           | A coordinator-configured node can't act as a worker-only node; the cluster won't form correctly |
| `node.environment` mismatch coord↔worker | Workers will not register                                                                       |
| `node.id` on workers                     | Shared across replicas → duplicate IDs                                                          |

#### 4.1.6: Catalog `.properties`

You do **not** hand-author catalog files. In the Vulcan/DataOS managed deployment model, the stack generates one `<catalog>.properties` per depot in `spec.depots[]` — the catalog name is derived from the depot name (a DataOS behavior, not a Trino concept) — and drops it into `/usr/trino/etc/catalog/`. Only the three connectors below are validated in the reference tenant — ship these.

**Iceberg lakehouse** (e.g. `abfsslhdepot`, ABFSS storage):

```properties
connector.name=iceberg
iceberg.catalog.type=rest
iceberg.file-format=PARQUET
iceberg.rest-catalog.uri=<metastoreUrl><metastoreRelativePath>
iceberg.rest-catalog.security=OAUTH2
iceberg.rest-catalog.oauth2.token=<dataos run-as apikey>
iceberg.rest-catalog.warehouse=abfss://<container>@<account>.<suffix>/<relativePath>
fs.native-azure.enabled=true
azure.auth-type=ACCESS_KEY
azure.access-key=<from depot secret>
```

For S3-backed lakehouse depots the storage lines become:

```properties
fs.native-s3.enabled=true
s3.region=<region>
s3.aws-access-key=<from depot secret>
s3.aws-secret-key=<from depot secret>
```

**Postgres** (e.g. `arabledepot`):

```properties
connector.name=postgresql
connection-url=jdbc:postgresql://<host>:<port>/<database>
connection-user=<from depot/secret>
connection-password=<from depot/secret>
```

**Snowflake** (e.g. `snowflakevulcan`):

```properties
connector.name=snowflake
connection-url=jdbc:snowflake://<account>.snowflakecomputing.com
connection-user=<from depot/secret>
connection-password=<from depot/secret>
snowflake.account=<account>
snowflake.database=<database>
snowflake.role=<role>
snowflake.warehouse=<warehouse>
```

**Adding extra properties to a generated catalog.** Use `spec.trino.overideCatalogConfig` keyed by the catalog (depot) name. The key/values are appended to that catalog's `.properties`. (`overideCatalogConfig` is spelled exactly as shown — it matches the actual `vulcan-trino` resource schema field, not a typo.) The one used in the reference deploy:

```yaml
trino:
  overideCatalogConfig:
    - name: abfsslhdepot
      properties:
        iceberg.max-partitions-per-writer: 100
```

> The stack also contains connector templates for **BigQuery, Databricks, and Delta Lake**, but these are **not validated** in the reference tenant — do not rely on them until you test them on your own depot.

### 4.2: Models

#### 4.2.1: Data Models

SQL models compile to Trino SQL. The Vulcan workflow runs `plan`/`run`The coordinator plans, and the workers execute. **Materialized output lands in the default (first-depot) catalog** — source reads can federate across every mounted catalog.

| Model kind                   | Trino operation                    | Notes                                                                   |
| ---------------------------- | ---------------------------------- | ----------------------------------------------------------------------- |
| VIEW                         | `CREATE VIEW` (or logical staging) | Federated staging layer — read across depot catalogs here               |
| FULL                         | `CREATE TABLE AS` / replace        | Good for dimensions, derived aggregates, rebuildable marts              |
| SEED                         | File-backed reference data         | Small reference tables                                                  |
| INCREMENTAL\_BY\_TIME\_RANGE | Insert/overwrite by time window    | Keep `time_column` set; filter source with `>= @start_dt AND < @end_dt` |
| INCREMENTAL\_BY\_PARTITION   | Insert/overwrite by partition key  | Best when partition key is the natural restatement boundary             |

**Federated VIEW (the Trino superpower):**

```sql
MODEL (
  name lakehouse.staging.customers,
  kind VIEW,
  grain customer_id,
  columns (customer_id BIGINT, name VARCHAR, email VARCHAR, region VARCHAR)
);
SELECT customer_id, name, email, region
FROM abfsslhdepot.azure_spark_dp_bronze.customers;   -- reads the Iceberg source catalog
```

**Time-range incremental (note `TIMESTAMP(6)` for Iceberg):**

```sql
MODEL (
  name lakehouse.gold.orders_daily,
  kind INCREMENTAL_BY_TIME_RANGE (time_column order_date),
  start '2026-06-01',
  cron '@daily',
  grains (order_id),
  partitioned_by (order_date),
  profiles (customer_id),
  assertions (
    unique_values(columns := order_id),
    not_null(columns := (order_id, order_date, customer_id))
  ),
  columns (
    order_id BIGINT,
    customer_id BIGINT,
    order_date TIMESTAMP(6)
  )
);
SELECT order_id, customer_id, order_date
FROM lakehouse.staging.orders
WHERE order_date >= @start_dt
  AND order_date <  @end_dt;
```

> **Use a half-open window (`>= start AND < end`), not `BETWEEN`.** `BETWEEN` is inclusive on both ends and overlaps adjacent incremental windows at the boundary, which can reprocess/duplicate rows. This is a general data-engineering best practice that applies to Trino too.

**Rule: deliberately pick the materialization depot.** FULL/INCREMENTAL output writes to the **first** depot in `spec.depots[]`. Make it a writable Iceberg lakehouse depot. Source-only systems (Postgres, Snowflake) should come later in the list.

**Rule: prefer `TIMESTAMP(6)` for Iceberg.** Trino supports `TIMESTAMP(p)` and Iceberg's expected precision varies by version/catalog configuration. `TIMESTAMP(6)` (microsecond) is the safe default that avoids precision mismatches — if your Iceberg catalog is configured differently, declare the precision the target table/catalog expects.

**Rule: per-catalog tuning via `overideCatalogConfig`.** To pass extra connector properties (e.g. `iceberg.max-partitions-per-writer`) into a generated catalog, add them under `spec.trino.overideCatalogConfig` keyed by depot/catalog name — they are appended to that catalog's `.properties`.

Canonical pages: [SQL models](../components/model/types/sql_models.md) · [Model kinds](../components/model/model_kinds.md)

#### 4.2.2: Semantic Models

Semantic models wrap Vulcan-managed tables and expose dimensions, measures, joins, and segments to API and SQL-wire consumers. The API track translates semantic queries into Trino SQL.

**Identifier casing.** Use **lowercase** identifiers — Trino lowercases unquoted names. This is the opposite of the Spark manual's UPPERCASE rule. Match the physical lowercase column names of your tables.

```yaml
kind: semantic
name: orders
depends_on: lakehouse.gold.orders_daily
description: Order facts from the gold layer.
dimensions:
  - order_id
  - customer_id
  - order_date
measures:
  - name: unique_orders
    type: count_distinct
    expression: "{orders.order_id}"
joins:
  - name: customers
    type: many_to_one
    expression: "{orders.customer_id} = {customers.customer_id}"
```

Declare explicit joins — Trino broadcasts/redistributes for joins, and an unconstrained cross-catalog join is the biggest avoidable latency risk on a federated cluster.

Canonical pages: [Semantic models](../components/model/types/models.md) · [Business metrics](../components/semantics/business_metrics.md)

#### 4.2.3: Metrics

A metric references a measure already defined in a semantic model and compiles to a Trino aggregation.

```yaml
kind: metric
name: daily_orders
measure: orders.unique_orders
ts: orders.order_date
granularity: day
dimensions:
  - name: region
    ref: customers.region
```

Trino-specific behaviour:

* **`COUNT(DISTINCT …)`** often requires distributed aggregation across workers and can become one of the most expensive operations on large, high-cardinality datasets (the exact strategy depends on the optimizer and query shape). Pre-aggregate into a mart, or use `approx_distinct` where exactness is not required — note that `approx_distinct` is approximate and introduces estimation error, so don't use it where an exact count matters.
* **Identifier casing in filters** follows the same lowercase rule as semantics. Quote (`"col"`) only when a name collides with a reserved word.

Canonical page: [Business metrics](../components/semantics/business_metrics.md)

### 4.3: Data Quality

Vulcan quality is layered on Trino. Live checks execute as Trino SQL against the catalogs.

| Layer                        | Where it runs                      | Trino cost                       | When it catches a problem      |
| ---------------------------- | ---------------------------------- | -------------------------------- | ------------------------------ |
| Linter                       | Locally, before execution          | None                             | Authoring time                 |
| Assertions (in `MODEL(...)`) | Trino during materialisation       | Counted in the model run         | Every run                      |
| Profiles (`profiles (...)`)  | Trino during the run               | One scan per profiled column     | Distribution/observability     |
| Unit tests (`tests/`)        | Locally (DuckDB in-process)        | No cluster cost                  | Pre-deploy logic regressions   |
| Audits (`AUDIT(...)`)        | Trino after materialisation        | One Trino query per audit        | Post-run relationship failures |
| Data quality (`kind: dq`)    | Trino SQL after run or on schedule | One or more Trino queries (Soda) | Drift, freshness, accuracy     |

**`kind: dq` example (Soda rules):**

```yaml
kind: dq
name: customers_dq
depends_on: lakehouse.gold.customers_full
rules:
  - row_count > 0:
      name: has_rows
      dimension: completeness
  - missing_count(customer_id) = 0:
      name: no_missing_customer_id
      dimension: completeness
  - duplicate_count(customer_id) = 0:
      name: unique_customer_id
      dimension: uniqueness
  - failed rows:
      name: positive_customer_id
      dimension: validity
      fail query: |
        SELECT customer_id, name
        FROM lakehouse.gold.customers_full
        WHERE customer_id <= 0
      samples limit: 5
```

**Standalone audit example** (note explicit `dialect trino` and double-quoted, fully qualified names):

```sql
AUDIT (
  name assert_orders_valid,
  dialect trino,
  standalone true
);
SELECT order_id, customer_id, order_date
FROM "abfsslhdepot"."azure_spark_dp_bronze"."orders"
WHERE order_id IS NULL OR order_id <= 0 OR customer_id IS NULL OR order_date IS NULL;
```

Trino-specific DQ notes:

* Use fully qualified `catalog.schema.table` names in all DQ/audit SQL, especially when reading across catalogs.
* Keep `failed rows` queries narrow and always set `samples limit` so incident payloads stay bounded.
* Profile only operationally useful columns — profiling high-cardinality columns on remote (Postgres/Snowflake) catalogs pushes load onto the source.

Canonical pages: [Tests](../components/tests.md) · [Audits](../components/assertions.md) · [Data quality](../guides/data_quality.md)

### 4.4: Lineage & version rollback

Lineage is computed from Vulcan's parsed model graph — Trino does not infer it from the catalogs. For cross-catalog references the linter may not resolve, declare them in `external_models.yaml`:

```yaml
- name: arabledepot.public.devices
  columns:
    device_id: BIGINT
    customer_id: BIGINT
    model: VARCHAR
```

Without the declaration, the linter throws `Table not found` and lineage stops at the model boundary.

Rollback replays the previous materialisation. For Iceberg-backed FULL/incremental tables this produces a new snapshot; for VIEWs, it re-points the definition.

### 4.5: Endpoints (REST, GraphQL, MySQL-wire)

The Trino stack serves API traffic through the API track plus two serving sidecars:

| Endpoint   | Runtime image / port                                     |
| ---------- | -------------------------------------------------------- |
| REST       | Vulcan API (`tmdcio/vulcan-trino:…`), port 8000 internal |
| GraphQL    | `tmdcio/vulcan-graphql:0.228.1.24-beta1`                 |
| MySQL-wire | `tmdcio/mysql-wire:0.0.9-beta1` (port 3306, TLS)         |

Endpoint queries read the semantic layer and push execution to Trino. Size the API track separately from the cluster, but expensive semantic queries still consume Trino compute. Keep API memory ≥ 2 GiB for large result sets; the MySQL-wire sidecar enforces a `VULCAN_API_QUERY_TIMEOUT` (default 300s).

Canonical pages: [REST](../guides/vulcan_api_guide.md) · [GraphQL](../guides/vulcan_api_guide.md) · [MySQL wire](../activation/mysql.md)

### 4.6: MCP tools

| MCP tool   | Trino behaviour                                      |
| ---------- | ---------------------------------------------------- |
| `about`    | Static — no engine call                              |
| `lineage`  | Parsed graph — no live query                         |
| `quality`  | Last check/audit results — typically no live call    |
| `data`     | Live Trino query — consumes cluster compute          |
| `run`      | Triggers the workflow — same cost as a scheduled run |
| `activity` | Reads workflow history from DataOS — no engine call  |

Treat agent-driven `data` queries like production dashboard queries — they hit the live cluster and can fan out across catalogs through the semantic layer.

Canonical pages: [Build-time MCP tools](../../../foundations/activation/ai-activation.md) · [Runtime MCP tools](../../../foundations/activation/ai-activation.md)

***

## Section 5: Metadata scanning & catalogue

DataOS scans the depots behind the Trino catalogs (not Trino itself) plus Vulcan's parsed model graph for lineage.

### 5.1: What shows up

| Object                             | Catalogue | Lineage                     |
| ---------------------------------- | --------- | --------------------------- |
| Catalogs (depots)                  | ✓         | —                           |
| Schemas / namespaces               | ✓         | —                           |
| Tables / views                     | ✓         | ✓ as nodes                  |
| Columns with types                 | ✓         | ✓ column-level              |
| Lineage edges (from parsed models) | —         | ✓ from Vulcan parse         |
| Cross-catalog federation edges     | —         | ✓ when sources are declared |

Lineage is primarily Vulcan-computed — DataOS parses the model SQL graph and `external_models.yaml`. Catalog/depot scans contribute schema and column metadata.

### 5.2: Scanner permissions

The scanner reads each depot's source metadata, read-only and separate from the Vulcan service role.

```
Iceberg/Lakehouse:  read on the REST catalog + object storage metadata
Postgres/Snowflake:   read on information_schema / catalog views
```

Grant the scanner principal `purpose: scan` on each source depot.

### 5.3: Refresh & lag

Scanner runs every 6–12 hours (configurable). New tables/columns appear after the next scan. Lineage from model runs is computed from Vulcan's SQL parse and is available immediately after a successful `vulcan run`.

***

## Section 6: Engine-native feature support

What Trino objects can you drive from a Vulcan Data Product, and where each capability belongs.

| Trino feature                            | Vulcan pattern                                       | Notes                                                                        |
| ---------------------------------------- | ---------------------------------------------------- | ---------------------------------------------------------------------------- |
| Trino runtime                            | Tenant-level `vulcan-trino` stack                    | Configured once per tenant by SRE                                            |
| Coordinator                              | `<name>-trino` service (`replicas: 1`)               | Plans queries; sized via `spec.trino.coordinator.resource`                   |
| Workers                                  | `<name>-trino-workers` service                       | `spec.trino.workers.replicas` (default 2); execute splits                    |
| Iceberg catalog (lakehouse) ✅            | lakehouse depot in `spec.depots[]`                   | Validated. `connector.name=iceberg` (REST, OAUTH2); ABFSS/S3                 |
| Postgres catalog ✅                       | Postgres depot                                       | Validated. `connector.name=postgresql`                                       |
| Snowflake catalog ✅                      | Snowflake depot                                      | Validated. `connector.name=snowflake`; user/pwd or key-pair                  |
| BigQuery catalog ⬜                       | BigQuery depot/secret                                | Template only — not validated; `connector.name=bigquery`, needs GCP JSON key |
| Databricks / Delta catalog ⬜             | depot                                                | Template only — not validated                                                |
| Secret-backed catalog                    | `spec.trino.catalog.config: ["tenant:secret"]`       | Secret's key/values become the catalog `.properties`                         |
| Per-catalog property override            | `spec.trino.overideCatalogConfig`                    | Appended to the generated `.properties`                                      |
| Custom plugin / connector / UDF JAR      | `dependencies/java/<plugin>/`                        | Subdir copied to `/usr/lib/trino/plugin/`                                    |
| Built-in SQL functions / UDFs            | Trino functions in model SQL                         | `date_trunc`, `regexp_like`, `coalesce`, `approx_distinct`, …                |
| Per-role JVM / config / log / node props | `spec.trino.{coordinator,workers}.trinoServerConfig` | Full-file override; identity lines auto-injected                             |
| Cluster autoscaling                      | Boundary                                             | Accepted but not rendered; use fixed replicas                                |
| Python execution                         | Boundary                                             | Not supported on Trino                                                       |
| Fault-tolerant execution                 | Boundary                                             | Needs exchange manager (not configured)                                      |

**Plugin layout** (coordinator + workers, copied at startup):

```
dependencies/java/
  udfs/                 # Java UDF plugin → loaded as a plugin folder
  plugin/<connector>/   # custom connector plugin
```

> A loose JAR placed directly at `dependencies/java/foo.jar` will **not** load — it must live in a subdirectory, which becomes the plugin folder name. Confirm the subdirectory → plugin mapping with the platform team.

***

## Section 7: Operational boundaries

Concrete settings with hard thresholds. Treat this as an engineering contract; tune from the Trino UI and DataOS telemetry.

### 7.1: Compute sizing & the JVM heap rule

> **The #1 deployment failure: if the JVM heap is left unmanaged it can exceed the pod memory limit, so workers OOM/never register and the cluster forms with 0 workers.** Always set `-Xmx` in `trinoServerConfig.jvmConfig` to fit the pod limit, with headroom. (Heap sizing depends on container awareness, JVM version, and memory limits — set it explicitly rather than relying on the default.)

The working JVM config is the stack default plus an explicit `-Xmx` — see section 4.1.1 for the full block. `4G` is the validated value for the reference deployment's `4Gi` pod limit; size yours to your own limit. The `-Xmx` line is the key memory tuning property and the cluster runs reliably with it.

> **The default property set runs the cluster without memory-cap properties (`query.max-memory`, `query.max-total-memory`, `query.max-memory-per-node`, `memory.heap-headroom-per-node`).** An incorrect cap relative to the heap OOM-kills queries (O10), so the defaults deliberately leave them out. Run on defaults; add caps only when a specific workload calls for them.

**Sizing that works (the reference deploy).** This configuration runs the full multi-depot demo — VIEW staging, FULL + INCREMENTAL models, semantics, metrics, and DQ — across three depot catalogs:

| Setting                       | Value                       |
| ----------------------------- | --------------------------- |
| `spec.trino.workers.replicas` | `1`                         |
| Coordinator / worker request  | `cpu: 1000m`, `memory: 2Gi` |
| Coordinator / worker limit    | `cpu: 2000m`, `memory: 4Gi` |
| `-Xmx`                        | `4G`                        |

> Set the pod `resource.limit.memory` **above** `-Xmx` (the reference uses `4Gi` limit for `-Xmx4G`). Coordinator/worker resources fall back to `spec.workflow.resource` if not set per role. Add workers (not coordinators) for more query parallelism.

### 7.2: Concurrency

| Recommendation                                      | Why                                                                                                         |
| --------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `concurrencyPolicy: Forbid`                         | Prevent overlapping runs writing to the same Iceberg target                                                 |
| Add workers, not coordinators, for query throughput | Coordinator stays at 1; workers execute splits                                                              |
| Constrain federated joins                           | Cross-catalog joins move data over the network                                                              |
| Keep `retry-policy=NONE`                            | Fault-tolerant execution is available in Trino but needs an exchange manager not enabled in this deployment |

### 7.3: API replicas & Kubernetes resources

The reference deploy runs a single API replica, which serves the REST, GraphQL, and MySQL-wire endpoints for the demo. Scale replicas up for higher request concurrency.

```yaml
# reference deploy
api:
  replicas: 1
  resource:
    request: { cpu: "1000m", memory: "2Gi" }
    limit:   { cpu: "2000m", memory: "4Gi" }
```

Add API replicas to improve request concurrency; add Trino workers to improve query execution. Different bottlenecks.

### 7.4: Scheduling

| Recommendation                       | Why                                  |
| ------------------------------------ | ------------------------------------ |
| Schedule after upstream sources land | Avoid partial reads and restatements |
| `timezone: UTC`                      | Avoid DST-shifted intervals          |
| `concurrencyPolicy: Forbid`          | Prevent overlapping writers          |
| Set `endOn` ≥ 1–2 years out          | Expired schedules stop silently      |

The reference deploy uses `crons: ["0 */6 * * *"]` (every 6 hours).

### 7.5 Latency floor

| Component                 | Floor                                                                      |
| ------------------------- | -------------------------------------------------------------------------- |
| Cluster cold start        | Coordinator + worker registration before the first query                   |
| Trino-ready gate (Vulcan) | plan/run waits for `SELECT 1` + the configured worker count to be active   |
| Source round trips        | Remote catalogs (Postgres/Snowflake/BigQuery) add network + source latency |
| Federated exchange        | Cross-catalog joins shuffle data between workers                           |
| API query overhead        | Parsing, planning, result serialisation                                    |

If your downstream SLO is sub-second on a cold cluster, keep the cluster warm and pre-aggregate hot marts.

### 7.6: Operational limitations

| #  | Limitation                                                           | Workaround                                                                                                       |
| -- | -------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| O1 | Unmanaged JVM heap can exceed the pod memory limit → 0 workers / OOM | Explicitly set `-Xmx` to fit the pod limit in `trinoServerConfig.jvmConfig` (`4G` for the reference `4Gi` limit) |
| O2 | Overriding `configProperties` replaces the default block             | Re-supply role lines; don't duplicate the auto-injected discovery/shared-secret                                  |
| O3 | `node.environment` mismatch between coordinator and workers          | Keep identical across roles; use simple lowercase names (the stack normalises them at startup)                   |
| O4 | `node.id` set on workers duplicates across replicas                  | Don't set `node.id` on workers; it auto-generates per pod                                                        |
| O5 | Loose JAR at `dependencies/java/` root not loaded                    | Place plugins in a subdirectory (`dependencies/java/<plugin>/`)                                                  |
| O6 | Bare `TIMESTAMP` precision can mismatch Iceberg                      | Declare the precision the catalog expects (`TIMESTAMP(6)` preferred)                                             |
| O7 | Materialized tables land on the wrong catalog                        | First depot in `spec.depots[]` is the default/materialization catalog — order deliberately                       |
| O8 | Snowflake/BigQuery/Databricks catalog won't mount                    | Ensure credentials are on the depot/secret; check `SHOW CATALOGS`                                                |
| O9 | Memory-cap properties are not in the validated default set           | Run with defaults; if you add `query.max-memory*`, keep them below heap or queries OOM-kill                      |

***

## Section 8: Performance & Cost

How fast this engine runs and what it costs. Use section 8.1 to size, compute, and tune; use section 8.2 to put cost guardrails in place.

### 8.1: Performance & tuning

Trino performance is driven by federation width, source latency, exchange size, and worker heap. The signals below tell you exactly what to watch and how to tune, and the loop in section 8.1.2 converges on the right shape for a given workload.

#### 8.1.1: What to measure

| Metric                   | Why it matters                             |
| ------------------------ | ------------------------------------------ |
| Cluster formation time   | Captures coordinator + worker registration |
| Per-source scan time     | Detects slow remote catalogs               |
| Exchange (shuffle) bytes | Main predictor of federated-join runtime   |
| Spilled bytes            | Memory/partitioning pressure               |
| Peak query memory        | Drives `query.max-memory` sizing           |
| Worker GC pause          | Detects undersized heap                    |

#### 8.1.2: Validation loop

1. Start from the reference deploy sizing (section 7.1)
2. Run a representative `vulcan plan` + `vulcan run`
3. Inspect the Trino UI for spill, exchange size, peak memory, stragglers
4. Apply one tuning change (heap, `query.max-memory`, worker count, or join shape)
5. Re-run and compare
6. Record the stable coordinator/worker/`configProperties` combination as the baseline

#### 8.1.3: Concurrency fix order

1. Prevent overlapping writers (`concurrencyPolicy: Forbid`)
2. Constrain federated join shapes (declare joins, push filters down)
3. Add workers
4. Raise the JVM heap (`-Xmx`) and pod limit together; only introduce memory-cap properties after testing (section 7.1)

#### 8.1.4: Performance ceilings

| #  | Ceiling                                      | Tune via                                                                                                                       |
| -- | -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| P1 | Wide federated joins shuffle large exchanges | Reduce join width; pre-aggregate; push predicates to sources                                                                   |
| P2 | Remote source is the bottleneck              | Cache/stage into the lakehouse; read the materialized copy                                                                     |
| P3 | High-cardinality `COUNT(DISTINCT)`           | Pre-aggregate, or use `approx_distinct` where an exact count isn't required (it's approximate and introduces estimation error) |
| P4 | Worker OOM on big queries                    | Raise the JVM heap (`-Xmx`) and pod limit; reduce query/join width                                                             |
| P5 | Cold-cluster latency                         | Keep the cluster warm; pre-warm before scheduled peaks                                                                         |

### 8.2: Cost guardrails

Trino cost comes from cluster lifetime (coordinator + workers running), source query load, and API concurrency.

#### 8.2.1: Right-size the cluster

Set `spec.trino.workers.replicas` to the real concurrency need. Idle workers cost compute; don't over-provision.

#### 8.2.2: Query-level controls (timeouts)

Trino supports query timeouts (`query.max-run-time`, `query.max-execution-time`, `query.client.timeout`) via `configProperties`. These are **not** in the validated default set documented in section 4.1 — setting any `configProperties` block replaces the working default (section 4.1.2), so introduce timeouts only after testing an explicit baseline on your cluster. The validated guardrail today is the API-side `VULCAN_API_QUERY_TIMEOUT` (default 300s, section 4.5).

#### 8.2.3: Prevent overlapping runs

Use `concurrencyPolicy: Forbid` for all scheduled workflows.

#### 8.2.4: Storage & source cost

* Materialize hot, repeatedly joined data into the lakehouse instead of re-federating every query.
* Keep `iceberg.max-partitions-per-writer` sane (e.g., 100) via `overideCatalogConfig` to avoid small-file explosions.
* Push filters/predicates to remote sources so Trino reads less.

Canonical pages: [Chargeback](/broken/pages/Z5g4QbLYpPYTGamo2o0l) · [Track cost by Data Product](/broken/pages/Z5g4QbLYpPYTGamo2o0l) · [Track cost by tenant](/broken/pages/Z5g4QbLYpPYTGamo2o0l)

***

## Section 9: Failure modes & troubleshooting

Top errors when running a Data Product on Trino, with cause and fix.

| #   | Symptom                                                                    | Likely cause                                                                         | Fix                                                                                                                                                                  |
| --- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| F1  | Cluster forms with **0 workers** / workers OOM at startup                  | Unmanaged JVM heap exceeds pod limit                                                 | Set `-Xmx` to fit the pod limit in `trinoServerConfig.jvmConfig` for both roles (`4G` for the reference `4Gi` limit)                                                 |
| F2  | Workers never register / cluster won't form                                | `node.environment` mismatch or `coordinator=true` on workers                         | Make `node.environment` identical; `coordinator=false` on workers                                                                                                    |
| F3  | Duplicate node errors across worker pods                                   | `node.id` set in worker `nodeProperties`                                             | Remove `node.id` from workers — it auto-generates per pod                                                                                                            |
| F4  | `Table not found` for a source                                             | Cross-catalog source not declared / wrong catalog name                               | Add to `external_models.yaml`; use `catalog.schema.table`                                                                                                            |
| F5  | `vulcan plan` works locally, fails in DataOS                               | Depot missing/misnamed in `spec.depots[]`, or wrong default catalog                  | Verify with `SHOW CATALOGS`; first depot = default catalog                                                                                                           |
| F6  | Iceberg timestamp precision mismatch                                       | `TIMESTAMP` precision differs from what the catalog expects                          | Declare the precision the catalog expects (`TIMESTAMP(6)` preferred) for Iceberg columns                                                                             |
| F7  | Catalog present but queries fail (or catalog missing from `SHOW CATALOGS`) | Missing creds, or permission/schema/warehouse issues that surface only on access     | Validate beyond `SHOW CATALOGS`: `SHOW SCHEMAS FROM <catalog>;` then `SELECT 1 FROM <catalog>.<schema>.<table> LIMIT 1;`. Add creds to the depot/secret and re-apply |
| F8  | Custom plugin/UDF not loaded                                               | JAR at `dependencies/java/` root, not in a subdir                                    | Move JAR into `dependencies/java/<plugin>/`                                                                                                                          |
| F9  | Query OOM-killed                                                           | JVM heap too small for the query (or, if you added them, memory caps set above heap) | Raise `-Xmx` and pod limit; if you set memory caps, keep them below heap                                                                                             |
| F10 | `configProperties` override breaks the cluster                             | Duplicated discovery/shared-secret or missing role lines                             | Don't duplicate injected lines; include role lines                                                                                                                   |
| F11 | Production `vulcan migrate` fails                                          | Missing/wrong `vulcan-state-connection` (Postgres)                                   | Fix the tenant state secret; ensure Postgres reachable                                                                                                               |
| F12 | plan/run pod hangs at startup                                              | Vulcan trino-ready gate waiting for the configured worker count                      | Check worker pods are `active` (see F1/F2); verify `TRINO_EXPECTED_WORKERS`                                                                                          |
| F13 | Time-range incremental reprocesses everything                              | Missing/wrong `time_column` or no `@start_dt/@end_dt` filter                         | Set `time_column` and filter the source by interval macros                                                                                                           |
| F14 | Deploy manifest parsed as a model                                          | `*-deploy.yaml` not ignored                                                          | Add it to `ignore_patterns` in `config.yaml`                                                                                                                         |

### 9.1: Logs and where to look

| Symptom                       | Where                   | How                                                                                                 |
| ----------------------------- | ----------------------- | --------------------------------------------------------------------------------------------------- |
| Local cluster startup         | Docker compose services | `docker compose -f trino/cluster/docker-compose.yml logs <svc>`                                     |
| Coordinator/cluster health    | Coordinator service     | `ds resource -t service -n <name>-trino logs -l 100`                                                |
| Worker health / OOM           | Workers service         | `ds resource -t service -n <name>-trino-workers logs -l 100`                                        |
| Rendered Trino config (proof) | Inside the pods         | `ds resource -t service -n <name>-trino exec -- cat /usr/trino/etc/config.properties`               |
| Plan/run failures             | Workflow pods           | `ds resource -t vulcan-trino -n <name> logs -l 500`                                                 |
| SQL smoke                     | Coordinator             | `ds resource -t service -n <name>-trino exec -- trino --execute "SELECT 1"`                         |
| Cluster membership            | Coordinator             | `trino --catalog system --schema runtime --execute "SELECT node_id, coordinator, state FROM nodes"` |

### 9.2 Recovery procedures

| Situation                               | Procedure                                                                |
| --------------------------------------- | ------------------------------------------------------------------------ |
| Cluster formed with 0 workers           | Set `-Xmx`, re-apply, confirm workers `active` in `system.runtime.nodes` |
| Time-range run failed mid-window        | Re-run the affected window; partition overwrite is safe to replay        |
| Source temporarily unavailable          | Re-run after the source recovers; declare retries at the workflow level  |
| Catalog credentials rotated             | Update depot/secret, re-apply (regenerates `.properties`)                |
| Workflow halted because `endOn` expired | Update `endOn` and re-apply                                              |
| Bad data materialized to Iceberg        | Use Iceberg snapshot rollback (coordinate with platform SRE)             |

***

## Section 10: Deployment recipes

### 10.1: Daily federated DP, small project (managed Trino)

```yaml
version: v1alpha
type: vulcan-trino
name: managed-trino-dp
owner: <owner>
spec:
  runAsUser: "<owner>"
  compute: <trino-compute-pool>
  engine: trino
  repo:
    url: https://bitbucket.org/rubik_/vulcan-examples
    syncFlags: ["--ref=main", "--submodules=off"]
    baseDir: vulcan-examples/trino/managed-trino
    secret: engineering:git-sync-rr
  depots:
    - dataos://lakehousedepot?purpose=rw   # default catalog (materialization)
    - dataos://postgresdepot?purpose=rw    # source
  trino:
    coordinator:
      trinoServerConfig:
        jvmConfig: |
          -server
          -Xmx4G
          -XX:+UseG1GC
          -XX:G1HeapRegionSize=32M
        logProperties: |
          io.trino=INFO
    workers:
      replicas: 1
      trinoServerConfig:
        jvmConfig: |
          -server
          -Xmx4G
          -XX:+UseG1GC
        logProperties: |
          io.trino=INFO
  workflow:
    schedule:
      crons: ["0 */6 * * *"]
      endOn: "2028-01-01T00:00:00-00:00"
      timezone: "UTC"
      concurrencyPolicy: Forbid
    resource:
      request: { cpu: "1000m", memory: "2Gi" }
      limit:   { cpu: "2000m", memory: "4Gi" }
    plan:
      command: [vulcan]
      arguments: ["--log-to-stdout", "plan", "--auto-apply"]
    run:
      command: [vulcan]
      arguments: ["--log-to-stdout", "run"]
  api:
    replicas: 2
    resource:
      request: { cpu: "1000m", memory: "2Gi" }
      limit:   { cpu: "2000m", memory: "4Gi" }
```

### 10.2: Multi-depot federation with per-catalog override (validated reference deploy)

This mirrors the validated reference deploy: three depot catalogs, a per-catalog Iceberg override, default `config.properties` (no `configProperties` block), and the only validated server change — `-Xmx4G` in `jvmConfig`.

```yaml
spec:
  engine: trino
  depots:
    - dataos://abfsslhdepot?purpose=rw     # Iceberg (default catalog)
    - dataos://arabledepot?purpose=rw      # Postgres
    - dataos://snowflakevulcan?purpose=rw  # Snowflake
  trino:
    overideCatalogConfig:
      - name: abfsslhdepot
        properties:
          iceberg.max-partitions-per-writer: 100
    coordinator:
      trinoServerConfig:
        # config.properties left to the stack default (validated working path)
        jvmConfig: |
          -server
          -Xmx4G
          -XX:+UseG1GC
          -XX:G1HeapRegionSize=32M
          -XX:+UseGCOverheadLimit
          -XX:+ExplicitGCInvokesConcurrent
          -XX:+HeapDumpOnOutOfMemoryError
        logProperties: |
          io.trino=INFO
    workers:
      replicas: 1
      trinoServerConfig:
        jvmConfig: |
          -server
          -Xmx4G
          -XX:+UseG1GC
          -XX:G1HeapRegionSize=32M
          -XX:+UseGCOverheadLimit
          -XX:+ExplicitGCInvokesConcurrent
          -XX:+HeapDumpOnOutOfMemoryError
        logProperties: |
          io.trino=INFO
```

### 10.3: External / Minerva Trino (connect to an existing cluster)

No `spec.trino` block — connect over the existing cluster's endpoint via a secret.

`config.yaml`:

```yaml
gateways:
  default:
    connection:
      type: trino
      host: "{{ env_var('TRINO_HOST') }}"
      user: "{{ env_var('TRINO_USER') }}"
      catalog: "{{ env_var('TRINO_CATALOG') }}"
      port: "{{ env_var('TRINO_PORT') }}"
      http_scheme: "{{ env_var('TRINO_HTTP_SCHEME', 'https') }}"
      method: "{{ env_var('TRINO_METHOD', 'basic') }}"
      password: "{{ env_var('TRINO_PASSWORD') }}"
      verify: true
model_defaults:
  dialect: trino
  start: 2026-06-03
  cron: '@daily'
ignore_patterns:
  - "*-deploy.yaml"
```

Resource (`type: vulcan`) projects the connection from a secret:

```yaml
version: v1alpha
type: vulcan
name: trino-minerva
spec:
  runAsUser: "<owner>"
  compute: <trino-compute-pool>
  engine: trino
  repo:
    url: https://bitbucket.org/rubik_/vulcan-examples
    syncFlags: ["--ref=main", "--submodules=off"]
    baseDir: vulcan-examples/trino/trino-mierva
    secret: engineering:git-sync-rr
  use:
    projection:
      secrets:
        - id: engineering:trino-minerva-sec
          contextAlias: tmsh
      projections:
        envVars:
          - { key: TRINO_HOST,        template: "{{ secrets['tmsh'].TRINO_HOST | base64_decode }}" }
          - { key: TRINO_PORT,        template: "{{ secrets['tmsh'].TRINO_PORT | base64_decode }}" }
          - { key: TRINO_USER,        template: "{{ secrets['tmsh'].TRINO_USER | base64_decode }}" }
          - { key: TRINO_CATALOG,     template: "{{ secrets['tmsh'].TRINO_CATALOG | base64_decode }}" }
          - { key: TRINO_HTTP_SCHEME, template: "{{ secrets['tmsh'].TRINO_HTTP_SCHEME | base64_decode }}" }
          - { key: TRINO_METHOD,      template: "{{ secrets['tmsh'].TRINO_METHOD | base64_decode }}" }
          - { key: TRINO_PASSWORD,    template: "{{ secrets['tmsh'].TRINO_PASSWORD | base64_decode }}" }
  workflow:
    schedule:
      crons: ["0 */6 * * *"]
      endOn: "2027-01-01T00:00:00-00:00"
      timezone: "UTC"
      concurrencyPolicy: Forbid
    plan:   { command: [vulcan], arguments: ["plan", "-vv", "--auto-apply"] }
    run:    { command: [vulcan], arguments: ["run"] }
  api:
    replicas: 1
    resource:
      request: { cpu: "250m", memory: "512Mi" }
      limit:   { cpu: "1000m", memory: "2Gi" }
```

### 10.4: Secret-backed (non-depot) catalog

Mount a catalog whose `.properties` come straight from a DataOS secret (key/values become the file):

```yaml
spec:
  engine: trino
  depots:
    - dataos://lakehousedepot?purpose=rw
  trino:
    catalog:
      config:
        - "engineering:my-trino-catalog-secret"   # secret key/values → catalog .properties
```

***
