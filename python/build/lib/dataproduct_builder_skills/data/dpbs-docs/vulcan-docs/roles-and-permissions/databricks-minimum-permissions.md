---
description: >-
  Minimum Databricks Unity Catalog grants for a Vulcan deployment: source,
  target, and state schema privileges, by secret_name tier.
---

# Databricks

Platform administrators use this reference to grant a Vulcan service principal the Databricks Unity Catalog permissions it needs to run Vulcan.

Vulcan does not create Databricks catalogs. Every catalog must exist before an administrator grants access; Vulcan only needs permission to use existing catalogs and, where required, create schemas and objects inside them.

{% hint style="warning" %}
Create every source and target catalog before granting permissions. Vulcan cannot create catalogs itself.
{% endhint %}

Unity Catalog schema-level grants on `SELECT` and `MODIFY` automatically cover objects created in the future inside that schema, so no separate future-grant step is needed.

{% hint style="info" %}
A schema-level `SELECT` or `MODIFY` grant also applies to tables and views created later in that schema. Unity Catalog has no equivalent of a Snowflake `FUTURE` grant.
{% endhint %}

## What Vulcan does

The table below summarizes what Vulcan does at each stage of a run and the privilege each action requires.

| Area                        | Privilege                                                | Purpose                                                                                     |
| --------------------------- | -------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| Source schemas (read-only)  | `SELECT`                                                 | Read tables and views referenced by models                                                  |
| Source schemas (read-only)  | `USE CATALOG` on the `system` catalog                    | Read `system.information_schema.tables` for object introspection                            |
| Model target schema (write) | `CREATE OR REPLACE TABLE`, `DROP TABLE`                  | Full model refresh                                                                          |
| Model target schema (write) | `CREATE VIEW`, `DROP VIEW`                               | Semantic layer views and virtual layer promotion                                            |
| Model target schema (write) | `ALTER TABLE`                                            | Column adds and drops when the model schema changes between deployments                     |
| Model target schema (write) | `ALTER TABLE ... ALTER COLUMN ... COMMENT`               | Column comments                                                                             |
| Model target schema (write) | `INSERT`, `MERGE`, `REPLACE WHERE`, `TRUNCATE`, `DELETE` | Incremental model evaluation (all covered by `MODIFY`)                                      |
| State schema (write)        | Same privileges as the target schema                     | Internal metadata storage (`_snapshots`, `_environments`, `_intervals`, and similar tables) |
| Session-level               | `USE CATALOG`                                            | Switches the active catalog context                                                         |
| Session-level               | `USE SCHEMA`                                             | Navigates to a schema                                                                       |
| Development only            | `CREATE TABLE ... SHALLOW CLONE`                         | Used only when creating a virtual data environment (VDE) branch                             |

The `USE CATALOG` privilege on the `system` catalog is granted to all users by default in most Databricks workspaces, so this grant is rarely needed explicitly.

By default, the state schema is the same schema as the model target. If `state_schema` in the gateway config points elsewhere, grant the same write privileges to that schema too.

## Required privileges summary

Choose the `secret_name` configuration that matches the deployment topology.

| secret_name                      | Use when                                                                                              |
| -------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `databricks-semantic-readonly`   | Vulcan only exposes existing Databricks tables or views through the semantic layer; no models run     |
| `databricks-single-catalog-full` | The source and target schemas live in the same Databricks catalog                                     |
| `databricks-cross-catalog-full`  | Vulcan reads from one or more source catalogs and writes model outputs into a separate target catalog |

## Role and service principal setup

Databricks recommends using a service principal for Vulcan. Assign the service principal to a group and grant the group the required permissions.

```sql
-- Create a group for Vulcan (optional but recommended)
-- Done via Databricks account admin UI or Terraform

-- Grant the service principal to the group
-- Done via Databricks account admin UI or Terraform
```

All SQL grants on this page use `<VULCAN_PRINCIPAL>`. Replace this placeholder with the service principal name or group name.

## secret_name: `databricks-semantic-readonly`

Use this tier when Vulcan only exposes Databricks tables or views through the semantic layer. No models run, and Vulcan creates no objects. This is a pure read-only connection.

### Catalog

```sql
GRANT USE CATALOG ON CATALOG <SOURCE_CATALOG> TO <VULCAN_PRINCIPAL>;
```

### Schema

```sql
GRANT USE SCHEMA ON SCHEMA <SOURCE_CATALOG>.<SOURCE_SCHEMA> TO <VULCAN_PRINCIPAL>;
```

### Tables and views

Grant `SELECT` only on the specific objects exposed to the semantic layer:

```sql
GRANT SELECT ON TABLE <SOURCE_CATALOG>.<SOURCE_SCHEMA>.<TABLE_NAME> TO <VULCAN_PRINCIPAL>;
GRANT SELECT ON VIEW  <SOURCE_CATALOG>.<SOURCE_SCHEMA>.<VIEW_NAME>  TO <VULCAN_PRINCIPAL>;
```

Or grant across the full schema if all objects are approved:

```sql
GRANT SELECT ON SCHEMA <SOURCE_CATALOG>.<SOURCE_SCHEMA> TO <VULCAN_PRINCIPAL>;
```

**What works:** Semantic queries over external models.

**What is blocked:** Vulcan cannot create, alter, truncate, delete, or drop any Databricks object.

## secret_name: `databricks-single-catalog-full`

Use this tier when the source schema and the Vulcan target schema are both inside one Databricks catalog. It covers all Vulcan model kinds (FULL, INCREMENTAL_BY_TIME_RANGE, SCD_TYPE_2, SEED, VIEW), plus semantic layer exposure.

### Catalog

```sql
GRANT USE CATALOG ON CATALOG <CATALOG_NAME> TO <VULCAN_PRINCIPAL>;
```

If Vulcan creates the target schema itself, add:

```sql
GRANT CREATE SCHEMA ON CATALOG <CATALOG_NAME> TO <VULCAN_PRINCIPAL>;
```

If an administrator pre-creates the schema, `CREATE SCHEMA` is not required.

### Source schema (read-only)

Grant read access on every source schema that Vulcan models read from within this catalog.

```sql
GRANT USE SCHEMA ON SCHEMA <CATALOG_NAME>.<SOURCE_SCHEMA> TO <VULCAN_PRINCIPAL>;
GRANT SELECT     ON SCHEMA <CATALOG_NAME>.<SOURCE_SCHEMA> TO <VULCAN_PRINCIPAL>;
```

{% hint style="info" %}
If models read from more than one schema within the same catalog, repeat the `USE SCHEMA` and `SELECT` grants above for each additional source schema.
{% endhint %}

### Vulcan target schema (read/write)

```sql
GRANT USE SCHEMA    ON SCHEMA <CATALOG_NAME>.<VULCAN_SCHEMA> TO <VULCAN_PRINCIPAL>;
GRANT CREATE TABLE  ON SCHEMA <CATALOG_NAME>.<VULCAN_SCHEMA> TO <VULCAN_PRINCIPAL>;
GRANT CREATE VIEW   ON SCHEMA <CATALOG_NAME>.<VULCAN_SCHEMA> TO <VULCAN_PRINCIPAL>;
GRANT SELECT        ON SCHEMA <CATALOG_NAME>.<VULCAN_SCHEMA> TO <VULCAN_PRINCIPAL>;
GRANT MODIFY        ON SCHEMA <CATALOG_NAME>.<VULCAN_SCHEMA> TO <VULCAN_PRINCIPAL>;
```

`MODIFY` covers `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, and `MERGE` on all tables in the schema, including tables created in the future.

### Optional: full schema ownership

Granting `ALL PRIVILEGES` on the Vulcan schema simplifies permission management and lets Vulcan fully manage the schema lifecycle, including `ALTER`, `DROP`, `REPLACE`, and cleanup.

```sql
GRANT ALL PRIVILEGES ON SCHEMA <CATALOG_NAME>.<VULCAN_SCHEMA> TO <VULCAN_PRINCIPAL>;
```

**What works:** All Vulcan model kinds, semantic layer, and state sync within a single Databricks catalog.

## secret_name: `databricks-cross-catalog-full`

Use this tier when Vulcan reads from one or more source catalogs and writes model outputs into a separate target catalog. Repeat the source catalog and schema grants for every source Vulcan reads from.

### Source catalogs (read-only)

Grant catalog access for every source catalog Vulcan reads from.

```sql
GRANT USE CATALOG ON CATALOG <SOURCE_CATALOG> TO <VULCAN_PRINCIPAL>;
```

{% hint style="info" %}
If models read from more than one source catalog, repeat this catalog-level grant for each additional source catalog.
{% endhint %}

### Source schemas (read-only)

Grant read access on every source schema Vulcan models read from.

```sql
GRANT USE SCHEMA ON SCHEMA <SOURCE_CATALOG>.<SOURCE_SCHEMA> TO <VULCAN_PRINCIPAL>;
GRANT SELECT     ON SCHEMA <SOURCE_CATALOG>.<SOURCE_SCHEMA> TO <VULCAN_PRINCIPAL>;
```

{% hint style="info" %}
If a source catalog has more than one schema that models read from, repeat the schema-level grants above for each additional source schema.
{% endhint %}

### Target catalog (read/write)

```sql
GRANT USE CATALOG   ON CATALOG <TARGET_CATALOG> TO <VULCAN_PRINCIPAL>;
GRANT CREATE SCHEMA ON CATALOG <TARGET_CATALOG> TO <VULCAN_PRINCIPAL>;
```

### Vulcan target schema (read/write)

```sql
GRANT USE SCHEMA    ON SCHEMA <TARGET_CATALOG>.<VULCAN_SCHEMA> TO <VULCAN_PRINCIPAL>;
GRANT CREATE TABLE  ON SCHEMA <TARGET_CATALOG>.<VULCAN_SCHEMA> TO <VULCAN_PRINCIPAL>;
GRANT CREATE VIEW   ON SCHEMA <TARGET_CATALOG>.<VULCAN_SCHEMA> TO <VULCAN_PRINCIPAL>;
GRANT SELECT        ON SCHEMA <TARGET_CATALOG>.<VULCAN_SCHEMA> TO <VULCAN_PRINCIPAL>;
GRANT MODIFY        ON SCHEMA <TARGET_CATALOG>.<VULCAN_SCHEMA> TO <VULCAN_PRINCIPAL>;
```

### Optional: full schema ownership

```sql
GRANT ALL PRIVILEGES ON SCHEMA <TARGET_CATALOG>.<VULCAN_SCHEMA> TO <VULCAN_PRINCIPAL>;
```

**What works:** All Vulcan model kinds, semantic layer, and state sync across multiple source catalogs into a dedicated target catalog. Source catalogs retain no write access.

## Notes

Unity Catalog schema-level `SELECT` and `MODIFY` grants cover all current and future tables in the schema. There is no equivalent of a Snowflake `FUTURE` grant.

`MODIFY` is the single privilege that covers `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, and `MERGE`. Unity Catalog has no separate `TRUNCATE` or `MERGE` privilege.

Column comments (`ALTER TABLE ... ALTER COLUMN ... COMMENT`) require `MODIFY` on the table. Since `MODIFY` is granted at the schema level above, this is already covered.

The `system` catalog (used for `system.information_schema.tables` introspection) is accessible to all users by default in most Databricks workspaces. If a workspace restricts it, grant `USE CATALOG ON CATALOG system` and `USE SCHEMA ON SCHEMA system.information_schema` to `<VULCAN_PRINCIPAL>`.

Re-run the grant statements for the matching tier whenever a new source schema, source catalog, or target catalog is added to a Vulcan deployment.

## Related resources

| Resource                                                                      | Relationship                                                               |
| ----------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| [PostgreSQL minimum permissions](postgres-minimum-permissions.md)             | Equivalent permission tiers for a PostgreSQL-backed Vulcan deployment      |
| [Snowflake minimum permissions](snowflake-minimum-permissions.md)             | Equivalent permission tiers for a Snowflake-backed Vulcan deployment       |
| [Dedicated Trino minimum permissions](dedicated-trino-minimum-permissions.md) | Equivalent permission tiers for a Dedicated Trino-backed Vulcan deployment |
