---
description: >-
  How `EXTERNAL` models describe schemas for tables Vulcan does not manage,
  and how to create and validate them.
---

# External models

Your models sometimes need to query tables that exist outside your Vulcan project: a third-party data source, a table managed by another system, or a read-only database. These are external tables.

Vulcan does not manage external tables, but it can use metadata about them. When you define external models, you give Vulcan column names and types. Even though Vulcan doesn't manage these tables, knowing their schema helps with:

* Column-level lineage (see how data flows through external tables)
* Query optimization (Vulcan can make better decisions)
* Documentation (your data catalog knows what is in those tables)

Vulcan stores this metadata as `EXTERNAL` models.

## How external models work

`EXTERNAL` models are metadata-only. They describe a table's schema (column names and types). There is no query for Vulcan to run, and Vulcan does not manage the data.

**Important limitations:**

* Vulcan does not know what data is in the table (or if it exists)
* If someone alters the external table, Vulcan doesn't detect it
* If all data is deleted, Vulcan doesn't know
* Vulcan never modifies external tables

**When external tables get queried:** only when a Vulcan model references them. Vulcan never proactively queries external tables on its own. The referencing model's [`kind`](../model-kinds.md), [`cron`](../properties.md#cron), and previously loaded time intervals determine exactly when that query happens.

## Creating external models

You define external models in YAML files. You have two options:

1. **Let Vulcan generate it** (easiest): use the `create_external_models` CLI command.
2. **Write it yourself**: hand-craft the YAML if you need more control.

The main file is `input.yaml` in your project root. You can also add more files in the `external_models/` directory.

Here's what an external model definition looks like, for three tables in a demo project:

```yaml
# input.yaml
- name: '"warehouse"."vulcan_demo"."customers"'
  columns:
    customer_id: INT
    name: TEXT
    email: TEXT
- name: '"warehouse"."vulcan_demo"."orders"'
  columns:
    order_id: INT
    customer_id: INT
    order_date: TIMESTAMP
- name: '"warehouse"."vulcan_demo"."order_items"'
  columns:
    order_id: INT
    quantity: INT
    unit_price: DECIMAL
```

Vulcan never runs this file; it's metadata only. The SQL model below is what actually queries these tables:

```sql
MODEL (
  name vulcan_demo.full_model,
  kind FULL
);

SELECT
  c.customer_id,
  c.name AS customer_name,
  c.email,
  COUNT(DISTINCT o.order_id) AS total_orders,
  COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS total_spent
FROM vulcan_demo.customers AS c
LEFT JOIN vulcan_demo.orders AS o
  ON c.customer_id = o.customer_id
LEFT JOIN vulcan_demo.order_items AS oi
  ON o.order_id = oi.order_id
GROUP BY c.customer_id, c.name, c.email
```

The following sections show how to create external models like these: generated automatically, written by hand, or a mix of both.

### Using CLI

Instead of writing `input.yaml` manually, Vulcan can generate it for you with the [create\_external\_models](../../../cli.md#create_external_models) CLI command:

```bash
vulcan create_external_models
```

**What it does:**

* Scans your project for references to external tables
* Fetches column information from your SQL engine's metadata
* Writes everything to `input.yaml`

`create_external_models` only queries SQL engine metadata, not the external tables themselves, so it's fast and safe to run.

**If Vulcan cannot access a table's metadata:** it omits that table from the file and issues a warning. Define it manually instead (see "Writing YAML by hand" below).

### Writing YAML by hand

Sometimes you need to define external models manually, when Vulcan cannot access the metadata or you want more control. Here is the structure:

```yaml
- name: '"warehouse"."vulcan_demo"."customers"'
  description: "Customer dimension table from external system"
  gateway: dev  # Optional: only load for this gateway
  columns:
    customer_id: INT
    region_id: INT
    name: TEXT
    email: TEXT
- name: '"warehouse"."vulcan_demo"."orders"'
  columns:
    order_id: INT
    customer_id: INT
    order_date: TIMESTAMP
    warehouse_id: INT
- name: '"warehouse"."vulcan_demo"."order_items"'
  columns:
    order_id: INT
    quantity: INT
    unit_price: DECIMAL
```

**What you need:**

* `name`: Fully qualified table name (with quotes if needed for case sensitivity)
* `columns`: Dictionary of column names to data types

**Optional fields:**

* `description`: Human-readable description
* `gateway`: Gateway name (for gateway-specific tables)

**Tip:** use triple-quoted names if your table names have special characters or need case sensitivity. The exact format depends on your SQL engine.

### Using the `external_models` directory

A common problem: you run `vulcan create_external_models` and it generates `input.yaml`. But some tables need manual definitions (when Vulcan cannot access their metadata). If you add them to `input.yaml` and run the command again, the command overwrites your manual changes.

**Solution:** put manual definitions in the `external_models/` directory:

```
input.yaml                         # Auto-generated by Vulcan
external_models/manual_tables.yaml # Your manual definitions
external_models/legacy_tables.yaml # More manual definitions
```

**How it works:**

* Vulcan loads `input.yaml` first (or `schema.yaml`)
* Then it loads all `.yaml` files from `external_models/`
* It merges everything together

**Best practice:** use `create_external_models` to manage the main file, and put any tables that need manual definitions in the `external_models/` directory. You can then regenerate the main file without losing your manual work.

### Gateway-specific external models

If you use [isolated systems with multiple gateways](../../../configurations/README.md#gateways), you may have external tables that only exist on specific gateways.

**Example:** your model uses a gateway variable to select different databases:

```sql
MODEL (
  name vulcan_demo.customer_summary,
  kind FULL
);

SELECT * FROM @{gateway}_db.customers;
```

When you run with `--gateway dev`, it queries `dev_db.customers`. When you run with `--gateway prod`, it queries `prod_db.customers`. These are different tables with potentially different schemas.

**Solution:** run `create_external_models` with the `--gateway` flag:

```bash
vulcan --gateway dev create_external_models
```

This sets `gateway: dev` on the external model, so it only loads when that gateway is active. Do this for each gateway that has different external tables.

{% hint style="info" %}
**Case-insensitive gateway names**

Gateway names are case-insensitive in external model configs. `gateway: dev`, `gateway: DEV`, and `gateway: Dev` all work the same.
{% endhint %}

### Validating external data

`input.yaml` is a pure contract file: name, dialect, grains, and columns. It doesn't carry validation rules. To validate upstream data from an external source, use one of these instead:

* **Standalone audits** in `audits/*.sql`: write SQL audit rules that select bad rows and reference the external table by name, then attach them as assertions on downstream models. See [Assertions](../../../quality/assertions.md) for the full syntax.
* **Data Quality rule packs** in `dq/*.yml` (`kind: dq`): non-blocking quality rules that run separately from the model pipeline. See [Data Quality](../../../quality/data-quality.md) for the full syntax.

Both run when the dependent Vulcan model executes, so quality issues in the upstream source are caught before they propagate downstream.
