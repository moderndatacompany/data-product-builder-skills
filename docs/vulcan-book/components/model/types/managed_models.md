# Managed models

Most Vulcan models manage their own data: you run `vulcan run`, and Vulcan updates the tables. Managed models are different. The database engine handles data updates automatically in the background.

**How it works:** you define a query, and the engine monitors upstream tables. When source data changes, the engine refreshes your managed table. No manual `REFRESH` commands needed.

Use this when you need always-fresh data without managing refresh schedules yourself. The engine handles incremental updates, change detection, and refresh timing.

**Best use case:** managed models are typically built on [External Models](external_models.md) rather than other Vulcan models. Vulcan already keeps its models up to date, so the main benefit comes when you read from external tables that Vulcan does not track. The engine keeps your managed table in sync with those external sources automatically.

{% hint style="warning" %}
**Python models not supported**

Python models do not support the `MANAGED` [model kind](../model_kinds.md). Use a SQL model instead.
{% endhint %}

## Difference from materialized views

Vulcan already supports [materialized views](../model_kinds.md#materialized-views), but they have limitations:

* Some engines only allow materialized views from a single base table
* Materialized views are not automatically refreshed. You need to run `REFRESH MATERIALIZED VIEW` manually
* You are responsible for scheduling refreshes

**Managed models are different:**

* **Automatic updates**: the engine refreshes data when source tables change
* **Smart refresh**: the engine understands your query and can do incremental or full refreshes as needed
* **No manual commands**: everything happens in the background

In some engines, there is no difference (they are the same thing). In others, managed models give you more automation and flexibility.

## Lifecycle in Vulcan

Managed models follow the same lifecycle as other Vulcan models:

* Virtual environments create pointers to model snapshots
* Model changes create new snapshots
* Upstream changes trigger new snapshots
* You can deploy and rollback like any other model
* Snapshots get cleaned up when TTL expires

**Cost consideration:** managed models usually cost more than regular tables. For example, Snowflake charges extra for Dynamic Tables. To save money, Vulcan uses regular tables for dev previews (in forward-only plans) and only creates managed tables when deploying to production.

{% hint style="warning" %}
**Dev vs prod differences**

Dev uses regular tables and prod uses managed tables. You can write a query that works in dev but fails in prod if you use features available to regular tables but not managed tables.

The cost savings are worth it, but if this causes issues, let us know.
{% endhint %}

## Supported engines

Vulcan supports managed models on:

| Engine                                                    | Implementation                                                                  |
| --------------------------------------------------------- | ------------------------------------------------------------------------------- |
| [Snowflake](../../../configurations/engines/snowflake.md) | [Dynamic Tables](https://docs.snowflake.com/en/user-guide/dynamic-tables-intro) |

To create a managed model, use the [`MANAGED`](../model_kinds.md#managed) model kind.

### Snowflake

On Snowflake, managed models are implemented as [Dynamic Tables](https://docs.snowflake.com/en/user-guide/dynamic-tables-intro). Dynamic Tables refresh when their source data changes, which is what managed models need.

Here is how to create one:

```sql
MODEL (
  name db.events,
  kind MANAGED,
  physical_properties (
    warehouse = datalake,
    target_lag = '2 minutes',
    data_retention_time_in_days = 2
  )
);

SELECT
  event_date::DATE as event_date,
  event_payload::TEXT as payload
FROM raw_events
```

results in:

```sql
CREATE OR REPLACE DYNAMIC TABLE db.events
  WAREHOUSE = "datalake",
  TARGET_LAG = '2 minutes'
  DATA_RETENTION_TIME_IN_DAYS = 2
AS SELECT
  event_date::DATE as event_date,
  event_payload::TEXT as payload
FROM raw_events
```

{% hint style="info" %}
**No intervals**

Vulcan does not create intervals or run this model on a schedule. You do not need `WHERE` clauses with date filters like you would for incremental models. Snowflake handles refreshing automatically. Define the query and let Snowflake handle it.
{% endhint %}

#### Table properties

Dynamic Tables have properties that control refresh frequency, initial data population, retention, and more. You can find the complete list in the [Snowflake documentation](https://docs.snowflake.com/sql-reference/sql/create-dynamic-table).

In Vulcan, you set these properties using [`physical_properties`](../properties.md#physical_properties) in your model definition. Here are the key ones:

| Snowflake Property                   | Required | Notes                                                                                                                                  |
| ------------------------------------ | -------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| target\_lag                          | Y        |                                                                                                                                        |
| warehouse                            | N        | In Snowflake, this is a required property. However, if not specified, then Vulcan will use the result of `select current_warehouse()`. |
| refresh\_mode                        | N        |                                                                                                                                        |
| initialize                           | N        |                                                                                                                                        |
| data\_retention\_time\_in\_days      | N        |                                                                                                                                        |
| max\_data\_extension\_time\_in\_days | N        |                                                                                                                                        |

The following Dynamic Table properties can be set directly on the model:

| Snowflake Property | Required | Notes                                                                                                                                                              |
| ------------------ | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| cluster by         | N        | `clustered_by` is a [standard model property](../properties.md#clustered_by), so set `clustered_by` on the model to add a `CLUSTER BY` clause to the Dynamic Table |
