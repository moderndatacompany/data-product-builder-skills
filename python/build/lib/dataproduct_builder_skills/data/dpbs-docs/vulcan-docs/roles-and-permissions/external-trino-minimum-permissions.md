---
description: >-
  Minimum Trino SQL or connector access-control privileges for running
  Vulcan against a client-managed Trino cluster, by secret_name tier.
---

# External Trino

This document covers the minimum Trino permissions needed to run Vulcan against an external Trino cluster. External Trino is a Trino cluster that the client already operates independently of DataOS; Vulcan connects to it as it would connect to any other external engine.

{% hint style="info" %}
If you are using DataOS Dedicated Trino (the domain resource that deploys coordinator and workers automatically from depot definitions), see [Dedicated Trino](dedicated-trino-minimum-permissions.md) instead. That setup requires no Trino-level SQL grants; permissions are on the underlying depot data sources.
{% endhint %}

Vulcan cannot create Trino catalogs. All catalogs must already exist and be registered in Trino's configuration. Vulcan only needs permission to use existing catalogs and, when required, create schemas and objects inside them.

`vde: true` is not supported for Trino, because Trino does not support the transactions that full Virtual Data Environments require. Vulcan always runs in `DEV_ONLY` mode with Trino: physical tables use a fixed `__novde` suffix, and a virtual layer view points at them.

{% hint style="warning" %}
Trino does not define a single permission model. Access control is handled by the connector and the configured access control plugin: none, file-based, OPA, Ranger, or Starburst. The SQL privileges in this document describe what the Vulcan user must be allowed to perform. How you configure that allowance depends on your environment.
{% endhint %}

## What Vulcan does

**On source schemas (read-only):**

- `SELECT` on tables and views referenced by models
- Reads `<catalog>.information_schema.tables` and `system.metadata.materialized_views` for object introspection (both are readable by all users in a standard Trino deployment)

**On the model target schema (write):**

- `CREATE TABLE`, `DROP TABLE` + `CREATE TABLE`: full model refresh (`CREATE OR REPLACE TABLE` only on Iceberg and Delta Lake catalogs; Hive uses DROP + CREATE)
- `CREATE VIEW`, `DROP VIEW`: semantic layer views and virtual layer promotion
- `ALTER TABLE`: column adds/drops when model schema changes between deployments
- `INSERT`, `DELETE`: incremental model evaluation
- `DELETE FROM`: used as the TRUNCATE fallback (some Trino connectors do not support `TRUNCATE`)
- `SET SESSION <catalog>.insert_existing_partitions_behavior`: session property for Hive connector partition overwrite; no special privilege required

**On the state schema (write):**

Same as target schema. Vulcan stores internal metadata here (`_snapshots`, `_environments`, `_intervals`, etc.). By default this is the same schema as the model target. If `state_schema` in the gateway config points elsewhere, apply the same write grants to that schema too.

**Not needed here:**

- `CREATE TABLE ... CLONE`: not supported by Trino
- `MERGE`: Trino does not expose a standard MERGE; Vulcan uses DELETE + INSERT within a logical merge
- `GRANT` / `REVOKE`: Vulcan does not issue grant statements through Trino (`SUPPORTS_GRANTS = false`)

## Required privileges summary

| Object         | Privilege needed                                                                                      |
| -------------- | ----------------------------------------------------------------------------------------------------- |
| Source catalog | `USE` / access to catalog                                                                             |
| Source schema  | `SELECT` on tables and views                                                                          |
| Target catalog | `USE` / access to catalog, `CREATE SCHEMA` if Vulcan creates the schema                               |
| Target schema  | `CREATE TABLE`, `CREATE VIEW`, `SELECT`, `INSERT`, `DELETE`, `DROP TABLE`, `DROP VIEW`, `ALTER TABLE` |

## secret_name: `trino-semantic-readonly`

Use this when Vulcan only exposes Trino tables or views through the semantic layer. No models are executed, and no objects are created or written. This is a pure read-only connection.

### Required privileges

The Vulcan user must be allowed to:

- Access the source catalog
- Read from the source schema (`SELECT` on tables and views)

{% tabs %}
{% tab title="Iceberg (SQL grants)" %}
```sql
GRANT SELECT ON SCHEMA "<SOURCE_CATALOG>"."<SOURCE_SCHEMA>" TO USER "<VULCAN_USER>";
```

Or on specific tables:

```sql
GRANT SELECT ON TABLE "<SOURCE_CATALOG>"."<SOURCE_SCHEMA>"."<TABLE_NAME>" TO USER "<VULCAN_USER>";
```
{% endtab %}

{% tab title="Hive (file-based)" %}
In your Trino `rules.json`:

```json
{
  "schemas": [
    {
      "catalog": "<SOURCE_CATALOG>",
      "schema": "<SOURCE_SCHEMA>",
      "owner": false
    }
  ],
  "tables": [
    {
      "catalog": "<SOURCE_CATALOG>",
      "schema": "<SOURCE_SCHEMA>",
      "table": ".*",
      "privileges": ["SELECT"]
    }
  ]
}
```
{% endtab %}
{% endtabs %}

**What works:** Semantic queries over external models.
**What is blocked:** Vulcan cannot create, alter, truncate, delete, or drop any Trino object.

## secret_name: `trino-single-catalog-full`

Use this when the source schema and the Vulcan target schema are both inside one Trino catalog. This covers all Vulcan model kinds (FULL, INCREMENTAL_BY_TIME_RANGE, SCD_TYPE_2, SEED, VIEW) plus semantic layer exposure.

### Source schema (read-only)

{% tabs %}
{% tab title="Iceberg (SQL grants)" %}
```sql
GRANT SELECT ON SCHEMA "<CATALOG_NAME>"."<SOURCE_SCHEMA>" TO USER "<VULCAN_USER>";
```

If models read from more than one schema within the same catalog, apply the same schema-level grant for each additional source schema.
{% endtab %}

{% tab title="Hive (file-based)" %}
```json
{
  "tables": [
    {
      "catalog": "<CATALOG_NAME>",
      "schema": "<SOURCE_SCHEMA>",
      "table": ".*",
      "privileges": ["SELECT"]
    }
  ]
}
```
{% endtab %}
{% endtabs %}

### Vulcan target schema (read/write)

The Vulcan user must be able to create and manage all objects in the target schema. If the schema does not yet exist, the user also needs permission to create it.

{% tabs %}
{% tab title="Iceberg (SQL grants)" %}
```sql
-- If Vulcan should create the schema itself
GRANT CREATE SCHEMA ON CATALOG "<CATALOG_NAME>" TO USER "<VULCAN_USER>";

-- On the target schema
GRANT SELECT        ON SCHEMA "<CATALOG_NAME>"."<VULCAN_SCHEMA>" TO USER "<VULCAN_USER>";
GRANT CREATE TABLE  ON SCHEMA "<CATALOG_NAME>"."<VULCAN_SCHEMA>" TO USER "<VULCAN_USER>";
GRANT CREATE VIEW   ON SCHEMA "<CATALOG_NAME>"."<VULCAN_SCHEMA>" TO USER "<VULCAN_USER>";
GRANT INSERT        ON SCHEMA "<CATALOG_NAME>"."<VULCAN_SCHEMA>" TO USER "<VULCAN_USER>";
GRANT DELETE        ON SCHEMA "<CATALOG_NAME>"."<VULCAN_SCHEMA>" TO USER "<VULCAN_USER>";
```

Or grant ownership on the schema to cover all current and future objects:

```sql
GRANT OWNERSHIP ON SCHEMA "<CATALOG_NAME>"."<VULCAN_SCHEMA>" TO USER "<VULCAN_USER>";
```
{% endtab %}

{% tab title="Hive (file-based)" %}
```json
{
  "schemas": [
    {
      "catalog": "<CATALOG_NAME>",
      "schema": "<VULCAN_SCHEMA>",
      "owner": true
    }
  ],
  "tables": [
    {
      "catalog": "<CATALOG_NAME>",
      "schema": "<VULCAN_SCHEMA>",
      "table": ".*",
      "privileges": ["SELECT", "INSERT", "DELETE", "UPDATE", "OWNERSHIP"]
    }
  ]
}
```
{% endtab %}
{% endtabs %}

**What works:** All Vulcan model kinds, semantic layer, and state sync, within a single Trino catalog.

## secret_name: `trino-cross-catalog-full`

Use this when Vulcan reads from one or more source catalogs and writes model outputs into a separate target catalog. Repeat the source catalog and schema grants for every source Vulcan reads from.

### Source catalogs (read-only)

{% tabs %}
{% tab title="Iceberg (SQL grants)" %}
```sql
GRANT SELECT ON SCHEMA "<SOURCE_CATALOG>"."<SOURCE_SCHEMA>" TO USER "<VULCAN_USER>";
```

If models read from more than one source catalog, apply the same schema-level grant for each additional source catalog and schema combination. If a source catalog has more than one schema that models read from, apply the same schema-level grant for each additional source schema.
{% endtab %}

{% tab title="Hive (file-based)" %}
```json
{
  "tables": [
    {
      "catalog": "<SOURCE_CATALOG>",
      "schema": "<SOURCE_SCHEMA>",
      "table": ".*",
      "privileges": ["SELECT"]
    }
  ]
}
```
{% endtab %}
{% endtabs %}

### Target catalog (read/write)

{% tabs %}
{% tab title="Iceberg (SQL grants)" %}
```sql
GRANT CREATE SCHEMA ON CATALOG "<TARGET_CATALOG>" TO USER "<VULCAN_USER>";

GRANT SELECT        ON SCHEMA "<TARGET_CATALOG>"."<VULCAN_SCHEMA>" TO USER "<VULCAN_USER>";
GRANT CREATE TABLE  ON SCHEMA "<TARGET_CATALOG>"."<VULCAN_SCHEMA>" TO USER "<VULCAN_USER>";
GRANT CREATE VIEW   ON SCHEMA "<TARGET_CATALOG>"."<VULCAN_SCHEMA>" TO USER "<VULCAN_USER>";
GRANT INSERT        ON SCHEMA "<TARGET_CATALOG>"."<VULCAN_SCHEMA>" TO USER "<VULCAN_USER>";
GRANT DELETE        ON SCHEMA "<TARGET_CATALOG>"."<VULCAN_SCHEMA>" TO USER "<VULCAN_USER>";
```
{% endtab %}

{% tab title="Hive (file-based)" %}
```json
{
  "schemas": [
    {
      "catalog": "<TARGET_CATALOG>",
      "schema": "<VULCAN_SCHEMA>",
      "owner": true
    }
  ],
  "tables": [
    {
      "catalog": "<TARGET_CATALOG>",
      "schema": "<VULCAN_SCHEMA>",
      "table": ".*",
      "privileges": ["SELECT", "INSERT", "DELETE", "UPDATE", "OWNERSHIP"]
    }
  ]
}
```
{% endtab %}
{% endtabs %}

**What works:** All Vulcan model kinds, semantic layer, and state sync, across multiple source catalogs into a dedicated target catalog. Source catalogs retain no write access.

## Notes

- `vde: true` is blocked for Trino. Vulcan always runs in `DEV_ONLY` mode: physical tables use a `__novde` suffix, and a virtual layer view maps the original model name to that table. This is automatic and requires no additional configuration.
- `TRUNCATE` is not supported on some Trino connectors, notably Hive. Vulcan falls back to `DELETE FROM` to empty a table. The required privilege is `DELETE`, not a separate `TRUNCATE` privilege.
- `CREATE OR REPLACE TABLE` is only supported on Iceberg and Delta Lake catalogs. On Hive catalogs, Vulcan drops the table and recreates it, so `DROP TABLE` permission is required on the target schema.
- `SET SESSION <catalog>.insert_existing_partitions_behavior` is used by Vulcan during partition overwrite on Hive catalogs. This is a session-scoped property and requires no special privilege in a standard Trino configuration.
- `system.metadata.catalogs` and `system.metadata.materialized_views` are part of Trino's built-in `system` catalog and are readable by all users in a standard deployment. If your workspace restricts access to the `system` catalog, grant read access on those tables to the Vulcan user.
- SQL `GRANT` syntax in Trino is only available on connectors that implement the `ConnectorAccessControl` interface (Iceberg is the most common). For Hive connector deployments, use file-based access control rules, Apache Ranger policies, or OPA rules to grant the equivalent privileges.

## Related resources

| Resource                                                  | Relationship                                                                                                                     |
| --------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [Dedicated Trino](dedicated-trino-minimum-permissions.md) | Minimum permissions for a DataOS-managed Trino deployment, where grants apply to depot data sources instead of Trino SQL objects |
