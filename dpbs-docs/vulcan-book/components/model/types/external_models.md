# External models

Your models sometimes need to query tables that exist outside your Vulcan project: a third-party data source, a table managed by another system, or a read-only database. These are external tables.

Vulcan does not manage external tables, but it can use metadata about them. When you define external models, you give Vulcan column names and types, which gives you better column-level lineage and query optimization.

Even though Vulcan does not manage them, knowing their schema helps with:

* Column-level lineage (see how data flows through external tables)
* Query optimization (Vulcan can make better decisions)
* Documentation (your data catalog knows what is in those tables)

Vulcan stores this metadata as `EXTERNAL` models.

## How external models work

`EXTERNAL` models are metadata-only. They describe a table's schema (column names and types). There is no query for Vulcan to run, and Vulcan does not manage the data.

**Important limitations:**

* Vulcan does not know what data is in the table (or if it exists)
* If someone alters the external table, Vulcan will not detect it
* If all data is deleted, Vulcan will not know
* Vulcan never modifies external tables

The querying model's [`kind`](../model_kinds.md), [`cron`](../properties.md#cron), and previously loaded time intervals determine when Vulcan queries the `EXTERNAL` model.

**When external tables get queried:** Only when a Vulcan model references them. The querying model's `kind`, `cron`, and time intervals determine when the external table is queried. Vulcan does not proactively query external tables. It queries them as part of executing your models.

## Creating external models

You define external models in YAML files. You have two options:

1. **Let Vulcan generate it** (easiest): use the `create_external_models` CLI command.
2. **Write it yourself**: hand-craft the YAML if you need more control.

The main file is `external_models.yaml` (or `schema.yaml`) in your project root. You can also add more files in the `external_models/` directory.

Here is an example model that queries external tables:

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

The following sections show how to create external models for these tables. You can define all external models in `external_models.yaml`, or split them across multiple files in the `external_models/` directory (useful for organization or when Vulcan regenerates the main file).

### Using CLI

Instead of creating the `external_models.yaml` file manually, Vulcan can generate it for you with the [create\_external\_models](../../../cli.md#create_external_models) CLI command.

The command identifies all external tables referenced in your Vulcan project, fetches their column information from the SQL engine's metadata, and stores the information in `external_models.yaml`.

If Vulcan does not have access to an external table's metadata, the table is omitted from the file and Vulcan issues a warning.

`create_external_models` only queries SQL engine metadata, not the external tables themselves.

### Gateway-specific external models

In some use cases, such as [isolated systems with multiple gateways](../../../configurations/README.md#gateways), external models only exist on a certain gateway.

**Gateway names are case-insensitive in external model configurations.** You can specify the gateway name using any case (for example, `gateway: dev`, `gateway: DEV`, `gateway: Dev`) and Vulcan handles the matching correctly.

Consider this model that queries an external table with a dynamic database based on the current gateway:

```bash
vulcan create_external_models
```

**What it does:**

* Scans your project for references to external tables
* Fetches column information from your SQL engine's metadata
* Writes everything to `external_models.yaml`

**Important:** This command only queries metadata (table schemas), not the actual data. It is fast and safe.

**If Vulcan cannot access a table's metadata:** That table is skipped and Vulcan warns you. Define it manually (see "Writing YAML by hand" below).

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
```

**What you need:**

* `name`: Fully qualified table name (with quotes if needed for case sensitivity)
* `columns`: Dictionary of column names to data types

**Optional fields:**

* `description`: Human-readable description
* `gateway`: Gateway name (for gateway-specific tables)

**Tip:** use triple-quoted names if your table names have special characters or need case sensitivity. The exact format depends on your SQL engine.

### Using the `external_models` directory

A common problem: you run `vulcan create_external_models` and it generates `external_models.yaml`. But some tables need manual definitions (when Vulcan cannot access their metadata). If you add them to `external_models.yaml` and run the command again, your manual changes get overwritten.

**Solution:** put manual definitions in the `external_models/` directory:

```
external_models.yaml              # Auto-generated by Vulcan
external_models/manual_tables.yaml # Your manual definitions
external_models/legacy_tables.yaml # More manual definitions
```

**How it works:**

* Vulcan loads `external_models.yaml` first (or `schema.yaml`)
* Then it loads all `.yaml` files from `external_models/`
* Everything gets merged together

**Best practice:** use `create_external_models` to manage the main file, and put any tables that need manual definitions in the `external_models/` directory. You can then regenerate the main file without losing your manual work.

### Validating external data

`external_models.yaml` is now a pure contract file: name, dialect, grains, and columns. The inline `audits:` block is no longer supported here.

To validate upstream data from an external source, use one of these instead:

* **Standalone audits** in `audits/*.sql`: write SQL audit rules that select bad rows and reference the external table by name, then attach them as assertions on downstream models.
* **Data Quality rule packs** in `dq/*.yml` (`kind: dq`): non-blocking quality rules that run separately from the model pipeline. See the [Data Quality](../../data-quality.md) component for the full syntax.

Both run when the dependent Vulcan model executes, so quality issues in the upstream source are caught before they propagate downstream.
