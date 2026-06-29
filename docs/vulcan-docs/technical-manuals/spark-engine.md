---
description: >-
  A Spark engine manual for DataOS Vulcan setup, development, deployment,
  operations, performance, and troubleshooting.
---

# Spark Engine

|                           |                                  |
| ------------------------- | -------------------------------- |
| **Template version**      | 2.0                              |
| **Engine**                | Apache Spark                     |
| **Tested Vulcan image**   | `tmdcio/vulcan-spark:0.228.1.23` |
| **Tested DataOS release** | Draco 1.38 series                |
| **Last updated**          | June 2026                        |

***

## How to use this manual

Use this manual as the working reference for shipping a Data Product on Apache Spark using DataOS. It assumes you already know the basics of Data Products and Vulcan. The structure stays consistent across engine manuals — only the Spark-specific content changes.

Use the path below that matches your role.

**If you are a data engineer setting up Vulcan on Spark for the first time:** section 2: Prerequisites (including pre-flight checklist) → section 3: LDK setup → section 10: Deployment recipes → section 7: Operational boundaries

**If you are a DP developer building or debugging a Data Product on Spark:** section 1: Snapshot → section 4: Vulcan on Spark (including subsection 4.7: Spark RDD with Iceberg tables) → section 9: Failure modes & troubleshooting

This manual is link-heavy by design. Every concept with an existing canonical page is summarized in one or two lines and linked. Section 11 is the full outbound link map.

***

## Section 1: Snapshot

This section is the fast path. If you only need the essentials, start here. It gives you the supported versions, key limits, runtime expectations, and the defaults you can rely on.

### **Architecture**

<figure><img src="../../../.gitbook/assets/image.png" alt=""><figcaption></figcaption></figure>

### **Version compatibility matrix**

| Vulcan image                     | DataOS release | Storage backend                      | Status            |
| -------------------------------- | -------------- | ------------------------------------ | ----------------- |
| `tmdcio/vulcan-spark:0.228.1.23` | Draco 1.38.x   | S3, ADLS Gen2 (Iceberg REST catalog) | ✅ Tested          |
| Earlier `0.228.1.x` builds       | Draco 1.37.x   | S3, ADLS Gen2                        | ⬜ Add when tested |
| `0.228.0.x`                      | Draco 1.36.x   | S3, ADLS Gen2                        | ⬜ Add when tested |

> GCS is **deferred** — out of scope for this manual version. S3 and ADLS Gen2 are the validated lakehouse paths.

| Item                         | Value                                                                                                                             |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Engine adapter type          | `spark`                                                                                                                           |
| Model dialect                | `spark2`                                                                                                                          |
| Support level                | GA for S3 and ADLS Gen2 lakehouse deployments                                                                                     |
| Tested Vulcan image          | `tmdcio/vulcan-spark:0.228.1.23`                                                                                                  |
| Serving images               | `tmdcio/vulcan-graphql:0.228.1.23`, `tmdcio/mysql-wire:0.0.8`                                                                     |
| Tested DataOS release        | Draco 1.38 series                                                                                                                 |
| Table format                 | Apache Iceberg through REST catalog                                                                                               |
| Object storage               | Amazon S3 and Azure ADLS Gen2                                                                                                     |
| Quality file format          | `kind: dq` YAML with `profiles:` and `rules:`                                                                                     |
| Semantic model format        | `kind: semantic` YAML with dimensions, measures, segments, joins, and optional `ai_context`                                       |
| Business metric format       | `kind: metric`, `name`, `measure`                                                                                                 |
| Supported model kinds        | FULL, VIEW, SEED / EMBEDDED, INCREMENTAL\_BY\_TIME\_RANGE, INCREMENTAL\_BY\_PARTITION, INCREMENTAL\_BY\_UNIQUE\_KEY, SCD\_TYPE\_2 |
| Unique-key upsert rule       | `INCREMENTAL_BY_UNIQUE_KEY` requires Iceberg `physical_properties`                                                                |
| Python runtime               | Spark DataFrame API (preferred); RDD API supported for legacy/custom logic; avoid Pandas for large model outputs                  |
| Python version               | 3.10 (local dev); runtime managed by image                                                                                        |
| Production deploy unit       | DataOS Vulcan resource (workflow + API)                                                                                           |
| Production state store       | External Postgres via `state_connection` (provisioned by SRE team)                                                                |
| Local state store            | DuckDB in local `config.yml`                                                                                                      |
| Required platform dependency | Tenant-level `vulcan-spark` stack                                                                                                 |
| Required storage dependency  | DataOS lakehouse resource + lakehouse depot                                                                                       |
| Dependency loading           | JARs from `dependencies/java/`, wheels from `dependencies/python/`                                                                |
| Main tuning levers           | Driver/executor resources, `sparkConf`, Iceberg commit retry, shuffle partitions                                                  |
| Identifier casing rule       | UPPERCASE in semantic models, filters, joins, DQ SQL, and metric expressions                                                      |

**SLOs you can commit to** (assumes recommended configuration in section 10 and workload validation in your tenant):

| SLO                                                              | Target                                                                     |
| ---------------------------------------------------------------- | -------------------------------------------------------------------------- |
| Daily incremental run success rate (stable upstream and compute) | ≥ 99%                                                                      |
| Plan/run driver startup success                                  | ≥ 99% after dependency and catalog validation                              |
| API track availability                                           | Same as DataOS service-level availability for the deployed Vulcan resource |
| Iceberg MERGE conflict recovery                                  | Commit retry configured before concurrent MERGE workloads go live          |
| Executor OOM rate                                                | 0 on representative production windows after sizing validation             |

> Spark performance is workload-shaped. A 10 GB dimension update, a 100 GB shuffle-heavy join, and a 1 TB backfill have different ceilings. Use section 6, section 8, and section 10 to size from the data shape, not from row count alone.

***

## Section 2: Prerequisites

What must be in place before you write a single line of Vulcan code: DataOS platform resources, lakehouse setup, and your local Python version.

### 2.1: Platform & storage permissions

Three roles are required, and each has a distinct scope.

| Role                    | Who holds it                           | Purpose                                                                                          |
| ----------------------- | -------------------------------------- | ------------------------------------------------------------------------------------------------ |
| **Admin role**          | DataOS / platform SRE                  | Provisions Spark compute pool, installs `vulcan-spark` stack, creates lakehouse resource + depot |
| **Vulcan service role** | The `runAsUser` in the Vulcan resource | Runs Spark jobs, writes Iceberg tables through the lakehouse depot                               |
| **Consumer role**       | BI users, endpoint consumers           | Read-only access to Data Product tables via Vulcan API endpoints                                 |

**Platform prerequisites (request from your DataOS SRE team):**

| Requirement                        | Notes                                                                                     |
| ---------------------------------- | ----------------------------------------------------------------------------------------- |
| Spark-capable compute pool         | Verify with `dataos-ctl resource -t compute get -a`; set `spec.compute` to this pool name |
| Tenant-level `vulcan-spark` stack  | Provides runtime image, serving sidecars, dependency loading, and catalog templating      |
| DataOS lakehouse resource          | Backed by S3 or ADLS Gen2 object storage                                                  |
| Lakehouse depot                    | Attached as `dataos://<depot>?purpose=rw` in the Vulcan resource                          |
| External Postgres for Vulcan state | `state_connection` in `config.yml`; provisioned by SRE team                               |
| Object-storage credentials         | Stored on the lakehouse/depot — never hard-coded in project code                          |
| Git-sync secret                    | Used by the Vulcan resource to pull model code                                            |

**Minimum object-storage grants by backend:**

```
S3:         s3:GetObject, s3:PutObject, s3:DeleteObject, s3:ListBucket on the warehouse bucket
ADLS Gen2:  Storage Blob Data Contributor on the container; Storage Account Key or SPN credentials on the depot
```

For the full permissions reference see [connect-to-engine/spark](spark-engine.md).

### 2.2: DataOS permissions

The following access must be provisioned by your DataOS operator before you can deploy or run a Vulcan Data Product.

| Permission                        | What it unlocks                                               | Who to request from                 |
| --------------------------------- | ------------------------------------------------------------- | ----------------------------------- |
| `roles:id:data-dev` or equivalent | Create and apply Vulcan resources (workflow, API)             | DataOS operator / admin             |
| Access to the target workspace    | Apply secrets, depots, and domain resources in that workspace | DataOS operator                     |
| `depot:rw:<lakehouse-depot-name>` | Read/write access to the lakehouse depot                      | DataOS operator                     |
| `depot:r:<lakehouse-depot-name>`  | Read-only access (consumer)                                   | DataOS operator                     |
| Git repository access             | Vulcan pulls model code via git-sync                          | Your VCS admin (GitHub / Bitbucket) |

> **Check your access** before starting. Run `dataos-ctl get depot` — if the lakehouse depot appears in the output, your read access is confirmed.

### 2.3: Python version

| Requirement                            | Version          |
| -------------------------------------- | ---------------- |
| Python (local development)             | **3.10**         |
| Python (Spark runtime in Vulcan image) | Managed by image |

```bash
python --version   # must be 3.10.x
```

### 2.4: Pre-flight checklist

#### Setup engineer checklist

**DataOS and lakehouse side**

* [ ] Spark-capable compute pool exists; name noted for `spec.compute`
* [ ] Tenant-level `vulcan-spark` stack is installed
* [ ] DataOS lakehouse resource exists (S3 or ADLS Gen2)
* [ ] Lakehouse depot exists and is attached as `dataos://<depot>?purpose=rw`
* [ ] Object-storage credentials are stored on the lakehouse/depot — not in project code
* [ ] Production Postgres `state_connection` is configured and reachable
* [ ] Git-sync secret exists and matches `spec.repo.secret`
* [ ] ADLS Azure Iceberg bundle JAR in `dependencies/java/` if using ADLS Gen2

**Local development**

* [ ] Docker stack starts: Spark master/worker, MinIO, Iceberg REST catalog, `vulcan-cli`
* [ ] Vulcan wheel matches `tmdcio/vulcan-spark:0.228.1.23`
* [ ] Local `config.yml` points to Spark master, Iceberg REST, and MinIO
* [ ] JAR and wheel dependencies present under `dependencies/java/` and `dependencies/python/`
* [ ] `vulcan plan` and at least one representative `vulcan run` succeed locally

**DataOS production**

* [ ] Vulcan resource has `spec.engine: spark`
* [ ] Driver and executor resources match the chosen workload tier (subsection 7.1)
* [ ] `sparkConf` includes AQE, coalescing, Kryo, and workload-specific shuffle settings
* [ ] MERGE-heavy workloads include Iceberg commit retry settings
* [ ] `timezone: UTC`; `endOn` ≥ 1–2 years out; `concurrencyPolicy: Forbid`
* [ ] API replicas and resources sized separately from workflow resources

#### Before you ship checklist (DP developer)

* [ ] Spark tables declare Iceberg `physical_properties`
* [ ] `INCREMENTAL_BY_UNIQUE_KEY` models use `table_format iceberg` or `physical_properties(format = 'iceberg')`
* [ ] `grains` align with `unique_key` on unique-key models
* [ ] Time-range incrementals filter by interval macros; `time_column` is UTC
* [ ] Python models return Spark DataFrames — not driver-collected Pandas frames
* [ ] All semantic model identifiers are UPPERCASE
* [ ] `kind: dq` files use fully qualified lakehouse table names
* [ ] `endOn` set and reviewed in the Vulcan resource schedule

***

## Section 3: Local Development Kit (LDK)

Step-by-step setup to run Vulcan locally against Spark. Complete section 2 before starting here.

### 3.1: Install Vulcan

Vulcan is distributed as a Python wheel (`.whl`) and installed directly via `pip`.

```bash
pip install vulcan_spark-<version>-py3-none-any.whl
```

Get the latest `.whl` for the Spark engine from your DataOS distribution channel. For the local Docker stack, place the wheel at the project root — the `vulcan-cli` container installs from it automatically.

```bash
vulcan --version   # verify after install
```

> Local Spark development requires Docker for the full infrastructure stack (Spark master/worker, MinIO, Iceberg REST). See subsection 3.2 for the Docker setup.

### 3.2: Set up local environment

The local stack mirrors production: a Spark standalone cluster, MinIO (S3-compatible), Iceberg REST catalog, and the Vulcan CLI as the Spark driver.

```bash
# Start local infrastructure
docker compose -f docker/docker-compose.yml up -d

# Fetch local test dependencies (JARs and wheels)
./scripts/fetch_test_dependencies.sh

# Set up the Vulcan CLI alias
alias vulcan='docker exec -i <project>-vulcan-cli vulcan'
```

**Local service map:**

| Service        | Image                                 | Host ports                 | Purpose                            |
| -------------- | ------------------------------------- | -------------------------- | ---------------------------------- |
| `spark-master` | `tmdcio/vulcan-spark-base:0.228.1.23` | 7077, 8080                 | Spark standalone master            |
| `spark-worker` | `tmdcio/vulcan-spark-base:0.228.1.23` | 8081                       | Local executor worker              |
| `minio`        | `minio/minio:latest`                  | 9000 (API), 9001 (console) | S3-compatible object storage       |
| `mc`           | `minio/mc:latest`                     | —                          | One-shot warehouse bucket creation |
| `iceberg-rest` | `tabulario/iceberg-rest:latest`       | 8181                       | Local Iceberg REST catalog         |
| `vulcan-cli`   | Python runtime + Vulcan wheel         | —                          | Vulcan CLI; acts as Spark driver   |

### 3.3: Configure config.yml

Minimum Spark connection config (local):

```yaml
gateways:
  default:
    connection:
      type: spark
      master: spark://spark-master:7077
      config:
        spark.sql.catalog.<depot>: org.apache.iceberg.spark.SparkCatalog
        spark.sql.catalog.<depot>.type: rest
        spark.sql.catalog.<depot>.uri: http://iceberg-rest:8181
        spark.sql.extensions: org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions
    state_connection:
      type: duckdb                            # local dev only
      database: /workspace/.state/local.db

default_gateway: default
model_defaults:
  dialect: spark2
  start: '2024-01-01'
```

> **`state_connection` is required for Spark.** Vulcan plan/interval state cannot live in the Iceberg catalog. Use DuckDB for local development. In production, the SRE team provisions an external Postgres — update `state_connection` to `type: postgres` for production `config.yml`.

> **The catalog block should not be hand-authored in production.** Attach the lakehouse depot in `spec.depots[]` and let the `vulcan-spark` stack generate the catalog config automatically. The local example above is for Docker-only development.

### 3.4: Validate your connection

```bash
vulcan migrate        # initializes Vulcan state in DuckDB (local) or Postgres (production)
vulcan plan           # dry run against the local Iceberg catalog — should succeed with no errors
vulcan run            # executes one representative model window to confirm end-to-end
```

If `vulcan plan` succeeds, your local setup is complete. Common failures at this step are covered in section 9 (F1–F5).

### 3.5: DataOS production deployment

Production deployment follows this apply order — each step depends on the previous:

```
Lakehouse resource → Lakehouse depot → Git secret → config.yml → Vulcan domain resource
```

| Manifest                                 | Purpose                                      | Key fields                                                                                                  |
| ---------------------------------------- | -------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Lakehouse resource                       | Object-storage-backed Iceberg storage        | S3 or ADLS Gen2 configuration                                                                               |
| Lakehouse depot                          | Exposes lakehouse to Spark and Vulcan        | `name`, `spec.type`, storage credentials, `purpose: rw`                                                     |
| `secret-git-sync.yaml`                   | Repo credentials for git-sync                | `GITSYNC_USERNAME`, `GITSYNC_PASSWORD`                                                                      |
| `config.yml`                             | Project config + production state connection | `engine: spark`, `state_connection` (Postgres), `model_defaults`                                            |
| `domain-resource.yaml` (Vulcan resource) | Spark driver + executors + API + schedule    | `spec.engine: spark`, `spec.compute`, `spec.depots`, `spec.workflow.resource`, `spec.api`, `spec.sparkConf` |

**Why order matters.** The `vulcan-spark` stack can only generate catalog config from a depot that already exists. The Vulcan resource can only sync code if the Git secret is available. A depot name mismatch in `spec.depots[]` passes `apply` but fails at every workflow run.

Reference configurations for all manifests: section 10.

### 3.6: Hello-world starter

Minimum viable Data Product on Spark. Requires the local Docker stack from subsection 3.2.

**`config.yml`**

```yaml
gateways:
  default:
    connection:
      type: spark
      master: spark://spark-master:7077
      config:
        spark.sql.extensions: org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions
        spark.sql.catalog.warehouse: org.apache.iceberg.spark.SparkCatalog
        spark.sql.catalog.warehouse.type: rest
        spark.sql.catalog.warehouse.uri: http://iceberg-rest:8181
        spark.sql.catalog.warehouse.warehouse: s3://warehouse/
        spark.sql.catalog.warehouse.io-impl: org.apache.iceberg.aws.s3.S3FileIO
        spark.sql.catalog.warehouse.s3.endpoint: http://minio:9000
    state_connection:
      type: duckdb
      database: /workspace/.state/local.db
default_gateway: default
model_defaults:
  dialect: spark2
  start: '2024-01-01'
```

**`models/orders.sql`**

```sql
MODEL (
  name warehouse.gold.orders,
  kind FULL,
  physical_properties (format = 'iceberg')
);
SELECT order_id, customer_id, total_price, order_date
FROM   warehouse.raw.orders
```

**`models/semantic/orders.yaml`**

```yaml
kind: semantic
name: ORDERS
depends_on: warehouse.gold.orders
dimensions:
  - ORDER_DATE
measures:
  - name: TOTAL_SALES
    type: sum
    expression: "{ORDERS.TOTAL_PRICE}"
```

**`metrics/daily_revenue.yaml`**

```yaml
kind: metric
name: DAILY_REVENUE
measure: ORDERS.TOTAL_SALES
ts: ORDERS.ORDER_DATE
granularity: day
```

Run `vulcan plan` — you should see `warehouse.gold.orders` staged. Run `vulcan run` to materialise it. Call the REST endpoint to confirm end-to-end behavior.

***

## Section 4: Vulcan on Spark

What changes when Spark is the engine: materialization strategies, Iceberg behavior, runtime ownership, and what does not work. For general Vulcan concepts and syntax, see the canonical docs linked in each sub-section.

> **Architectural constraints on Spark:**
>
> * Spark requires a DataOS compute pool — there is no warehouse-style serverless abstraction.
> * Production Vulcan state must live in an external Postgres database; Spark cannot hold plan/interval state internally.
> * The tenant-level `vulcan-spark` stack is a hard prerequisite — it owns the runtime image, serving sidecars, dependency loading, and catalog templating.
> * The lakehouse depot must exist before `vulcan apply`; the stack generates the Iceberg REST catalog configuration from it.
> * Iceberg commits are optimistic; concurrent writers to the same table can conflict.
> * API queries can trigger Spark jobs; Spark is not a sub-second serving engine for arbitrary semantic queries.

**Not supported on Spark via Vulcan**

| Feature                                      | Why not supported                                                           | Alternative                                                                           |
| -------------------------------------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| Spark compute lifecycle (create/resize/stop) | Vulcan has no compute pool management API                                   | Provision compute pools via DataOS admin or Terraform                                 |
| GCS object storage                           | Deferred in this manual version                                             | Use S3 or ADLS Gen2; file a request for GCS support                                   |
| Materialized views (Spark)                   | Not the default Spark/Iceberg path; version-dependent                       | Use `kind FULL` incremental models as materialized equivalents                        |
| Sub-second API serving for arbitrary queries | Spark/Iceberg is a batch/lakehouse engine — not optimized for point lookups | Pre-aggregate into a serving store or use a lower-latency engine for that surface     |
| Concurrent writes to the same Iceberg table  | Optimistic commit — concurrent MERGE writers can conflict                   | Use `concurrencyPolicy: Forbid` and stagger heavy writers; configure commit retry     |
| DLT / streaming tables                       | Separate concern; not in Vulcan's model kinds                               | Build streaming pipelines natively; land results as Iceberg tables for Vulcan to read |

### 4.1: Data movement

Before data can be transformed or served, it must be in the Iceberg lakehouse. This section covers how data arrives, what each depot purpose controls, and how consumers read the data.

**How data gets into the lakehouse — Nilus**

Nilus is the DataOS ingestion service that moves data from external sources, such as object stores, databases, SaaS APIs, and streams, into Iceberg tables in the lakehouse. Vulcan models then read these as sources. Vulcan does not move raw data — it transforms data that Nilus (or another pipeline) has already landed.

| Role           | Tool   | What it does                                                             |
| -------------- | ------ | ------------------------------------------------------------------------ |
| Ingestion      | Nilus  | Moves raw data into Iceberg Bronze/staging tables on S3 or ADLS Gen2     |
| Transformation | Vulcan | Transforms ingested data into Data Products (Silver/Gold Iceberg tables) |

**Spark lakehouse as a source vs. sink**

| Mode       | When it applies                                                                                     |
| ---------- | --------------------------------------------------------------------------------------------------- |
| **Sink**   | Nilus writes raw data into Iceberg; Vulcan materialises models into managed Iceberg tables          |
| **Source** | Vulcan reads Iceberg tables to build models; consumers query via endpoints or direct catalog access |

**Depot purposes**

| Purpose | Who uses it             | What it allows                                                                                            |
| ------- | ----------------------- | --------------------------------------------------------------------------------------------------------- |
| `rw`    | Vulcan workflow         | Read source tables, create and write model output Iceberg tables, manage schemas                          |
| `scan`  | DataOS metadata scanner | Read Iceberg REST catalog and object-storage metadata to populate the catalog and lineage (see section 5) |
| `query` | Consumer direct access  | Read-only access to Data Product tables; used for depot-issued credential access                          |

> Bind the correct purpose to each credential in the depot manifest. A `query`-purpose credential cannot create tables; an `rw` credential handed to a consumer is an over-permission risk.

Canonical pages: [Nilus](spark-engine.md) · [Depot configuration](spark-engine.md) · [Lakehouse resource](spark-engine.md)

### 4.2: Models

#### 4.2.1: Data Models

SQL models compile to Spark SQL and write Iceberg tables through the lakehouse REST catalog. The Vulcan workflow acts as the Spark driver; executors perform scans, joins, shuffles, and writes.

| Model kind                   | Spark / Iceberg operation                       | Notes                                                                          |
| ---------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------ |
| FULL                         | Insert overwrite / replace target content       | Good for small tables, derived aggregates, and rebuildable marts               |
| VIEW                         | Spark view (where supported by catalog/runtime) | Staging and intermediate layer                                                 |
| SEED / EMBEDDED              | File-backed or embedded reference data          | Useful for small reference tables                                              |
| INCREMENTAL\_BY\_TIME\_RANGE | Insert overwrite by time-window partition       | Keep `time_column` UTC; filter source by interval macros                       |
| INCREMENTAL\_BY\_PARTITION   | Insert overwrite by partition key               | Best when partition key is the natural restatement boundary                    |
| INCREMENTAL\_BY\_UNIQUE\_KEY | Iceberg `MERGE INTO`                            | Requires Iceberg `physical_properties`; supports upsert and conditional delete |
| SCD\_TYPE\_2                 | Spark/Iceberg slowly changing dimension         | Use for dimension history where current and historical values both matter      |

**Production model example:**

```sql
MODEL (
  name lakehouse_depot.tpch_lakehouse.customer_360,
  kind FULL,
  owner 'data-product-owner',
  grains (customer_key),
  physical_properties (
    format = 'iceberg',
    'write.format.default' = 'parquet',
    'write.parquet.compression-codec' = 'snappy'
  ),
  assertions (
    unique_values(columns := customer_key),
    not_null(columns := (customer_key, customer_name))
  )
);
SELECT
  cn.c_custkey                                               AS customer_key,
  cn.c_name                                                  AS customer_name,
  cn.c_mktsegment                                            AS market_segment,
  COUNT(DISTINCT oi.l_orderkey)                              AS order_count,
  COALESCE(SUM(oi.net_amount), 0)                            AS total_revenue
FROM lakehouse_depot.tpch_lakehouse.int_customer_nation cn
LEFT JOIN lakehouse_depot.tpch_lakehouse.int_order_items oi
  ON oi.o_custkey = cn.c_custkey
GROUP BY cn.c_custkey, cn.c_name, cn.c_mktsegment;
```

**Python models** should return a Spark DataFrame. Use `context.spark.sql()` or the DataFrame API. Do not convert large inputs to Pandas on the driver — this pulls data to the driver and causes OOM.

```python
from vulcan import ExecutionContext, ModelKindName, model

@model(
    "warehouse.gold.catalog_search",
    columns={"table_name": "string", "row_count": "long"},
    kind=dict(name=ModelKindName.FULL),
)
def execute(context: ExecutionContext, start, end, execution_time, **kwargs):
    source_df = context.spark.sql("SELECT * FROM warehouse.default.part")
    # Single-row summary — Pandas is fine here
    import pandas as pd
    return pd.DataFrame([{"table_name": "warehouse.default.part", "row_count": source_df.count()}])
```

> For models that produce large outputs, always return a Spark DataFrame. A Pandas return is only safe when the output is a bounded summary (e.g. one row).

**Rule: Declare Iceberg physical properties**

All production Spark tables should explicitly declare the Iceberg format:

```sql
physical_properties (
  format = 'iceberg',
  'write.format.default' = 'parquet',
  'write.metadata.compression-codec' = 'gzip',
  'write.parquet.compression-codec' = 'snappy'
)
```

**Rule: Unique-key incrementals require Iceberg**

`INCREMENTAL_BY_UNIQUE_KEY` compiles to Iceberg `MERGE INTO`. Add `physical_properties(format = 'iceberg')` or `table_format iceberg`, and align `grains` with `unique_key`. Without this, the model silently does nothing.

**Rule: Ship dependencies with the project**

Place JVM dependencies under `dependencies/java/` and Python wheels under `dependencies/python/`. The stack loads them for driver and executors automatically.

Canonical pages: [SQL models](spark-engine.md) · [Python models](spark-engine.md) · [Model kinds](spark-engine.md)

#### 4.2.2: Semantic Models

Semantic models on Spark wrap Vulcan-managed Iceberg tables and expose dimensions, measures, segments, and joins to API and SQL-wire consumers. The API track translates semantic queries into Spark/Iceberg reads.

**Identifier casing.** Use UPPERCASE dimensions and measure expressions to match the physical column casing in the underlying Iceberg tables (as aliased in staging models).

```yaml
kind: semantic
name: CUSTOMER_ORDERS_SUMMARY
depends_on: lakehouse_depot.tpch_lakehouse.customer_360
dimensions:
  - MARKET_SEGMENT
measures:
  - name: TOTAL_REVENUE
    type: sum
    expression: "{CUSTOMER_ORDERS_SUMMARY.TOTAL_REVENUE}"
  - name: CUSTOMER_COUNT
    type: count_distinct
    expression: "{CUSTOMER_ORDERS_SUMMARY.CUSTOMER_KEY}"
segments:
  - name: positive_balance
    expression: "{CUSTOMER_ORDERS_SUMMARY.ACCT_BAL} > 0"
```

Semantic queries execute against Iceberg tables and can launch Spark jobs. Declare explicit joins in semantics; cross-join-shaped queries are the biggest avoidable latency risk on Spark.

Canonical pages: [Semantic models](spark-engine.md) · [Business metrics](spark-engine.md)

#### 4.2.3: Metrics

A metric is a YAML manifest that references a measure already defined in a semantic model. Vulcan compiles it to a Spark SQL aggregation executed against Iceberg.

```yaml
kind: metric
name: DAILY_REVENUE
measure: CUSTOMER_ORDERS_SUMMARY.TOTAL_REVENUE
ts: CUSTOMER_ORDERS_SUMMARY.ORDER_DATE
granularity: day
dimensions:
  - name: MARKET_SEGMENT
    ref: CUSTOMER_ORDERS_SUMMARY.MARKET_SEGMENT
```

Two Spark-specific behaviors matter at runtime:

**`COUNT(DISTINCT …)` over large Iceberg tables** is shuffle-heavy and is the primary compute sizing driver. Size up executors or pre-aggregate distinct counts into a mart before rewriting the metric.

**Identifier casing in metric filters** follows the same UPPERCASE rule as semantic models (subsection 4.2.2). Lowercase column references in `filters` or `expressions` will cause "column not found" errors.

Canonical page: [Business metrics](spark-engine.md)

### 4.3: Data Quality

Vulcan quality is layered on Spark. Live checks execute as Spark SQL against Iceberg tables and consume compute from the workflow run or quality track.

| Layer                                   | Where it runs                                  | Spark cost                | When it catches a problem                 |
| --------------------------------------- | ---------------------------------------------- | ------------------------- | ----------------------------------------- |
| Linter                                  | Locally, before Spark execution                | None                      | Authoring time                            |
| Unit tests (`tests/`)                   | Locally (DuckDB in-process)                    | No cluster cost           | Pre-deploy logic regressions              |
| Assertions (built-in or `audits/*.sql`) | Spark after the model materializes             | One Spark query per audit | Every run, blocking                       |
| Data quality (`kind: dq`, `dq/*.yml`)   | Spark SQL after model execution or on schedule | One or more Spark jobs    | Observability, drift, freshness, accuracy |

An assertion attaches an audit (the validation rule) to a model. Built-in audits like `not_null(...)` and user-defined audits in `audits/*.sql` are both invoked from the model's `assertions (...)` block and share the same post-materialization execution phase.

**Rule: Assertions for blocking contract checks; `kind: dq` for observability**

Use `assertions` inside `MODEL(...)` for invariants that make the table unsafe if they fail (primary key uniqueness, required columns, non-negative measures). Use `kind: dq` for non-blocking drift, freshness, and distribution checks.

```yaml
# Example kind: dq file
kind: dq
name: customer_360_dq
depends_on: lakehouse_depot.tpch_lakehouse.customer_360
profiles:
  - order_count
  - total_revenue
  - market_segment
rules:
  - row_count > 0:
      name: customer_360_not_empty
      dimension: completeness
  - missing_count(customer_key) = 0:
      name: no_missing_customer_key
      dimension: completeness
  - failed rows:
      name: negative_revenue
      dimension: accuracy
      fail query: |
        SELECT customer_key, total_revenue
        FROM lakehouse_depot.tpch_lakehouse.customer_360
        WHERE total_revenue < 0
      samples limit: 10
```

Spark-specific DQ notes:

* Keep `failed rows` queries narrow, and always set `samples limit` so incident payloads stay bounded
* Profile only operationally useful columns — profiling high-cardinality string columns on large Iceberg tables is expensive
* Use fully qualified lakehouse table names in all DQ and audit SQL
* For partitioned Iceberg tables, add partition predicates to DQ/audit SQL where the rule only needs the latest window

Canonical pages: [Tests](spark-engine.md) · [Audits](spark-engine.md) · [Data quality](spark-engine.md)

### 4.4: Lineage & version rollback

Lineage is computed from Vulcan's parsed model graph — Spark does not infer missing lineage from the Iceberg catalog automatically. Declare external tables in `external_models.yaml` and keep fully qualified lakehouse names consistent across models, DQ files, and semantic files.

Rollback replays the previous materialization strategy and produces new Iceberg snapshots. For `INCREMENTAL_BY_UNIQUE_KEY`, plan rollbacks carefully — the MERGE path is not a cheap metadata pointer flip; it consumes Spark compute and creates Iceberg commits.

**Rule: Declare external Iceberg sources**

`vulcan create_external_models` may not discover tables from external catalogs or source systems. Declare them manually:

```yaml
- name: lakehouse_depot.tpch_lakehouse.int_customer_nation
  columns:
    c_custkey:    BIGINT
    c_name:       STRING
    c_mktsegment: STRING
```

Without the declaration, the linter throws `Table not found` and lineage stops at the model boundary.

### 4.5: Endpoints (REST, GraphQL, MySQL-wire)

The Spark stack serves API traffic through three dedicated serving images on the deployed `api` track:

| Endpoint   | Runtime image                                 |
| ---------- | --------------------------------------------- |
| REST       | Vulcan API (`tmdcio/vulcan-spark:0.228.1.23`) |
| GraphQL    | `tmdcio/vulcan-graphql:0.228.1.23`            |
| MySQL-wire | `tmdcio/mysql-wire:0.0.8` (port 3306)         |

Endpoint queries read the semantic layer and push execution to Spark/Iceberg. Size the API track separately from the workflow cluster, but remember that expensive semantic queries still consume Spark compute. Keep `api.limit.memory ≥ 1.5 GiB` (recommended 2 GiB) to avoid OOM on large result sets.

Canonical pages: [REST](spark-engine.md) · [GraphQL](spark-engine.md) · [MySQL wire](spark-engine.md)

### 4.6: MCP tools

| MCP tool   | Spark behavior                                      |
| ---------- | --------------------------------------------------- |
| `about`    | Static — no engine call                             |
| `lineage`  | Parsed graph — no live Spark job                    |
| `quality`  | Last check/audit results — typically no live call   |
| `data`     | Live Spark/Iceberg query — consumes compute         |
| `run`      | Triggers workflow — same cost as a scheduled run    |
| `activity` | Reads workflow history from DataOS — no engine call |

Treat agent-driven `data` tool queries like production dashboard queries. They can trigger Spark scans, shuffles, and Iceberg reads through the semantic layer.

Canonical pages: [Build-time MCP tools](spark-engine.md) · [Runtime MCP tools](spark-engine.md)

### 4.7: Spark RDD with Iceberg tables

This section covers the basic syntax for using Spark Core RDD APIs with data stored in Iceberg tables. The pattern is straightforward: read the Iceberg table as a Spark DataFrame, convert it to an RDD, apply standard RDD operations, then optionally convert the result back to a DataFrame and write it to Iceberg.

> **Prefer DataFrames for Vulcan models.** RDD APIs are lower-level and bypass the Catalyst optimizer and Iceberg column pruning. Use RDDs only when you need legacy Spark Core logic, custom partition processing, or PairRDD aggregations that are awkward in the DataFrame API. For production Vulcan Python models, return a Spark DataFrame (subsection 4.2.1).

#### 4.7.1: Read an Iceberg table as an RDD

```python
df = spark.read.table("warehouse.staging.sample_products")
rdd = df.rdd
```

Use fully qualified lakehouse table names (`<catalog>.<schema>.<table>`) consistent with your depot catalog name.

#### 4.7.2: Basic RDD actions

```python
row_count = rdd.count()
all_rows = rdd.collect()
first_row = rdd.first()
first_five = rdd.take(5)
```

Access row fields:

```python
name_by_column = first_row["product_name"]
name_by_index = first_row[1]
```

> Avoid `collect()` on large Iceberg tables — it pulls all partitions to the driver and causes OOM (same rule as `toPandas()` in subsection 4.2.1).

#### 4.7.3: RDD transformations

```python
names = rdd.map(lambda row: row["product_name"])

electronics = rdd.filter(
    lambda row: row["category"] == "Electronics"
)

tokens = rdd.flatMap(
    lambda row: row["product_name"].split()
)

partition_counts = rdd.mapPartitions(
    lambda rows: [sum(1 for _ in rows)]
)
```

#### 4.7.4: PairRDD operations

```python
pair_rdd = rdd.keyBy(lambda row: row["category"])

category_totals = (
    pair_rdd
    .mapValues(lambda row: float(row["price"]))
    .reduceByKey(lambda a, b: a + b)
)
```

Other PairRDD operations:

```python
grouped = pair_rdd.groupByKey()

averages = (
    pair_rdd
    .mapValues(lambda row: float(row["price"]))
    .aggregateByKey(
        (0.0, 0),
        lambda acc, price: (acc[0] + price, acc[1] + 1),
        lambda left, right: (left[0] + right[0], left[1] + right[1]),
    )
    .mapValues(lambda acc: acc[0] / acc[1])
)

counts = pair_rdd.countByKey()
```

#### 4.7.5: RDD persistence

```python
from pyspark import StorageLevel

cached_rdd = rdd.cache()
cached_rdd.count()

persisted_rdd = rdd.persist(StorageLevel.MEMORY_AND_DISK)
persisted_rdd.count()

cached_rdd.unpersist()
persisted_rdd.unpersist()
```

Cache or persist the RDD when it is reused across multiple actions. Unpersist when done to free executor memory.

#### 4.7.6: RDD to DataFrame

```python
from pyspark.sql import Row
from pyspark.sql.types import StructType, StructField, StringType, DoubleType

totals_rdd = category_totals.map(
    lambda item: Row(
        category=item[0],
        total_price=float(item[1]),
    )
)

schema = StructType([
    StructField("category", StringType(), nullable=False),
    StructField("total_price", DoubleType(), nullable=False),
])

result_df = spark.createDataFrame(totals_rdd, schema)
```

#### 4.7.7: Write back to Iceberg

```python
result_df.writeTo(
    "warehouse.staging.category_price_totals"
).createOrReplace()
```

Or, depending on Spark/Iceberg version:

```python
result_df.write \
    .format("iceberg") \
    .mode("overwrite") \
    .saveAsTable("warehouse.staging.category_price_totals")
```

Declare Iceberg `physical_properties` on the target table when writing from Vulcan models (subsection 4.2.1). For ad-hoc RDD pipelines outside Vulcan model manifests, ensure the target namespace exists in the REST catalog and the Vulcan service role has `rw` depot access.

#### 4.7.8: SparkContext interop

```python
from pyspark.sql import Row

sc = spark.sparkContext

synthetic_rdd = sc.parallelize([
    Row(product_id="P009", product_name="Stapler", category="Stationery", price=8.25)
])

combined = rdd.union(synthetic_rdd)

broadcast_categories = sc.broadcast(
    set(rdd.map(lambda row: row["category"]).distinct().collect())
)

filtered = rdd.filter(
    lambda row: row["category"] in broadcast_categories.value
)

counter = sc.accumulator(0)
rdd.foreach(lambda row: counter.add(1))
```

Use broadcast variables for small lookup sets. Accumulators are write-only from executors; read the value only after the action completes.

#### 4.7.9: Scala equivalent for row access

```scala
val df = spark.read.table("warehouse.staging.sample_products")
val rdd = df.rdd
val first = rdd.first()
val nameByColumn = first.getAs[String]("product_name")
val nameByIndex = first(1)
```

***

## Section 5: Metadata scanning & catalog

DataOS scans two Spark/Iceberg sources: the Iceberg REST catalog (real-time structural metadata — tables, schemas, columns, partition specs) and object-storage scan logs or Iceberg history (lineage).

### 5.1: What shows up

| Object                             | Catalog                      | Lineage             |
| ---------------------------------- | ---------------------------- | ------------------- |
| Namespaces (schemas)               | ✓                            | —                   |
| Iceberg tables                     | ✓                            | ✓ as nodes          |
| Columns with types                 | ✓                            | ✓ column-level      |
| Partition specs                    | ✓ as metadata                | —                   |
| Lineage edges (from parsed models) | —                            | ✓ from Vulcan parse |
| Iceberg snapshots / history        | Partially shown              | Used internally     |
| Views                              | Ingested if catalog supports | ✓ if declared       |

Lineage is primarily Vulcan-computed — DataOS parses the model SQL graph and `external_models.yaml`. Iceberg metadata contributes snapshot and schema evolution history.

### 5.2: Scanner permissions

The scanner role is read-only and separate from the Vulcan service role.

```
Iceberg REST catalog:   GET /v1/catalogs/*, /v1/namespaces/*, /v1/tables/*
S3:                     s3:GetObject, s3:ListBucket on the warehouse bucket
ADLS Gen2:              Storage Blob Data Reader on the container
```

Grant the scanner principal read access to the lakehouse depot with `purpose: scan`.

### 5.3: Refresh & lag

Scanner runs every 6–12 hours (configurable). Structural changes (new tables, columns) appear after the next scan. Lineage from model runs is computed from Vulcan's SQL parse and is available immediately after a successful `vulcan run`. Iceberg snapshot-level lineage (e.g. partition evolution) may lag behind the catalog scan cycle.

***

## Section 6: Engine-native feature support

Which Spark and Iceberg objects you can drive from a Vulcan Data Product, and where each capability belongs.

| Spark / Iceberg feature            | Vulcan pattern                                                          | Notes                                                               |
| ---------------------------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Spark runtime                      | Tenant-level `vulcan-spark` stack                                       | Configured once per tenant by SRE                                   |
| Spark driver                       | `spec.workflow.resource.driver`                                         | Runs migrate, plan, run                                             |
| Spark executors                    | `spec.workflow.resource.executor`                                       | Distributed scan, shuffle, join, write                              |
| Iceberg REST catalog               | Lakehouse depot in `spec.depots[]`                                      | Stack generates `spark.sql.catalog.*` automatically                 |
| S3 object storage                  | Lakehouse with `storageType: s3`                                        | Uses `S3FileIO`                                                     |
| ADLS Gen2 object storage           | Lakehouse with `storageType: abfss`                                     | Uses `ADLSFileIO`; may need Azure bundle JAR                        |
| Full-refresh Iceberg table         | kind `FULL` + `physical_properties(format = 'iceberg')`                 | Rebuildable; good for aggregates and marts                          |
| Time-range incremental             | `INCREMENTAL_BY_TIME_RANGE`                                             | Insert overwrite by interval partition                              |
| Partition incremental              | `INCREMENTAL_BY_PARTITION`                                              | Insert overwrite by partition key                                   |
| Unique-key upsert                  | `INCREMENTAL_BY_UNIQUE_KEY` + `physical_properties(format = 'iceberg')` | Compiles to Iceberg `MERGE INTO`                                    |
| Conditional delete/update in MERGE | `when_matched` inside unique-key model                                  | Uses `source.` and `target.` aliases                                |
| SCD Type 2                         | `SCD_TYPE_2` kind                                                       | Dimension history with current and historical rows                  |
| View                               | kind `VIEW`                                                             | Staging / intermediate layer                                        |
| SEED / EMBEDDED                    | kind `SEED` or `EMBEDDED`                                               | File-backed reference data                                          |
| Python models (Spark DataFrame)    | `.py` model returning `SparkDataFrame`                                  | Return Spark DataFrames; avoid Pandas for large outputs             |
| Spark RDD with Iceberg             | Read DataFrame → `.rdd` → RDD ops → DataFrame → Iceberg write           | Lower-level; prefer DataFrame API in Vulcan models (subsection 4.7) |
| JVM dependencies                   | `dependencies/java/`                                                    | JARs auto-loaded by stack for driver + executors                    |
| Python wheel dependencies          | `dependencies/python/`                                                  | Wheels auto-loaded by stack                                         |
| Spark tuning                       | `spec.sparkConf`                                                        | Merged with generated catalog config                                |
| Serving                            | `spec.api` + sidecar images                                             | REST, GraphQL, MySQL-wire                                           |
| GCS object storage                 | Deferred                                                                | Out of scope for this manual version                                |
| Spark compute lifecycle            | Boundary                                                                | Provision compute pools via DataOS admin                            |
| DLT / Streaming tables             | Boundary                                                                | Separate concern; land results as Iceberg tables                    |

**Guard rule for lifecycle DDL.** Wrap `pre_statements` / `post_statements` that should only run on real execution:

```sql
@IF(@runtime_stage = 'evaluating',
  ALTER TABLE lakehouse_depot.gold.orders SET TBLPROPERTIES ('write.metadata.delete-after-commit.enabled' = 'true')
);
```

Without the guard, `vulcan plan` dry-runs will execute it.

***

## Section 7: Operational boundaries

Concrete settings with hard thresholds. Treat this as an engineering contract; tune from the Spark UI and DataOS telemetry.

### 7.1: Driver and executor sizing

| Workload                           | Starting shape                                     | Rationale                                                 |
| ---------------------------------- | -------------------------------------------------- | --------------------------------------------------------- |
| Dev / local plan (\~1 GB)          | 1 driver, 1 worker                                 | Validate syntax, catalog, and small data paths            |
| Small production models (\~1 GB)   | Driver: 1 core / 2G; Executor: 2× 2 cores / 4G     | Mostly scheduler and catalog overhead                     |
| Medium production models (\~10 GB) | Driver: 2 cores / 4G; Executor: 3× 2 cores / 4G    | Enough parallelism for moderate joins                     |
| Large production models (\~100 GB) | Driver: 2 cores / 6G; Executor: 4× 3 cores / 6G    | Baseline for shuffle-heavy lakehouse workloads            |
| XL backfill (\~1 TB)               | Driver: 4 cores / 8G; Executor: 8–16× 4 cores / 8G | Scale executor instances after tuning shuffle/read splits |

> Executor parallelism ≈ `executor.cores × executor.instances`. Add 10–15% memory overhead for runtime. Fix shuffle partitions and AQE before adding more executors.

### 7.2: Spark tuning

| Setting                                         | Guidance                                                      |
| ----------------------------------------------- | ------------------------------------------------------------- |
| `spark.sql.shuffle.partitions`                  | First lever for shuffle-heavy stages; raise when stages spill |
| `spark.sql.adaptive.enabled`                    | Keep `true` for Spark/Iceberg workloads                       |
| `spark.sql.adaptive.coalescePartitions.enabled` | Keep `true` to reduce tiny output files                       |
| `spark.sql.adaptive.skewJoin.enabled`           | Enable for skewed joins and straggler stages                  |
| `spark.sql.files.maxPartitionBytes`             | Raise for huge scans; lower if executors OOM                  |
| `spark.serializer`                              | Use `org.apache.spark.serializer.KryoSerializer`              |
| `spark.sql.catalog.<depot>.commit.retry.*`      | Configure for concurrent MERGE / Iceberg commit conflicts     |

**Tuning order:** shuffle partitions → AQE + coalescing → skew join handling → `maxPartitionBytes` → executor memory/instances → Iceberg commit retry.

### 7.3: API replicas & Kubernetes resources

| Traffic                           | API replicas |
| --------------------------------- | ------------ |
| Single team                       | 1–2          |
| Multi-team / scheduled dashboards | 3–5          |
| Enterprise / high-volume          | 5+           |

The API track is sized separately from the Spark workflow cluster.

```yaml
# api track
api:
  replicas: 2
  resource:
    request: { cpu: "200m", memory: "512Mi" }
    limit:   { cpu: "2000m", memory: "2Gi" }
```

Add API replicas for request concurrency. Add workflow executors for Spark query execution. These address different bottlenecks.

### 7.4: Scheduling

| Recommendation                     | Why                                                            |
| ---------------------------------- | -------------------------------------------------------------- |
| Schedule after upstream files land | Avoid partial reads and unnecessary restatements               |
| `timezone: UTC`                    | Avoid DST-shifted intervals                                    |
| `concurrencyPolicy: Forbid`        | Prevent overlapping Spark writers and Iceberg commit conflicts |
| Set `endOn` ≥ 1–2 years out        | Expired schedules stop silently                                |
| Stagger MERGE-heavy models         | Avoid concurrent commits on shared Iceberg targets             |

### 7.5: Latency floor

| Component                           | Floor                                               |
| ----------------------------------- | --------------------------------------------------- |
| Spark application startup           | Driver + executor startup + dependency load         |
| Iceberg REST catalog metadata calls | Round trips to catalog and object storage           |
| Object-storage listing/read latency | S3/ADLS path and file-count dependent               |
| API query overhead                  | Parsing, planning, and result serialization         |
| Small-file overhead                 | Many tiny files increase metadata and task overhead |

If your downstream SLO is sub-second, Spark/Iceberg is the wrong serving path. Pre-aggregate, cache into a serving store, or use a lower-latency engine for that surface.

### 7.6: Operational limitations

| #  | Limitation                                                                         | Workaround                                                                          |
| -- | ---------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| O1 | ADLS classes missing at runtime (`NoClassDefFoundError: DataLakeStorageException`) | Add the Azure Iceberg bundle JAR under `dependencies/java/`                         |
| O2 | Unique-key model does not upsert                                                   | Add `physical_properties(format = 'iceberg')` to the model definition               |
| O3 | Delete tombstones insert rows for missing keys                                     | Filter tombstones before MERGE or handle downstream                                 |
| O4 | JVM / Python dependencies missing on executors                                     | Place JARs/wheels under `dependencies/` and redeploy                                |
| O5 | Many tiny output files slow subsequent queries                                     | Keep AQE coalescing enabled; tune `shuffle.partitions`                              |
| O6 | Python model OOM — driver collection                                               | Return Spark DataFrames from Python models; avoid Pandas for large outputs          |
| O7 | Schedule overlap causes Iceberg commit conflict                                    | Use `concurrencyPolicy: Forbid` and stagger writers                                 |
| O8 | Local `vulcan run` succeeds but production fails state migration                   | Configure production Postgres `state_connection`; run `vulcan migrate` after fixing |
| O9 | First job after idle period is slow                                                | Spark startup + dependency load; document in SLO or pre-warm                        |

***

## Section 8: Performance & Cost

How fast this engine runs and what it costs. Use subsection 8.1 to set SLO expectations and size compute. Use subsection 8.2 to put guardrails in place before going to production.

### 8.1: Benchmarks

> Spark benchmark results depend strongly on data size, file layout, partitioning, shuffle width, object-storage latency, and executor shape. Use the tiers below as planning baselines, and **validate on tenant data before publishing SLOs externally.**

#### 8.1.1: Reference sizing tiers

| Tier | Approx data | Driver       | Executor           | Total exec cores | `shuffle.partitions` | `maxPartitionBytes` | Expected complex-join time |
| ---- | ----------- | ------------ | ------------------ | ---------------- | -------------------- | ------------------- | -------------------------- |
| S    | \~1 GB      | 1 core / 2G  | 2× 2 cores / 4G    | 4                | 64–100               | 128 MB              | seconds–\~1 min            |
| M    | \~10 GB     | 2 cores / 4G | 3× 2 cores / 4G    | 6                | 200                  | 128 MB              | \~1–3 min                  |
| L    | \~100 GB    | 2 cores / 6G | 4× 3 cores / 6G    | 12               | 200–400              | 128 MB              | \~5–15 min                 |
| XL   | \~1 TB      | 4 cores / 8G | 8–16× 4 cores / 8G | 32–64            | 1000–2000            | 256 MB              | \~30–90 min                |

These are planning starting points for TPC-H-shaped joins on Iceberg over object storage, with AQE enabled.

#### 8.1.2: What to measure

| Metric                   | Why it matters                                          |
| ------------------------ | ------------------------------------------------------- |
| Driver startup time      | Captures dependency load and Spark app startup overhead |
| Executor allocation time | Detects compute capacity pressure                       |
| Shuffle read/write size  | Main predictor of runtime and spill                     |
| Spill to disk            | Indicates memory or partitioning pressure               |
| Straggler tasks          | Indicates skew or bad partitioning                      |
| Output file count        | Indicates small-file risk                               |
| Iceberg commit duration  | Detects catalog/storage commit bottlenecks              |

#### 8.1.3: Validation loop

1. Pick the closest tier from subsection 8.1.1
2. Run a representative `vulcan plan` + `vulcan run` window
3. Inspect Spark UI for spill, stragglers, executor OOM, shuffle size
4. Apply one tuning change from subsection 7.2
5. Re-run the same window and compare
6. Record the stable driver/executor/`sparkConf` combination as the workload baseline

#### 8.1.4: Concurrency fix order

When concurrency degrades:

1. Prevent overlapping writers to the same Iceberg target (`concurrencyPolicy: Forbid`)
2. Add Iceberg commit retry for MERGE workloads
3. Stagger heavy schedules
4. Increase executor instances
5. Split workloads across compute pools only after query shape and scheduling are clean

#### 8.1.5: Performance ceilings

| #  | Ceiling                                                 | Tune via                                                          |
| -- | ------------------------------------------------------- | ----------------------------------------------------------------- |
| P1 | Shuffle-heavy joins spill to disk                       | Increase `shuffle.partitions`, executor memory, and skew handling |
| P2 | Object-storage small files dominate planning            | Keep AQE coalescing enabled; compact/rewrite tables when needed   |
| P3 | High-cardinality semantic queries run slowly            | Pre-aggregate marts; constrain governed query shapes              |
| P4 | Iceberg MERGE commit conflicts under concurrent writers | Stagger writers; raise `commit.retry.*` values                    |
| P5 | Executor OOM on wide scans                              | Lower `maxPartitionBytes` or raise executor memory                |
| P6 | Low cluster utilization                                 | Reduce executor instances or increase partition parallelism       |

### 8.2: Cost guardrails

Spark costs come from compute lifetime, object-storage operations, metadata growth, and API query concurrency.

#### 8.2.1: Size from telemetry, not instinct

If stages spill, tune shuffle partitions and memory before adding executors. If executors sit idle, reduce instances. Use the Spark UI as the primary sizing signal.

#### 8.2.2: Prevent overlapping runs

Use `concurrencyPolicy: Forbid` for all scheduled workflows. Overlapping runs are expensive and can conflict on Iceberg commits.

#### 8.2.3: Cost attribution (query tagging)

Where supported, tag Spark sessions to attribute spend by project and model:

```python
# In Python model or lifecycle hook
context.spark.conf.set("spark.sql.session.description", "vulcan:<project>:<model>")
```

See [Track cost by Data Product](spark-engine.md).

#### 8.2.4: Storage cost management

* Keep AQE coalescing enabled to control output file counts
* Run `VACUUM` on high-churn Iceberg tables to reclaim deleted-file storage
* Set Bronze/staging tables with short snapshot retention where data can be re-derived
* Partition deliberately — over-partitioning creates small files; under-partitioning forces full scans

Canonical pages: [Chargeback](spark-engine.md) · [Track cost by Data Product](spark-engine.md) · [Track cost by tenant](spark-engine.md)

***

## Section 9: Failure modes & troubleshooting

The top 15 errors when running a Data Product on Spark, with causes and fixes.

| #   | Symptom                                          | Likely cause                                             | Fix                                                                                        |
| --- | ------------------------------------------------ | -------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| F1  | Unique-key model "does nothing"                  | Iceberg format missing from model                        | Add `physical_properties(format = 'iceberg')` to the model                                 |
| F2  | `NoClassDefFoundError: DataLakeStorageException` | ADLS FileIO classes missing from classpath               | Add `iceberg-azure-bundle` JAR under `dependencies/java/`                                  |
| F3  | Dependency not available in model or at runtime  | JAR/wheel not shipped or not imported                    | Place artifact under `dependencies/java/` or `dependencies/python/`; redeploy              |
| F4  | `CommitFailedException` (Iceberg)                | Concurrent writers to the same Iceberg table             | Raise commit retry settings and stagger schedules (`concurrencyPolicy: Forbid`)            |
| F5  | Delete tombstones appear as rows after MERGE     | Missing-key DELETE falls through to implicit insert      | Filter tombstones before MERGE or handle downstream                                        |
| F6  | Many tiny output files slow subsequent queries   | Shuffle partitions too high or AQE coalescing disabled   | Keep AQE coalescing enabled; tune `spark.sql.shuffle.partitions`                           |
| F7  | One task runs far longer than all others         | Skewed join key                                          | Enable skew join handling (`spark.sql.adaptive.skewJoin.enabled`) and review join strategy |
| F8  | Executor OOM                                     | Partitions too large or executor memory too low          | Lower `maxPartitionBytes` or raise executor memory                                         |
| F9  | Driver OOM                                       | Python model collects large DataFrame to driver          | Return Spark DataFrames from Python models; avoid `toPandas()` on large outputs            |
| F10 | API query times out                              | Semantic query launches expensive Spark job              | Pre-aggregate, add segments, or constrain query shape                                      |
| F11 | DataOS fails to resolve catalog (works locally)  | Depot missing or misnamed in `spec.depots[]`             | Verify `spec.depots[]` references and fully qualified table catalog prefix                 |
| F12 | Production `vulcan migrate` fails                | Missing or wrong Postgres `state_connection`             | Fix `state_connection` in production `config.yml`; ensure Postgres is reachable            |
| F13 | `Table not found` for external source            | External model not declared                              | Add to `external_models.yaml` with fully qualified lakehouse name                          |
| F14 | Time-range incremental reprocesses all history   | Missing or wrong `time_column`; interval macros not used | Verify `kind INCREMENTAL_BY_TIME_RANGE (time_column <col>)` and source filter              |
| F15 | Straggler stage on large join                    | Data skew on join key                                    | Enable AQE skew join; review partition distribution; pre-aggregate skewed side             |

### 9.1: Logs and where to look

| Symptom                                        | Where                                  | How                                                                                        |
| ---------------------------------------------- | -------------------------------------- | ------------------------------------------------------------------------------------------ |
| Local Docker startup issue                     | Docker compose services                | `docker compose -f docker/docker-compose.yml logs <service>`                               |
| Spark scheduler / catalog / auth failure       | DataOS driver container                | `dataos-ctl resource log -t Vulcan -n <name> --container-group <name>-run-execute -c main` |
| Executor OOM, shuffle-fetch failure, UDF error | Spark executor logs                    | Spark UI → application → executors                                                         |
| API / semantic query issue                     | API track containers                   | `dataos-ctl resource log ... --container-group <name>-api`                                 |
| Iceberg commit conflict                        | Driver logs + Spark SQL execution logs | Search for `CommitFailedException` and target table name                                   |

### 9.2: Recovery procedures

| Situation                                    | Procedure                                                                             |
| -------------------------------------------- | ------------------------------------------------------------------------------------- |
| Incremental time-range run failed mid-window | Re-run the affected window; partition overwrite is safe to replay                     |
| Unique-key MERGE failed before commit        | Re-run after checking target table snapshots and commit conflict logs                 |
| Unique-key MERGE committed bad data          | Restore with Iceberg snapshot rollback procedures (coordinate with platform SRE team) |
| Dependency artifact missing                  | Add JAR/wheel under `dependencies/`, redeploy, run `vulcan plan` before `vulcan run`  |
| Compute exhausted                            | Reduce concurrency, tune shuffle/read splits, then scale executor instances           |
| Schedule overlap caused Iceberg conflict     | Stop overlapping run; set `concurrencyPolicy: Forbid`; stagger heavy writers          |
| Workflow halted because `endOn` expired      | Update the Vulcan resource with a new `endOn` and re-apply                            |

***

## Section 10: Deployment recipes

### 10.1: Daily incremental, small project (5–20 models)

```yaml
spec:
  engine: spark
  compute: spark-compute
  depots:
    - dataos://lakehouse-depot?purpose=rw
  workflow:
    schedule:
      crons: ['0 3 * * *']
      timezone: UTC
      endOn: '2028-01-01T00:00:00Z'
      concurrencyPolicy: Forbid
    resource:
      driver:
        coreLimit: "2000m"
        cores: 1
        memory: "2G"
      executor:
        coreLimit: "4000m"
        cores: 2
        memory: "4G"
        instances: 2
  sparkConf:
    spark.sql.adaptive.enabled: "true"
    spark.sql.adaptive.coalescePartitions.enabled: "true"
    spark.serializer: org.apache.spark.serializer.KryoSerializer
  api:
    replicas: 2
    resource:
      request: { cpu: "200m", memory: "512Mi" }
      limit:   { cpu: "2000m", memory: "2Gi" }
```

### 10.2: Medium lakehouse mart (\~10–100 GB)

```yaml
spec:
  engine: spark
  compute: spark-compute
  workflow:
    resource:
      driver:
        coreLimit: "4000m"
        cores: 2
        memory: "6G"
      executor:
        coreLimit: "4000m"
        cores: 3
        memory: "6G"
        instances: 4
  sparkConf:
    spark.sql.shuffle.partitions: "300"
    spark.sql.adaptive.enabled: "true"
    spark.sql.adaptive.skewJoin.enabled: "true"
    spark.sql.adaptive.coalescePartitions.enabled: "true"
    spark.sql.files.maxPartitionBytes: "134217728"
    spark.serializer: org.apache.spark.serializer.KryoSerializer
```

### 10.3: Large backfill (first run, 1–5 years of history)

```yaml
spec:
  workflow:
    type: trigger                 # one-shot; no recurring schedule
    resource:
      driver:
        coreLimit: "4000m"
        cores: 4
        memory: "8G"
      executor:
        coreLimit: "6000m"
        cores: 4
        memory: "8G"
        instances: 8
  sparkConf:
    spark.sql.shuffle.partitions: "1000"
    spark.sql.files.maxPartitionBytes: "268435456"
    spark.sql.adaptive.enabled: "true"
    spark.sql.adaptive.skewJoin.enabled: "true"
```

Run backfills during off-peak hours. Return to the normal executor count immediately after the backfill completes.

### 10.4: MERGE-heavy CDC project

```yaml
spec:
  workflow:
    schedule:
      crons: ['30 2 * * *']
      timezone: UTC
      concurrencyPolicy: Forbid
    resource:
      driver:
        coreLimit: "4000m"
        cores: 2
        memory: "6G"
      executor:
        coreLimit: "4000m"
        cores: 3
        memory: "6G"
        instances: 4
  sparkConf:
    spark.sql.shuffle.partitions: "300"
    spark.sql.adaptive.enabled: "true"
    spark.sql.catalog.lakehouse_depot.commit.retry.num-retries: "10"
    spark.sql.catalog.lakehouse_depot.commit.retry.min-wait-ms: "1000"
    spark.sql.catalog.lakehouse_depot.commit.retry.max-wait-ms: "60000"
```

Pair with unique-key models that explicitly declare Iceberg format:

```sql
MODEL (
  name lakehouse_depot.crm.customer_snapshot,
  kind INCREMENTAL_BY_UNIQUE_KEY (
    unique_key c_custkey,
    batch_size 1,
    when_matched (
      WHEN MATCHED AND source.last_op = 'D' THEN DELETE
      WHEN MATCHED AND source.last_op IN ('I', 'U') THEN UPDATE SET
        c_name       = source.c_name,
        c_mktsegment = source.c_mktsegment,
        last_op      = source.last_op
    )
  ),
  table_format iceberg,
  partitioned_by (source_ds),
  grain (c_custkey)
);
```

> `when_matched` branches use `source.` and `target.` aliases. New keys fall through to an implicit insert. Delete tombstones for missing keys therefore insert rows unless filtered upstream.

***
