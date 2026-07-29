---
description: >-
  Configure modelDefaults in config.yaml: the required dialect, owner
  enforcement against config.users, identifier normalization strategy, and
  gateway-specific overrides.
---

# Model defaults

The `modelDefaults` section is required. You must specify a value for the `dialect` key.

All supported `modelDefaults` keys are listed in the [configuration reference](README.md#model-defaults).

## Basic configuration

Example:

{% tabs %}
{% tab title="YAML" %}
```yaml
users:
  - username: jen
    email: jen@example.com
    type: OWNER

modelDefaults:
  dialect: snowflake
  owner: jen
  start: 2022-01-01
```
{% endtab %}

{% tab title="Python" %}
```python
from vulcan.core.config import Config, ModelDefaultsConfig

config = Config(
    model_defaults=ModelDefaultsConfig(
        dialect="snowflake",
        owner="jen",
        start="2022-01-01",
    ),
)
```
{% endtab %}

{% endtabs %}

The default model kind is `VIEW` unless you override it with the `kind` key. See [model kinds](../models/data-models/model-kinds.md) for more information.

## Owner enforcement

The `owner` field in `modelDefaults` is subject to the following rules at config load time:

* **Default value.** If `modelDefaults.owner` is not set, it defaults to the `username` of the first entry in `config.users`.
* **Must be a listed user.** Whether set explicitly or defaulted, the resolved owner must be a `username` present in `config.users`. If it references an unknown username, config load fails.
* **Per-model validation.** Each model's individual `owner` field is also validated against `config.users` at load time. A model that names an owner not listed in `config.users` is rejected with a load error.

{% hint style="warning" %}
`config.users` must contain at least one entry. If the list is empty or the key is omitted, config load fails before `modelDefaults.owner` is resolved.
{% endhint %}

Example showing all three levels: project users, a default owner, and a per-model owner override:

```yaml
users:
  - username: jen
    email: jen@example.com
    type: OWNER
  - username: data_team
    email: data-team@example.com
    type: CONTRIBUTOR

modelDefaults:
  dialect: snowflake
  owner: jen          # defaults to "jen" even if omitted, because jen is first in users

# In a model file, you can override the owner — but only with a username from config.users:
# MODEL(
#   name analytics.daily_sales,
#   owner data_team,   -- valid: data_team is listed in config.users
# );
```

## Identifier resolution

When a SQL engine receives a query like `SELECT id FROM "some_table"`, it needs to understand what database objects the identifiers `id` and `"some_table"` correspond to. This is identifier resolution.

Different SQL dialects resolve identifiers differently. Some identifiers are case-sensitive if quoted. Case-insensitive identifiers are usually lowercased or uppercased before the engine looks up the object.

Vulcan analyzes model queries to extract information such as column-level lineage. To do this, it normalizes and quotes all identifiers in queries, respecting each dialect's resolution rules.

The normalization strategy determines whether case-insensitive identifiers are lowercased or uppercased. You can configure this per dialect. To treat all identifiers as case-sensitive in a Databricks project:

{% tabs %}
{% tab title="YAML" %}
```yaml
modelDefaults:
  dialect: "databricks,normalization_strategy=case_sensitive"
```
{% endtab %}

{% endtabs %}

Use this when you need to preserve name casing. Vulcan does not normalize them.

See [normalization strategies](https://sqlglot.com/sqlglot/dialects/dialect.html#NormalizationStrategy) for all supported options.

## Gateway-specific model defaults

Define gateway-specific `modelDefaults` in the `gateways` section. These override the global defaults for that gateway.

```yaml hl_lines="6 14"
gateways:
  postgres:
    connection:
      type: postgres
    modelDefaults:
      dialect: "snowflake,normalization_strategy=case_insensitive"
  snowflake:
    connection:
      type: snowflake

defaultGateway: snowflake

modelDefaults:
  dialect: snowflake
  start: 2025-02-05
```

This lets you customize model behavior for each gateway without affecting global `modelDefaults`.

Some SQL engines treat table and column names as case-sensitive. Others treat them as case-insensitive. If your project uses both types of engines, models need to align with each engine's normalization behavior, which makes maintenance and debugging harder.

Gateway-specific `modelDefaults` let you change how Vulcan performs identifier normalization per engine to align their behavior.


In the example above, the project's default dialect is `snowflake` (line 14). The `postgres` gateway overrides that with `"snowflake,normalization_strategy=case_insensitive"` (line 6).

This tells Vulcan that the `postgres` gateway's models are written in Snowflake SQL dialect (so they need to be transpiled from Snowflake to postgres), but the resulting PostgreSQL should treat identifiers as case-insensitive to match Snowflake's behavior.

