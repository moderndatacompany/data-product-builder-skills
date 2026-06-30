# Engines

Use engine configuration to connect Vulcan to your warehouse or compute layer.

Each engine page lists connection fields, prerequisites, permissions, and engine-specific behavior.

## What you configure here

Use this section when you need to:

* choose the engine adapter for a gateway
* set engine-specific connection properties
* check permissions and authentication requirements
* understand engine-specific materialization behavior

## Basic pattern

Every gateway needs a `connection.type`.

Your project also needs `model_defaults.dialect`.

In most projects, both values match the target engine.

```yaml
gateways:
  default:
    connection:
      type: postgres
      host: warehouse
      port: 5432
      database: analytics
      user: vulcan
      password: "{{ env_var('POSTGRES_PASSWORD') }}"

model_defaults:
  dialect: postgres
```

{% hint style="info" %}
Use environment variables for secrets such as passwords, tokens, and key files.
{% endhint %}

## Choose an engine

<table data-view="cards"><thead><tr><th></th><th data-card-target data-type="content-ref"></th></tr></thead><tbody><tr><td><strong>BigQuery</strong><br>Configure BigQuery authentication, permissions, and connection settings.</td><td><a href="bigquery.md">bigquery.md</a></td></tr><tr><td><strong>Databricks</strong><br>Connect Vulcan to Databricks and review engine-specific options.</td><td><a href="databricks.md">databricks.md</a></td></tr><tr><td><strong>Microsoft Fabric</strong><br>Set up Microsoft Fabric connection details for Vulcan workloads.</td><td><a href="fabric.md">fabric.md</a></td></tr><tr><td><strong>Microsoft SQL Server</strong><br>Configure SQL Server connectivity and required connection fields.</td><td><a href="mssql.md">mssql.md</a></td></tr><tr><td><strong>MySQL</strong><br>Review MySQL connection requirements and engine behavior.</td><td><a href="mysql.md">mysql.md</a></td></tr><tr><td><strong>Postgres</strong><br>Configure PostgreSQL gateways for development or production workloads.</td><td><a href="postgres.md">postgres.md</a></td></tr><tr><td><strong>Amazon Redshift</strong><br>Set up Redshift-specific connection properties and permissions.</td><td><a href="redshift.md">redshift.md</a></td></tr><tr><td><strong>Snowflake</strong><br>Configure Snowflake authentication, warehouse settings, and connectivity.</td><td><a href="snowflake.md">snowflake.md</a></td></tr><tr><td><strong>Spark</strong><br>Review Spark engine support and supported connection patterns.</td><td><a href="spark.md">spark.md</a></td></tr><tr><td><strong>Trino</strong><br>Set up Trino connectivity and engine-specific configuration.</td><td><a href="trino/">trino</a></td></tr></tbody></table>

## Engine availability

Some engines are fully available today.

Some are still marked as work in progress.

Check the engine page before you finalize production configuration.

## Best practices

Keep `connection.type` and `model_defaults.dialect` aligned unless you have a specific transpilation need.

Use separate gateways for dev, staging, and prod when connection details differ.

Store credentials outside `config.yaml` and inject them at runtime.
