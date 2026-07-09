---
description: >-
  A Postgres engine manual for DataOS Vulcan setup, development, deployment,
  operations, performance, and troubleshooting.
---

# Postgres Engine

| Item                      | Details                             |
| ------------------------- | ----------------------------------- |
| **Template version**      | 1.0                                 |
| **Engine**                | PostgreSQL                          |
| **Tested Vulcan image**   | `tmdcio/vulcan-postgres:0.228.1.23` |
| **Tested DataOS release** | Draco 1.38 series                   |
| **Last updated**          | June 2026                           |

***

## How to use this manual

Use this manual as the working reference for shipping a Data Product on PostgreSQL using DataOS. It assumes you already know the basics of Data Products and Vulcan. The structure stays consistent across engine manuals — only the PostgreSQL-specific content changes.

Use the path below that matches your role.

**If you are a data engineer setting up Vulcan on PostgreSQL for the first time:** section 2: Prerequisites (including pre-flight checklist) → section 3: LDK setup → section 10: Deployment recipes → section 7: Operational boundaries

**If you are a DP developer building or debugging a Data Product on PostgreSQL:** section 1: Snapshot → section 4: Vulcan on PostgreSQL → section 9: Failure modes & troubleshooting

This manual is link-heavy by design. Every concept with an existing canonical page is summarized in one or two lines and linked. Section 11 is the full outbound link map.

***

## Section 1: Snapshot

This section is the fast path. If you only need the essentials, start here. It gives you the supported versions, key limits, runtime expectations, and the defaults you can rely on.

### **Architecture**

<figure><img src="../../../.gitbook/assets/image.png" alt=""><figcaption></figcaption></figure>

### **Version compatibility matrix**

| Vulcan image                        | DataOS release | PostgreSQL target | Status            |
| ----------------------------------- | -------------- | ----------------- | ----------------- |
| `tmdcio/vulcan-postgres:0.228.1.23` | Draco 1.38.x   | PostgreSQL 14-16  | ✅ Tested          |
| Earlier `0.228.1.x` builds          | Draco 1.37.x   | PostgreSQL 14-16  | ⬜ Add when tested |
| `0.228.0.x`                         | Draco 1.36.x   | PostgreSQL 13-15  | ⬜ Add when tested |

| Item                   | Value                                                                                                                                                                                                      |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Engine adapter type    | `postgres`                                                                                                                                                                                                 |
| Model dialect          | `postgres`                                                                                                                                                                                                 |
| Support level          | GA                                                                                                                                                                                                         |
| Tested Vulcan image    | `tmdcio/vulcan-postgres:0.228.1.23`                                                                                                                                                                        |
| Tested DataOS release  | Draco 1.38 series                                                                                                                                                                                          |
| Execution vehicle      | PostgreSQL server; queries execute in-database                                                                                                                                                             |
| Namespace              | `database.schema.table`; `connection.database` must already exist                                                                                                                                          |
| Auth (local / CI)      | Username + password; add `sslmode` when required                                                                                                                                                           |
| Auth (DataOS)          | Instance secret with password → PostgreSQL depot, or bound secret read through `env_var()`                                                                                                                 |
| SQL model kinds        | SEED, FULL, VIEW, INCREMENTAL\_BY\_TIME\_RANGE, INCREMENTAL\_BY\_UNIQUE\_KEY, INCREMENTAL\_BY\_PARTITION, INCREMENTAL\_UNMANAGED, SCD\_TYPE\_2, SCD\_TYPE\_2\_BY\_TIME, SCD\_TYPE\_2\_BY\_COLUMN, EMBEDDED |
| Python model support   | In-process Pandas DataFrame models; Python models do not support VIEW, EMBEDDED, SEED, or MANAGED kinds                                                                                                    |
| Quality file format    | Current: `kind: dq` YAML with `profiles:` and `rules:`; older Postgres examples also show `checks:` map files                                                                                              |
| Semantic model format  | `kind: semantic` YAML with dimensions, measures, segments, joins, and optional `ai_context`                                                                                                                |
| Business metric format | Current: `kind: metric`, `name`, `measure`, `ts`, `granularity`; older Postgres examples also show a `metrics:` map with `time:`                                                                           |
| Python runtime         | In-process Python; Pandas DataFrames are written through the PostgreSQL adapter                                                                                                                            |
| Python version         | 3.10 (local dev); runtime managed by image                                                                                                                                                                 |
| Production deploy unit | DataOS Vulcan resource (`engine: postgres`) + depot / bound secret                                                                                                                                         |
| Local connection       | Single PostgreSQL gateway connection for the starter project                                                                                                                                               |
| Identifier casing rule | Lowercase; PostgreSQL folds unquoted identifiers to lowercase                                                                                                                                              |

**SLOs you can commit to** (validate on your instance size and data volume before publishing externally):

| SLO                                                                             | Target                                                                                                                          |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Daily incremental run success rate (instance healthy, grants correct)           | ≥ 99%                                                                                                                           |
| `vulcan plan` / `vulcan apply` success after database and credential validation | ≥ 99%                                                                                                                           |
| Semantic API availability                                                       | Same as deployed Vulcan API track                                                                                               |
| First query latency                                                             | Typically no warehouse-style cold start on provisioned instances; serverless or auto-paused deployments can add wake-up latency |

PostgreSQL latency is shaped by instance size, IOPS, indexes, and data volume. There is no warehouse cold-start penalty, but there is also no elastic scale-out. Validate representative data before publishing external SLOs.

***

## Section 2: Prerequisites

What must be in place before you write a single line of Vulcan code: PostgreSQL-side permissions, DataOS access, and your local Python version.

### 2.1: PostgreSQL permissions

Three roles are required, and each has a distinct scope. Do not collapse them into one.

| Role                    | Who holds it                           | Purpose                                                                            |
| ----------------------- | -------------------------------------- | ---------------------------------------------------------------------------------- |
| **Admin role**          | PostgreSQL superuser / DBA             | Creates databases, installs extensions, grants privileges                          |
| **Vulcan service role** | The role whose credentials Vulcan uses | Runs models, creates/modifies schemas and tables in the target database            |
| **Consumer role**       | BI users, endpoint consumers           | Read-only access to Data Product tables via Vulcan endpoints or issued credentials |

**Minimum grants** (run as a superuser or database owner with `psql`):

```sql
-- Target database. Vulcan materialises here; the database must already exist.
GRANT CONNECT ON DATABASE warehouse TO vulcan;
GRANT CREATE ON DATABASE warehouse TO vulcan;

-- Source data landed by Nilus, seeds, or another ingestion path.
GRANT USAGE ON SCHEMA raw TO vulcan;
GRANT SELECT ON ALL TABLES IN SCHEMA raw TO vulcan;
ALTER DEFAULT PRIVILEGES IN SCHEMA raw GRANT SELECT ON TABLES TO vulcan;

-- Optional federation showcase; DBA privilege and managed-service allow-listing may be required.
-- CREATE EXTENSION IF NOT EXISTS postgres_fdw;
```

**Consumer role — read-only grants:**

```sql
GRANT CONNECT ON DATABASE warehouse TO consumer;
GRANT USAGE ON SCHEMA sales TO consumer;
GRANT SELECT ON ALL TABLES IN SCHEMA sales TO consumer;
ALTER DEFAULT PRIVILEGES IN SCHEMA sales GRANT SELECT ON TABLES TO consumer;
```

**Verify grants** (run in `psql`):

```sql
SELECT current_user, current_database();
\dn
\dp raw.*
```

For the full permissions reference, see [connect-to-engine/postgres](postgres-engine.md).

### 2.2: DataOS permissions

The following access must be provisioned by your DataOS operator before you can deploy or run a Vulcan Data Product.

| Permission                        | What it unlocks                                               | Who to request from                 |
| --------------------------------- | ------------------------------------------------------------- | ----------------------------------- |
| `roles:id:data-dev` or equivalent | Create and apply Vulcan resources (workflow, API)             | DataOS operator / admin             |
| Access to the target workspace    | Apply secrets, depots, and domain resources in that workspace | DataOS operator                     |
| `depot:rw:<postgres-depot-name>`  | Read/write access to the PostgreSQL depot                     | DataOS operator                     |
| `depot:r:<postgres-depot-name>`   | Read-only access (consumer)                                   | DataOS operator                     |
| Git repository access             | Vulcan pulls model code via git-sync                          | Your VCS admin (GitHub / Bitbucket) |

> **Check your access** before starting. Run `dataos-ctl get depot` — if the PostgreSQL depot appears in the output, your read access is confirmed. If it is missing, request `depot:r` from your operator.

### 2.3: Python version

| Requirement                      | Version          |
| -------------------------------- | ---------------- |
| Python (local development)       | **3.10**         |
| Python (runtime in Vulcan image) | Managed by image |

Python 3.10 is required for local development and CLI tooling. Python 3.13+ is not supported.

```bash
python --version   # must be 3.10.x
```

### 2.4: Pre-flight checklist

#### Setup engineer checklist

**PostgreSQL side**

* [ ] Host/port reachable from the DataOS data plane and developer laptops
* [ ] Target database exists; Vulcan creates schemas inside it, not the database itself
* [ ] Vulcan service role has `CONNECT` + `CREATE` on the target database
* [ ] Source schemas/tables granted with `USAGE` + `SELECT`; default privileges set for future tables
* [ ] Optional extensions reviewed with the DBA if the project uses federation or other native PostgreSQL features
* [ ] Password rotation and `sslmode` policy set
* [ ] `max_connections` sized for Vulcan workers, API replicas, and BI sessions

**Local development**

* [ ] Universal prereqs complete (Python, Docker if using local PostgreSQL, CLI, repo access)
* [ ] Vulcan wheel installed for the PostgreSQL image version
* [ ] `.env` has `WAREHOUSE_`\*
* [ ] PostgreSQL container or instance reachable
* [ ] `external_models.yaml` lists source tables Vulcan does not own
* [ ] `vulcan plan` succeeds

**DataOS production**

* [ ] Instance secret applied (`<workspace>:<name>`) holding the PostgreSQL password
* [ ] Depot applied; name matches `dataos://<name>?purpose=rw` where used
* [ ] Depot `secrets[].id` references the PostgreSQL instance secret
* [ ] Git secret applied (`GITSYNC_USERNAME`, `GITSYNC_PASSWORD`)
* [ ] `config.yaml` uses either a depot gateway or bound env vars, not conflicting sources
* [ ] Vulcan resource: `engine: postgres`, `compute`, `repo`, `depots` or `envFrom`, workflow, and `api.replicas` are set
* [ ] Cron `timezone: UTC`; `endOn` ≥ 1–2 years out; `concurrencyPolicy: Forbid`

#### Before you ship checklist (DP developer)

* [ ] All SQL, semantic, metric, and DQ identifiers are lowercase unless intentionally quoted
* [ ] Lifecycle DDL guarded with `@IF(@runtime_stage = 'evaluating', ...)`
* [ ] Raw PL/pgSQL blocks are expected to emit harmless parser warnings (subsection 4.2.1)
* [ ] Source tables Vulcan does not own are declared in `external_models.yaml`
* [ ] Joins declared for all multi-entity semantic queries
* [ ] Composite-key grains declared correctly
* [ ] Audits and DQ checks reviewed (subsection 4.3)
* [ ] `endOn` set and reviewed in the Vulcan resource schedule

***

## Section 3: Local Development Kit (LDK)

Step-by-step setup for running Vulcan locally against PostgreSQL. Complete section 2 before starting here.

### 3.1: Install Vulcan

Vulcan is distributed as a Python wheel (`.whl`) and installed directly via `pip`.

```bash
python -m venv .venv
source .venv/bin/activate
pip install vulcan_postgres-<version>-py3-none-any.whl
```

Get the latest `.whl` for the PostgreSQL engine from your DataOS distribution channel. Replace `<version>` with the version listed in section 1: Snapshot.

```bash
vulcan --version   # verify after install
```

The reference PostgreSQL project needs a reachable PostgreSQL instance. For local development, one Docker PostgreSQL container and one database are enough to validate the connection and run the starter project.

### 3.2: Set up authentication

PostgreSQL uses a username and password. Store the password in `.env`; never commit it.

```bash
WAREHOUSE_HOST=localhost
WAREHOUSE_PORT=5432
WAREHOUSE_DATABASE=warehouse
WAREHOUSE_USER=vulcan
WAREHOUSE_PASSWORD=<your-password>
```

The role must have the grants in subsection 2.1. For TLS, add `sslmode: require` or stricter to the connection block.

### 3.3: Configure config.yaml

Minimum PostgreSQL connection config:

```yaml
gateways:
  default:
    connection:
      type: postgres
      host: "{{ env_var('WAREHOUSE_HOST', 'localhost') }}"
      port: "{{ env_var('WAREHOUSE_PORT', '5432') }}"
      database: "{{ env_var('WAREHOUSE_DATABASE', 'warehouse') }}"
      user: "{{ env_var('WAREHOUSE_USER', 'vulcan') }}"
      password: "{{ env_var('WAREHOUSE_PASSWORD', 'vulcan') }}"

default_gateway: default
model_defaults:
  dialect: postgres
  start: '2024-01-01'
```

For a local starter project, Vulcan can use the default PostgreSQL gateway connection.

### 3.4: Validate your connection

```bash
vulcan --log-to-stdout plan
```

`--log-to-stdout` skips creating a `.logs/` directory, which avoids `PermissionError` when the working directory is not writable. Common failures at this step are covered in section 9.

### 3.5: DataOS production deployment

Production deployment usually uses a depot instead of a direct password in the project config. Apply resources in this order:

PostgreSQL password instance secret → PostgreSQL depot → Git secret → `config.yaml` → Vulcan domain resource

| Manifest                        | Purpose                                                       | Key fields                                                                                                       |
| ------------------------------- | ------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `instance-secret-postgres.yaml` | Stores PostgreSQL password                                    | `name`, `data.password`                                                                                          |
| `depot-postgres.yaml`           | Registers host, port, database; binds purposes to the secret  | `name`, `spec.type: postgres`, host, port, database, `secrets[].id`                                              |
| `secret-git-sync.yaml`          | Repo credentials for git-sync                                 | `GITSYNC_USERNAME`, `GITSYNC_PASSWORD`                                                                           |
| `config.yaml`                   | Project config; gateway points at the depot or reads env vars | `type: depot` + `address: dataos://<depot-name>` or `env_var()` connection fields                                |
| `domain-resource.yaml`          | Workflow + API; references engine, repo, and credentials      | `engine: postgres`, `runAsUser`, `compute`, `repo.*`, `depots` or `envFrom`, `workflow.schedule`, `api.replicas` |

Two valid wiring styles are supported. Use a depot gateway (`type: depot`, `address: dataos://<name>`) or bind an instance secret into the workflow with `envFrom` and let `config.yaml` read `WAREHOUSE_*` through `env_var()`. Pick one style per project. Do not mix a depot gateway with conflicting environment variables.

### 3.6: Hello-world starter

Start a local PostgreSQL container and verify the connection:

```bash
docker run -d --name vulcan-pg \
  -e POSTGRES_USER=vulcan -e POSTGRES_PASSWORD=vulcan \
  -e POSTGRES_DB=warehouse -p 5432:5432 postgres:16

docker exec -it vulcan-pg psql -U vulcan -d warehouse -c "SELECT current_user, current_database();"
```

`**config.yaml**`

```yaml
gateways:
  default:
    connection:
      type: postgres
      host: localhost
      port: 5432
      database: warehouse
      user: vulcan
      password: vulcan
default_gateway: default
model_defaults:
  dialect: postgres
  start: '2024-01-01'
```

`**models/orders.sql**`

```sql
MODEL (
  name sales.orders,
  kind FULL
);

SELECT order_id, customer_id, total_amount, order_date
FROM raw.orders;
```

`**models/semantics/orders.yml**`

```yaml
kind: semantic
name: orders
depends_on: sales.orders
description: Orders fact semantic layer

dimensions:
  - order_date
  - customer_id

measures:
  - name: total_revenue
    type: sum
    expression: "{orders.total_amount}"
    description: Sum of order total_amount
```

`**models/metrics/daily_revenue.yml**`

```yaml
kind: metric
name: daily_revenue
measure: orders.total_revenue
ts: orders.order_date
granularity: day
description: Daily sum of order total_amount
```

Run `vulcan plan` — you should see `sales.orders` staged for creation. Run `vulcan apply` to materialize it, then call the metric through the REST endpoint to confirm that the semantic layer is wired end to end.

***

## Section 4: Vulcan on PostgreSQL

What changes when PostgreSQL is the engine: materialization strategies, runtime behavior, and what does not work. For general Vulcan concepts and syntax, see the canonical docs linked in each subsection.

> **Architectural constraints on PostgreSQL:**
>
> * Vulcan does not provision or manage the PostgreSQL server, databases, extensions, or instance parameters.
> * Queries execute in the PostgreSQL server itself; there is no separate warehouse/compute to start, stop, or resize from Vulcan.
> * `connection.database` must exist before `vulcan plan`.
> * PostgreSQL has no catalog tier; use `database.schema.table`, and schemas referenced by models are created automatically when privileges allow.

**Not supported on PostgreSQL via Vulcan**

| Feature                                                          | Why not supported                                                                                   | Alternative                                                                                            |
| ---------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `MANAGED` model kind                                             | Snowflake Dynamic Tables only                                                                       | Use FULL / incrementals and refresh by schedule                                                        |
| Real materialized view from `kind VIEW` with `materialized true` | PostgreSQL adapter does not support creating MV                                                     | Create/refresh a native `MATERIALIZED VIEW` with guarded raw DDL or a macro                            |
| Elastic scale-out / auto-suspend                                 | Vulcan does not manage PostgreSQL compute lifecycle; behavior depends on your PostgreSQL deployment | Vertically size provisioned instances; use replicas/pooling, or account for serverless wake-up latency |
| Cross-database queries in one SQL statement                      | PostgreSQL cannot query another database directly                                                   | Land data into the same database                                                                       |

### 4.1: Data movement

Nilus is the DataOS ingestion service that moves data from external sources into PostgreSQL. For local/dev, Vulcan SEED models can load CSVs into `raw.`\*. Vulcan transforms data that Nilus, seeds, or another ingestion path has already landed.

| Role           | Tool                                  | What it does                                                             |
| -------------- | ------------------------------------- | ------------------------------------------------------------------------ |
| Ingestion      | Nilus / SEED models                   | Moves raw data into PostgreSQL tables                                    |
| Transformation | Vulcan                                | Transforms ingested data into Data Product tables/views                  |
| Serving        | Vulcan API / direct depot credentials | Reads the Data Product through REST, GraphQL, MySQL-wire, or SQL clients |

| Depot purpose | Who uses it             | What it allows                                                   |
| ------------- | ----------------------- | ---------------------------------------------------------------- |
| `rw`          | Vulcan workflow         | Read sources, create/write model outputs, manage schemas         |
| `scan`        | DataOS metadata scanner | Read `information_schema` / `pg_catalog` for catalog and lineage |
| `query`       | Consumers               | Read-only access to Data Product tables                          |

Canonical pages: [Nilus](postgres-engine.md) · [Depot configuration](postgres-engine.md)

### 4.2: Models

#### 4.2.1: Data Models

SQL models compile to PostgreSQL SQL and execute directly on the server.

| Model kind                            | PostgreSQL operation                                                                                                                   |
| ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| SEED                                  | COPY / batched INSERT from CSV into a table                                                                                            |
| FULL                                  | Table replacement using PostgreSQL-compatible create/drop/insert behavior                                                              |
| VIEW                                  | `CREATE OR REPLACE VIEW`                                                                                                               |
| INCREMENTAL\_BY\_TIME\_RANGE          | Delete/insert by `time_column` window                                                                                                  |
| INCREMENTAL\_BY\_UNIQUE\_KEY          | PostgreSQL adapter merge path: native `MERGE` on PostgreSQL 15+, logical merge fallback on earlier versions                            |
| INCREMENTAL\_BY\_PARTITION            | Partition-key replacement through Vulcan's generic delete+insert fallback; not native PostgreSQL partition DDL                         |
| INCREMENTAL\_UNMANAGED                | Append/unmanaged incremental pattern; Vulcan does not manage updates or deletes                                                        |
| SCD\_TYPE\_2 / SCD\_TYPE\_2\_BY\_TIME | History table with validity windows tracked by time                                                                                    |
| SCD\_TYPE\_2\_BY\_COLUMN              | History table with validity windows tracked by checked columns                                                                         |
| EMBEDDED                              | Not materialized; inlined into downstream models                                                                                       |
| Python                                | In-process Python materializes a Pandas DataFrame and writes through the adapter; not valid for VIEW, EMBEDDED, SEED, or MANAGED kinds |

**Lifecycle DDL guard**

Wrap DDL in `pre_statements` / `post_statements` when it should only run during real execution:

```sql
@IF(@runtime_stage = 'evaluating',
  CREATE INDEX IF NOT EXISTS ix_orders_customer ON sales.orders (customer_id)
);
```

Without the guard, a dry-run plan can execute lifecycle DDL.

**Raw PL/pgSQL parser warning**

PostgreSQL-native DDL that SQLGlot cannot parse, such as anonymous `DO $$ ... $$` blocks, `CREATE FUNCTION ... LANGUAGE plpgsql`, and trigger bodies, can log a warning similar to:

```
[WARNING] 'DO $$ ...' could not be semantically understood
```

The block still runs verbatim. Silence console noise with `VULCAN_IGNORE_WARNINGS=1` or `vulcan --ignore-warnings ...`; keep the log file for debugging.

**External source declarations**

Declare non-owned source tables in `external_models.yaml` so linting and lineage can resolve them:

```yaml
- name: '"warehouse"."raw_external"."country_lookup"'
  columns:
    country_code: VARCHAR
    country_name: VARCHAR
    region: VARCHAR
```

These declarations act as a schema cache. The physical table must exist only if a model actually selects from it.

**Lowercase identifiers**

PostgreSQL folds unquoted identifiers to lowercase. Author model names, columns, semantic references, metric references, and DQ SQL in lowercase unless you intentionally use quoted identifiers everywhere.

Canonical pages: [SQL models](postgres-engine.md) · [Model kinds](postgres-engine.md)

#### 4.2.2: Semantic Models

Semantic models compile to SQL against the tables and views that Vulcan created under your database. Use one YAML resource per file with top-level `kind: semantic`.

```yaml
kind: semantic
name: customers
depends_on: sales.customers
description: Customer dimension semantic layer

dimensions:
  - customer_id
  - customer_segment
  - account_status

measures:
  - name: total_customers
    type: count
    expression: "*"
    description: Total number of customers

  - name: active_customers
    type: count
    expression: "*"
    filters:
      - "{customers.account_status} = 'Active'"

segments:
  - name: high_value_customers
    expression: "{customers.customer_segment} IN ('Platinum', 'Gold')"
```

Measure references use `{semantic_model.column}` braces. Declare joins for multi-entity queries. Cross-join-shaped semantic queries are one of the easiest ways to saturate a single PostgreSQL instance.

Canonical pages: [Semantic models](postgres-engine.md) · [Business metrics](postgres-engine.md)

#### 4.2.3: Metrics

Metrics live as single-resource YAML files with top-level `kind: metric`. In the current Vulcan model, the metric time fields are `ts` and `granularity`.

```yaml
kind: metric
name: daily_total_revenue
measure: orders.total_revenue
ts: orders.order_date
granularity: day
description: Daily sum of order total_amount from sales.orders
owner: qa@vulcan
tags:
  - orders
  - revenue
```

Some older PostgreSQL examples in this repo use an aggregate `metrics:` map with `time:` and no `granularity:`. Treat that as legacy/example-project syntax. Use the current `kind: metric` shape for new manuals and new projects unless you are maintaining that older project layout.

Two PostgreSQL-specific runtime behaviors matter:

* Heavy `COUNT(DISTINCT ...)` measures over wide tables are a primary cost driver. Pre-aggregate distinct counts into a mart or add supporting indexes before the query saturates the instance.
* Indexing matters more than it does on elastic warehouses. If a metric filter is slow, add an index on the filter/join column through guarded `post_statements`.

Canonical page: [Business metrics](postgres-engine.md)

### 4.3: Data Quality

All Vulcan quality layers can run on PostgreSQL. Every assertion or DQ rule is a query against the same instance, so it competes with model runs and endpoint reads for CPU, memory, and IOPS.

| Layer                                   | Where it runs                       | PostgreSQL cost     | When it catches a problem |
| --------------------------------------- | ----------------------------------- | ------------------- | ------------------------- |
| Linter                                  | Locally before DB calls             | None                | Authoring time            |
| Unit tests                              | Locally / in test runtime           | None on the server  | Pre-merge / pre-deploy    |
| Assertions (built-in or `audits/*.sql`) | PostgreSQL after model materialises | One query per audit | Every run, blocking       |
| Data quality (`kind: dq`, `dq/*.yml`)   | PostgreSQL on a schedule or with run | One query per rule  | Drift / freshness, non-blocking |

An assertion attaches an audit (the validation rule) to a model. Built-in audits like `not_null(...)` and user-defined audits in `audits/*.sql` are both invoked from the model's `assertions (...)` block and share the same post-materialisation execution phase.

Example DQ file:

```yaml
kind: dq
name: orders_dq
depends_on: sales.orders

profiles:
  - order_date
  - customer_id

rules:
  - row_count > 0:
      name: orders_not_empty
      dimension: completeness
      description: Orders fact table must contain at least one row

  - missing_count(order_id) = 0:
      name: no_missing_order_ids
      dimension: completeness
      description: Every order must have an order_id
```

Some older PostgreSQL examples in this repository use `checks:` map files grouped by dimensions such as `completeness`, `validity`, `uniqueness`, `accuracy`, and `timeliness`. For new documentation, prefer the current `kind: dq` resource shape above unless you are specifically documenting that older project layout.

Native PostgreSQL constraints (`NOT NULL`, `CHECK`, `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`) are enforced at write time and complement Vulcan audits/checks.

Canonical pages: [Tests](../components/tests.md) · [Assertions](../components/assertions.md) · [Data quality](../components/data-quality.md)

### 4.4: Lineage & version rollback

Lineage is computed from Vulcan's SQLGlot parse and the declared model graph, not from PostgreSQL query history. Source references resolve when the upstream is a Vulcan model or declared in `inouts.yaml`. PL/pgSQL inside `DO $$` blocks is opaque to the parser, so objects created there are structural PostgreSQL objects but not SQL lineage nodes.

Use the same database and a role with equivalent visibility when debugging with `psql`, your IDE, and the Vulcan connection. Objects created by the `vulcan` role can appear missing to another role without `USAGE`/`SELECT`.

### 4.5: Endpoints (REST, GraphQL, MySQL-wire)

Every deployed Data Product gets REST, GraphQL, and MySQL-wire endpoints. Endpoint queries push down to the same PostgreSQL gateway. The endpoint layer adds API overhead. Validate the observed floor in your tenant.

Large result sets are buffered by the API before streaming. Keep `api.resource.limit.memory` sized for expected payloads; 3 GiB is a practical starting point for high-row responses.

Canonical pages: [REST](postgres-engine.md) · [GraphQL](postgres-engine.md) · [MySQL wire](postgres-engine.md)

### 4.6: MCP tools

| MCP tool   | PostgreSQL behavior                                                         |
| ---------- | --------------------------------------------------------------------------- |
| `about`    | Static metadata; no live engine call                                        |
| `lineage`  | Static parsed graph; no live engine call                                    |
| `quality`  | Reads last audit/DQ status; no live engine call unless configured otherwise |
| `data`     | Live query against PostgreSQL; consumes CPU/IOPS                            |
| `run`      | Triggers a Vulcan workflow run; same cost as a scheduled run                |
| `activity` | Reads workflow history from DataOS; no engine call                          |

Treat agent-driven data queries like BI dashboard load. If `concurrencyPolicy: Forbid` is set and a scheduled run is in flight, overlapping workflow triggers can be rejected by orchestration policy.

Canonical pages: [Build-time MCP tools](postgres-engine.md) · [Runtime MCP tools](postgres-engine.md)

***

## Section 5: Metadata scanning & catalog

DataOS scans PostgreSQL through `information_schema` and `pg_catalog`. PostgreSQL does not provide a warehouse-style query-history table for scanner ingestion. Lineage comes from parsed definitions and Vulcan's model graph.

### 5.1: Metadata sources

| Metadata source      | Used for                                                                            |
| -------------------- | ----------------------------------------------------------------------------------- |
| `information_schema` | Databases, schemas, tables, columns, grants                                         |
| `pg_catalog`         | PostgreSQL-native metadata such as constraints, indexes, comments, view definitions |
| Vulcan parse graph   | Model lineage and semantic surface                                                  |

### 5.2: Scanner permissions

Use a read-only scanner role that is separate from the Vulcan service role.

```sql
GRANT CONNECT ON DATABASE warehouse TO scanner;
GRANT USAGE ON SCHEMA sales, raw TO scanner;
GRANT SELECT ON ALL TABLES IN SCHEMA sales, raw TO scanner;
ALTER DEFAULT PRIVILEGES IN SCHEMA sales GRANT SELECT ON TABLES TO scanner;
```

Catalog views are generally readable to a connected role, but table and column visibility depend on privileges.

### 5.3: What shows up in the catalog

| Object                          | Catalog                   | Lineage                                      |
| ------------------------------- | ------------------------- | -------------------------------------------- |
| Databases, schemas              | ✓                         | —                                            |
| Tables, views                   | ✓                         | ✓ as nodes                                   |
| Columns                         | ✓ with types              | ✓ when parsed from model/query definitions   |
| Comments (`COMMENT ON`)         | ✓ where scanner maps them | —                                            |
| Constraints                     | ✓                         | FK edges can aid relationship inference      |
| Native materialized views       | ✓                         | Depends on parser support for the definition |
| Objects created inside PL/pgSQL | Structural only           | Opaque to SQL parser                         |

### 5.4: Refresh cadence & lag

Scanner cadence is tenant/configuration-dependent, commonly every 6–12 hours. Structural changes appear after the next scan. If lineage is missing after `vulcan apply`, verify `external_models.yaml`, then wait for the next scan or trigger a scanner run.

***

## Section 6: Engine-native feature support

PostgreSQL is a full RDBMS, so many native features are reachable through guarded raw DDL in `pre_statements`, `post_statements`, or macros. Treat the PostgreSQL server lifecycle, database creation, extensions, replication settings, and instance parameters as platform/DBA boundaries.

| PostgreSQL feature     | Vulcan pattern                                            | Notes                                                                   |
| ---------------------- | --------------------------------------------------------- | ----------------------------------------------------------------------- |
| Database               | `connection.database`                                     | Must exist before apply                                                 |
| Schema                 | Referenced by model names                                 | Created automatically when role has privilege                           |
| Regular table          | FULL / incremental models                                 | Default materialized object                                             |
| View                   | `kind VIEW`                                               | Creates a PostgreSQL view                                               |
| Incremental table      | `INCREMENTAL_BY_TIME_RANGE` / `INCREMENTAL_BY_UNIQUE_KEY` | Delete+insert / logical upsert behavior                                 |
| SCD history            | `SCD_TYPE_2_BY_TIME` / `SCD_TYPE_2_BY_COLUMN`             | Validity-window history tables                                          |
| External/source tables | `external_models.yaml`                                    | For raw/Nilus/externally managed sources                                |
| Constraints            | Column/table DDL or lifecycle SQL                         | Enforced by PostgreSQL at write time                                    |
| Indexes                | `CREATE INDEX` in guarded `post_statements`               | PostgreSQL adapter supports indexes                                     |
| Row-level security     | `ENABLE ROW LEVEL SECURITY` + `CREATE POLICY`             | Enforced by PostgreSQL                                                  |
| Triggers/functions     | Guarded PL/pgSQL DDL                                      | Parser warning expected                                                 |
| Native partitioning    | Raw DDL / macros                                          | Manage carefully; keep Vulcan model strategy aligned                    |
| Materialized view      | Raw `CREATE MATERIALIZED VIEW` / `REFRESH`                | `kind VIEW materialized true` does not create native materialized views |
| Full-text search       | Generated `tsvector` + GIN index                          | Native PostgreSQL feature                                               |
| FDW federation         | `postgres_fdw` extension + foreign tables                 | Requires DBA-level extension setup                                      |

***

## Section 7: Operational boundaries

Concrete settings with hard thresholds. Tune from telemetry.

### 7.1: Compute sizing

| Workload                      | Guidance                                                                      |
| ----------------------------- | ----------------------------------------------------------------------------- |
| Dev / small reference dataset | 1–2 vCPU, 2–4 GiB is usually enough                                           |
| First full backfill           | Temporarily raise `work_mem` / `maintenance_work_mem`; ensure disk headroom   |
| Daily incremental runs        | Index the incremental `time_column` / `unique_key`; size IOPS to write volume |
| Semantic API / concurrent BI  | Add a pooler or read replica; watch connection count                          |
| Python models                 | Size client/runtime memory for DataFrame materialisation                      |

For provisioned PostgreSQL, there is usually no warehouse-style auto-stop or elastic scale-out. Serverless or auto-paused PostgreSQL deployments may wake up after idle periods. Tune `shared_buffers`, `work_mem`, `effective_cache_size`, and `max_connections` where your platform exposes them.

### 7.2: Concurrency

| Scenario                       | Setting                                                  |
| ------------------------------ | -------------------------------------------------------- |
| Model runs only, no live API   | Keep `concurrent_tasks` below free connection capacity   |
| Model runs + live semantic API | Reserve connections for API replicas                     |
| Many BI sessions               | Front PostgreSQL with PgBouncer; consider a read replica |

Start with `concurrent_tasks: 2` for daily incrementals. Raise it only if plan/run duration is the bottleneck and the instance has connection and I/O headroom.

### 7.3: API replicas & Kubernetes resources

| Traffic                           | API replicas             |
| --------------------------------- | ------------------------ |
| Single team                       | 1–2                      |
| Multi-team / scheduled dashboards | 3–5                      |
| Enterprise / high-volume          | 5+ with pooling/replicas |

```yaml
# workflow node
resource:
  request: { cpu: "200m", memory: "512Mi" }
  limit:   { cpu: "1000m", memory: "1Gi" }

# api node
resource:
  request: { cpu: "200m", memory: "512Mi" }
  limit:   { cpu: "4000m", memory: "3Gi" }
```

The API is stateless, but each replica consumes PostgreSQL connections. Pair replica increases with a pooler or higher connection capacity.

### 7.4: Scheduling

| Recommendation                                   | Why                                                              |
| ------------------------------------------------ | ---------------------------------------------------------------- |
| Schedule after upstream data lands               | Avoid reading partial data                                       |
| `timezone: UTC` in production                    | DST shifts will not move windows                                 |
| Set `endOn` ≥ 1-2 years out and review quarterly | Expired schedules halt workflows                                 |
| `concurrencyPolicy: Forbid`                      | Prevents overlapping incremental windows and connection pile-ups |

### 7.5: Latency floor

| Component                 | Floor                                                                                                     |
| ------------------------- | --------------------------------------------------------------------------------------------------------- |
| Warehouse cold start      | Typically none for provisioned PostgreSQL; serverless or auto-paused deployments may have wake-up latency |
| Connection establishment  | Sub-second when warm; use a pooler for repeated short queries                                             |
| Semantic API overhead     | Validate in your stack; expect seconds, not milliseconds                                                  |
| First-touch plan          | Catalog reads add to initial planning time                                                                |
| Query on unindexed filter | Sequential scan cost; add an index or pre-aggregate                                                       |

### 7.6: Operational limitations

| #  | Limitation                                              | Workaround                                                                        |
| -- | ------------------------------------------------------- | --------------------------------------------------------------------------------- |
| O1 | `database "x" does not exist` on apply                  | Create the database out of band; fix `WAREHOUSE_DATABASE` / `connection.database` |
| O2 | Permission denied for schema after apply                | Grant `USAGE`/`CREATE`; align Vulcan and debugging roles                          |
| O3 | PostgreSQL connection refused from Docker-based CLI     | Use `host.docker.internal` when crossing container boundary; confirm port mapping |
| O4 | Source tables not found                                 | Declare in `external_models.yaml`; verify `USAGE`/`SELECT`                        |
| O5 | Unit tests do not exercise PostgreSQL instance behavior | Use audits/DQ checks for instance-level validation                                |
| O6 | `unacceptable schema name "pg_..."`                     | `pg_` prefix is reserved; rename the schema                                       |
| O7 | Expired `endOn` halts workflow                          | Audit `endOn` quarterly                                                           |
| O8 | Too many connections under load                         | Lower `concurrent_tasks` / replicas, add PgBouncer, or add read replicas          |

***

## Section 8: Performance

PostgreSQL has a fixed instance cost rather than consumption-based warehouse billing. Performance guardrails are mostly about indexes, concurrency, memory, and avoiding live semantic queries that should be pre-aggregated.

### 8.1: Benchmarks

Validate on your own instance size and data scale before publishing SLOs externally.

#### 8.1.1: What to measure

| Metric                                          | Why                               |
| ----------------------------------------------- | --------------------------------- |
| Active connections vs `max_connections`         | Concurrency saturation signal     |
| Plan/run duration per model                     | Incremental vs full cost baseline |
| Semantic query wall time                        | API overhead + query execution    |
| Rows touched per incremental window             | Primary write-cost driver         |
| Sequential scan vs index scan ratio (`EXPLAIN`) | Missing-index signal              |

#### 8.1.2: Benchmark pattern

Use a repeatable harness or project-specific script that seeds data, runs a representative query battery, captures `EXPLAIN ANALYZE`, verifies `statement_timeout`, and tears down after itself. Keep benchmark schemas separate from Vulcan-managed `sales.*` / `raw.*` schemas.

#### 8.1.3: How to read results

Cheap indexed lookups are often dominated by the client-to-database round trip and API overhead. Expensive joins, `COUNT(DISTINCT ...)`, and unindexed filters are dominated by server execution. Tune these separately:

* For user-perceived latency on cheap queries: co-locate clients, use connection pooling, and keep API replicas warm.
* For server execution: add indexes, push filters down, pre-aggregate, or resize the instance.

#### 8.1.4: Concurrency fix order

1. Remove cross-join-shaped semantic queries.
2. Add missing indexes on hot filter/join columns.
3. Add a connection pooler such as PgBouncer.
4. Add a read replica for query/BI traffic.
5. Raise instance size last.

#### 8.1.5: Performance ceilings

| #  | Ceiling                                                    | Tune via                                                        |
| -- | ---------------------------------------------------------- | --------------------------------------------------------------- |
| P1 | Sequential scans on large tables dominate latency          | Add B-tree/BRIN indexes; push filters down; pre-aggregate marts |
| P2 | High-cardinality `COUNT(DISTINCT ...)` is CPU/memory bound | Pre-aggregate distinct counts; raise `work_mem`                 |
| P3 | Semantic API timeout on heavy multi-join query             | Constrain joins/measures; pre-aggregate                         |
| P4 | Incremental backfill duration                              | Raise maintenance memory; build secondary indexes after load    |
| P5 | API memory OOM on large result sets                        | Keep API memory sized for expected payloads                     |
| P6 | Too many connections                                       | Pooler; lower `concurrent_tasks` / replicas                     |

### 8.2: Measured results — 50M local run (2026-06-12)

> Real measurements were recorded on **2026-06-12** against a managed PostgreSQL **15.17** instance (`max_connections=859`, `shared_buffers=4GB`, `work_mem=4MB`, `effective_cache_size=12GB`). Synthetic dataset built by `scripts/pg_perf`: **customers 5,010,000 · products 50,000 · orders 50,100,000** (scale 167). Active connections during the run: **4 / 859**. Reproduce on your own instance and data scale before quoting these externally.

#### 8.2.1: Raw query battery (`scripts/pg_perf`, scale 167, 7 iterations/query)

Bare-SQL battery against the `perf.`\* tables — one warm-up was discarded, p50/p95 over 7 timed runs, `EXPLAIN (ANALYZE, BUFFERS)` for scan types:

| Query                                     | Shape                  | p50 (ms) | p95 (ms) | min (ms) | max (ms) | EXPLAIN exec (ms) | Scan nodes                      |
| ----------------------------------------- | ---------------------- | -------- | -------- | -------- | -------- | ----------------- | ------------------------------- |
| Q1 point lookup by PK                     | Index scan (PK)        | 48.59    | 50.55    | 47.89    | 50.68    | 0.03              | Index Scan                      |
| Q2 date-range scan (`order_date BETWEEN`) | Index range scan       | 2954.70  | 6393.97  | 2895.27  | 6487.88  | 2969.79           | Seq Scan                        |
| Q3 revenue by segment (join + GROUP BY)   | Hash join + aggregate  | 23463.85 | 23989.22 | 23139.60 | 24048.15 | 27543.98          | Seq Scan ×2                     |
| Q4 orders × customers × products (3-way)  | Multi-join + aggregate | 35616.51 | 36020.53 | 34389.25 | 36058.90 | 40199.16          | Seq Scan ×3                     |
| Q5 `COUNT(DISTINCT customer_id)`          | Distinct aggregate     | 27917.67 | 29309.65 | 27507.12 | 29321.64 | 31265.77          | Seq Scan                        |
| Q6 running `SUM OVER (PARTITION BY)`      | WindowAgg              | 85.03    | 95.39    | 82.20    | 95.88    | 4.98              | Bitmap Heap Scan + Bitmap Index |
| Q7 filter on unindexed `total_amount`     | Seq scan (expected)    | 4507.76  | 4609.77  | 4480.14  | 4612.70  | 4521.68           | Seq Scan                        |

* Scan-type ratio: **Seq Scan 5 / 7**, **Index Scan 2 / 7**.
* `statement_timeout` enforcement: **confirmed** — `pg_sleep(2)` cancelled by `statement_timeout=200ms`.

#### 8.2.2: Vulcan-orchestrated backfill (`vulcan plan --auto-apply`)

`kind FULL` models reading the same 50.1M `perf.`\* rows, built end-to-end through Vulcan (plan → snapshot → CTAS → audits). The three models ran **in parallel**, so the per-model figures are cumulative wall-clock at completion (not additive); total backfill wall clock was **2m28s**. Project unit tests ran first on DuckDB in **0.27s**.

| Model (full refresh)                    | Output rows | Completed at        |
| --------------------------------------- | ----------- | ------------------- |
| `revenue_by_segment` (join + GROUP BY)  | 4           | 61.09 s             |
| `orders_materialized` (full 50.1M CTAS) | 50,100,000  | 125.70 s            |
| `category_segment_revenue` (3-way join) | 24          | 148.54 s            |
| **Total (parallel wall clock)**         | —           | **148.5 s (2m28s)** |

> These are single-run wall-clock times, not percentiles. Subsection 8.2.1 isolates raw server execution; subsection 8.2.2 captures Vulcan's end-to-end orchestration cost over the same data.

***

## Section 9: Failure modes & troubleshooting

| #   | Symptom                                              | Likely cause                                           | Fix                                                                      |
| --- | ---------------------------------------------------- | ------------------------------------------------------ | ------------------------------------------------------------------------ |
| F1  | `database "warehouse" does not exist`                | Target database missing or wrong name                  | Create the database; fix `WAREHOUSE_DATABASE` / `connection.database`    |
| F2  | PostgreSQL connection refused                        | Infra not running or wrong host/port                   | Start PostgreSQL; use `host.docker.internal` from containers when needed |
| F3  | Password authentication failed                       | Wrong password or role                                 | Fix password; confirm the role exists and can log in                     |
| F4  | `relation raw.raw_orders does not exist`             | Missing table, missing grant, or not declared external | Grant `SELECT`; add to `external_models.yaml`                            |
| F5  | `vulcan plan` succeeds but `psql` shows empty schema | Different role/database used for debugging             | Use the same database and a role with `USAGE`                            |
| F6  | Semantic `column does not exist`                     | Casing mismatch                                        | Use lowercase identifiers or quote consistently                          |
| F7  | Depot not resolvable on DataOS                       | Depot name mismatch                                    | Verify `dataos://<depot-name>?purpose=rw` matches the depot manifest     |
| F8  | `PermissionError: '.logs'`                           | CWD not writable                                       | Run `vulcan --log-to-stdout ...` or make the directory writable          |
| F9  | `unacceptable schema name "pg_..."`                  | `pg_` prefix is reserved                               | Rename the schema                                                        |
| F10 | `vulcan plan` runs DDL                               | Lifecycle DDL not guarded                              | Wrap in `@IF(@runtime_stage = 'evaluating', ...)`                        |
| F11 | Incremental model reprocesses history                | Missing/wrong `time_column` or `unique_key`            | Verify model kind config matches actual columns                          |
| F12 | Endpoint OOM-kills on large result                   | API memory too low for payload                         | Raise API memory and limit result size                                   |
| F13 | `DO $$ ... could not be semantically understood`     | SQLGlot cannot parse PL/pgSQL                          | Harmless for execution; silence console warning if needed                |
| F14 | Too many connections for role                        | Workers + API replicas + BI exceed connection budget   | Lower concurrency/replicas; add PgBouncer                                |
| F15 | `psycopg2` fails to build from source                | Local build lacks `pg_config` / libpq headers          | Prefer the wheel/binary dependency supplied by the Vulcan distribution   |

### 9.1: Health-check queries

Run these in `psql` using the same database and role as the Vulcan connection.

```sql
SELECT current_user, current_database(), current_schema();
\dn

SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_schema, table_name
LIMIT 50;

SELECT count(*) AS conns, state
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY state;

EXPLAIN ANALYZE SELECT ...;
```

### 9.2: Recovery procedures

| Situation                               | Procedure                                                                                                                           |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Incremental run failed mid-window       | Re-run the workflow; time-range incrementals reprocess affected windows                                                             |
| Table dropped manually                  | `vulcan plan` should detect and recreate; use a rebuild command if needed                                                           |
| Wrong database applied                  | Fix `WAREHOUSE_DATABASE`, verify the active connection with `SELECT current_database()`, then re-run `vulcan plan` / `vulcan apply` |
| Credentials leaked                      | Rotate PostgreSQL password, update `.env` / DataOS instance secret                                                                  |
| Workflow halted because `endOn` expired | Update Vulcan resource with a new `endOn` and re-apply                                                                              |
| Connection exhaustion                   | Lower concurrency/replicas, restart pooler, investigate idle-in-transaction sessions                                                |
| Depot not resolving                     | Verify depot name and purpose in the Vulcan resource manifest                                                                       |

***

## Section 10: Deployment recipes

### 10.1: Daily incremental Kimball

Daily incremental, Kimball-style project with one database and `raw.*` sources:

```yaml
# config.yaml
name: tpch-postgres
default_gateway: postgres
model_defaults:
  dialect: postgres
  start: '2024-01-01'
  cron: '@daily'
concurrent_tasks: 2

gateways:
  postgres:
    connection:
      type: postgres
      host: "{{ env_var('WAREHOUSE_HOST', 'localhost') }}"
      port: "{{ env_var('WAREHOUSE_PORT', '5432') }}"
      database: "{{ env_var('WAREHOUSE_DATABASE', 'warehouse') }}"
      user: "{{ env_var('WAREHOUSE_USER', 'vulcan') }}"
      password: "{{ env_var('WAREHOUSE_PASSWORD', 'vulcan') }}"
```

```yaml
# domain-resource.yaml
version: v1alpha
type: vulcan
name: tpch-postgres
owner: qaowner
spec:
  runAsUser: qaowner
  compute: desertqa-compute
  engine: postgres
  repo:
    url: https://bitbucket.org/rubik_/vulcan-examples
    syncFlags: ["--ref=main", "--submodules=off"]
    baseDir: vulcan-qa/projects/tpch_postgres
    secret: qa:git-sync
  envFrom:
    - secret:
        name: qa:postgres-tpch-creds
  workflow:
    type: schedule
    schedule:
      crons: ['0 */6 * * *']
      endOn: '2027-01-01T00:00:00-00:00'
      timezone: UTC
      concurrencyPolicy: Forbid
    plan:
      command: [vulcan]
      arguments: ['--log-to-stdout', plan, '--auto-apply']
    run:
      command: [vulcan]
      arguments: ['--log-to-stdout', run]
  api:
    replicas: 1
    resource:
      request: { cpu: "250m", memory: "512Mi" }
      limit:   { cpu: "1000m", memory: "2Gi" }
```

### 10.2: Separate read replica for query traffic

The primary handles plan/run/incrementals. The replica handles semantic API and BI reads.

```yaml
gateways:
  build:
    connection:
      type: depot
      address: dataos://postgres-primary-depot
  query:
    connection:
      type: depot
      address: dataos://postgres-replica-depot

api:
  replicas: 5
  resource:
    request: { cpu: "500m", memory: "1Gi" }
    limit:   { cpu: "4000m", memory: "3Gi" }
```

Point read-only endpoints at a streaming replica where your deployment supports separate serving connections. Vulcan writes must go to the primary.

### 10.3: First-time backfill

```yaml
# config.yaml
concurrent_tasks: 6

# Vulcan resource
workflow:
  type: trigger
  resource:
    limit: { cpu: "2000m", memory: "2Gi" }
```

Temporarily raise PostgreSQL memory settings if allowed, run the backfill, build secondary indexes after large loads, run `VACUUM ANALYZE`, then return to the scheduled configuration.

### 10.4: Local full stack

```bash
docker run -d --name vulcan-pg \
  -e POSTGRES_USER=vulcan -e POSTGRES_PASSWORD=vulcan \
  -e POSTGRES_DB=warehouse -p 5432:5432 postgres:16
docker exec -it vulcan-pg psql -U vulcan -d warehouse -c "SELECT current_user, current_database();"

export WAREHOUSE_HOST=localhost WAREHOUSE_DATABASE=warehouse \
       WAREHOUSE_USER=vulcan WAREHOUSE_PASSWORD=vulcan

vulcan --log-to-stdout plan
```

***
