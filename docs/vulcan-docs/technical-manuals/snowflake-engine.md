---
description: >-
  A Snowflake engine manual for DataOS Vulcan setup, development, deployment,
  operations, performance, and troubleshooting.
---

# Snowflake Engine

|                           |                                      |
| ------------------------- | ------------------------------------ |
| **Template version**      | 1.0                                  |
| **Engine**                | Snowflake                            |
| **Tested Vulcan image**   | `tmdcio/vulcan-snowflake:0.228.1.23` |
| **Tested DataOS release** | Draco 1.38 series                    |
| **Last updated**          | June 2026                            |

## How to use this manual

Use this manual as the working reference for building and running a Snowflake-backed Data Product in DataOS. It assumes you already know the basics of Data Products and Vulcan. The structure stays consistent across engine manuals — only the Snowflake-specific content changes.

Use the path below that matches your role.

**If you are a data engineer setting up Vulcan on Snowflake for the first time:** section 2: Prerequisites (including pre-flight checklist) → section 3: LDK setup → section 10: Deployment recipes → section 7: Operational boundaries

**If you are a DP developer building or debugging a Data Product on Snowflake:** section 1: Snapshot → section 4: Vulcan on Snowflake → section 9: Failure modes & troubleshooting

## Section 1: Snapshot

This section is the fast path. If you only need the essentials, start here. It gives you the supported versions, key limits, runtime expectations, and the defaults you can rely on.

### Architecture

<figure><img src="../../../.gitbook/assets/Architecture-diagram.png" alt=""><figcaption></figcaption></figure>

### Version compatibility matrix

| Vulcan image                         | DataOS release | Snowflake edition                       | Status            |
| ------------------------------------ | -------------- | --------------------------------------- | ----------------- |
| `tmdcio/vulcan-snowflake:0.228.1.23` | Draco 1.38.x   | Standard, Enterprise, Business Critical | ✅ Tested          |
| Earlier `0.228.1.x` builds           | Draco 1.37.x   | Standard, Enterprise                    | ⬜ Add when tested |
| `0.228.0.x`                          | Draco 1.36.x   | Standard, Enterprise                    | ⬜ Add when tested |

{% hint style="info" %}
Dynamic Tables (MANAGED model kind) require **Enterprise+**. Standard edition is otherwise fully supported.
{% endhint %}

| Item                                             | Value                                                                                                             |
| ------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------- |
| Engine adapter type                              | `snowflake`                                                                                                       |
| Support level                                    | GA                                                                                                                |
| Tested Vulcan image                              | `tmdcio/vulcan-snowflake:0.228.1.23`                                                                              |
| Tested DataOS release                            | Draco 1.38 series                                                                                                 |
| Tested Snowflake editions                        | Standard, Enterprise, Business Critical                                                                           |
| Recommended auth                                 | Key-pair JWT (`authenticator: snowflake_jwt`)                                                                     |
| Supported model kinds                            | FULL, SEED, VIEW, INCREMENTAL\_BY\_TIME\_RANGE, INCREMENTAL\_BY\_UNIQUE\_KEY, INCREMENTAL\_BY\_PARTITION, MANAGED |
| Quality file format                              | `kind: dq` YAML with rules                                                                                        |
| Semantic model format                            | `kind: semantic` YAML with dimensions, measures, segments, joins, and optional `ai_context`                       |
| Business metric format                           | `kind: metric`, `name`, `measure`                                                                                 |
| Python runtime                                   | Snowpark; import Snowpark functions inside `execute()`                                                            |
| Python version                                   | 3.10 (local dev); runtime managed by image                                                                        |
| Production deploy unit                           | DataOS Vulcan resource (workflow + API)                                                                           |
| Catalog metadata source                          | Snowflake `INFORMATION_SCHEMA` + `SNOWFLAKE.ACCOUNT_USAGE`                                                        |
| Catalog refresh expectation                      | Scanner schedule; treat lineage as nearline because `ACCOUNT_USAGE` lags by \~3 hours                             |
| Headline query latency (TPC-H SF1000, Medium WH) | 12–15 s                                                                                                           |
| Semantic API overhead                            | \~1.84 s                                                                                                          |
| Concurrency tested                               | 10 users × 5 parallel = 100 queries, 82% success                                                                  |
| Identifier casing rule                           | UPPERCASE in semantic models, filters, joins, DQ SQL, and metric expressions                                      |

### SLOs you can commit to

Assumes recommended configuration in section 10:

| SLO                                                          | Target                                      |
| ------------------------------------------------------------ | ------------------------------------------- |
| Semantic API p50 latency (standard query, Medium WH, SF1000) | ≤ 15 s                                      |
| Semantic API p95 latency (standard query, Medium WH, SF1000) | ≤ 25 s                                      |
| Semantic API overhead floor                                  | ≥ 1.5 s (API layer; not tunable below this) |
| Concurrent success rate at 10 users × 5 parallel             | ≥ 80%                                       |
| Daily incremental run success rate (warehouse healthy)       | ≥ 99%                                       |
| Cold start added after AUTO\_SUSPEND                         | +1–3 s                                      |

{% hint style="warning" %}
If your downstream SLO is tighter than these, scale up (section 7) or rethink the workload shape (section 8.1).
{% endhint %}

## Section 2: Prerequisites

{% hint style="info" %}
**Start here for implementation readiness.** Complete the Snowflake-side permissions, DataOS access, Python version, and pre-flight checklist before moving to LDK setup.
{% endhint %}

### 2.1: Snowflake permissions

Three roles are required. Each has a distinct scope — do not collapse them into one.

| Role                    | Who holds it                 | Purpose                                                                                   |
| ----------------------- | ---------------------------- | ----------------------------------------------------------------------------------------- |
| **Admin role**          | Snowflake account admin      | Provisions warehouses, creates resource monitors, manages masking and row access policies |
| **Vulcan service role** | The user Vulcan connects as  | Runs models, creates and modifies tables and schemas in the target database               |
| **Consumer role**       | BI users, endpoint consumers | Reads data via Vulcan endpoints; no write access                                          |

#### Admin role — one-time setup

Run as SYSADMIN or ACCOUNTADMIN:

```sql
-- Create warehouse
CREATE WAREHOUSE vulcan_wh
  WITH WAREHOUSE_SIZE = 'MEDIUM'
       AUTO_SUSPEND = 60
       AUTO_RESUME = TRUE;

-- Attach resource monitor (required before production)
ALTER WAREHOUSE vulcan_wh SET RESOURCE_MONITOR = vulcan_monthly_cap;
```

#### Vulcan service role — minimum grants

```sql
-- Warehouse access
GRANT USAGE ON WAREHOUSE <wh> TO ROLE <vulcan_role>;

-- Database access
GRANT USAGE ON DATABASE <db> TO ROLE <vulcan_role>;

-- Create objects (required for model materialization)
GRANT CREATE SCHEMA ON DATABASE <db> TO ROLE <vulcan_role>;
GRANT USAGE, CREATE TABLE, CREATE VIEW
  ON FUTURE SCHEMAS IN DATABASE <db> TO ROLE <vulcan_role>;

-- Key-pair auth on the user
ALTER USER <vulcan_user> SET RSA_PUBLIC_KEY = '<public_key>';

-- Bind role to user
GRANT ROLE <vulcan_role> TO USER <vulcan_user>;
```

#### Consumer role — read-only grants

```sql
GRANT USAGE ON DATABASE <db> TO ROLE <consumer_role>;
GRANT USAGE ON SCHEMA <db>.<schema> TO ROLE <consumer_role>;
GRANT SELECT ON ALL TABLES IN SCHEMA <db>.<schema> TO ROLE <consumer_role>;
GRANT SELECT ON FUTURE TABLES IN SCHEMA <db>.<schema> TO ROLE <consumer_role>;
```

#### Access model overview

Snowflake access in DataOS is split into two distinct areas:

| Area | Purpose |
| ---- | ------- |
| **Source schema (read-only)** | Dataset discovery, profiling, data quality checks, semantic querying, and reading upstream tables during model builds |
| **Target schema (managed by Vulcan)** | Tables and views created and updated by Vulcan during model materialization |

#### Source schema access (read-only)

Grant these permissions on every source schema Vulcan reads from:

```sql
GRANT USAGE ON WAREHOUSE <WAREHOUSE_NAME> TO ROLE <DATAOS_ROLE>;
GRANT USAGE ON DATABASE <DATABASE_NAME> TO ROLE <DATAOS_ROLE>;
GRANT USAGE ON SCHEMA <DATABASE_NAME>.<SOURCE_SCHEMA> TO ROLE <DATAOS_ROLE>;

GRANT SELECT ON ALL TABLES IN SCHEMA <DATABASE_NAME>.<SOURCE_SCHEMA> TO ROLE <DATAOS_ROLE>;
GRANT SELECT ON FUTURE TABLES IN SCHEMA <DATABASE_NAME>.<SOURCE_SCHEMA> TO ROLE <DATAOS_ROLE>;

GRANT SELECT ON ALL VIEWS IN SCHEMA <DATABASE_NAME>.<SOURCE_SCHEMA> TO ROLE <DATAOS_ROLE>;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA <DATABASE_NAME>.<SOURCE_SCHEMA> TO ROLE <DATAOS_ROLE>;
```

#### Target schema access (managed by Vulcan)

Grant these permissions on the schema where Vulcan materializes model output:

```sql
GRANT CREATE SCHEMA ON DATABASE <DATABASE_NAME> TO ROLE <DATAOS_ROLE>;

GRANT USAGE ON SCHEMA <DATABASE_NAME>.<TARGET_SCHEMA> TO ROLE <DATAOS_ROLE>;
GRANT CREATE TABLE ON SCHEMA <DATABASE_NAME>.<TARGET_SCHEMA> TO ROLE <DATAOS_ROLE>;
GRANT CREATE VIEW ON SCHEMA <DATABASE_NAME>.<TARGET_SCHEMA> TO ROLE <DATAOS_ROLE>;

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE
  ON ALL TABLES IN SCHEMA <DATABASE_NAME>.<TARGET_SCHEMA>
  TO ROLE <DATAOS_ROLE>;

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE
  ON FUTURE TABLES IN SCHEMA <DATABASE_NAME>.<TARGET_SCHEMA>
  TO ROLE <DATAOS_ROLE>;

GRANT SELECT ON ALL VIEWS IN SCHEMA <DATABASE_NAME>.<TARGET_SCHEMA> TO ROLE <DATAOS_ROLE>;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA <DATABASE_NAME>.<TARGET_SCHEMA> TO ROLE <DATAOS_ROLE>;
```

#### Why `DELETE` is required

Vulcan uses `DELETE` for incremental model rebuilds. When reprocessing a partition or time range, Vulcan:

1. Deletes existing rows for that slice
2. Inserts refreshed rows

This prevents duplicate and stale records. `DELETE` is only required on Vulcan-managed target tables and is **not required** on source schemas.

#### Why `TRUNCATE` is required

Vulcan uses `TRUNCATE` for:

- Full refreshes
- Overwrite-style rebuilds
- Complete table regeneration

#### When `OWNERSHIP` is required

`OWNERSHIP` is needed only when DataOS must fully manage the target schema lifecycle, including `ALTER`, `REPLACE`, and `DROP` operations:

```sql
CREATE SCHEMA IF NOT EXISTS <DATABASE_NAME>.<TARGET_SCHEMA>;

GRANT OWNERSHIP ON SCHEMA <DATABASE_NAME>.<TARGET_SCHEMA>
  TO ROLE <DATAOS_ROLE>
  COPY CURRENT GRANTS;
```

#### Additional grants by feature

Add to the Vulcan service role as needed:

| Feature                    | Additional grant required                                                                                     | Edition     |
| -------------------------- | ------------------------------------------------------------------------------------------------------------- | ----------- |
| Read Snowflake sample data | `GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_SAMPLE_DATA TO ROLE <vulcan_role>`                           | Standard+   |
| Masking policies           | `GRANT CREATE MASKING POLICY ON SCHEMA <db>.<schema> TO ROLE <vulcan_role>` + `APPLY MASKING POLICY ON TABLE` | Enterprise+ |
| Row access policies        | `GRANT CREATE ROW ACCESS POLICY ON SCHEMA <db>.<schema> TO ROLE <vulcan_role>`                                | Enterprise+ |
| Snowpark external access   | `GRANT USAGE ON INTEGRATION <integration_name> TO ROLE <vulcan_role>`                                         | Standard+   |
| Dynamic Tables             | `GRANT CREATE DYNAMIC TABLE ON SCHEMA <db>.<schema> TO ROLE <vulcan_role>`                                    | Enterprise+ |

For the full permissions reference, see [Snowflake](../configurations/engines/snowflake.md).

### 2.2: DataOS permissions

The following access must be provisioned by your DataOS operator before you can deploy or run a Vulcan Data Product.

| Permission                        | What it unlocks                                               | Who to request from                 |
| --------------------------------- | ------------------------------------------------------------- | ----------------------------------- |
| `roles:id:data-dev` or equivalent | Create and apply Vulcan resources (workflow, API)             | DataOS operator / admin             |
| Access to the target workspace    | Apply secrets, depots, and domain resources in that workspace | DataOS operator                     |
| `depot:rw:<snowflake-depot-name>` | Read/write access to the Snowflake depot                      | DataOS operator                     |
| `depot:r:<snowflake-depot-name>`  | Read-only access (consumer)                                   | DataOS operator                     |
| Git repository access             | Vulcan pulls model code via git-sync                          | Your VCS admin (GitHub / Bitbucket) |

{% hint style="warning" %}
**Check your access** before starting. Run `dataos-ctl get depot` — if the Snowflake depot appears in the output, your read access is confirmed. If it's missing, request `depot:r` from your operator.
{% endhint %}

### 2.3: Python version

| Requirement                               | Version                    |
| ----------------------------------------- | -------------------------- |
| Python (local development)                | **3.10**                   |
| Python (Snowpark runtime in Vulcan image) | 3.9 (managed by the image) |

Python 3.10 is required for local development and CLI tooling. Python 3.13+ is not supported. Use `pyenv` or a virtual environment to pin the version if your system default differs.

```bash
python --version   # must be 3.10.x
```

### 2.4: Pre-flight checklist

#### Checklist for engine setup

**Engine side**

* [ ] Account region within 200 ms of the DataOS data-plane region
* [ ] Snowflake edition matches features needed (section 6)
* [ ] User has key-pair auth configured
* [ ] Role has grants per section 2.1
* [ ] Warehouse provisioned with `AUTO_SUSPEND=60`, `AUTO_RESUME=TRUE`, `MAX_CONCURRENCY_LEVEL` per section 7.2
* [ ] Resource monitor attached with monthly credit quota and trigger thresholds (section 8.2.1)
* [ ] `STATEMENT_TIMEOUT_IN_SECONDS` and `STATEMENT_QUEUED_TIMEOUT_IN_SECONDS` set (section 8.2.2)
* [ ] Sample-data shares mounted if read by models
* [ ] Network policy allows DataOS data-plane egress IPs

**Local development**

* [ ] Universal prereqs complete (Python, Docker, CLI, data connection, repo)
* [ ] Snowflake image pulled (`tmdcio/vulcan-snowflake:0.228.1.23`)
* [ ] Key pair generated; public key registered on Snowflake user
* [ ] `config.yaml` uses `authenticator: snowflake_jwt`, correct `<org>-<account>` format
* [ ] `vulcan migrate` and `vulcan plan` succeed against an empty target DB

**DataOS production**

* [ ] Snowflake key-pair secret applied (`<workspace>:<name>`)
* [ ] Depot applied; `name` matches `dataos://<name>?purpose=rw` in Vulcan resource
* [ ] Depot `secrets[].id` references the Snowflake secret
* [ ] Git secret applied (`GITSYNC_USERNAME`, `GITSYNC_PASSWORD`)
* [ ] `config.yaml` gateway points at the depot
* [ ] Vulcan resource: `runAsUser`, `compute`, `repo`, `depots`, `workflow`, `api.replicas` all set
* [ ] Cron `timezone: UTC`; `endOn` ≥ 1–2 years out; `concurrencyPolicy: Forbid`

#### Before you ship- checklist (DP developer)

* [ ] All semantic model identifiers are UPPERCASE
* [ ] Lifecycle DDL guarded with `@IF(@runtime_stage = 'evaluating', …)`
* [ ] Macros use `.sql(dialect=evaluator.dialect)` for column AST rendering
* [ ] `macros/__init__.py` exists
* [ ] Cross-database sources declared in `external_models.yaml` with triple-quoted identifiers
* [ ] Composite-key grains declared correctly (not single-column `unique_values`)
* [ ] Audits and DQ checks tagged separately from production reads (section 8.2.3)
* [ ] Query tag set on session for cost attribution
* [ ] `endOn` set and reviewed in the Vulcan resource schedule

## Section 3: Local Development Kit (LDK)

This section gets you from a blank project to a working local setup. Finish the prerequisites first, then install Vulcan, configure Snowflake access, and validate the connection.

### 3.1: Install Vulcan

Vulcan is distributed as a Python wheel (`.whl`) and installed directly via `pip`. No Docker setup required.

```bash
pip install vulcan_snowflake-<version>-py3-none-any.whl
```

Get the latest `.whl` for the Snowflake engine from your DataOS distribution channel. Replace `<version>` with the version listed in section 1: Snapshot. Confirm the installed version matches the tested image before running `vulcan plan`.

```bash
vulcan --version   # verify after install
```

### 3.2: Set up authentication

Generate the key pair once per developer machine. Keep the private key local and out of version control.

Keep the `.p8` file next to your project config. Never commit it.

```bash
openssl genrsa -out snowflake_key.pem 2048
openssl pkcs8 -topk8 -inform PEM -outform PEM \
  -in snowflake_key.pem -out snowflake_key.p8 \
  -v2 aes256cbc -passphrase pass:<YOUR_PASSPHRASE>
```

Register the public key on your Snowflake user (run as your Snowflake admin or yourself if you have the privilege):

```sql
ALTER USER <your_user> SET RSA_PUBLIC_KEY = '<contents_of_snowflake_key.pem>';
```

### 3.3: Configure config.yaml

Minimum Snowflake connection config:

```yaml
gateways:
  default:
    connection:
      type: snowflake
      account: <org>-<account>          # from your Snowflake console URL
      user: <vulcan_user>
      authenticator: snowflake_jwt
      private_key_path: ./snowflake_key.p8
      private_key_passphrase: <YOUR_PASSPHRASE>
      warehouse: <wh>
      database: <db>
      role: <vulcan_role>

model_defaults:
  dialect: snowflake
```

Use `<org>-<account>` format for the account field. The legacy locator format will fail.

### 3.4: Validate your connection

```bash
vulcan migrate        # initializes Vulcan state in Snowflake
vulcan plan           # dry run against your target DB — should succeed with no errors
```

If `vulcan plan` succeeds, your local setup is complete. Common failures at this step are covered in section 9 (F1–F5).

### 3.5: DataOS production deployment

Production deployment uses a depot instead of a direct connection. Apply resources in this order — each step depends on the previous:

```
Snowflake key-pair Secret → Snowflake Depot → Git Secret → Vulcan config.yaml → Vulcan domain resource
```

| Manifest                        | Purpose                                                                 | Key fields                                                                                              |
| ------------------------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `secret-snowflake-keypair.yaml` | Stores Snowflake user + encrypted PEM + passphrase                      | `name`, `username`, `key` (PEM), `passphrase`                                                           |
| `depot-snowflake.yaml`          | Registers Snowflake URL/DB/warehouse/role; binds purposes to the secret | `name`, `spec.spec.url/database/warehouse/account/role`, `secrets[].id`                                 |
| `secret-git-sync.yaml`          | Repo credentials for git-sync                                           | `GITSYNC_USERNAME`, `GITSYNC_PASSWORD`                                                                  |
| `config.yaml`                   | Project config; gateway points at the depot                             | `gateways.default.connection.type: depot`, `gateways.default.connection.address: dataos://<depot-name>` |
| `domain-resource.yaml`          | Workflow + API; references depot and repo                               | `runAsUser`, `compute`, `engine: snowflake`, `repo.*`, `depots`, `workflow.schedule`, `api.replicas`    |

**Why order matters.** Applying the depot before the secret exists means `secrets[].id` won't resolve. A misspelled depot name in the Vulcan resource passes `apply` but fails at every workflow run — verify `dataos://<depot-name>?purpose=rw` matches the depot manifest's `name` field exactly.

Reference configurations for all five manifests: section 10.

### 3.6: Hello-world starter

Use this starter for a minimum viable Data Product on Snowflake. Fill in your credentials and database name, then run `vulcan plan`. Nothing else needs to change.

#### `config.yaml`

```yaml
gateways:
  default:
    connection:
      type: snowflake
      account: <org>-<account>
      user: <vulcan_user>
      authenticator: snowflake_jwt
      private_key_path: ./snowflake_key.p8
      private_key_passphrase: <passphrase>
      warehouse: <wh>
      database: <db>
      role: <vulcan_role>
model_defaults:
  dialect: snowflake
  start: '2024-01-01'
```

#### `models/orders.sql`

```sql
MODEL (
  name db.gold.orders,
  kind FULL
);
SELECT o_orderkey, o_custkey, o_totalprice, o_orderdate
FROM   db.raw.orders
```

#### `models/semantic/orders.yaml`

```yaml
kind: model
name: ORDERS
model: db.gold.orders
dimensions:
  - O_ORDERDATE
measures:
  - name: TOTAL_SALES
    type: sum
    sql: O_TOTALPRICE
```

#### `metrics/total_orders.yaml`

```yaml
kind: metric
name: DAILY_REVENUE
measure: ORDERS.TOTAL_SALES
ts: ORDERS.O_ORDERDATE
granularity: day
```

Run `vulcan plan` — you should see one model (`db.gold.orders`) staged for creation with no errors. Run `vulcan apply` to materialize it. Call the metric via the REST endpoint to confirm the semantic layer is wired end to end.

## 4: Vulcan on Snowflake

This section covers the parts of Vulcan that behave differently on Snowflake. Use it to understand the runtime boundaries, supported patterns, and the trade-offs that matter in production.

{% hint style="danger" %}
**Architectural constraints on Snowflake:**

* Vulcan does not create or manage Snowflake warehouses. Warehouses must be provisioned out of band.
* The semantic API adds a stable \~1.5–2 s overhead per standard query. Not tunable below this floor.
* OAuth and external-browser SSO are not the recommended path for the Vulcan gateway in production. Use key-pair JWT.
* The Vulcan resource references depots by name. A misspelled depot name passes `apply` but fails at every workflow run.
* Snowflake `MAX_CONCURRENCY_LEVEL` is a per-warehouse setting; the API cannot exceed what the warehouse admits.
{% endhint %}

**Not supported on Snowflake via Vulcan**

| Feature                                      | Why not supported                                                                             | Alternative                                                                                                    |
| -------------------------------------------- | --------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Warehouse create / resize / suspend          | Vulcan has no warehouse lifecycle API                                                         | Provision out of band via Snowflake console, Terraform, or resource monitor                                    |
| OAuth / external-browser SSO for gateway     | Not supported for service-account connections in production                                   | Use key-pair JWT (`authenticator: snowflake_jwt`)                                                              |
| Cross-database external model auto-discovery | `vulcan create_external_models` only inspects the gateway database                            | Declare cross-database sources manually in `external_models.yaml` with triple-quoted identifiers (section 4.4) |
| MANAGED (Dynamic Table) on Standard edition  | Dynamic Tables require Enterprise+                                                            | Use `INCREMENTAL_BY_TIME_RANGE` or `INCREMENTAL_BY_UNIQUE_KEY` on Standard; upgrade edition for MANAGED        |
| Incremental processing on VIEW kind          | `CREATE OR REPLACE VIEW` is always a full rewrite; no partition or key tracking               | Move incremental logic to a TABLE kind model; keep VIEW as a thin projection on top                            |
| Snowpark external network access             | External integrations must be created and granted by a Snowflake admin; Vulcan cannot do this | Create the `EXTERNAL ACCESS INTEGRATION` out of band and grant it to the Vulcan service role                   |

### Section 4.1: Data movement

For data to be transformed or served, it must first exist in Snowflake. This section covers how data arrives, what depot purposes control, and the two paths consumers use to read it.

**How data gets into Snowflake — Nilus**

Nilus is the DataOS ingestion service that moves data into Snowflake from external sources (object stores, databases, SaaS APIs, streams). It writes to Snowflake tables that Vulcan models then read as sources. Vulcan does not move raw data — it transforms data that Nilus (or another pipeline) has already landed.

| Role           | Tool   | What it does                                              |
| -------------- | ------ | --------------------------------------------------------- |
| Ingestion      | Nilus  | Moves raw data into Snowflake (Bronze/staging layer)      |
| Transformation | Vulcan | Transforms ingested data into Data Products (Silver/Gold) |

**Snowflake as a source vs. sink**

| Mode       | When it applies                                                                                                |
| ---------- | -------------------------------------------------------------------------------------------------------------- |
| **Sink**   | Nilus writes raw data into Snowflake; Vulcan materialises models into Snowflake tables                         |
| **Source** | Vulcan reads Snowflake tables to build models; consumers query the Data Product via endpoints or direct access |

**Depot purposes**

A Snowflake depot is registered in DataOS with one or more purposes. Each purpose controls what the bound credentials are allowed to do.

| Purpose | Who uses it             | What it allows                                                                                    |
| ------- | ----------------------- | ------------------------------------------------------------------------------------------------- |
| `rw`    | Vulcan workflow         | Read source tables, create and write model output tables, manage schemas                          |
| `scan`  | DataOS metadata scanner | Read `INFORMATION_SCHEMA` and `ACCOUNT_USAGE` to populate the catalog and lineage (see section 5) |
| `query` | Consumer direct access  | Read-only access to Data Product tables; used for depot-issued credential access                  |

{% hint style="warning" %}
Bind the correct purpose to each secret in the depot manifest. A `query`-purpose credential cannot create tables; an `rw` credential handed to a consumer is an over-permission risk.
{% endhint %}

Primary references: [Nilus](../../nilus/) · [Depot configuration](../../depot/)

### 4.2: Models

#### 4.2.1: Data Models

SQL models compile to native Snowflake SQL via the Vulcan transpiler. Model kinds map to Snowflake DDL as follows:

| Model kind                   | Snowflake operation                                            |
| ---------------------------- | -------------------------------------------------------------- |
| FULL                         | `CREATE OR REPLACE TABLE`                                      |
| SEED                         | Loads a file-backed reference dataset (commonly CSV)           |
| VIEW                         | `CREATE OR REPLACE VIEW`                                       |
| INCREMENTAL\_BY\_TIME\_RANGE | DELETE by time range → INSERT                                  |
| INCREMENTAL\_BY\_UNIQUE\_KEY | MERGE on the unique key                                        |
| INCREMENTAL\_BY\_PARTITION   | DELETE by partitioning key → INSERT                            |
| MANAGED                      | `CREATE OR REPLACE DYNAMIC TABLE` (Enterprise+, see section 6) |

**Python models** run via Snowpark. The model file declares kind via `@model(...)` and the body returns a Snowpark DataFrame.

{% hint style="warning" %}
**Snowflake-specific rule for Snowpark.** Import Snowpark functions (`col`, `lit`, `when`, …) inside `execute()`, not at module scope. This is the most common Python-model error on Snowflake.
{% endhint %}

```python
def execute(context, start, end, execution_time, **kwargs):
    from snowflake.snowpark.functions import col, lit, when   # INSIDE the function
    df = context.snowpark.table(
        context.resolve_table('"SNOWFLAKE_SAMPLE_DATA"."TPCH_SF1"."CUSTOMER"')
    )
    return df.select(col("C_CUSTKEY"), col("C_NAME"))
```

#### When to pick SQL vs Snowpark

| Use SQL when…                       | Use Snowpark when…                                           |
| ----------------------------------- | ------------------------------------------------------------ |
| Standard SELECT / JOIN / GROUP BY   | Logic needs Python libraries (numpy, pandas, custom modules) |
| Simple derived columns              | Complex window operations are cleaner in DataFrame API       |
| Performance is the primary concern  | Reusable Python helpers across multiple models               |
| Most Bronze and Silver layer models | Multi-step transformations that would need many CTEs in SQL  |

Primary references: [SQL models](../components/model/types/sql_models.md) · [Python models](../components/model/types/python_models.md) · [Model kinds](../components/model/model_kinds.md)

#### Rule: Lifecycle DDL guards

Wrap any DDL in `pre_statements` / `post_statements` that should only run during real execution:

```sql
@IF(@runtime_stage = 'evaluating',
  ALTER TABLE myproj.gold.orders CLUSTER BY (order_date, nation_name)
);
```

{% hint style="warning" %}
Without the guard, `vulcan plan` will execute it. This is the source of the "plan succeeded but my role doesn't exist" class of bugs.
{% endhint %}

#### Rule: Macro parameter rendering

In `@macro()` Python functions, column arguments arrive as SQLGlot AST expressions, not strings. Render them with `.sql(dialect=evaluator.dialect)`:

```python
from vulcan import macro

@macro()
def is_late_delivery(evaluator, receipt_col, commit_col):   # NO : str annotations
    receipt_sql = receipt_col.sql(dialect=evaluator.dialect)
    commit_sql  = commit_col.sql(dialect=evaluator.dialect)
    return f"CASE WHEN {receipt_sql} > {commit_sql} THEN 1 ELSE 0 END"
```

{% hint style="warning" %}
Annotating parameters as `: str` triggers `Coercion failed`. Also ensure `macros/__init__.py` exists or macros won't be discovered.
{% endhint %}

#### Rule: SQL vs Snowpark choice

Default to SQL. Reach for Snowpark when you need Python libraries, complex window expressions, or chained DataFrame ops. Always import Snowpark functions inside `execute()` : see the Snowflake-specific Snowpark rule above.

#### 4.2.2: Semantic Models

Semantic models define the governed query layer on top of Snowflake tables. They expose dimensions, measures, filters, and joins in a form that the API and query interfaces can serve consistently.

{% hint style="warning" %}
**Identifier casing — the rule that bites everyone once.** Snowflake stores unquoted identifiers in UPPERCASE. Every column reference in a semantic model — dimensions, measure expressions, segment filters, join clauses — must be uppercase. Lowercase causes "object does not exist."
{% endhint %}

```yaml
# Snowflake — UPPERCASE column names everywhere
dimensions:
  - USER_ID
  - SIGNUP_DATE
  - PLAN_TYPE
measures:
  - name: active_users
    type: count
    filters:
      - "{users.STATUS} = 'active'"
```

`COUNT(DISTINCT …)` measures over high-cardinality columns benefit disproportionately from sizing up the warehouse. CROSS JOIN-shaped semantic queries (joins without a foreign-key relation) are 30× slower than equivalent grouped queries — model joins explicitly in the semantic layer.

Primary references: [Semantic models](../components/model/types/models.md) · [Business metrics](../components/semantics/business_metrics.md)

#### Rule: Identifier casing

Snowflake stores unquoted identifiers in UPPERCASE. Use UPPERCASE everywhere in semantic models. In model SQL, lowercase identifiers in SELECT work because Snowflake folds them; quoted lowercase (`"col"`) does not work. Prefer unquoted UPPERCASE consistently.

#### 4.2.3: Metrics

Metrics package a business-friendly aggregation on top of an existing semantic measure. Vulcan compiles it to a native Snowflake SQL aggregation executed on the warehouse.

```yaml
kind: metric
name: MONTHLY_SALES_PERFORMANCE
measure: ORDERS.TOTAL_SALES        # must match a measure in the ORDERS semantic model
ts: ORDERS.ORDERDATE
granularity: day
dimensions:
  - name: ORDERSTATUS
    ref: ORDERS.ORDERSTATUS
description: "Monthly total sales by order status and market segment"
tags:
  - tpch
  - sales
```

Three Snowflake-specific behaviors matter at runtime:

COUNT DISTINCT on high-cardinality columns runs exactly on Snowflake — there is no automatic downgrade to HyperLogLog approximation. On SF1000-scale data this is the single biggest warehouse-sizing driver. If a metric backed by a `COUNT(DISTINCT …)` measure over a 100M-row fact table is slow, size up the warehouse before rewriting the metric.

Cross-join metric patterns — metrics that require joining two unrelated aggregations without a shared key — run up to 30× slower than grouped aggregations on Snowflake (see section 8.1.2). If the generated SQL contains a cross-join, pre-aggregate one side into a mart model and reference that instead.

Identifier casing in metric filters follows the same UPPERCASE rule as semantic models (section 4.2.2). Lowercase column references in `filters` or `expressions` within a metric definition will cause "object does not exist" errors on Snowflake.

Primary reference: [Business metrics](../components/semantics/business_metrics.md)

### 4.3: Data Quality

All quality layers work fully on Snowflake. Cost characteristics differ.

| Layer                                   | Where it runs                             | Snowflake cost      | When it catches a problem       |
| --------------------------------------- | ----------------------------------------- | ------------------- | ------------------------------- |
| Linter                                  | Locally, before any DB call               | None                | Authoring time                  |
| Unit tests (`tests/`)                   | Locally with mocked rows                  | None                | Pre-merge / pre-deploy          |
| Assertions (built-in or `audits/*.sql`) | In Snowflake after model materialises     | One query per audit | Every run, blocking             |
| Data quality (`kind: dq`, `dq/*.yml`)   | In Snowflake on a schedule or with run    | One query per rule  | Drift / freshness, non-blocking |

An assertion attaches an audit (the validation rule) to a model. Built-in audits like `not_null(...)` and user-defined audits in `audits/*.sql` are both invoked from the model's `assertions (...)` block and share the same post-materialisation execution phase.

{% hint style="warning" %}
Assertions and DQ rules count against your warehouse credits. On a Medium warehouse, a completeness check on a 50M-row table is sub-second; a heavy validity check can run 5–30 s. Tag DQ queries separately (section 8.2.3). Snowflake's result cache will short-circuit repeat queries within the cache window.
{% endhint %}

Primary references: [Tests](../components/tests.md) · [Assertions](../components/assertions.md) · [Data quality](../components/data-quality.md)

### 4.4: Lineage & version rollback

Column-level lineage is computed from Vulcan's SQLGlot parse, not from Snowflake metadata.

Two Snowflake-relevant facts: lineage resolves cross-database references (e.g. `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS`) only when the upstream is declared in `external_models.yaml` with the triple-quoted identifier form (see the rule below). `vulcan rollback` to a previous plan version replays the materialization strategy in section 4.2.1 — for INCREMENTAL\_BY\_TIME\_RANGE this re-deletes and re-inserts affected windows, which consumes credits.

#### Rule: Cross-database external models

`vulcan create_external_models` discovers tables only in the database configured on the gateway. For cross-database sources (e.g. `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1`), declare them manually in `external_models.yaml`:

```yaml
- name: '"SNOWFLAKE_SAMPLE_DATA"."TPCH_SF1"."ORDERS"'
  columns:
    o_orderkey:   NUMBER
    o_custkey:    NUMBER
    o_orderdate:  DATE
    o_totalprice: NUMBER
```

The triple-quote (`'"DB"."SCHEMA"."TABLE"'`) tells Snowflake to treat the identifier as case-sensitive UPPERCASE. Without this, the linter throws `Table not found` and lineage stops at the model boundary.

### 4.5: Endpoints (REST, GraphQL, MySQL-wire, Postgres-wire)

Every Data Product on Snowflake automatically gets REST, GraphQL, MySQL-wire, and Postgres-wire endpoints. All four push queries down to the same Snowflake gateway — latency is identical across protocols. The endpoint layer adds \~1.5–2 s overhead on standard queries and \~4–5 s on complex queries (full numbers in section 8.1).

Result sets up to \~50k rows are buffered in API memory before streaming. Keep `api.limit.memory ≥ 1.5 GiB` to avoid OOM; recommended 3 GiB (section 7.3). Endpoint queries hit the same warehouse as model runs unless you split warehouses by purpose (section 10.2).

Primary references: [APIs](../../../foundations/activation/apis/) · [Vulcan API Guide](../guides/vulcan_api_guide.md) · [MySQL](../activation/mysql.md)

### 4.6: MCP tools

| MCP tool   | Snowflake behavior                                                        |
| ---------- | ------------------------------------------------------------------------- |
| `about`    | Static — no engine call                                                   |
| `lineage`  | Static — Vulcan's parsed graph, no engine call                            |
| `quality`  | Static read of last audit/DQ result, no live engine call                  |
| `data`     | Live query against Snowflake — uses the warehouse, counts against credits |
| `run`      | Triggers a Vulcan workflow run — same cost as a scheduled run             |
| `activity` | Reads workflow history from DataOS — no engine call                       |

{% hint style="info" %}
`data` tool calls inherit the warehouse's `MAX_CONCURRENCY_LEVEL`. If `concurrencyPolicy: Forbid` is set and a scheduled run is in flight, MCP-triggered `run` calls are rejected — use `Allow` only for ad-hoc support if your models are idempotent.
{% endhint %}

Primary references: [Activation overview](../../../foundations/activation/) · [AI activation](../../../foundations/activation/ai-activation.md)

### 4.7: Importing Snowflake Semantic Views

If you have a semantic view defined natively in Snowflake, you can import it into a Vulcan project with `vulcan import_semantic_view`. The command reads the view definition via `SYSTEM$READ_YAML_FROM_SEMANTIC_VIEW()` and writes one `kind: semantic` YAML file per table. The result is a standard Vulcan semantic layer, queryable via REST, GraphQL, and MySQL wire protocol.

**Snowflake edition requirement:** Semantic Views require Snowflake Enterprise edition or higher. Standard edition does not support this feature.

**Additional permission required:** The Vulcan service role must be able to call `SYSTEM$READ_YAML_FROM_SEMANTIC_VIEW()` on the target view. Ensure `USAGE` on the view's schema and `SELECT` on the view are granted to the Vulcan service role.

**Identifier casing:** The generated YAML files follow the UPPERCASE rule documented in section 4.2.2. All measure names, dimension names, and segment names in API queries must be UPPERCASE.

**`inputs.yaml` known limitation:** `vulcan create_external_models`, which must be run after import to generate external table stubs, currently wraps table names in extra quotes. Remove the quotes from each entry before running `vulcan plan`. This is a known issue being addressed in a future release.

For the full step-by-step workflow, see [Import Snowflake Semantic Views](../guides/import-snowflake-semantic-views.md).

## Section 5: Metadata scanning & catalog

DataOS scans two Snowflake sources: `INFORMATION_SCHEMA` (real-time structural metadata) and `ACCOUNT_USAGE` (lineage, tags, query history — up to **\~3 hour lag**, Snowflake-imposed and not configurable).

### 5.1: What shows up

| Object                                   | Catalog              | Lineage                     |
| ---------------------------------------- | -------------------- | --------------------------- |
| Databases, schemas                       | ✓                    | —                           |
| Tables, views, Dynamic Tables            | ✓                    | ✓ as nodes                  |
| Columns                                  | ✓ with types         | ✓ column-level              |
| Tags                                     | ✓ as classifications | —                           |
| Lineage edges                            | —                    | ✓ \~3 hr lag                |
| Streams, stages, stored procedures, UDFs | Ingested, not shown  | Used internally for lineage |

{% hint style="info" %}
Lineage is computed — not fetched directly. DataOS parses view definitions, write queries (`MERGE`, `INSERT INTO SELECT`, `CTAS`, etc.), stored procedure child queries, and external table locations from `ACCOUNT_USAGE.QUERY_HISTORY`.
{% endhint %}

### 5.2: Scanner permissions

Separate read-only role from the Vulcan service role in section 2.1.

```sql
GRANT USAGE ON DATABASE <db> TO ROLE <scanner_role>;
GRANT USAGE ON ALL SCHEMAS IN DATABASE <db> TO ROLE <scanner_role>;
GRANT REFERENCES ON ALL TABLES IN DATABASE <db> TO ROLE <scanner_role>;
GRANT REFERENCES ON FUTURE TABLES IN DATABASE <db> TO ROLE <scanner_role>;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <scanner_role>;
GRANT ROLE <scanner_role> TO USER <scanner_user>;
```

{% hint style="warning" %}
`IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE` requires ACCOUNTADMIN. Without it, lineage edges and tags will not be populated.
{% endhint %}

### 5.3: What the metadata scanner reads

The metadata scanner reads from two Snowflake surfaces: `INFORMATION_SCHEMA` and `SNOWFLAKE.ACCOUNT_USAGE`.

#### INFORMATION_SCHEMA

Access to `INFORMATION_SCHEMA` is covered by the existing `USAGE` on database and schema plus `SELECT` (or `REFERENCES`) on objects. No additional grants are needed.

The metadata scanner reads from:

```
<DATABASE_NAME>.INFORMATION_SCHEMA.DATABASES
<DATABASE_NAME>.INFORMATION_SCHEMA.SCHEMATA
<DATABASE_NAME>.INFORMATION_SCHEMA.TABLES
<DATABASE_NAME>.INFORMATION_SCHEMA.COLUMNS
<DATABASE_NAME>.INFORMATION_SCHEMA.VIEWS
```

#### SNOWFLAKE.ACCOUNT_USAGE

Account-level metadata, usage history, lineage, stored procedures, and functions are accessed via `ACCOUNT_USAGE`. This requires one additional grant:

```sql
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <DATAOS_ROLE>;
```

The metadata scanner reads from:

```
SNOWFLAKE.ACCOUNT_USAGE.TABLES
SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES
SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
SNOWFLAKE.ACCOUNT_USAGE.PROCEDURES
SNOWFLAKE.ACCOUNT_USAGE.FUNCTIONS
SNOWFLAKE.ACCOUNT_USAGE.DYNAMIC_TABLE_REFRESH_HISTORY
```

{% hint style="warning" %}
`IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE` requires ACCOUNTADMIN. Without it, lineage edges, tags, procedures, functions, and Dynamic Table history will not be populated in the catalog.
{% endhint %}

### 5.4: Refresh & lag

Scanner runs every 6–12 hours (**configurable**). Structural changes appear after the next run. Lineage edges appear up to 3 hours after a query executes — this is a Snowflake platform constraint. If lineage is missing after a `vulcan apply`, wait or trigger a manual scanner run.

## Section 6: Engine-native feature support

This section lists what Snowflake objects you can drive from a Vulcan Data Product, and which edition each requires.

| Snowflake feature                      | Vulcan pattern                                                                                         | Edition                                           |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------ | ------------------------------------------------- |
| Warehouse selection                    | `gateway.connection.warehouse` or `physical_properties (warehouse = …)` per model                      | Standard+                                         |
| Full-refresh table                     | kind `FULL`                                                                                            | Standard+                                         |
| Incremental table                      | kind `INCREMENTAL_BY_TIME_RANGE / UNIQUE_KEY / PARTITION`                                              | Standard+                                         |
| Transient table                        | kind `FULL` + `physical_properties (creatable_type = TRANSIENT)`                                       | Standard+                                         |
| Temporary table                        | kind `FULL` + `physical_properties (creatable_type = TEMPORARY)`                                       | Standard+                                         |
| Dynamic Table                          | kind `MANAGED` + `physical_properties (target_lag, warehouse)`                                         | Enterprise+                                       |
| Standard view                          | kind `VIEW`                                                                                            | Standard+                                         |
| Secure view                            | kind `VIEW` + `virtual_properties (createable_type = SECURE)`                                          | Standard+                                         |
| Materialized view (via Dynamic Tables) | kind `VIEW (materialized true)` — compiles to Dynamic Table                                            | Enterprise+                                       |
| Stream (CDC)                           | Base table + `CREATE STREAM` in `before_all`; model selects from stream                                | Standard+                                         |
| SQL / JS / Python UDF (inline)         | `CREATE OR REPLACE FUNCTION` in `pre_statements`                                                       | Standard+                                         |
| UDF from internal stage                | `PUT` zip via script; `IMPORTS = (@stage/file.zip)` in the UDF body                                    | Standard+                                         |
| Stored procedure                       | `CREATE PROCEDURE` + `CALL` in `before_all`; model selects from produced table                         | Standard+                                         |
| Snowpark Python model                  | `.py` model file with `@model(...)` and `def execute(...)`                                             | Standard+ (Snowpark-enabled WH)                   |
| Clustering                             | `ALTER TABLE … CLUSTER BY` in `post_statements`, guarded by `@IF(@runtime_stage = 'evaluating', …)`    | Standard+                                         |
| GRANT                                  | `GRANT … TO ROLE …` in `post_statements`, guarded                                                      | Standard+                                         |
| Masking policy                         | `CREATE MASKING POLICY` in `before_all`; `ALTER TABLE … SET MASKING POLICY` in `post_statements`       | Enterprise+                                       |
| Row access policy                      | `CREATE ROW ACCESS POLICY` in `before_all`; `ALTER TABLE … ADD ROW ACCESS POLICY` in `post_statements` | Enterprise+                                       |
| Internal stage                         | `CREATE STAGE` in `before_all`                                                                         | Standard+                                         |
| External stage (S3/GCS/Azure)          | `CREATE STAGE URL = '…'` with cloud credentials in `before_all`                                        | Standard+                                         |
| Sequence                               | `CREATE SEQUENCE` in `before_all`; `seq.NEXTVAL` in model SQL                                          | Standard+                                         |
| Table clone                            | `CREATE … CLONE` in `after_all` or a standalone script                                                 | Standard+                                         |
| Iceberg table                          | `CREATE ICEBERG TABLE` in `before_all`; reference like any other table                                 | Standard+ (external volume required)              |
| Snowflake Task                         | `CREATE TASK` + `ALTER TASK RESUME` in `after_all`                                                     | Standard+                                         |
| Result cache                           | Automatic — no Vulcan config needed                                                                    | Standard+                                         |
| Time Travel                            | `DATA_RETENTION_TIME_IN_DAYS` on the DB/table                                                          | Standard (1 day max), Enterprise+ (up to 90 days) |
| Fail-safe                              | Automatic on permanent tables (7 days); none on TRANSIENT / TEMPORARY                                  | Standard+                                         |

**Guard rule for lifecycle DDL.** Any DDL in `pre_statements` / `post_statements` that should only run during real execution must be wrapped:

```sql
@IF(@runtime_stage = 'evaluating',
  ALTER TABLE myproj.gold.orders CLUSTER BY (order_date, nation_name)
);
```

Without the guard, `vulcan plan` dry-runs will execute it.

## Section 7: Operational boundaries

These are concrete settings with hard thresholds. Treat it as an engineering contract; tune from telemetry.

### 7.1: Compute sizing

| Workload                         | Size                                  | Rationale                                                                                                |
| -------------------------------- | ------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Dev / single-user plan iteration | X-SMALL or SMALL                      | Plan only builds a few models; larger wastes credits                                                     |
| First full backfill              | LARGE or X-LARGE                      | Backfills parallelize across historical intervals; bigger finishes faster and is usually cheaper overall |
| Daily incremental runs           | MEDIUM                                | Touches only new partitions; oversizing burns credits with no latency gain                               |
| Semantic API / concurrent BI     | LARGE (raise MAX\_CONCURRENCY\_LEVEL) | Each API query hits Snowflake directly; size for queue depth                                             |
| Snowpark / Python models         | One size up vs. equivalent SQL        | The warehouse coordinates the Snowpark pool; under-sizing stalls executor allocation                     |

Always set:

```sql
ALTER WAREHOUSE <wh> SET
  AUTO_SUSPEND = 60       -- seconds; Vulcan workloads are bursty
  AUTO_RESUME  = TRUE;
```

### 7.2: Concurrency

`MAX_CONCURRENCY_LEVEL` controls how many simultaneous queries the warehouse runs before queueing.

| Scenario                               | Setting     |
| -------------------------------------- | ----------- |
| Model runs only, no live API           | default (8) |
| Model runs + live semantic API         | 12–16       |
| BI / dashboard load with many sessions | 20+         |

Keep `concurrent_tasks` in `config.yaml` ≤ `MAX_CONCURRENCY_LEVEL / 3` so model builds don't starve API queries.

```sql
ALTER WAREHOUSE <wh> SET MAX_CONCURRENCY_LEVEL = 12;
```

### 7.3: API replicas & Kubernetes resources

| Traffic                           | API replicas |
| --------------------------------- | ------------ |
| Single team                       | 1–2          |
| Multi-team / scheduled dashboards | 3–5          |
| Enterprise / high-volume          | 5+           |

The API is stateless — add replicas before raising Snowflake concurrency.

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

| Recommendation                     | Why                                                    |
| ---------------------------------- | ------------------------------------------------------ |
| Schedule after upstream data lands | Avoid reading partial data                             |
| `timezone: UTC` in production      | DST shifts won't silently move the window              |
| Set `endOn` ≥ 1–2 years out        | Expired `endOn` halts the workflow silently            |
| `concurrencyPolicy: Forbid`        | Prevents a second job from launching during an overrun |

### 7.5: Latency floor

What you cannot tune below, regardless of warehouse size:

| Component                                    | Floor                     |
| -------------------------------------------- | ------------------------- |
| Cold start after AUTO\_SUSPEND               | +1–3 s on the first query |
| Semantic API overhead (standard query)       | \~1.5–2 s                 |
| Semantic API overhead (cross-join / complex) | \~4–5 s                   |
| Snowflake query parse + plan                 | 50–200 ms                 |
| Result-cache hit                             | < 1 s end-to-end          |

{% hint style="info" %}
If your downstream SLO is tighter than this floor + your Snowflake execution time, sizing up will not save you. Reshape the workload or shorten the call chain.
{% endhint %}

### 7.6: Operational limitations

| #  | Limitation                                                                              | Workaround                                                                              |
| -- | --------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| O1 | `vulcan create_external_models` returns empty for cross-database sources                | Declare manually in `external_models.yaml` with triple-quoted identifiers (section 4.4) |
| O2 | Lifecycle DDL in `pre_/post_statements` runs during `vulcan plan`                       | Wrap in `@IF(@runtime_stage = 'evaluating', …)` (section 4.2.1)                         |
| O3 | Module-level Snowpark imports may be invisible inside `execute()`                       | Import Snowpark functions inside `execute()` (section 4.2.1)                            |
| O4 | `@macro()` parameters annotated `: str` raise `Coercion failed`                         | Don't annotate; render with `.sql(dialect=evaluator.dialect)` (section 4.2.1)           |
| O5 | `unique_values` assertion on one column of a composite key flags valid rows             | Declare grain `(col_a, col_b)` instead                                                  |
| O6 | Snowflake stores unquoted identifiers in UPPERCASE — lowercase in semantic models fails | Use UPPERCASE everywhere in semantic models (section 4.2.2)                             |
| O7 | Expired `endOn` halts the workflow silently                                             | Audit `endOn` quarterly                                                                 |
| O8 | Macros not discovered if `macros/__init__.py` is missing                                | Keep the empty `__init__.py`                                                            |
| O9 | First query after `AUTO_SUSPEND` pays 1–3 s cold-start                                  | Keep `AUTO_SUSPEND = 60`; pin a warming query if SLO-critical                           |

## Section 8: Performance & Cost

Use this section to set realistic expectations before production. The benchmark numbers show where Snowflake performs well, where it degrades, and which bottlenecks you should solve first.

{% hint style="warning" %}
**Use these numbers for SLO and cost planning.** The benchmark values are reference numbers; tune from telemetry once deployed.
{% endhint %}

Refer to section 8.1 to set SLO expectations and size compute; use section 8.2 to put guardrails in place before going to production.

### 8.1: Benchmarks

Treat these numbers as planning baselines, not guarantees. The final outcome still depends on data shape, join patterns, concurrency, and warehouse sizing.

Reference numbers from TPC-H SF1000, Medium warehouse, 100 queries simulating 10 users at 5 parallel requests.

#### 8.1.1: Headline numbers

| Metric                                              | Value          |
| --------------------------------------------------- | -------------- |
| Standard query completion (TPC-H SF1000, Medium WH) | 12–15 s        |
| Semantic API overhead, standard queries             | \~1.84 s       |
| Cross-join heavy queries                            | up to 5.13 min |
| Concurrent success rate (10 users × 5 parallel)     | 82%            |

Budget 1.5–2 s of API overhead on top of Snowflake execution for any standard query.

#### 8.1.2: By query type

TPC-H SF1000, Medium WH:

| Query type                | Snowflake exec | API overhead | Result rows |
| ------------------------- | -------------- | ------------ | ----------- |
| Low-cardinality GROUP BY  | 10.2 s         | 2.3 s        | 5           |
| Multi-column GROUP BY     | 10.3 s         | 1.8 s        | 25          |
| High-cardinality GROUP BY | 10.25 s        | 1.66 s       | 50k         |
| Fact aggregation          | 10.3 s         | 1.8 s        | 50k         |
| SUM + GROUP BY            | 10.25 s        | 1.66 s       | 50k         |
| Cross-join aggregation    | 5.13 min       | 4.8 s        | 3.5k        |

{% hint style="info" %}
Cross-joins are the only outlier — 30× slower. The fix is always in the SQL shape, never warehouse sizing.
{% endhint %}

#### 8.1.3: By compute size × dataset scale

| Warehouse        | Snowflake exec | API overhead | Total   |
| ---------------- | -------------- | ------------ | ------- |
| **TPC-H SF1**    |                |              |         |
| X-Small          | 3–5 s          | 1.5–2 s      | 5–7 s   |
| Medium           | 1–3 s          | 1.5–2 s      | 3–5 s   |
| X-Large          | < 1 s          | 1–2 s        | 2–3 s   |
| **TPC-H SF10**   |                |              |         |
| X-Small          | 6–12 s         | 1.5–2 s      | 8–14 s  |
| Small            | 5–10 s         | 1.5–2 s      | 7–12 s  |
| Medium           | 4–8 s          | 1.5–2 s      | 6–10 s  |
| Large            | 3–6 s          | 1.5–2 s      | 5–8 s   |
| X-Large          | 2–5 s          | 1.5–2 s      | 4–7 s   |
| **TPC-H SF100**  |                |              |         |
| X-Small          | 15–30 s        | 2 s          | 17–32 s |
| Small            | 12–25 s        | 2 s          | 14–27 s |
| Medium           | 8–20 s         | 2 s          | 10–22 s |
| Large            | 5–15 s         | 2 s          | 7–17 s  |
| X-Large          | 3–10 s         | 2 s          | 5–12 s  |
| **TPC-H SF1000** |                |              |         |
| X-Small          | 60+ s          | 2–5 s        | 65+ s   |
| Small            | 25–50 s        | 2–5 s        | 30–55 s |
| Medium           | 10–15 s        | 1.8–5 s      | 12–20 s |
| Large            | 5–10 s         | 1.8–5 s      | 7–15 s  |
| X-Large          | 3–8 s          | 1.8–5 s      | 5–13 s  |

{% hint style="info" %}
Doubling warehouse size halves engine time but does not change the API floor. Beyond Large on SF1000 you are paying for diminishing returns unless you have a hard sub-10 s SLO.
{% endhint %}

#### 8.1.4: Concurrency

| Metric        | Result                                                           |
| ------------- | ---------------------------------------------------------------- |
| Total queries | 100                                                              |
| Successful    | 82                                                               |
| Failed        | 18                                                               |
| Failure modes | API throttling, warehouse saturation, query queuing past timeout |

Fix order when concurrency degrades: cut cross-joins → add API replicas → raise `MAX_CONCURRENCY_LEVEL` → only then size up the warehouse.

#### 8.1.5: Performance ceilings

| #  | Ceiling                                                                            | Tune via                                                                   |
| -- | ---------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| P1 | Cross-join queries run 30× longer than grouped queries (up to 5 min on SF1000)     | Replace with explicit JOINs; pre-aggregate; introduce a mart               |
| P2 | Concurrency degrades past \~10 users × 5 parallel on a single Medium WH            | Raise `MAX_CONCURRENCY_LEVEL`; add API replicas; size up                   |
| P3 | Sizing up the warehouse reduces Snowflake exec time but not API overhead           | Treat the API floor as a constant; budget SLOs above it                    |
| P4 | API memory below 1.5 GiB risks OOM on 50k-row endpoint results                     | Keep `api.limit.memory` at 3 GiB                                           |
| P5 | Snowpark coordinator stalls on undersized warehouses                               | Size up one step vs. equivalent SQL                                        |
| P6 | Iceberg-table reads can be slower than native Snowflake tables for small workloads | Use native tables for Bronze/Silver; Iceberg for cross-engine sharing only |

### 8.2: Cost guardrails

#### 8.2.1: Hard spend cap

```sql
CREATE RESOURCE MONITOR vulcan_monthly_cap
  WITH CREDIT_QUOTA = 500
       FREQUENCY    = MONTHLY
       START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 75  PERCENT DO NOTIFY
    ON 90  PERCENT DO SUSPEND
    ON 100 PERCENT DO SUSPEND_IMMEDIATE;

ALTER WAREHOUSE vulcan_wh SET RESOURCE_MONITOR = vulcan_monthly_cap;
```

#### 8.2.2: Query-level controls (timeouts)

```sql
ALTER WAREHOUSE vulcan_wh SET
  STATEMENT_TIMEOUT_IN_SECONDS        = 3600
  STATEMENT_QUEUED_TIMEOUT_IN_SECONDS = 300;
```

The queued timeout is the more important of the two on a high-concurrency API workload — it prevents endpoint requests from piling up behind a stuck job.

#### 8.2.3: Cost attribution (query tagging)

Tag every query the Data Product issues so cost can be sliced by project / model / consumer:

```sql
ALTER SESSION SET QUERY_TAG = 'vulcan:<project>:<model>';
```

Or set a default at the gateway via lifecycle SQL. See [Data product](../../../data-product.md).

#### 8.2.4: Storage cost management

Always set `AUTO_SUSPEND = 60` seconds. Vulcan workloads are bursty — anything longer wastes credits between runs.

`DATA_RETENTION_TIME_IN_DAYS = 1` (default) is fine for most projects. Storage cost scales with retention × table size — a 1 TB table at 30 days retention can store 30 TB of historical snapshots. Set Bronze/staging tables to `TRANSIENT` (no Fail-safe; up to 1 day Time Travel) when you can re-derive them from sources.

Primary references: [Data product](../../../data-product.md) · [Data Product Lifecycle](../guides/data-product-lifecycle.md)

## Section 9: Failure modes & troubleshooting

Start from the symptom you can observe. Map it to the most likely cause, apply the smallest safe fix, and confirm recovery with a health check before moving on.

{% hint style="info" %}
**Debugging flow.** Start with the symptom, confirm the likely cause, apply the fix, then use the health-check queries to validate recovery.
{% endhint %}

These are the top 15 errors you are most likely to hit in real projects. Use the table as a fast triage guide, then jump to the related section when the issue needs deeper context.

| #   | Symptom                                                                   | Likely cause                                               | Fix                                                                              |
| --- | ------------------------------------------------------------------------- | ---------------------------------------------------------- | -------------------------------------------------------------------------------- |
| F1  | JWT token is invalid on first run                                         | Public key not registered, or PEM encryption mismatch      | `ALTER USER … SET RSA_PUBLIC_KEY = '<pub>'`; verify passphrase                   |
| F2  | Account identifier not found                                              | Wrong format                                               | Use `<org>-<account>` (from Snowflake console URL); not the legacy locator       |
| F3  | Object 'COL' does not exist in semantic queries                           | Lowercase column in semantic model                         | Switch all dimensions/measures/filters to UPPERCASE (section 4.2.2)              |
| F4  | Table not found: `SNOWFLAKE_SAMPLE_DATA…` during `vulcan plan`            | Cross-DB source not declared as external                   | Add to `external_models.yaml` with triple-quoted identifier (section 4.4)        |
| F5  | Insufficient privileges to operate on schema during auto-apply            | Role missing `CREATE SCHEMA / CREATE TABLE`                | Grant per section 2.1 template                                                   |
| F6  | `IMPORTED PRIVILEGES` required when reading `SNOWFLAKE_SAMPLE_DATA`       | Share not mounted to your role                             | `GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_SAMPLE_DATA TO ROLE <r>`        |
| F7  | Workflow `apply` succeeds but every run fails with `Depot not resolvable` | Depot name in Vulcan resource doesn't match depot manifest | Verify `dataos://<depot-name>?purpose=rw` matches the depot's `name` field       |
| F8  | `vulcan plan` mysteriously runs DDL on Snowflake                          | `pre_/post_statements` DDL not guarded                     | Wrap in `@IF(@runtime_stage = 'evaluating', …)` (section 4.2.1)                  |
| F9  | `Coercion failed` when evaluating macro                                   | Macro parameter annotated `: str`                          | Remove annotation; render with `.sql(dialect=evaluator.dialect)` (section 4.2.1) |
| F10 | `NameError: 'col' is not defined` in Snowpark model                       | Snowpark functions imported at module level                | Move imports inside `execute()` (section 4.2.1)                                  |
| F11 | Snowpark model runs 5–10× longer than equivalent SQL                      | Warehouse undersized for Snowpark coordinator              | Size up one step (section 7.1)                                                   |
| F12 | Endpoint OOM-kills on a 50k-row result                                    | `api.memory.limit` below 1.5 GiB                           | Raise to 3 GiB (section 7.3)                                                     |
| F13 | First query after idle period is consistently 1–3 s slower                | Warehouse cold start                                       | Expected; document in SLO or pin a warming query                                 |
| F14 | Dashboard concurrent users hit 18% failure rate                           | Warehouse saturating at `MAX_CONCURRENCY_LEVEL`            | Raise concurrency → add API replicas → size up (section 8.1.4)                   |
| F15 | Audit/DQ checks suspiciously fast on re-run                               | Snowflake result cache hit                                 | Expected; tag DQ queries separately if benchmarking (section 8.2.3)              |

### 9.1: Health-check queries

```sql
-- Recent Vulcan queries
SELECT query_id, query_text, execution_status,
       total_elapsed_time/1000 AS seconds, warehouse_name
FROM   snowflake.account_usage.query_history
WHERE  query_tag LIKE 'vulcan:%'
  AND  start_time > DATEADD(hour, -2, CURRENT_TIMESTAMP())
ORDER  BY start_time DESC
LIMIT  50;

-- Queueing check
SELECT warehouse_name,
       COUNT(*) AS queries,
       AVG(queued_provisioning_time + queued_overload_time)/1000 AS avg_queued_s
FROM   snowflake.account_usage.query_history
WHERE  start_time > DATEADD(hour, -1, CURRENT_TIMESTAMP())
GROUP  BY warehouse_name
ORDER  BY avg_queued_s DESC;

-- Top expensive queries this week
SELECT query_id, query_tag,
       credits_used_cloud_services, total_elapsed_time/1000 AS seconds
FROM   snowflake.account_usage.query_history
WHERE  start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER  BY total_elapsed_time DESC
LIMIT  20;
```

### 9.2: Recovery procedures

| Situation                                | Procedure                                                                                                         |
| ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Incremental run failed mid-way           | Re-run the workflow; `INCREMENTAL_BY_TIME_RANGE` re-deletes and re-inserts the affected window — re-runs are safe |
| State drifted (table dropped manually)   | `vulcan plan` will detect and re-create; or `vulcan run --rebuild <model>` to force                               |
| Need to roll back a plan version         | `vulcan rollback <plan_id>` — re-runs prior materialisation; counts credits                                       |
| Workflow halted because `endOn` expired  | Update the Vulcan resource with a new `endOn` and re-apply                                                        |
| Resource monitor suspended the warehouse | Investigate spend; raise the monitor's `CREDIT_QUOTA` or `ALTER WAREHOUSE … RESUME`                               |

## Section 10: Deployment recipes

### 10.1: Daily incremental, small project

Daily incremental, small project (5–20 models):

```sql
-- Snowflake
CREATE WAREHOUSE vulcan_wh
  WITH WAREHOUSE_SIZE = 'MEDIUM'
       AUTO_SUSPEND   = 60
       AUTO_RESUME    = TRUE
       MAX_CONCURRENCY_LEVEL = 8
       STATEMENT_TIMEOUT_IN_SECONDS = 1800
       STATEMENT_QUEUED_TIMEOUT_IN_SECONDS = 300;
```

```yaml
# config.yaml
model_defaults:
  dialect: snowflake
  start: '<YYYY-MM-DD>'
  cron: '@daily'
concurrent_tasks: 2

# Vulcan resource
api:
  replicas: 2
  resource:
    request: { cpu: "200m", memory: "512Mi" }
    limit:   { cpu: "2000m", memory: "1500Mi" }
workflow:
  schedule:
    crons: ['0 3 * * *']
    timezone: UTC
    endOn: '<2027-01-01T00:00:00Z>'
    concurrencyPolicy: Forbid
```

### 10.2: High-concurrency workload

High-concurrency BI workload (multi-team dashboards):

```sql
-- Split model runs from API traffic
CREATE WAREHOUSE vulcan_build_wh
  WITH WAREHOUSE_SIZE = 'MEDIUM'
       AUTO_SUSPEND = 60
       MAX_CONCURRENCY_LEVEL = 8;

CREATE WAREHOUSE vulcan_api_wh
  WITH WAREHOUSE_SIZE = 'LARGE'
       AUTO_SUSPEND = 60
       MAX_CONCURRENCY_LEVEL = 16
       STATEMENT_TIMEOUT_IN_SECONDS = 600
       STATEMENT_QUEUED_TIMEOUT_IN_SECONDS = 60;
```

```yaml
# config.yaml — split gateways by purpose
gateways:
  default:
    connection: { type: depot, address: 'dataos://vulcan-build-depot' }
  api:
    connection: { type: depot, address: 'dataos://vulcan-api-depot' }

api:
  replicas: 5
  resource:
    request: { cpu: "500m", memory: "1Gi" }
    limit:   { cpu: "4000m", memory: "3Gi" }
```

### 10.3: Large backfill

Large backfill (first run, 1–5 years of history):

```sql
-- Upsize for backfill, then revert
ALTER WAREHOUSE vulcan_wh SET WAREHOUSE_SIZE = 'X-LARGE';
-- After backfill: ALTER WAREHOUSE vulcan_wh SET WAREHOUSE_SIZE = 'MEDIUM';
```

```yaml
# config.yaml — raise parallelism for backfill only
concurrent_tasks: 8

# Vulcan resource — one-shot run, no schedule
workflow:
  type: trigger
  resource:
    limit: { cpu: "2000m", memory: "2Gi" }
```

Time the backfill at off-peak hours. Resource monitor credit quota should account for the spike (5–10× a normal day).

### 10.4: Mixed SQL + native runtime

Mixed SQL + Snowpark project:

```sql
CREATE WAREHOUSE vulcan_wh
  WITH WAREHOUSE_SIZE = 'LARGE'
       AUTO_SUSPEND = 60
       MAX_CONCURRENCY_LEVEL = 12
       STATEMENT_TIMEOUT_IN_SECONDS = 3600;
```

```yaml
# config.yaml
model_defaults:
  dialect: snowflake
  cron: '@daily'
concurrent_tasks: 4
```

Snowpark code rules apply (section 4.2.1).
