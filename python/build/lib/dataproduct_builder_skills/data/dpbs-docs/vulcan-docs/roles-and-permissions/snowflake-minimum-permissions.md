---
description: >-
  Minimum Snowflake grants for a Vulcan deployment: source, target, and
  state schema privileges, by secret_name tier.
---

# Snowflake

This page documents the minimum Snowflake privileges required to run Vulcan. Use it as a reference when granting access to the Vulcan service account, as a platform or database administrator.

Vulcan does not create Snowflake databases. Every database must already exist before you grant access; Vulcan only needs permission to use existing databases and, when required, create schemas and objects inside them.

{% hint style="warning" %}
Vulcan cannot create Snowflake databases. Provision the service account only against databases that already exist, and grant schema-creation privileges only where Vulcan needs to create its own working schema.
{% endhint %}

## What Vulcan does

The privileges Vulcan needs depend on the role a schema plays: source schemas are read-only, while the model target and state schemas require write access.

| Area                        | Privilege                                                                                             | Purpose                                                                                  |
| --------------------------- | ----------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| Source schemas (read-only)  | `SELECT`                                                                                              | Read tables and views referenced by models                                               |
| Source schemas (read-only)  | `DESCRIBE TABLE`                                                                                      | Check whether an object exists                                                           |
| Model target schema (write) | `CREATE TABLE`, `CREATE OR REPLACE TABLE`                                                             | Full model refresh                                                                       |
| Model target schema (write) | `DROP TABLE`                                                                                          | Clean up replaced tables                                                                 |
| Model target schema (write) | `CREATE VIEW`, `CREATE OR REPLACE VIEW`, `DROP VIEW`                                                  | Semantic layer views and virtual layer promotion                                         |
| Model target schema (write) | `ALTER TABLE`                                                                                         | Add or drop columns when the model schema changes between deployments                    |
| Model target schema (write) | `INSERT`, `MERGE`, `TRUNCATE`, `DELETE`                                                               | Incremental model evaluation                                                             |
| Model target schema (write) | `SELECT` on `INFORMATION_SCHEMA.TABLES`                                                               | Object introspection                                                                     |
| State schema (write)        | Same privileges as the model target schema                                                            | Stores internal metadata (`_snapshots`, `_environments`, `_intervals`, etc.)             |
| Session-level               | `USE WAREHOUSE`, `SELECT CURRENT_WAREHOUSE()`, `SELECT CURRENT_DATABASE()`, `SELECT CURRENT_SCHEMA()` | No special privilege required                                                            |
| Session-level               | `ALTER SESSION SET QUERY_TAG`                                                                         | Applied automatically when `correlation_id` is configured; no special privilege required |
| Development only            | `CREATE TABLE ... CLONE`                                                                              | Used only when creating a virtual data environment (VDE) branch                          |
| Development only            | Schema-creation grants on multiple databases                                                          | Only relevant for per-developer virtual data environment (VDE) branches                  |

By default, the state schema is the same schema as the model target. If `state_schema` in the gateway config points elsewhere, apply the same write grants listed above to that schema too.

## Role and user setup

Run once before applying any grants.

```sql
USE ROLE USERADMIN;

CREATE ROLE IF NOT EXISTS <VULCAN_ROLE>;
GRANT ROLE <VULCAN_ROLE> TO USER <VULCAN_USER>;
ALTER USER <VULCAN_USER> SET DEFAULT_ROLE = <VULCAN_ROLE>;
```

{% hint style="warning" %}
**`role` is resolved from the secret projection, not the depot spec**

Vulcan reads the Snowflake `role` from the `role` key in the DataOS secret projection, rather than from the depot spec. This applies to both a direct Snowflake gateway connection and a Dedicated Trino cluster using a Snowflake catalog. If this project uses a custom Snowflake role (such as `<VULCAN_ROLE>` above), make sure the `role` key is present in the secret.
{% endhint %}

## secret_name: `snowflake-semantic-readonly`

Use this tier when Vulcan only exposes Snowflake tables or views through the semantic layer. Vulcan executes no models and creates or writes no objects. This is a pure read-only connection.

### Warehouse

```sql
USE ROLE SYSADMIN;

GRANT USAGE ON WAREHOUSE <WAREHOUSE_NAME> TO ROLE <VULCAN_ROLE>;
```

### Database

```sql
GRANT USAGE ON DATABASE <SOURCE_DATABASE> TO ROLE <VULCAN_ROLE>;
```

### Schema

```sql
GRANT USAGE ON SCHEMA <SOURCE_DATABASE>.<SOURCE_SCHEMA> TO ROLE <VULCAN_ROLE>;
```

### Tables and views

Grant `SELECT` only on the specific objects exposed to the semantic layer:

```sql
GRANT SELECT ON TABLE <SOURCE_DATABASE>.<SOURCE_SCHEMA>.<TABLE_NAME> TO ROLE <VULCAN_ROLE>;
GRANT SELECT ON VIEW  <SOURCE_DATABASE>.<SOURCE_SCHEMA>.<VIEW_NAME>  TO ROLE <VULCAN_ROLE>;
```

Or grant across the full schema if all objects are approved:

```sql
GRANT SELECT ON ALL TABLES    IN SCHEMA <SOURCE_DATABASE>.<SOURCE_SCHEMA> TO ROLE <VULCAN_ROLE>;
GRANT SELECT ON FUTURE TABLES IN SCHEMA <SOURCE_DATABASE>.<SOURCE_SCHEMA> TO ROLE <VULCAN_ROLE>;
GRANT SELECT ON ALL VIEWS     IN SCHEMA <SOURCE_DATABASE>.<SOURCE_SCHEMA> TO ROLE <VULCAN_ROLE>;
GRANT SELECT ON FUTURE VIEWS  IN SCHEMA <SOURCE_DATABASE>.<SOURCE_SCHEMA> TO ROLE <VULCAN_ROLE>;
```

**What works:** Semantic queries over external models.
**What is blocked:** Vulcan cannot create, alter, truncate, delete, or drop any Snowflake object.

## secret_name: `snowflake-single-db-full`

Use this tier when the source schema and the Vulcan target schema are both inside one Snowflake database. It covers all Vulcan model kinds (FULL, INCREMENTAL_BY_TIME_RANGE, SCD_TYPE_2, SEED, VIEW) plus semantic layer exposure.

### Warehouse

```sql
USE ROLE SYSADMIN;

GRANT USAGE ON WAREHOUSE <WAREHOUSE_NAME> TO ROLE <VULCAN_ROLE>;
```

### Database

```sql
GRANT USAGE ON DATABASE <DATABASE_NAME> TO ROLE <VULCAN_ROLE>;
```

If Vulcan should create the Vulcan schema itself:

```sql
GRANT CREATE SCHEMA ON DATABASE <DATABASE_NAME> TO ROLE <VULCAN_ROLE>;
```

If an administrator pre-creates the schema, `CREATE SCHEMA` is not required.

### Source schema (read-only)

```sql
GRANT USAGE ON SCHEMA <DATABASE_NAME>.<SOURCE_SCHEMA> TO ROLE <VULCAN_ROLE>;

GRANT SELECT ON ALL TABLES    IN SCHEMA <DATABASE_NAME>.<SOURCE_SCHEMA> TO ROLE <VULCAN_ROLE>;
GRANT SELECT ON FUTURE TABLES IN SCHEMA <DATABASE_NAME>.<SOURCE_SCHEMA> TO ROLE <VULCAN_ROLE>;
GRANT SELECT ON ALL VIEWS     IN SCHEMA <DATABASE_NAME>.<SOURCE_SCHEMA> TO ROLE <VULCAN_ROLE>;
GRANT SELECT ON FUTURE VIEWS  IN SCHEMA <DATABASE_NAME>.<SOURCE_SCHEMA> TO ROLE <VULCAN_ROLE>;
```

{% hint style="info" %}
If models read from more than one schema within this database, apply the same schema-level grants to each additional source schema.
{% endhint %}

### Vulcan target schema (read/write)

This is where Vulcan writes model outputs, state tables, and semantic layer views.

```sql
CREATE SCHEMA IF NOT EXISTS <DATABASE_NAME>.<VULCAN_SCHEMA>;

GRANT USAGE      ON SCHEMA <DATABASE_NAME>.<VULCAN_SCHEMA> TO ROLE <VULCAN_ROLE>;
GRANT CREATE TABLE ON SCHEMA <DATABASE_NAME>.<VULCAN_SCHEMA> TO ROLE <VULCAN_ROLE>;
GRANT CREATE VIEW  ON SCHEMA <DATABASE_NAME>.<VULCAN_SCHEMA> TO ROLE <VULCAN_ROLE>;

-- Tables (model outputs and state tables)
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE
  ON ALL TABLES    IN SCHEMA <DATABASE_NAME>.<VULCAN_SCHEMA> TO ROLE <VULCAN_ROLE>;

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE
  ON FUTURE TABLES IN SCHEMA <DATABASE_NAME>.<VULCAN_SCHEMA> TO ROLE <VULCAN_ROLE>;

-- Views (semantic layer + virtual layer promotion)
GRANT SELECT ON ALL VIEWS    IN SCHEMA <DATABASE_NAME>.<VULCAN_SCHEMA> TO ROLE <VULCAN_ROLE>;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA <DATABASE_NAME>.<VULCAN_SCHEMA> TO ROLE <VULCAN_ROLE>;
```

### ALTER TABLE on existing objects

`CREATE TABLE` at the schema level covers new tables but does not grant `ALTER` on tables that already exist. Vulcan issues `ALTER TABLE` when model columns change between deployments. To cover this without ownership, grant ownership on the Vulcan schema (recommended), or manually grant `ALTER` on affected tables after they are created.

### Optional: schema ownership

Ownership lets Vulcan fully manage the schema (`ALTER`, `DROP`, `REPLACE`, cleanup) without per-object privilege escalation.

```sql
GRANT OWNERSHIP ON SCHEMA <DATABASE_NAME>.<VULCAN_SCHEMA>
  TO ROLE <VULCAN_ROLE>
  COPY CURRENT GRANTS;
```

If the schema already contains objects created by another role, transfer ownership on those specific objects or recreate them using the Vulcan role.

**What works:** All Vulcan model kinds, semantic layer, and state sync within a single database.

## secret_name: `snowflake-cross-db-full`

Use this tier when Vulcan reads from one or more source databases and writes model outputs into a separate target database. Repeat the source database and schema grants for every source Vulcan reads from.

### Warehouse

```sql
USE ROLE SYSADMIN;

GRANT USAGE ON WAREHOUSE <WAREHOUSE_NAME> TO ROLE <VULCAN_ROLE>;
```

### Source database (read-only)

```sql
GRANT USAGE ON DATABASE <SOURCE_DATABASE> TO ROLE <VULCAN_ROLE>;
```

{% hint style="info" %}
If models read from more than one source database, apply the same database-level grant to each additional source database.
{% endhint %}

### Source schema (read-only)

```sql
GRANT USAGE ON SCHEMA <SOURCE_DATABASE>.<SOURCE_SCHEMA> TO ROLE <VULCAN_ROLE>;

GRANT SELECT ON ALL TABLES    IN SCHEMA <SOURCE_DATABASE>.<SOURCE_SCHEMA> TO ROLE <VULCAN_ROLE>;
GRANT SELECT ON FUTURE TABLES IN SCHEMA <SOURCE_DATABASE>.<SOURCE_SCHEMA> TO ROLE <VULCAN_ROLE>;
GRANT SELECT ON ALL VIEWS     IN SCHEMA <SOURCE_DATABASE>.<SOURCE_SCHEMA> TO ROLE <VULCAN_ROLE>;
GRANT SELECT ON FUTURE VIEWS  IN SCHEMA <SOURCE_DATABASE>.<SOURCE_SCHEMA> TO ROLE <VULCAN_ROLE>;
```

{% hint style="info" %}
If a source database has more than one schema that models read from, apply the same schema-level grants to each additional source schema.
{% endhint %}

### Target database (read/write)

```sql
GRANT USAGE ON DATABASE <TARGET_DATABASE> TO ROLE <VULCAN_ROLE>;
GRANT CREATE SCHEMA ON DATABASE <TARGET_DATABASE> TO ROLE <VULCAN_ROLE>;
```

### Vulcan target schema (read/write)

```sql
CREATE SCHEMA IF NOT EXISTS <TARGET_DATABASE>.<VULCAN_SCHEMA>;

GRANT USAGE       ON SCHEMA <TARGET_DATABASE>.<VULCAN_SCHEMA> TO ROLE <VULCAN_ROLE>;
GRANT CREATE TABLE ON SCHEMA <TARGET_DATABASE>.<VULCAN_SCHEMA> TO ROLE <VULCAN_ROLE>;
GRANT CREATE VIEW  ON SCHEMA <TARGET_DATABASE>.<VULCAN_SCHEMA> TO ROLE <VULCAN_ROLE>;

-- Tables (model outputs and state tables)
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE
  ON ALL TABLES    IN SCHEMA <TARGET_DATABASE>.<VULCAN_SCHEMA> TO ROLE <VULCAN_ROLE>;

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE
  ON FUTURE TABLES IN SCHEMA <TARGET_DATABASE>.<VULCAN_SCHEMA> TO ROLE <VULCAN_ROLE>;

-- Views (semantic layer + virtual layer promotion)
GRANT SELECT ON ALL VIEWS    IN SCHEMA <TARGET_DATABASE>.<VULCAN_SCHEMA> TO ROLE <VULCAN_ROLE>;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA <TARGET_DATABASE>.<VULCAN_SCHEMA> TO ROLE <VULCAN_ROLE>;
```

### Optional: schema ownership

```sql
GRANT OWNERSHIP ON SCHEMA <TARGET_DATABASE>.<VULCAN_SCHEMA>
  TO ROLE <VULCAN_ROLE>
  COPY CURRENT GRANTS;
```

**What works:** All Vulcan model kinds, semantic layer, and state sync across multiple source databases into a dedicated target database. Source databases retain no write access.

## Notes

`FUTURE` grants are not retroactive. If tables or views already exist when you apply the grants, also run the corresponding `ON ALL TABLES` / `ON ALL VIEWS` grants on existing objects.

Column comments (`ALTER TABLE ... ALTER COLUMN ... COMMENT`) are applied after table creation. If the role lacks `ALTER` on an existing table, Vulcan logs a warning and continues. Column comments are absent, but no other operation is affected.

If source and target are in the same database (the single-database case), apply the `GRANT USAGE ON DATABASE` and warehouse grants only once.

## Related resources

| Resource                                                                      | Relationship                                                                          |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| [Databricks minimum permissions](databricks-minimum-permissions.md)           | Equivalent privilege reference for Databricks-backed Vulcan deployments               |
| [Dedicated Trino minimum permissions](dedicated-trino-minimum-permissions.md) | Equivalent privilege reference for dedicated Trino-backed Vulcan deployments          |
| [External Trino minimum permissions](external-trino-minimum-permissions.md)   | Equivalent privilege reference for externally managed Trino-backed Vulcan deployments |
| [PostgreSQL minimum permissions](postgres-minimum-permissions.md)             | Equivalent privilege reference for PostgreSQL-backed Vulcan deployments               |
| [Spark minimum permissions](spark-minimum-permissions.md)                     | Equivalent privilege reference for Spark-backed Vulcan deployments                    |
