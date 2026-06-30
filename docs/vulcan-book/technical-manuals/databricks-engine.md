---
description: >-
  A Databricks engine manual for DataOS Vulcan setup, development, deployment,
  operations, performance, and troubleshooting.
---

# Databricks Engine

| Item                      | Details                               |
| ------------------------- | ------------------------------------- |
| **Template version**      | 1.0                                   |
| **Engine**                | Databricks                            |
| **Tested Vulcan image**   | `tmdcio/vulcan-databricks:0.228.1.23` |
| **Tested DataOS release** | Draco 1.38 series                     |
| **Last updated**          | June 2026                             |

***

## How to use this manual

This is the single source of truth for shipping a Data Product on Databricks using DataOS. It assumes you know what a Data Product is and what Vulcan does. Every section follows a fixed structure shared across all engine manuals — only the Databricks-specific content changes.

Use the path below that matches your role.

**If you are a data engineer setting up Vulcan on Databricks for the first time:** Prerequisites, including the pre-flight checklist → Local Development Kit setup → Deployment recipes → Operational boundaries

**If you are a DP developer building or debugging a Data Product on Databricks:** Snapshot → Vulcan on Databricks → Failure modes and troubleshooting

This manual is link-heavy by design. Every concept with an existing canonical page is summarized in one or two lines and linked.

***

## Section 1: Snapshot

This section is the fast path. If you only need the essentials, start here. It gives you the supported versions, key limits, runtime expectations, and the defaults you can rely on.

### **Architecture**

<figure><img src="../../../.gitbook/assets/image.png" alt=""><figcaption></figcaption></figure>

### **Version compatibility matrix**

| Vulcan image                          | DataOS release | Databricks target             | Status            |
| ------------------------------------- | -------------- | ----------------------------- | ----------------- |
| `tmdcio/vulcan-databricks:0.228.1.23` | Draco 1.38.x   | SQL warehouse + Unity Catalog | ✅ Tested          |
| Earlier `0.228.1.x` builds            | Draco 1.37.x   | SQL warehouse + Unity Catalog | ⬜ Add when tested |
| `0.228.0.x`                           | Draco 1.36.x   | SQL warehouse + Unity Catalog | ⬜ Add when tested |

{% hint style="info" %}
Python / Databricks Connect path is **Partial** — default execution is SQL warehouse. Validate Python model support against your specific Vulcan image before using in production.
{% endhint %}

| Item                   | Value                                                                                                            |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Engine adapter type    | `databricks`                                                                                                     |
| Model dialect          | `databricks`                                                                                                     |
| Support level          | GA (SQL warehouse + Unity Catalog path)                                                                          |
| Tested Vulcan image    | `tmdcio/vulcan-databricks:0.228.1.23`                                                                            |
| Tested DataOS release  | Draco 1.38 series                                                                                                |
| Execution vehicle      | SQL warehouse (`http_path`); not all-purpose cluster by default                                                  |
| Catalog                | Unity Catalog — `connection.catalog` must exist before apply                                                     |
| Auth (local / CI)      | Personal access token (PAT)                                                                                      |
| Auth (DataOS)          | Instance secret with token → Databricks depot                                                                    |
| Supported model kinds  | FULL, VIEW, INCREMENTAL\_BY\_TIME\_RANGE, INCREMENTAL\_BY\_UNIQUE\_KEY, INCREMENTAL\_BY\_PARTITION, SCD\_TYPE\_2 |
| Quality file format    | `kind: dq` YAML with rules                                                                                       |
| Semantic model format  | `kind: semantic` YAML with dimensions, measures, segments, joins, and optional `ai_context`                      |
| Business metric format | `kind: metric`, `name`, `measure`                                                                                |
| Production deploy unit | DataOS Vulcan resource (`engine: databricks`) + depot                                                            |
| Local state store      | Postgres (`state_connection`); isolate projects with `state_schema`                                              |
| Identifier casing rule | UPPERCASE in semantic models, filters, joins, DQ SQL, and metric expressions                                     |

**SLOs you can commit to** (validate on your warehouse tier and data volume before publishing externally):

| SLO                                                                       | Target                                        |
| ------------------------------------------------------------------------- | --------------------------------------------- |
| Daily incremental run success rate (warehouse healthy, UC grants correct) | ≥ 99%                                         |
| `vulcan plan` / `apply` success (after catalog + PAT validation)          | ≥ 99%                                         |
| Semantic API availability                                                 | Same as deployed Vulcan API track             |
| First query after warehouse auto-stop                                     | +2–10 s cold start (warehouse tier dependent) |

{% hint style="info" %}
Databricks latency is warehouse-tier and data-volume shaped. Validate on a known dataset before committing external SLOs.
{% endhint %}

***

## Section 2: Prerequisites

What must be in place before you write a single line of Vulcan code: Databricks-side permissions, DataOS access, and your local Python version.

### 2.1: Databricks permissions

Three roles are required, and each has a distinct scope. Do not collapse them into one.

| Role                    | Who holds it                        | Purpose                                                                   |
| ----------------------- | ----------------------------------- | ------------------------------------------------------------------------- |
| **Admin role**          | Databricks workspace admin          | Creates SQL warehouses, UC catalogs, grants Unity Catalog permissions     |
| **Vulcan service role** | The principal whose PAT Vulcan uses | Runs models, creates and modifies tables/schemas in the target UC catalog |
| **Consumer role**       | BI users, endpoint consumers        | Read-only access to Data Product tables via Vulcan endpoints              |

**Minimum grants (run as workspace admin in SQL editor on the same warehouse as `http_path`):**

```sql
-- Target catalog (for Vulcan materialization)
GRANT USE CATALOG ON CATALOG <your_catalog> TO `<principal>`;
GRANT CREATE SCHEMA ON CATALOG <your_catalog> TO `<principal>`;

-- Source data (e.g. Unity Catalog sample data)
GRANT USE CATALOG ON CATALOG samples TO `<principal>`;
GRANT USE SCHEMA ON SCHEMA samples.tpch TO `<principal>`;
GRANT SELECT ON SCHEMA samples.tpch TO `<principal>`;

-- Future schemas in target catalog
GRANT CREATE TABLE ON CATALOG <your_catalog> TO `<principal>`;
GRANT CREATE VIEW ON CATALOG <your_catalog> TO `<principal>`;
```

**Consumer role — read-only grants:**

```sql
GRANT USE CATALOG ON CATALOG <your_catalog> TO `<consumer>`;
GRANT USE SCHEMA ON SCHEMA <your_catalog>.<schema> TO `<consumer>`;
GRANT SELECT ON SCHEMA <your_catalog>.<schema> TO `<consumer>`;
```

**Verify grants (run in SQL editor, same warehouse as `http_path`):**

```sql
SELECT current_user() AS user, current_catalog() AS catalog;
SHOW SCHEMAS IN <your_catalog>;
SHOW TABLES IN samples.tpch;
```

For production setup order and connection wiring, see [Deployment Steps](../guides/deployment_guide.md).

### 2.2: DataOS permissions

The following access must be provisioned by your DataOS operator before you can deploy or run a Vulcan Data Product.

| Permission                         | What it unlocks                                               | Who to request from                 |
| ---------------------------------- | ------------------------------------------------------------- | ----------------------------------- |
| `roles:id:data-dev` or equivalent  | Create and apply Vulcan resources (workflow, API)             | DataOS operator / admin             |
| Access to the target workspace     | Apply secrets, depots, and domain resources in that workspace | DataOS operator                     |
| `depot:rw:<databricks-depot-name>` | Read/write access to the Databricks depot                     | DataOS operator                     |
| `depot:r:<databricks-depot-name>`  | Read-only access (consumer)                                   | DataOS operator                     |
| Git repository access              | Vulcan pulls model code via git-sync                          | Your VCS admin (GitHub / Bitbucket) |

{% hint style="info" %}
Check your access before starting. Run `dataos-ctl get depot` — if the Databricks depot appears in the output, your read access is confirmed. If it's missing, request `depot:r` from your operator.
{% endhint %}

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

**Databricks side**

* [ ] Workspace URL matches `server_hostname` in config (e.g. `dbc-xxxxxxxx-xxxx.cloud.databricks.com`)
* [ ] SQL warehouse provisioned and running; `http_path` copied from workspace UI
* [ ] UC catalog exists and PAT principal has `USE CATALOG` + `CREATE SCHEMA`
* [ ] Source data granted (`SELECT` on source schemas/tables)
* [ ] Service principal / user aligned between PAT and Catalog Explorer
* [ ] Network from DataOS data-plane and developer laptops can reach the workspace URL
* [ ] PAT not expired; rotation schedule set

**Local development**

* [ ] Universal prereqs complete (Python, Docker, CLI, data connection, repo)
* [ ] Vulcan wheel installed (`tmdcio/vulcan-databricks:0.228.1.23`)
* [ ] `.env` has `DATABRICKS_ACCESS_TOKEN`, `DATABRICKS_CATALOG`, `STATESTORE_*`
* [ ] Postgres statestore running (local Docker infra)
* [ ] `external_models.yaml` lists all cross-catalog source tables
* [ ] `vulcan migrate` and `vulcan plan` succeed

**DataOS production**

* [ ] Instance secret applied (`<workspace>:<name>`)
* [ ] Depot applied; `name` matches `dataos://<name>?purpose=rw` in Vulcan resource
* [ ] Depot `secrets[].id` references the Databricks instance secret
* [ ] Git secret applied (`GITSYNC_USERNAME`, `GITSYNC_PASSWORD`)
* [ ] `config.yaml` gateway points at the depot
* [ ] Vulcan resource: `engine: databricks`, `runAsUser`, `compute`, `repo`, `depots`, `workflow`, `api.replicas` all set
* [ ] Cron `timezone: UTC`; `endOn` ≥ 1–2 years out; `concurrencyPolicy: Forbid`

#### Before you ship checklist (DP developer)

* [ ] All semantic model identifiers are UPPERCASE
* [ ] Lifecycle DDL guarded with `@IF(@runtime_stage = 'evaluating', …)`
* [ ] Cross-catalog sources declared in `external_models.yaml`
* [ ] Joins declared for all multi-entity semantic queries
* [ ] Composite-key grains declared correctly (not single-column `unique_values`)
* [ ] Audits and DQ checks tagged separately from production reads
* [ ] `endOn` set and reviewed in the Vulcan resource schedule

***

## Section 3: Local Development Kit (LDK)

Step-by-step setup to run Vulcan locally against Databricks. Complete the prerequisites before starting here.

### 3.1: Install Vulcan

Vulcan is distributed as a Python wheel (`.whl`) and installed directly via `pip`. No Docker setup is required for Vulcan itself.

```bash
pip install vulcan_databricks-<version>-py3-none-any.whl
```

Get the latest `.whl` for the Databricks engine from your DataOS distribution channel. Replace `<version>` with the version listed in Snapshot. Confirm the installed version matches the tested image before running `vulcan plan`.

```bash
vulcan --version   # verify after install
```

> The reference project (`databricks_tpch`) uses a Docker-based local stack for its Postgres statestore and full API layer. If you are running the reference project, see the hello-world starter below for the full stack setup.

### 3.2: Set up authentication

Databricks uses a Personal Access Token (PAT). Store it in `.env`; never commit it.

```bash
# .env
DATABRICKS_ACCESS_TOKEN=dapi<your-token>
DATABRICKS_CATALOG=<your-uc-catalog>
```

Generate a PAT in Databricks: **User Settings → Developer → Access tokens → Generate new token**.

The PAT's principal must have the grants above. If using a service principal, ensure it has the same UC grants.

### 3.3: Configure config.yaml

Minimum Databricks connection config:

```yaml
gateways:
  default:
    connection:
      type: databricks
      server_hostname: <workspace-host>          # e.g. dbc-xxxxxxxx-xxxx.cloud.databricks.com
      http_path: /sql/1.0/warehouses/<id>        # from SQL Warehouse → Connection details
      access_token: "{{ env_var('DATABRICKS_ACCESS_TOKEN', '') }}"
      catalog: "{{ env_var('DATABRICKS_CATALOG', 'main') }}"
    state_connection:
      type: postgres
      host: "{{ env_var('STATESTORE_HOST', 'localhost') }}"
      port: "{{ env_var('STATESTORE_PORT', '5432') }}"
      user: "{{ env_var('STATESTORE_USER', 'vulcan') }}"
      password: "{{ env_var('STATESTORE_PASSWORD', 'vulcan') }}"
      database: "{{ env_var('STATESTORE_DATABASE', 'statestore') }}"
    state_schema: <project_name>

default_gateway: default
model_defaults:
  dialect: databricks
```

{% hint style="info" %}
`state_connection` is required for Databricks. Vulcan's plan/interval state cannot be stored in the SQL warehouse; it uses an external Postgres database. For local development, run Postgres in Docker, as shown in the hello-world starter. In production, a DataOS-managed Postgres is used. Isolate multiple projects using different `state_schema` values on the same Postgres instance.
{% endhint %}

### 3.4: Validate your connection

```bash
vulcan migrate        # initializes Vulcan state in Postgres
vulcan plan           # dry run against Unity Catalog — should succeed with no errors
```

If `vulcan plan` succeeds, you will see your models staged for creation. Common failures at this step are covered in the troubleshooting section below.

### 3.5: DataOS production deployment

Production deployment uses a depot instead of a direct connection. Apply resources in this order:

```
Databricks PAT instance secret → Databricks depot → Git secret → Vulcan config.yaml → Vulcan domain resource
```

| Manifest                                 | Purpose                                                                      | Key fields                                                                                              |
| ---------------------------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `instance-secret-databricks-pat.yaml`    | Stores Databricks PAT                                                        | `name`, `data.token`                                                                                    |
| `depot-databricks.yaml`                  | Registers workspace URL, HTTP path, UC catalog; binds purposes to the secret | `name`, `spec.type: databricks`, `url`, `http_path`, `catalog`, `secrets[].id`                          |
| `secret-git-sync.yaml`                   | Repo credentials for git-sync                                                | `GITSYNC_USERNAME`, `GITSYNC_PASSWORD`                                                                  |
| `config.yaml`                            | Project config; gateway points at the depot                                  | `gateways.default.connection.type: depot`, `gateways.default.connection.address: dataos://<depot-name>` |
| `domain-resource.yaml` (Vulcan resource) | Workflow + API; references depot and repo                                    | `engine: databricks`, `runAsUser`, `compute`, `repo.*`, `depots`, `workflow.schedule`, `api.replicas`   |

**Why order matters.** Applying the depot before the instance secret exists means `secrets[].id` will not resolve. A misspelled depot name in the Vulcan resource passes `apply` but fails at every workflow run. Verify `dataos://<depot-name>?purpose=rw` matches the depot manifest's `name` field exactly.

Reference configurations for all five manifests are in the deployment recipes below.

### 3.6: Hello-world starter

Minimum viable Data Product on Databricks. This requires a running Postgres statestore and an existing UC catalog. Fill in the credentials and run `vulcan plan`.

**Start local Postgres statestore (Docker):**

```bash
docker run -d --name vulcan-state \
  -e POSTGRES_USER=vulcan -e POSTGRES_PASSWORD=vulcan \
  -e POSTGRES_DB=statestore -p 5432:5432 postgres:15
```

**`config.yaml`**

```yaml
gateways:
  default:
    connection:
      type: databricks
      server_hostname: <workspace-host>
      http_path: /sql/1.0/warehouses/<id>
      access_token: "{{ env_var('DATABRICKS_ACCESS_TOKEN', '') }}"
      catalog: "{{ env_var('DATABRICKS_CATALOG', 'main') }}"
    state_connection:
      type: postgres
      host: localhost
      port: 5432
      user: vulcan
      password: vulcan
      database: statestore
    state_schema: hello_world
default_gateway: default
model_defaults:
  dialect: databricks
  start: '2024-01-01'
```

**`models/orders.sql`**

```sql
MODEL (
  name main.gold.orders,
  kind FULL
);
SELECT order_id, customer_id, total_price, order_date
FROM   main.raw.orders
```

**`models/semantic/orders.yaml`**

```yaml
kind: semantic
name: ORDERS
model: main.gold.orders
dimensions:
  - ORDER_DATE
measures:
  - name: TOTAL_SALES
    type: sum
    sql: TOTAL_PRICE
```

**`metrics/daily_revenue.yaml`**

```yaml
kind: metric
name: DAILY_REVENUE
measure: ORDERS.TOTAL_SALES
ts: ORDERS.ORDER_DATE
granularity: day
```

Run `vulcan plan` — you should see `main.gold.orders` staged for creation. Run `vulcan apply` to materialize it. Call the metric via the REST endpoint to confirm end-to-end behavior.

***

## Section 4: Vulcan on Databricks

What changes when Databricks is the engine: materialization strategies, runtime behavior, and what does not work. For general Vulcan concepts and syntax, see the canonical docs linked in each subsection.

{% hint style="warning" %}
**Architectural constraints on Databricks:**

* Vulcan does not create or manage Databricks SQL warehouses or Unity Catalog metastores. Both must be provisioned out of band.
* The default execution path is SQL warehouse. All-purpose cluster and Databricks Connect are not the standard Vulcan path.
* Vulcan state (plans, snapshots, intervals) lives in an external Postgres database — not in Databricks. A running `state_connection` is mandatory.
* The UC catalog referenced in `connection.catalog` must exist before `vulcan apply`. Vulcan creates schemas and tables inside it; it cannot create the catalog itself.
* The PAT workspace must match `server_hostname`. A cross-workspace PAT fails silently at auth.
{% endhint %}

**Not supported on Databricks via Vulcan**

| Feature                                          | Why not supported                                        | Alternative                                                                                       |
| ------------------------------------------------ | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| SQL warehouse create / resize / auto-stop config | Vulcan has no Databricks compute lifecycle API           | Provision via Databricks console, Terraform, or workspace admin                                   |
| All-purpose cluster as default execution         | Standard Vulcan SQL path uses SQL warehouse              | Use SQL warehouse; file a request if Databricks Connect support is needed for your image          |
| DLT / Streaming tables                           | Separate Databricks product; not in Vulcan's model kinds | Build streaming pipelines in Databricks natively; land results as Delta tables for Vulcan to read |
| Unity Catalog catalog creation                   | Vulcan cannot create UC catalogs                         | Create catalog in UC admin console before running `vulcan apply`                                  |
| Delta Sharing (provider/consumer)                | Platform-level Databricks admin concern                  | Configure Delta Sharing out of band; expose shared tables as external models                      |
| MLflow / Feature Store                           | Outside core SQL Data Product scope                      | Use Databricks natively; expose results as a table Vulcan reads                                   |
| Row filters / column masks management            | Vulcan SQL must remain compatible with UC policies       | UC enforces at query time; test queries with the PAT principal's effective permissions            |

### 4.1: Data movement

Before data can be transformed or served, it must be in Databricks Unity Catalog. This section covers how data arrives, what the depot purposes control, and how consumers read.

**How data gets into Databricks — Nilus**

Nilus is the DataOS ingestion service that moves data into Databricks from external sources, such as object stores, databases, SaaS APIs, and streams. It writes to Delta tables in Unity Catalog that Vulcan models then read as sources. Vulcan does not move raw data; it transforms data that Nilus or another pipeline has already landed.

| Role           | Tool   | What it does                                                       |
| -------------- | ------ | ------------------------------------------------------------------ |
| Ingestion      | Nilus  | Moves raw data into Databricks Delta tables (Bronze/staging layer) |
| Transformation | Vulcan | Transforms ingested data into Data Products (Silver/Gold)          |

**Databricks as a source vs. sink**

| Mode       | When it applies                                                                                            |
| ---------- | ---------------------------------------------------------------------------------------------------------- |
| **Sink**   | Nilus writes raw data into Databricks Delta tables; Vulcan materializes models into managed UC tables      |
| **Source** | Vulcan reads UC tables to build models; consumers query the Data Product via endpoints or direct UC access |

**Depot purposes**

| Purpose | Who uses it             | What it allows                                                                             |
| ------- | ----------------------- | ------------------------------------------------------------------------------------------ |
| `rw`    | Vulcan workflow         | Read source tables, create and write model output tables, manage schemas in the UC catalog |
| `scan`  | DataOS metadata scanner | Read Unity Catalog `information_schema` to populate the catalog and lineage                |
| `query` | Consumer direct access  | Read-only access to Data Product tables; used for depot-issued credential access           |

{% hint style="warning" %}
Bind the correct purpose to each secret in the depot manifest. A `query`-purpose credential cannot create tables, and an `rw` credential handed to a consumer is an over-permission risk.
{% endhint %}

Canonical pages: [Databricks source](../../nilus/batch/batch-sources/databricks.md) · [Databricks destination](../../nilus/destinations/cloud-warehouses/databricks.md) · [Databricks depot](../../depot/supported-sources/databricks.md)

### 4.2: Models

#### 4.2.1: Data Models

SQL models compile to Databricks SQL and execute on the configured SQL warehouse. Model kinds map to Delta/UC operations as follows:

| Model kind                   | Databricks operation                                    |
| ---------------------------- | ------------------------------------------------------- |
| FULL                         | `CREATE OR REPLACE TABLE` (Delta, UC-managed)           |
| VIEW                         | `CREATE OR REPLACE VIEW` (staging / intermediate layer) |
| INCREMENTAL\_BY\_TIME\_RANGE | Delete/overwrite by time window → INSERT                |
| INCREMENTAL\_BY\_UNIQUE\_KEY | MERGE on the unique key                                 |
| INCREMENTAL\_BY\_PARTITION   | Partition-scoped overwrite → INSERT                     |

**Reference layering pattern (databricks\_tpch):**

| Layer           | Kind                               | Reads from                                                    |
| --------------- | ---------------------------------- | ------------------------------------------------------------- |
| Bronze / source | Declared in `external_models.yaml` | Unity Catalog sample data (`samples.tpch.*`)                  |
| Staging         | VIEW                               | Bronze external models; aliases raw columns to business names |
| Intermediate    | VIEW                               | Staging views                                                 |
| Gold dimensions | FULL                               | Intermediate views                                            |
| Gold fact       | INCREMENTAL\_BY\_TIME\_RANGE       | Intermediate; partitioned on `order_date`                     |

```sql
MODEL (
  name marts.fct_sales,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column order_date
  ),
  grains (ORDER_LINE_ID)
);
SELECT ...
FROM   intermediate.int_order_items
WHERE  order_date BETWEEN @start_date AND @end_date;
```

**Rule: Lifecycle DDL guards**

Wrap any DDL in `pre_statements` / `post_statements` when it should only run during real execution:

```sql
@IF(@runtime_stage = 'evaluating',
  ALTER TABLE marts.fct_sales SET TBLPROPERTIES ('delta.autoOptimize.optimizeWrite' = 'true')
);
```

Without the guard, `vulcan plan` will execute it.

**Rule: Declare cross-catalog external models**

`vulcan create_external_models` may not discover tables outside the configured catalog (e.g. `samples.tpch`). Declare them manually in `external_models.yaml`:

```yaml
- name: samples.tpch.customer
  columns:
    c_custkey: BIGINT
    c_name:    VARCHAR(25)
    c_mktsegment: VARCHAR(10)
```

Without the declaration, the linter throws `Table not found`, and lineage stops at the model boundary.

**Rule: Lowercase source, uppercase business columns**

Databricks sample/raw tables use lowercase column names (`c_custkey`). Staging models alias them to UPPERCASE for consistent downstream semantics:

```sql
SELECT c_custkey AS CUSTOMER_ID, c_name AS CUSTOMER_NAME FROM samples.tpch.customer
```

Canonical pages: [SQL models](../components/model/types/sql_models.md) · [Model kinds](../components/model/model_kinds.md)

#### 4.2.2: Semantic Models

Semantic models compile to SQL against logical views/tables that Vulcan created under your UC catalog.

**Identifier casing — the rule that bites everyone once.** Match semantic model identifiers to the physical column casing of the model they reference. Because staging models alias to UPPERCASE, all semantic dimensions and measures must be UPPERCASE. Lowercase causes "column not found."

```yaml
kind: semantic
name: ORDERS
model: marts.fct_sales
dimensions:
  includes:
    - ORDER_LINE_ID
    - ORDER_DATE
    - CUSTOMER_ID
measures:
  - name: TOTAL_SALES
    type: sum
    sql: "{ORDERS.TOTAL_REVENUE}"
```

Declare explicit joins for multi-entity queries (see `sales.yaml → customers, parts, suppliers` in `databricks_tpch`). Cross-join-shaped queries — joins without a foreign-key relation — are the single biggest latency outlier on any SQL warehouse.

Canonical pages: [Semantic models](../components/model/types/models.md) · [Business metrics](../components/semantics/business_metrics.md)

#### 4.2.3: Metrics

A metric is a YAML manifest that references a measure already defined in a semantic model. Vulcan compiles it to a Databricks SQL aggregation executed on the SQL warehouse.

```yaml
kind: metric
name: DAILY_REVENUE
measure: ORDERS.TOTAL_SALES
ts: ORDERS.ORDER_DATE
granularity: day
dimensions:
  - name: ORDER_STATUS
    ref: ORDERS.ORDER_STATUS
```

Two Databricks-specific behaviors matter at runtime:

**Heavy `COUNT(DISTINCT …)` measures** over wide fact tables are the primary warehouse-sizing driver. If a metric backed by a high-cardinality distinct count is slow, size up the SQL warehouse before rewriting the metric definition.

**Identifier casing in metric filters** follows the same UPPERCASE rule as semantic models. Lowercase column references in `filters` or `expressions` will cause "column not found" errors.

Canonical page: [Business metrics](../components/semantics/business_metrics.md)

### 4.3: Data Quality

All quality layers work on Databricks. Cost characteristics differ.

| Layer                                   | Where it runs                          | Databricks cost     | When it catches a problem |
| --------------------------------------- | -------------------------------------- | ------------------- | ------------------------- |
| Linter                                  | Locally, before any warehouse call     | None                | Authoring time            |
| Unit tests (`tests/`)                   | Locally (DuckDB in-process)            | None on warehouse   | Pre-merge / pre-deploy    |
| Assertions (built-in or `audits/*.sql`) | SQL warehouse after model materializes | One query per audit | Every run, blocking       |
| Data quality (`kind: dq`, `dq/*.yml`)   | SQL warehouse on a schedule or with run | One query per rule  | Drift / freshness, non-blocking |

An assertion attaches an audit (the validation rule) to a model. Built-in audits like `not_null(...)` and user-defined audits in `audits/*.sql` are both invoked from the model's `assertions (...)` block and share the same post-materialization execution phase.

{% hint style="info" %}
Unit tests run against DuckDB even when `default_gateway: databricks`; that is expected for in-memory tests. They are not a substitute for warehouse-level assertion validation.
{% endhint %}

Tag DQ queries so you can separate their spend from production reads. Databricks query history and system tables attribute DBU spend per query.

Canonical pages: [Tests](../components/tests.md) · [Assertions](../components/assertions.md) · [Data quality](../components/data-quality.md)

### 4.4: Lineage & version rollback

Lineage is computed from Vulcan's SQLGlot parse, not from Databricks system tables. Two Databricks-relevant facts matter:

Lineage resolves cross-catalog references (e.g. `samples.tpch.orders`) only when the upstream is declared in `external_models.yaml`. Without the declaration, lineage stops at the model boundary.

`vulcan rollback` to a previous plan version replays the materialization strategy from the data-model section above. For `INCREMENTAL_BY_TIME_RANGE`, the rollback re-processes affected time windows and consumes warehouse DBUs.

**Rule: Same warehouse for debugging and Vulcan**

SQL editor, Catalog Explorer, and the `http_path` in config must use the same SQL warehouse when triaging missing objects. A table created by one warehouse may not be visible via a different warehouse's session if UC metadata hasn't propagated.

### 4.5: Endpoints (REST, GraphQL, MySQL-wire)

Every Data Product on Databricks automatically gets REST, GraphQL, and MySQL-wire endpoints. All push queries down to the same SQL warehouse gateway; latency is identical across protocols. The endpoint layer adds \~1.5–3 s overhead (validate in your stack; Databricks warehouse tier affects this).

Result sets up to \~50k rows are buffered in API memory before streaming. Keep `api.limit.memory ≥ 1.5 GiB` to avoid OOM. The recommended value is 3 GiB.

Canonical pages: [Vulcan API Guide](../guides/vulcan_api_guide.md) · [Activation overview](../../../foundations/activation/) · [MySQL activation](../activation/mysql.md)

### 4.6: MCP tools

| MCP tool   | Databricks behavior                                           |
| ---------- | ------------------------------------------------------------- |
| `about`    | Static — no engine call                                       |
| `lineage`  | Static — Vulcan's parsed graph, no engine call                |
| `quality`  | Static read of last audit/DQ result, no live engine call      |
| `data`     | Live query against Databricks SQL warehouse — consumes DBUs   |
| `run`      | Triggers a Vulcan workflow run — same cost as a scheduled run |
| `activity` | Reads workflow history from DataOS — no engine call           |

Treat agent-driven `data` tool queries like BI dashboard load on the warehouse. If `concurrencyPolicy: Forbid` is set and a scheduled run is in flight, MCP-triggered `run` calls are rejected.

Canonical pages: [AI activation](../../../foundations/activation/ai-activation.md) · [Activation overview](../../../foundations/activation/)

***

## Section 5: Metadata scanning & catalog

DataOS scans two Databricks sources: Unity Catalog `information_schema` (real-time structural metadata) and Databricks system tables (query history, lineage — may have ingestion lag depending on workspace tier).

### 5.1: What shows up

| Object                              | Catalog                    | Lineage                     |
| ----------------------------------- | -------------------------- | --------------------------- |
| Catalogs, schemas                   | ✓                          | —                           |
| Delta tables, views                 | ✓                          | ✓ as nodes                  |
| Columns                             | ✓ with types               | ✓ column-level              |
| UC tags / comments                  | ✓ as classifications       | —                           |
| Lineage edges                       | —                          | ✓ (lag varies by tier)      |
| External tables, materialized views | Ingested, not always shown | Used internally for lineage |

Lineage is computed: DataOS parses view definitions, `MERGE`/`INSERT INTO SELECT`/`CTAS` statements from Databricks system tables or Vulcan's own SQL parse.

### 5.2: Scanner permissions

Separate the read-only role from the Vulcan service role above.

```sql
GRANT USE CATALOG ON CATALOG <your_catalog> TO `<scanner_principal>`;
GRANT USE SCHEMA ON ALL SCHEMAS IN CATALOG <your_catalog> TO `<scanner_principal>`;
GRANT SELECT ON ALL TABLES IN CATALOG <your_catalog> TO `<scanner_principal>`;

-- System tables (for query history / lineage)
GRANT USE CATALOG ON CATALOG system TO `<scanner_principal>`;
GRANT SELECT ON ALL TABLES IN CATALOG system TO `<scanner_principal>`;
```

### 5.3: Refresh & lag

The scanner runs every 6–12 hours (configurable). Structural changes (new tables, columns) appear after the next scan. Lineage edges from query history depend on Databricks system table ingestion latency — this varies by workspace tier (serverless system tables are near-real-time; classic may lag minutes to hours). If lineage is missing after a `vulcan apply`, wait or trigger a manual scanner run.

***

## Section 6: Engine-native feature support

Which Databricks objects you can drive from a Vulcan Data Product, and what is a platform boundary.

| Databricks feature            | Vulcan pattern                                                  | Notes                                                           |
| ----------------------------- | --------------------------------------------------------------- | --------------------------------------------------------------- |
| SQL warehouse                 | `connection.http_path` + PAT                                    | Primary execution path                                          |
| UC catalog (existing)         | `connection.catalog`                                            | Must exist; Vulcan creates schemas inside it                    |
| UC schema                     | Vulcan creates automatically                                    | e.g. `<catalog>.vulcan__<schema>`, `<catalog>.<logical_schema>` |
| Managed Delta table           | kind `FULL` / incrementals                                      | Default for all materialized models                             |
| View                          | kind `VIEW`                                                     | Staging and intermediate layer                                  |
| Incremental Delta table       | kind `INCREMENTAL_BY_TIME_RANGE / UNIQUE_KEY / PARTITION`       | Delta MERGE / overwrite                                         |
| External / sample tables      | `external_models.yaml`                                          | e.g. `samples.tpch.*`                                           |
| UC row filters / column masks | Enforced at query time by UC                                    | Partial — SQL must remain compatible; test with PAT principal   |
| Delta table properties        | `ALTER TABLE … SET TBLPROPERTIES` in `post_statements`, guarded | Standard+                                                       |
| Table clustering / Z-order    | `OPTIMIZE … ZORDER BY` in `post_statements`, guarded            | Standard+                                                       |
| SQL UDF (inline)              | `CREATE OR REPLACE FUNCTION` in `pre_statements`                | Standard+                                                       |
| Sequence / identity column    | `GENERATED ALWAYS AS IDENTITY` in model DDL                     | Standard+                                                       |
| Materialized view (SQL)       | Version / image dependent                                       | Mark TBD until validated for your image                         |
| All-purpose cluster           | Not default                                                     | Boundary for standard Vulcan SQL path                           |
| DLT / Streaming tables        | Boundary                                                        | Separate Databricks product                                     |
| Databricks Jobs / Workflows   | Wrap `vulcan run`                                               | Optional orchestration shell; boundary for native job features  |
| Delta Sharing                 | Boundary                                                        | Provider/consumer flows — out of Vulcan scope                   |
| MLflow / Feature Store        | Boundary                                                        | Out of core SQL Data Product                                    |

**Guard rule for lifecycle DDL.** Any DDL in `pre_statements` / `post_statements` that should only run during real execution must be wrapped:

```sql
@IF(@runtime_stage = 'evaluating',
  OPTIMIZE <catalog>.<schema>.<table> ZORDER BY (order_date)
);
```

Without the guard, `vulcan plan` dry-runs will execute it.

***

## Section 7: Operational boundaries

Concrete settings with hard thresholds. Treat this as an engineering contract; tune from telemetry.

**Model table properties to support altering tables**

If you are making a forward-only change to the structure of a table, you may need to add the following to your model's physical\_properties:

```
MODEL (
    name vulcan_example.new_model,
    ...
    physical_properties (
        'delta.columnMapping.mode' = 'name'
    ),
)
```

If you attempt to alter the table without this property set, you will get an error similar to `databricks.sql.exc.ServerOperationError: [DELTA_UNSUPPORTED_DROP_COLUMN] DROP COLUMN is not supported for your Delta table`.

### 7.1: Compute sizing

| Workload                                 | Guidance                                                            |
| ---------------------------------------- | ------------------------------------------------------------------- |
| Dev / small reference dataset            | Small SQL warehouse; auto-stop after 10 min                         |
| First full backfill (multi-year history) | Temporarily scale up warehouse size; revert after backfill          |
| Daily incremental runs                   | Right-size to partition touch volume — oversizing wastes DBUs       |
| Semantic API / concurrent BI             | Dedicated warehouse or higher tier; monitor queue time              |
| Python models (Databricks Connect)       | Validate compute requirements separately; not the standard SQL path |

Always enable auto-stop on dev warehouses:

```
Workspace UI → SQL Warehouses → Edit → Auto Stop: 10 min
```

### 7.2: Concurrency

| Scenario                       | Setting                                            |
| ------------------------------ | -------------------------------------------------- |
| Model runs only, no live API   | Default warehouse concurrency                      |
| Model runs + live semantic API | Increase warehouse cluster count; add API replicas |
| Many BI sessions               | Split build and query warehouses                   |

Keep `concurrent_tasks` in `config.yaml` below what the warehouse can admit without queue timeouts. Start at 2 for daily incrementals. Raise it only if plan duration is the bottleneck.

### 7.3: API replicas & Kubernetes resources

| Traffic                           | API replicas |
| --------------------------------- | ------------ |
| Single team                       | 1–2          |
| Multi-team / scheduled dashboards | 3–5          |
| Enterprise / high-volume          | 5+           |

The API is stateless; add replicas before raising warehouse concurrency.

```yaml
# workflow node
resource:
  request: { cpu: "200m",  memory: "512Mi" }
  limit:   { cpu: "1000m", memory: "1Gi" }

# api node
resource:
  request: { cpu: "200m",  memory: "512Mi" }
  limit:   { cpu: "4000m", memory: "3Gi" }
```

Keep `api.limit.memory` at 3 GiB. Dropping below 1.5 GiB risks OOM on 50k-row endpoint result sets.

### 7.4: Scheduling

| Recommendation                                   | Why                                         |
| ------------------------------------------------ | ------------------------------------------- |
| Schedule after upstream data lands               | Avoid reading partial data                  |
| `timezone: UTC` in production                    | DST shifts won't silently move the window   |
| Set `endOn` ≥ 1–2 years out and review quarterly | Expired `endOn` halts the workflow silently |
| `concurrencyPolicy: Forbid`                      | Prevents overlapping incremental windows    |

### 7.5: Latency floor

| Component                                             | Floor                                       |
| ----------------------------------------------------- | ------------------------------------------- |
| SQL warehouse auto-stop cold start                    | +2–10 s (tier-dependent)                    |
| Semantic API overhead                                 | \~1.5–3 s (validate in your stack)          |
| UC metadata / information schema on first-touch plans | Adds to initial `plan` execution            |
| Result-cache hit                                      | < 1 s end-to-end (if Delta caching enabled) |

### 7.6: Operational limitations

| #  | Limitation                                            | Workaround                                                                   |
| -- | ----------------------------------------------------- | ---------------------------------------------------------------------------- |
| O1 | `NO_SUCH_CATALOG_EXCEPTION` on apply                  | Use an existing UC catalog; fix `DATABRICKS_CATALOG` or `connection.catalog` |
| O2 | Objects not visible in Catalog Explorer after apply   | Ensure SQL editor and `http_path` use the same SQL warehouse                 |
| O3 | Postgres connection refused from Docker-based CLI     | Set `STATESTORE_HOST=host.docker.internal`; confirm port mapping             |
| O4 | Cross-catalog source tables not found                 | Declare in `external_models.yaml`; verify grants on source catalog           |
| O5 | Unit tests use DuckDB, not the warehouse              | Expected for in-memory unit tests; use audits for warehouse-level validation |
| O6 | Stale state causes apply to skip models               | Create a new `state_schema`, run `vulcan migrate`, re-apply                  |
| O7 | Lowercase identifiers in semantic models fail         | Use UPPERCASE everywhere in semantic models                                  |
| O8 | Expired `endOn` halts the workflow silently           | Audit `endOn` quarterly                                                      |
| O9 | First query after warehouse auto-stop pays cold-start | Keep auto-stop ≥ 10 min; pin a warming query if SLO-critical                 |

***

## Section 8: Performance & Cost

How fast this engine runs and what it costs. Use benchmarks to set SLO expectations. Use cost guardrails before going to production.

### 8.1: Benchmarks

> Databricks latency is warehouse-tier and data-volume shaped. The numbers below are guidance from the `databricks_tpch` reference project (`samples.tpch` — small dataset). **Validate on your warehouse tier and catalog scale before publishing SLOs externally.**

#### 8.1.1: What to measure

| Metric                              | Why                                 |
| ----------------------------------- | ----------------------------------- |
| Warehouse queue time                | Concurrency saturation signal       |
| `plan` / `run` duration per model   | Incremental vs full cost baseline   |
| Semantic query wall time            | API overhead + warehouse execution  |
| Rows touched per incremental window | Primary DBU driver                  |
| Cold-start overhead                 | First-query latency after auto-stop |

#### 8.1.2: Validation loop (databricks\_tpch reference project)

1. Start local infra: `docker run` Postgres statestore → `vulcan migrate` → `vulcan plan`
2. Confirm objects under `<DATABRICKS_CATALOG>` in Catalog Explorer (same warehouse as `http_path`)
3. Hit GraphQL/REST with a simple measure on `sales`
4. Record warehouse size, row counts, p50/p95 query latency
5. Scale warehouse one step; repeat only if SLO requires it

#### 8.1.3: Concurrency fix order

When concurrency degrades, fix it in this order:

1. Remove cross-join-shaped semantic queries
2. Add API replicas (cheap; stateless)
3. Raise SQL warehouse cluster count
4. Split build and query warehouses
5. Increase warehouse size last

#### 8.1.4: Performance ceilings

| #  | Ceiling                                              | Tune via                                                    |
| -- | ---------------------------------------------------- | ----------------------------------------------------------- |
| P1 | Large shuffle joins on warehouse dominate latency    | Pre-aggregate marts; push filters down; reduce join fan-out |
| P2 | High-cardinality `COUNT(DISTINCT …)` drives DBU cost | Warehouse scale-up; pre-aggregate distinct counts into mart |
| P3 | Semantic API timeout on heavy cross-join query       | Constrain joins/measures in semantic layer; pre-aggregate   |
| P4 | Incremental backfill duration                        | Temporarily increase warehouse size; revert after           |
| P5 | API memory OOM on large result sets                  | Keep `api.limit.memory` at 3 GiB                            |

### 8.2: Cost guardrails

Databricks bills SQL warehouse DBUs. The default behavior is "spend up to whatever the warehouse can do." Set these guardrails before going to production.

#### 8.2.1: Warehouse auto-stop

Always enable auto-stop on non-production warehouses. Set it to ≥ 10 min for dev (lower risks cold-start on every query); use workspace-level policy for production.

#### 8.2.2: Query-level controls (timeouts)

Set query timeout at the warehouse or session level to kill runaway endpoint queries:

```sql
-- Session-level (in pre_statements or lifecycle SQL)
SET spark.sql.session.timeoutMs = 3600000;   -- 1 hour
```

Or configure via **SQL Warehouse → Edit → Query timeout**.

#### 8.2.3: Cost attribution (query tagging)

Tag every query the Data Product issues so spend can be sliced by project / model / consumer:

```sql
-- In pre_statements or session lifecycle SQL
SET spark.sql.query.tag = 'vulcan:<project>:<model>';
```

Then attribute spend in Databricks Query History or system tables. See [Data Product API](../../../foundations/activation/apis/).

#### 8.2.4: Storage cost management

Set Bronze/staging tables to external or managed Delta with short retention where re-derivable from sources. Use `VACUUM` to reclaim deleted Delta files. Keep `delta.deletedFileRetentionDuration` at the default (7 days) unless audit requirements demand longer.

Cost tracking depends on your Databricks query history and system-table setup. Use the query tags above to separate spend by project, model, or consumer.

***

## Section 9: Failure modes & troubleshooting

The top 15 errors when running a Data Product on Databricks, with cause and fix.

| #   | Symptom                                                        | Likely cause                                                | Fix                                                                                     |
| --- | -------------------------------------------------------------- | ----------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| F1  | `NO_SUCH_CATALOG_EXCEPTION`                                    | Catalog missing or wrong name in config                     | Create UC catalog via admin console; update `DATABRICKS_CATALOG` / `connection.catalog` |
| F2  | `connection refused` to Postgres statestore                    | Infra not running or wrong host/port                        | Start Postgres; use `host.docker.internal:5432` from inside Docker                      |
| F3  | `Auth / 403 on warehouse`                                      | Expired PAT or wrong workspace URL                          | Generate new PAT; ensure `server_hostname` matches the PAT's workspace                  |
| F4  | `Table samples.tpch.customer not found`                        | Missing UC grant or not declared as external                | Grant `SELECT` on `samples.tpch`; add to `external_models.yaml`                         |
| F5  | `vulcan plan` succeeds but Catalog Explorer shows empty schema | Different SQL warehouse used in UI vs `http_path`           | Use the same warehouse in SQL editor and in `config.yaml`                               |
| F6  | Semantic "column not found"                                    | Casing mismatch between model columns and semantic model    | Use UPPERCASE identifiers in semantic models                                            |
| F7  | `Depot not resolvable` on DataOS                               | Depot name in Vulcan resource doesn't match depot manifest  | Verify `dataos://<depot-name>?purpose=rw` matches depot `name` field exactly            |
| F8  | Port conflict on local stack transpiler                        | Standalone transpiler already running when `make vulcan-up` | Stop standalone process before starting full stack                                      |
| F9  | Duplicate apply appears skipped                                | Postgres state believes model is current                    | Create new `state_schema`, run `vulcan migrate`, re-apply (dev only)                    |
| F10 | `http_path invalid` or `warehouse not found`                   | Warehouse stopped or deleted                                | Recreate warehouse; update `http_path` in config                                        |
| F11 | `vulcan plan` mysteriously runs DDL                            | `pre_/post_statements` DDL not guarded                      | Wrap in `@IF(@runtime_stage = 'evaluating', …)`                                         |
| F12 | Incremental model re-processes all history on every run        | Missing or wrong `time_column` in model kind config         | Verify `kind INCREMENTAL_BY_TIME_RANGE (time_column <col>)` matches actual date column  |
| F13 | Endpoint OOM-kills on large result                             | `api.memory.limit` below 1.5 GiB                            | Raise to 3 GiB                                                                          |
| F14 | First query after idle period is 2–10 s slower                 | Warehouse cold start after auto-stop                        | Expected; document in SLO or pin a warming query                                        |
| F15 | DQ checks faster than expected on re-run                       | Delta result caching                                        | Expected within cache window; force re-read if benchmarking                             |

### 9.1: Health-check queries

Run these in the Databricks SQL editor (same warehouse as `http_path`) to triage a misbehaving project:

```sql
-- Confirm current identity and catalog
SELECT current_user() AS user, current_catalog() AS catalog, current_schema() AS schema;

-- List Vulcan-managed schemas in your catalog
SHOW SCHEMAS IN <your_catalog>;

-- List tables Vulcan created
SELECT table_catalog, table_schema, table_name, table_type
FROM   <your_catalog>.information_schema.tables
WHERE  table_schema NOT LIKE 'information_schema'
ORDER  BY table_schema, table_name
LIMIT  50;

-- Recent queries on this warehouse (system tables)
SELECT statement_id, statement_text, status,
       total_task_duration_ms / 1000 AS seconds,
       user_name
FROM   system.query.history
WHERE  warehouse_id = '<your-warehouse-id>'
  AND  start_time > CURRENT_TIMESTAMP - INTERVAL 2 HOURS
ORDER  BY start_time DESC
LIMIT  50;
```

### 9.2: Recovery procedures

| Situation                               | Procedure                                                                                            |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Incremental run failed mid-window       | Re-run the workflow; `INCREMENTAL_BY_TIME_RANGE` re-processes the affected window — re-runs are safe |
| Table dropped manually                  | `vulcan plan` will detect and re-create; or `vulcan run --rebuild <model>` to force                  |
| Wrong UC catalog applied                | Fix `DATABRICKS_CATALOG`, create a new `state_schema`, run `vulcan migrate`, re-apply                |
| PAT leaked or expired                   | Revoke PAT, issue new token, update `.env` / DataOS instance secret                                  |
| Workflow halted because `endOn` expired | Update the Vulcan resource with a new `endOn` and re-apply                                           |
| Depot not resolving                     | Verify depot `name` matches `dataos://<name>?purpose=rw` in the Vulcan resource manifest             |

***

## Section 10: Deployment recipes

### 10.1: Daily incremental Kimball (databricks\_tpch shape)

Daily incremental, Kimball-style project (10–30 models, UC catalog, `samples.tpch` or equivalent source):

```yaml
# config.yaml
name: tpch-databricks
default_gateway: databricks
model_defaults:
  dialect: databricks
  start: '2024-01-01'
  cron: '@daily'
concurrent_tasks: 2

gateways:
  databricks:
    connection:
      type: databricks
      server_hostname: <workspace-host>
      http_path: /sql/1.0/warehouses/<id>
      access_token: "{{ env_var('DATABRICKS_ACCESS_TOKEN', '') }}"
      catalog: "{{ env_var('DATABRICKS_CATALOG', 'main') }}"
    state_connection:
      type: postgres
      host: "{{ env_var('STATESTORE_HOST', 'localhost') }}"
      port: "{{ env_var('STATESTORE_PORT', '5432') }}"
      user: vulcan
      password: vulcan
      database: statestore
    state_schema: tpch_daily
```

```yaml
# Vulcan resource
spec:
  engine: databricks
  depots:
    - dataos://databricks-depot?purpose=rw
  workflow:
    schedule:
      crons: ['0 3 * * *']
      timezone: UTC
      endOn: '2027-01-01T00:00:00Z'
      concurrencyPolicy: Forbid
  api:
    replicas: 2
    resource:
      request: { cpu: "200m", memory: "512Mi" }
      limit:   { cpu: "2000m", memory: "1500Mi" }
```

### 10.2: Split build vs query warehouses

Build warehouse (Small) — plan, run, and incrementals.\
Query warehouse (Medium/Large) — semantic API and BI reads only.

```yaml
gateways:
  build:
    connection:
      type: depot
      address: dataos://databricks-build-depot
  query:
    connection:
      type: depot
      address: dataos://databricks-query-depot

api:
  replicas: 5
  resource:
    request: { cpu: "500m", memory: "1Gi" }
    limit:   { cpu: "4000m", memory: "3Gi" }
```

### 10.3: First-time backfill (multi-year history)

```yaml
# config.yaml — raise parallelism for backfill only
concurrent_tasks: 6

# Vulcan resource — one-shot trigger, no schedule
workflow:
  type: trigger
  resource:
    limit: { cpu: "2000m", memory: "2Gi" }
```

1. Temporarily scale up warehouse in Databricks UI before running
2. Run `vulcan apply` or trigger workflow
3. After the backfill completes, scale the warehouse back down and switch back to `type: schedule`

### 10.4: Local full stack (databricks\_tpch reference)

```bash
# Start Postgres statestore
docker run -d --name vulcan-state \
  -e POSTGRES_USER=vulcan -e POSTGRES_PASSWORD=vulcan \
  -e POSTGRES_DB=statestore -p 5432:5432 postgres:15

# Set env
export DATABRICKS_ACCESS_TOKEN=dapi<your-token>
export DATABRICKS_CATALOG=<your-catalog>

# Run
vulcan migrate
vulcan plan
# API: http://localhost:8000/redoc
```

***
