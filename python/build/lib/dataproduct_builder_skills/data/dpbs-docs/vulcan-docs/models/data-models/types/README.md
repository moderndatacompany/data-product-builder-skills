---
description: >-
  SQL, Python, and external model types, and how to choose between them.
---

# Types

Vulcan supports multiple model types for different execution patterns.

Choose the type that matches how you define, execute, and maintain your data.

## What this section covers

Use this section when you need to:

* decide between SQL and Python models
* reference data that Vulcan does not manage
* understand the tradeoffs between model definitions

## Quick selection guide

Start with **SQL models** for most projects.

Use **Python models** when SQL is not enough.

Use **External models** when you need metadata for tables outside the project.

## Compare model types

| Type       | Best for                                            | Managed by Vulcan | Query required |
| ---------- | --------------------------------------------------- | :---------------: | :------------: |
| `SQL`      | Standard transformations and warehouse-native logic |        Yes        |       Yes      |
| `Python`   | API calls, ML workflows, complex procedural logic   |        Yes        |       No       |
| `EXTERNAL` | Schema metadata for external tables                 |         No        |       No       |

{% hint style="info" %}
Most projects rely mainly on SQL models. Add other types only when they solve a specific need.
{% endhint %}

## Choose a model type

<table data-view="cards"><thead><tr><th></th><th data-card-target data-type="content-ref"></th></tr></thead><tbody><tr><td><strong>SQL models</strong><br>Use SQL files for most transformations, scheduling, and materialization patterns.</td><td><a href="sql.md">sql.md</a></td></tr><tr><td><strong>Python models</strong><br>Use Python when you need custom logic, external libraries, or DataFrame APIs.</td><td><a href="python.md">python.md</a></td></tr><tr><td><strong>External models</strong><br>Describe external table schemas so Vulcan can reason about lineage and optimization.</td><td><a href="external-models.md">external-models.md</a></td></tr></tbody></table>

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

## Best practices

Prefer SQL models unless you clearly need Python.

Keep external model definitions accurate, because Vulcan relies on them as metadata contracts.
