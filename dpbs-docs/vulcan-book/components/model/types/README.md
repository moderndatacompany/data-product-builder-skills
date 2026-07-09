# Types

Vulcan supports multiple model types for different execution patterns.

Choose the type that matches how your data is defined, executed, and maintained.

## What this section covers

Use this section when you need to:

* decide between SQL and Python models
* reference data that Vulcan does not manage
* use engine-managed refresh behavior
* understand the tradeoffs between model definitions

## Quick selection guide

Start with **SQL models** for most projects.

Use **Python models** when SQL is not enough.

Use **External models** when you need metadata for tables outside the project.

Use **Managed models** when the engine should refresh data automatically.

## Compare model types

| Type       | Best for                                            | Managed by Vulcan | Query required |
| ---------- | --------------------------------------------------- | :---------------: | :------------: |
| `SQL`      | Standard transformations and warehouse-native logic |        Yes        |       Yes      |
| `Python`   | API calls, ML workflows, complex procedural logic   |        Yes        |       No       |
| `EXTERNAL` | Schema metadata for external tables                 |         No        |       No       |
| `MANAGED`  | Engine-driven refresh for supported platforms       |       Partly      |       Yes      |

{% hint style="info" %}
Most projects rely mainly on SQL models. Add other types only when they solve a specific need.
{% endhint %}

## Choose a model type

<table data-view="cards"><thead><tr><th></th><th data-card-target data-type="content-ref"></th></tr></thead><tbody><tr><td><strong>SQL models</strong><br>Use SQL files for most transformations, scheduling, and materialization patterns.</td><td><a href="sql_models.md">sql_models.md</a></td></tr><tr><td><strong>Python models</strong><br>Use Python when you need custom logic, external libraries, or DataFrame APIs.</td><td><a href="python_models.md">python_models.md</a></td></tr><tr><td><strong>External models</strong><br>Describe external table schemas so Vulcan can reason about lineage and optimization.</td><td><a href="external_models.md">external_models.md</a></td></tr><tr><td><strong>Managed models</strong><br>Let the engine maintain refreshes automatically for supported managed table features.</td><td><a href="managed_models.md">managed_models.md</a></td></tr></tbody></table>

## Common decision points

### Choose SQL models when

* the transformation is naturally expressed in SQL
* you want broad engine support
* you need standard Vulcan model behavior

### Choose Python models when

* the logic depends on Python libraries or APIs
* DataFrame code is clearer than SQL
* you can define schemas and dependencies explicitly

### Choose External models when

* the source table already exists outside Vulcan
* you need schema metadata, not lifecycle management
* you want better lineage for external dependencies

### Choose Managed models when

* the engine supports managed refresh natively
* you want automatic freshness without manual scheduling
* the source data changes outside normal Vulcan execution

## Best practices

Prefer SQL models unless Python or engine-managed behavior is clearly needed.

Keep external model definitions accurate, because Vulcan relies on them as metadata contracts.

Use managed models carefully in production, and confirm engine-specific limits before rollout.
