# Execution hooks

Run SQL statements, SQL files, or macros automatically at the start and end of `vulcan plan` and `vulcan run` commands. Automate setup and cleanup tasks: create temporary tables, grant permissions, log pipeline runs, clean up after execution.

## Overview

Two hooks run at different times:

| Hook         | When it runs                   | Common use cases                                              |
|--------------|--------------------------------|---------------------------------------------------------------|
| `before_all` | Before any model is processed  | Setup tables, initialize logging, validate prerequisites      |
| `after_all`  | After all models are processed | Grant privileges, cleanup, send notifications, update metadata |

The `before_all` hook runs once at the beginning, before Vulcan processes any models. Use it for setup tasks. The `after_all` hook runs once at the end, after all models are processed. Use it for cleanup or post-processing.

Each hook entry can take one of these forms:

| Form              | Example                                  | Use when                                                  |
|-------------------|------------------------------------------|-----------------------------------------------------------|
| Inline SQL string | `CREATE SCHEMA IF NOT EXISTS analytics`  | The statement is short and easy to read in `config.yaml`. |
| Macro call        | `"@grant_select_privileges()"`           | The hook needs runtime context or reusable Python logic.  |
| File object       | `{file: ./statements/select_1.txt}`      | You want to make the file reference explicit.             |
| File path string  | `./statements/select_3.sql`              | The hook should run SQL from a file.                      |

## Basic configuration

{% tabs %}
{% tab title="YAML" %}
```yaml
before_all:
  - CREATE TABLE IF NOT EXISTS audit_log (model VARCHAR, started_at TIMESTAMP)

  - INSERT INTO audit_log VALUES ('pipeline', CURRENT_TIMESTAMP)

  - file: ./statements/select_1.txt

after_all:
  - "@grant_select_privileges()"

  - UPDATE audit_log SET completed_at = CURRENT_TIMESTAMP WHERE model = 'pipeline'

  - ./statements/select_3.sql
```
{% endtab %}

{% tab title="Python" %}
```python
from vulcan.core.config import Config

config = Config(
    before_all=[
        "CREATE TABLE IF NOT EXISTS audit_log (model VARCHAR, started_at TIMESTAMP)",
        "INSERT INTO audit_log VALUES ('pipeline', CURRENT_TIMESTAMP)"
    ],
    after_all=[
        "@grant_select_privileges()",
        "UPDATE audit_log SET completed_at = CURRENT_TIMESTAMP WHERE model = 'pipeline'"
    ],
)
```
{% endtab %}

{% endtabs %}

## File-backed statements

Use file-backed hooks when setup or cleanup SQL is too long for `config.yaml`, or when multiple environments share the same statement file.

```yaml title="config.yaml"
before_all:
  - file: ./statements/select_1.txt
  - file: ./statements/select_2.sql

after_all:
  - ./statements/select_3.sql
```

Statement files can use `.txt` or `.sql` extensions and may contain multiple SQL statements:

```sql title="statements/select_1.txt"
select 1;
select 2;
select 3;
select 4;
select 5;
select 6;
select 7;
select 8;
select 9;
select 10;
```

File paths are resolved relative to the project root. Keep long setup scripts in a folder such as `statements/` so `config.yaml` stays readable.

## Using macros in hooks

Hooks execute Vulcan macros using the `@macro_name()` syntax. Macros have access to runtime context, so hooks can be dynamic. They see what views were created, what schemas are used, and what environment you are running in. Write hooks that adapt to your pipeline state.

### Available context variables

Macros invoked in hooks have access to:

| Property             | Type        | Description                                              |
|----------------------|-------------|----------------------------------------------------------|
| `evaluator.views`    | `list[str]` | All view names created in the virtual layer              |
| `evaluator.schemas`  | `list[str]` | All schema names used by models                          |
| `evaluator.this_env` | `str`       | Current environment name (for example, `prod`, `dev`)    |
| `evaluator.gateway`  | `str`       | Current gateway name                                     |

---

## Use cases

### 1. Granting privileges on views

Creating many views and granting permissions model-by-model gets tedious. Use `after_all` to grant access to all views at once:

```python title="macros/privileges.py"
from vulcan.core.macros import macro

@macro()
def grant_select_privileges(evaluator):
    """Grant SELECT on all views to the analytics role."""
    if not evaluator.views:
        return []
    
    return [
        f"GRANT SELECT ON VIEW {view_name} /* sqlglot.meta replace=false */ TO ROLE analytics_role;"
        for view_name in evaluator.views
    ]
```

```yaml title="config.yaml"
after_all:
  - "@grant_select_privileges()"
```

{% hint style="success" %}
**Preventing name replacement**

The `/* sqlglot.meta replace=false */` comment tells Vulcan not to replace the view name with the physical table name during SQL rendering. Without it, Vulcan may swap in the underlying table name, which breaks your `GRANT` statement.
{% endhint %}

### 2. Environment-specific execution

Use different behavior in different environments. Grant certain permissions only in production. Run cleanup tasks only in development. The `@IF` macro conditionally executes statements based on the current environment:

```yaml title="config.yaml"
after_all:
  # Only grant schema usage in production
  - "@IF(@this_env = 'prod', @grant_schema_usage())"
  
  # Only run cleanup in development
  - "@IF(@this_env != 'prod', @cleanup_dev_tables())"
```

```python title="macros/privileges.py"
from vulcan.core.macros import macro

@macro()
def grant_schema_usage(evaluator):
    """Grant USAGE on all schemas to admin role (production only)."""
    if evaluator.this_env != "prod" or not evaluator.schemas:
        return []
    
    return [
        f"GRANT USAGE ON SCHEMA {schema} TO ROLE admin_role;"
        for schema in evaluator.schemas
    ]

@macro()
def cleanup_dev_tables(evaluator):
    """Clean up temporary tables in development environments."""
    return [
        "DROP TABLE IF EXISTS temp_debug_output;",
        "DROP TABLE IF EXISTS temp_test_data;"
    ]
```

### 3. Pipeline audit logging

Track when your pipeline runs and how long it takes. Log the start time in `before_all` and the completion time in `after_all`:

```yaml title="config.yaml"
before_all:
  - |
    CREATE TABLE IF NOT EXISTS pipeline_audit (
      run_id VARCHAR,
      environment VARCHAR,
      started_at TIMESTAMP,
      completed_at TIMESTAMP,
      status VARCHAR
    )
  - "@log_pipeline_start()"

after_all:
  - "@log_pipeline_end()"
```

```python title="macros/audit.py"
from vulcan.core.macros import macro
import uuid

@macro()
def log_pipeline_start(evaluator):
    run_id = str(uuid.uuid4())[:8]
    return [
        f"""
        INSERT INTO pipeline_audit (run_id, environment, started_at, status)
        VALUES ('{run_id}', '{evaluator.this_env}', CURRENT_TIMESTAMP, 'running')
        """
    ]

@macro()
def log_pipeline_end(evaluator):
    return [
        f"""
        UPDATE pipeline_audit 
        SET completed_at = CURRENT_TIMESTAMP, status = 'completed'
        WHERE environment = '{evaluator.this_env}' 
          AND status = 'running'
        """
    ]
```

### 4. Schema and database setup

Before models run, make sure all schemas they depend on exist. Instead of creating them manually or remembering the order, let `before_all` handle it:

```yaml title="config.yaml"
before_all:
  - CREATE SCHEMA IF NOT EXISTS staging

  - CREATE SCHEMA IF NOT EXISTS analytics

  - CREATE SCHEMA IF NOT EXISTS reporting

  - "@setup_external_tables()"
```

```python title="macros/setup.py"
from vulcan.core.macros import macro

@macro()
def setup_external_tables(evaluator):
    """Create external tables for data ingestion."""
    return [
        """
        CREATE EXTERNAL TABLE IF NOT EXISTS staging.raw_events (
            event_id VARCHAR,
            event_type VARCHAR,
            event_data VARCHAR,
            created_at TIMESTAMP
        )
        LOCATION 's3://data-lake/events/'
        FILE_FORMAT = (TYPE = 'PARQUET')
        """
    ]
```

### 5. Data quality gates

Validate source data before processing. Use `before_all` to run validation checks. If checks fail, the pipeline stops before processing bad data:

```yaml title="config.yaml"
before_all:
  - "@validate_source_data()"
```

```python title="macros/validation.py"
from vulcan.core.macros import macro

@macro()
def validate_source_data(evaluator):
    """Validate that source data meets quality requirements."""
    return [
        """
        DO $$
        DECLARE
            row_count INTEGER;
        BEGIN
            SELECT COUNT(*) INTO row_count FROM raw_data.events WHERE created_at >= CURRENT_DATE;
            IF row_count = 0 THEN
                RAISE EXCEPTION 'No data found for today in raw_data.events';
            END IF;
        END $$;
        """
    ]
```

### 6. Refresh materialized views

If materialized views depend on your Vulcan models, refresh them after models update. Let `after_all` handle it:

```yaml title="config.yaml"
after_all:
  - "@refresh_materialized_views()"
```

```python title="macros/refresh.py"
from vulcan.core.macros import macro

@macro()
def refresh_materialized_views(evaluator):
    """Refresh all materialized views that depend on our models."""
    materialized_views = [
        "reporting.daily_summary_mv",
        "reporting.weekly_trends_mv",
        "analytics.user_metrics_mv"
    ]
    
    return [
        f"REFRESH MATERIALIZED VIEW {mv};"
        for mv in materialized_views
    ]
```

### 7. Notification integration

Notify your team when the pipeline finishes. Use `after_all` to send notifications. This example logs to a table. Extend it to call an external API or send emails:

```yaml title="config.yaml"
after_all:
  - "@notify_completion()"
```

```python title="macros/notify.py"
from vulcan.core.macros import macro
import os

@macro()
def notify_completion(evaluator):
    """Log completion status (integrate with your notification system)."""
    # This example logs to a table; you could also call an external API
    view_count = len(evaluator.views) if evaluator.views else 0
    schema_count = len(evaluator.schemas) if evaluator.schemas else 0
    
    return [
        f"""
        INSERT INTO notifications_log (
            environment, 
            message, 
            view_count, 
            schema_count, 
            created_at
        )
        VALUES (
            '{evaluator.this_env}',
            'Pipeline completed successfully',
            {view_count},
            {schema_count},
            CURRENT_TIMESTAMP
        )
        """
    ]
```

---

## Execution order

```mermaid
%%{init: {"theme":"base","themeVariables":{"fontFamily":"PP Neue Montreal, Inter, Helvetica Neue, Arial, sans-serif","fontSize":"14px","primaryColor":"#EDE9E5","primaryTextColor":"#242422","primaryBorderColor":"#242422","lineColor":"#242422","secondaryColor":"#D6CDC6","tertiaryColor":"#FFFFFF","clusterBkg":"#EDE9E5","clusterBorder":"#54DED1","edgeLabelBackground":"#FFFFFF"},"flowchart":{"curve":"basis","padding":12,"nodeSpacing":40,"rankSpacing":50}}}%%
graph LR
    A[Start] --> B[before_all]
    B --> C[Process Models]
    C --> D[after_all]
    D --> E[Complete]

    classDef primary-teal fill:#54DED1,color:#202F36,stroke:#009293,stroke-width:1.5px,font-weight:600;
    classDef dark-teal    fill:#009293,color:#FFFFFF,stroke:#242422,stroke-width:1.5px,font-weight:600;
    classDef surface      fill:#FFFFFF,color:#242422,stroke:#242422,stroke-width:1px;

    class A surface;
    class B,D primary-teal;
    class C dark-teal;
    class E primary-teal;
```

## Best practices

Use macros for complex logic. If hook logic gets complicated, move it to a Python macro. This keeps your YAML config clean and makes the logic easier to test and maintain.

Make hooks idempotent. Hooks may run multiple times if a plan fails and gets retried. Make sure they are safe to run repeatedly. Use `IF NOT EXISTS`, `ON CONFLICT`, or similar patterns.

Use environment checks. Not everything should run in every environment. Use `@IF(@this_env = 'prod', ...)` to gate production-only operations so you do not accidentally run them in development.

Handle failures gracefully. Think about what happens if a hook fails. Will it break your entire pipeline? Use transactions where appropriate, and handle failures appropriately.

Document your hooks. Add comments explaining why each hook exists and what it does.

Test in development first. Always test hooks in a development environment before running them in production. Hooks run automatically, so mistakes can be costly.

## Comparison with model-level hooks

When should you use execution hooks versus model-level hooks? The difference:

| Feature   | `before_all` / `after_all`        | Model `pre_statements` / `post_statements` |
|-----------|-----------------------------------|---------------------------------------------|
| Scope     | Entire pipeline                   | Single model                                |
| Runs      | Once per plan/run                 | Once per model execution                    |
| Access to | All views, schemas, environment   | Model-specific context                      |
| Use for   | Global setup, cleanup, privileges | Model-specific operations                   |

Use execution hooks (`before_all`/`after_all`) for operations that apply to your entire pipeline: setting up assertion tables, granting permissions on all views, sending completion notifications.

Use model-level hooks (`pre_statements`/`post_statements`) for operations specific to individual models: creating temporary tables that only one model needs, running model-specific validations.
