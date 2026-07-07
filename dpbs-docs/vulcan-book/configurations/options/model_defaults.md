# Model defaults

The `model_defaults` section is required. You must specify a value for the `dialect` key.

All supported `model_defaults` keys are listed in the [models configuration reference](../../components/model/properties.md#model-defaults).

## Basic configuration

Example:

{% tabs %}
{% tab title="YAML" %}
```yaml
model_defaults:
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

The default model kind is `VIEW` unless you override it with the `kind` key. See [model kinds](../../components/model/model_kinds.md) for more information.

## Identifier resolution

When a SQL engine receives a query like `SELECT id FROM "some_table"`, it needs to understand what database objects the identifiers `id` and `"some_table"` correspond to. This is identifier resolution.

Different SQL dialects resolve identifiers differently. Some identifiers are case-sensitive if quoted. Case-insensitive identifiers are usually lowercased or uppercased before the engine looks up the object.

Vulcan analyzes model queries to extract information such as column-level lineage. To do this, it normalizes and quotes all identifiers in queries, respecting each dialect's resolution rules.

The normalization strategy determines whether case-insensitive identifiers are lowercased or uppercased. You can configure this per dialect. To treat all identifiers as case-sensitive in a BigQuery project:

{% tabs %}
{% tab title="YAML" %}
```yaml
model_defaults:
  dialect: "bigquery,normalization_strategy=case_sensitive"
```
{% endtab %}

{% endtabs %}

Use this when you need to preserve name casing. Vulcan does not normalize them.

See [normalization strategies](https://sqlglot.com/sqlglot/dialects/dialect.html#NormalizationStrategy) for all supported options.

## Gateway-specific model defaults

Define gateway-specific `model_defaults` in the `gateways` section. These override the global defaults for that gateway.

```yaml hl_lines="6 14"
gateways:
  redshift:
    connection:
      type: redshift
    model_defaults:
      dialect: "snowflake,normalization_strategy=case_insensitive"
  snowflake:
    connection:
      type: snowflake

default_gateway: snowflake

model_defaults:
  dialect: snowflake
  start: 2025-02-05
```

This lets you customize model behavior for each gateway without affecting global `model_defaults`.

Some SQL engines treat table and column names as case-sensitive. Others treat them as case-insensitive. If your project uses both types of engines, models need to align with each engine's normalization behavior, which makes maintenance and debugging harder.

Gateway-specific `model_defaults` let you change how Vulcan performs identifier normalization per engine to align their behavior.


In the example above, the project's default dialect is `snowflake` (line 14). The `redshift` gateway overrides that with `"snowflake,normalization_strategy=case_insensitive"` (line 6).

This tells Vulcan that the `redshift` gateway's models are written in Snowflake SQL dialect (so they need to be transpiled from Snowflake to Redshift), but the resulting Redshift SQL should treat identifiers as case-insensitive to match Snowflake's behavior.

