---
description: >-
  Minimum engine privileges required to run a Vulcan domain resource, engine
  by engine: PostgreSQL, Snowflake, Databricks, Spark, and Trino.
---

# Roles and permissions

Before a Vulcan domain resource can connect to a data engine, that engine must grant Vulcan's service account or principal a specific, minimal set of privileges: nothing more than what Vulcan actually does at each stage of a run.

This section is a reference for platform, database, and security administrators who need to grant those privileges correctly, engine by engine.

{% hint style="info" %}
**Not the same as** [**Plugins and auth**](../plugins-and-auth.md)

This page is about engine-level access: the SQL `GRANT`s or IAM policies the underlying database or warehouse needs on Vulcan's service account. [Plugins and auth](../plugins-and-auth.md) is a different layer entirely: it resolves a DataOS user's role tags into semantic-layer policy groups after DataOS authorization. Grant engine privileges here; configure semantic-layer policy resolution there.
{% endhint %}

## Supported engines

| Engine          | Guide                                                     | Access model                                                                                |
| --------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| PostgreSQL      | [PostgreSQL](postgres-minimum-permissions.md)             | SQL `GRANT` statements on roles                                                             |
| Snowflake       | [Snowflake](snowflake-minimum-permissions.md)             | SQL `GRANT` statements on roles                                                             |
| Databricks      | [Databricks](databricks-minimum-permissions.md)           | Unity Catalog `GRANT` statements on a service principal                                     |
| Spark           | [Spark](spark-minimum-permissions.md)                     | DataOS policies on the Lakehouse depot, plus storage-layer IAM                     |
| External Trino  | [External Trino](external-trino-minimum-permissions.md)   | SQL `GRANT` statements or connector access-control rules, on a client-managed Trino cluster |
| Dedicated Trino | [Dedicated Trino](dedicated-trino-minimum-permissions.md) | No Trino-level grants (access control lives on each depot's underlying data source)         |

## How the permission tiers work

Each guide (except Dedicated Trino, which has no SQL grants of its own) breaks its privileges into three `secret_name` tiers, matched to what a Vulcan deployment actually needs:

| Tier pattern                 | Use when                                                                                      |
| ---------------------------- | --------------------------------------------------------------------------------------------- |
| `<engine>-semantic-readonly` | Vulcan only exposes existing tables or views through the semantic layer; no models run        |
| `<engine>-single-*-full`     | The source and target objects live inside a single database, catalog, or schema               |
| `<engine>-cross-*-full`      | Vulcan reads from one or more source catalogs and writes model outputs into a separate target |

Grant the tier that matches the deployment topology, not more.

## Where this fits

Consult the matching guide before pointing a Vulcan domain resource at a new data engine, or before rotating the credentials in a Vulcan gateway secret. Each guide documents exactly what Vulcan does: reads, writes, and internal state tracking, so the grants can be scoped to that behavior instead of granted broadly.

If a domain resource sets `spec.trino:`, DataOS provisions and connects to a Dedicated Trino cluster automatically. Read the Dedicated Trino guide first, since it changes where permissions apply. Otherwise, Vulcan connects directly to the engine named in the gateway configuration.

## Next steps

* [PostgreSQL](postgres-minimum-permissions.md) - Grant access for a PostgreSQL-backed deployment
* [Snowflake](snowflake-minimum-permissions.md) - Grant access for a Snowflake-backed deployment
* [Databricks](databricks-minimum-permissions.md) - Grant access for a Databricks Unity Catalog deployment
* [Spark](spark-minimum-permissions.md) - Grant access for a DataOS Lakehouse deployment via Spark
* [External Trino](external-trino-minimum-permissions.md) - Grant access for a client-managed Trino cluster
* [Dedicated Trino](dedicated-trino-minimum-permissions.md) - Understand the depot-level access model for a DataOS-managed Trino cluster
