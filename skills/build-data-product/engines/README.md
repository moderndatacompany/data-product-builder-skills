# Per-Engine Notes

Supplements `dpbs-docs/vulcan-examples/<ENGINE>/` — read the matching file here
**alongside** the examples, before generating Group A/B (models) and Group C
(semantics) for that engine. These notes capture syntax deltas observed
across real examples that the raw example files don't call out explicitly:
identifier casing convention, physical-model typing style, model-kind default
pattern, and — the most common real defect source — date/time function
syntax used inside semantic `segments:`/`measures:` expressions.

DQ (`dq/`), audits (`audits/`), and tests (`tests/*.yaml`) are ANSI-portable
across all five engines in the examples reviewed — no per-engine file needed
for those layers unless a specific engine note below says otherwise.

| Engine | File |
|---|---|
| Postgres | [postgres.md](postgres.md) |
| Snowflake | [snowflake.md](snowflake.md) |
| Databricks | [databricks.md](databricks.md) |
| Spark | [spark.md](spark.md) |
| Trino | [trino.md](trino.md) |
| MSSQL | [mssql.md](mssql.md) |
| Fabric | [fabric.md](fabric.md) |

If the engine's dialect name in `config.yaml` `model_defaults.dialect`
doesn't match the connection `type` (older Vulcan versions used `tsql` for
mssql and `spark2` for spark) — trust whatever the installed CLI accepts,
these notes don't track that; it's a CLI/version detail, not a component
syntax one.
