---
description: >-
  Minimum PostgreSQL grants for a Vulcan deployment: source, target, and
  state schema privileges, by secret_name tier.
---

# PostgreSQL

This page covers the minimum PostgreSQL permissions needed to run Vulcan. Platform and database administrators use it to grant a Vulcan service account exactly the privileges Vulcan needs, and nothing more.

Vulcan cannot create PostgreSQL databases. All databases must already exist before you grant access; Vulcan only needs permission to connect to existing databases and, when required, create schemas and objects inside them.

PostgreSQL is a single-catalog engine, so cross-database queries are not supported. All source schemas and the Vulcan target schema must reside in the same database. If your sources span multiple databases, use a foreign data wrapper or a different engine.

{% hint style="warning" %}
Confirm every source schema and the Vulcan target schema live in the same PostgreSQL database before granting these permissions. Vulcan cannot query across databases.
{% endhint %}

## What Vulcan does

### Source schemas (read-only)

| Privilege                                                            | Purpose                                                                               |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| `SELECT`                                                             | Reads tables and views referenced by models.                                          |
| Catalog reads (`pg_tables`, `pg_views`, `pg_matviews`, `pg_catalog`) | Object introspection. Accessible to all users by default; no special grant is needed. |

### Model target schema (write)

| Privilege                                                                                                              | Purpose                                                                            |
| ---------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `CREATE TABLE`, `DROP TABLE` + `CREATE TABLE`                                                                          | Full model refresh. Postgres does not support `CREATE OR REPLACE TABLE`.           |
| `DROP VIEW` + `CREATE VIEW`                                                                                            | Semantic layer views and virtual layer promotion.                                  |
| `ALTER TABLE`                                                                                                          | Column adds and drops when the model schema changes between deployments.           |
| `INSERT`, `MERGE` (Postgres 15+; logical merge via `INSERT`/`UPDATE`/`DELETE` on older versions), `TRUNCATE`, `DELETE` | Incremental model evaluation.                                                      |
| `COMMENT ON TABLE / VIEW / COLUMN`                                                                                     | Applied automatically. Requires ownership, which Vulcan has on objects it creates. |

### State schema (write)

The state schema requires the same grants as the target schema. Vulcan stores internal metadata here, including `_snapshots`, `_environments`, and `_intervals`. By default, this is the same schema as the model target. If `state_schema` in the gateway config points elsewhere, apply the same write grants to that schema too.

### Session-level

Vulcan runs `SHOW server_version` to check the Postgres version and decide whether to use native `MERGE` or a logical merge fallback. This requires no special privilege.

### Not required here

| Item                     | Reason                                                         |
| ------------------------ | -------------------------------------------------------------- |
| `CREATE TABLE ... CLONE` | Not supported by Postgres. This is a Snowflake-only concept.   |
| Multiple database grants | Postgres is single-catalog; all schemas exist in one database. |

## Role and user setup

Run this once before applying any grants:

```sql
CREATE ROLE <VULCAN_ROLE> WITH LOGIN PASSWORD '<PASSWORD>';
```

To use a separate login user and a group role instead:

```sql
CREATE ROLE <VULCAN_ROLE>;
CREATE USER <VULCAN_USER> WITH PASSWORD '<PASSWORD>';
GRANT <VULCAN_ROLE> TO <VULCAN_USER>;
```

## secret_name: `postgres-semantic-readonly`

Use this tier when Vulcan only exposes PostgreSQL tables or views through the semantic layer. No models run, and no objects are created or written. This is a pure read-only connection.

### Database

```sql
GRANT CONNECT ON DATABASE <DATABASE_NAME> TO <VULCAN_ROLE>;
```

### Schema

```sql
GRANT USAGE ON SCHEMA <SOURCE_SCHEMA> TO <VULCAN_ROLE>;
```

### Tables and views

Grant `SELECT` only on the specific objects exposed to the semantic layer:

```sql
GRANT SELECT ON TABLE <SOURCE_SCHEMA>.<TABLE_NAME> TO <VULCAN_ROLE>;
GRANT SELECT ON VIEW  <SOURCE_SCHEMA>.<VIEW_NAME>  TO <VULCAN_ROLE>;
```

Or grant across the full schema if all objects are approved:

```sql
GRANT SELECT ON ALL TABLES IN SCHEMA <SOURCE_SCHEMA> TO <VULCAN_ROLE>;
GRANT SELECT ON ALL VIEWS  IN SCHEMA <SOURCE_SCHEMA> TO <VULCAN_ROLE>;
```

To cover tables and views created in the future:

```sql
ALTER DEFAULT PRIVILEGES IN SCHEMA <SOURCE_SCHEMA>
  GRANT SELECT ON TABLES TO <VULCAN_ROLE>;
```

**What works:** Semantic queries over external models.
**What is blocked:** Vulcan cannot create, alter, truncate, delete, or drop any PostgreSQL object.

## secret_name: `postgres-single-db-full`

Use this tier when the source schema and the Vulcan target schema are both inside one PostgreSQL database. It covers every Vulcan model kind (`FULL`, `INCREMENTAL_BY_TIME_RANGE`, `SCD_TYPE_2`, `SEED`, `VIEW`), plus semantic layer exposure.

### Database

```sql
GRANT CONNECT ON DATABASE <DATABASE_NAME> TO <VULCAN_ROLE>;
```

### Source schema (read-only)

```sql
GRANT USAGE  ON SCHEMA <SOURCE_SCHEMA> TO <VULCAN_ROLE>;

GRANT SELECT ON ALL TABLES IN SCHEMA <SOURCE_SCHEMA> TO <VULCAN_ROLE>;
GRANT SELECT ON ALL VIEWS  IN SCHEMA <SOURCE_SCHEMA> TO <VULCAN_ROLE>;
```

To cover tables and views added to the source schema in the future:

```sql
ALTER DEFAULT PRIVILEGES IN SCHEMA <SOURCE_SCHEMA>
  GRANT SELECT ON TABLES TO <VULCAN_ROLE>;
```

If models read from more than one schema within the same database, apply the same schema-level grants to each additional source schema.

{% hint style="info" %}
Repeat the source schema grants above for every additional schema a model reads from.
{% endhint %}

### Vulcan target schema (read/write)

Create the schema if it does not exist, then grant write access:

```sql
CREATE SCHEMA IF NOT EXISTS <VULCAN_SCHEMA>;

GRANT USAGE  ON SCHEMA <VULCAN_SCHEMA> TO <VULCAN_ROLE>;
GRANT CREATE ON SCHEMA <VULCAN_SCHEMA> TO <VULCAN_ROLE>;
```

`CREATE` on the schema lets Vulcan create tables and views. Because Vulcan's role creates these objects, it automatically owns them and has full access. No additional table-level grants are needed for objects Vulcan creates itself.

If the Vulcan schema already contains objects created by a different role, grant explicit access on those existing objects:

```sql
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE
  ON ALL TABLES IN SCHEMA <VULCAN_SCHEMA> TO <VULCAN_ROLE>;
```

### Optional: schema ownership

Ownership lets Vulcan fully manage the schema lifecycle (`ALTER`, `DROP`, `REPLACE`, cleanup) without per-object privilege issues when another role created the objects.

```sql
ALTER SCHEMA <VULCAN_SCHEMA> OWNER TO <VULCAN_ROLE>;
```

If existing tables or views in the schema were created by a different role, transfer ownership on those objects:

```sql
-- Transfer ownership of all tables
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = '<VULCAN_SCHEMA>'
  LOOP
    EXECUTE 'ALTER TABLE <VULCAN_SCHEMA>.' || quote_ident(r.tablename) || ' OWNER TO <VULCAN_ROLE>';
  END LOOP;
END $$;
```

**What works:** All Vulcan model kinds, semantic layer, and state sync, within a single PostgreSQL database.

## Notes

PostgreSQL does not have `FUTURE` grants. Use `ALTER DEFAULT PRIVILEGES` to cover objects created after the grants are applied. `GRANT ... ON ALL TABLES` commands cover only objects that exist at the time the grant runs.

`COMMENT ON TABLE` and `COMMENT ON COLUMN` require that the role own the object. Vulcan automatically owns objects it creates in the target schema. For source schema objects, Vulcan does not add comments.

`DROP VIEW` in Postgres automatically cascades, so dependent objects are also dropped. This is intentional: Vulcan recreates the view immediately after dropping it.

Postgres 15+ supports native `MERGE`. On older versions, Vulcan falls back to a logical merge using separate `INSERT`, `UPDATE`, and `DELETE` statements within a transaction. The required privileges are the same either way.

## Related resources

| Resource                                                                      | Relationship                                                                |
| ----------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| [Snowflake minimum permissions](snowflake-minimum-permissions.md)             | Equivalent permission tiers for a Snowflake-backed Vulcan deployment.       |
| [Databricks minimum permissions](databricks-minimum-permissions.md)           | Equivalent permission tiers for a Databricks-backed Vulcan deployment.      |
| [Dedicated Trino minimum permissions](dedicated-trino-minimum-permissions.md) | Equivalent permission tiers for a Dedicated Trino-backed Vulcan deployment. |
| [External Trino minimum permissions](external-trino-minimum-permissions.md)   | Equivalent permission tiers for an External Trino-backed Vulcan deployment. |
