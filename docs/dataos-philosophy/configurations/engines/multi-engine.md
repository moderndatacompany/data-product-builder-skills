# Harnessing Multi-Engine Capability

## The Engine Is an Implementation Detail

Most data tools make the engine central to how you think. You pick Snowflake, and you learn to think in Snowflake. You migrate to BigQuery, and you relearn materialization, permissions, and SQL dialect from scratch.

The coupling between logic and compute becomes so tight that switching engines isn't a configuration change, but a whole rewrite. That's a poor tradeoff. **Your business logic shouldn't be hostage to your infrastructure decisions.**

*Vulcan* treats the engine as an implementation detail. You write models in SQL or Python. You define validation logic, semantic models, and business metrics. The engine is declared in the gateway configuration: a single parameter that tells *Vulcan* where to execute, not how your models should be structured.

The same data product specification runs on Postgres in development and Snowflake in production without changing a line of transformation logic. The engine is swappable because the **data product definition is engine-agnostic.**

## Abstracting Compute Without Abstracting Control

Compute abstraction is easy to get wrong. The naive version is a lowest-common-denominator abstraction: hide everything engine-specific behind a generic interface and lose all the performance and capability that makes each engine worth using.

*Vulcan* takes a different approach: The abstraction lives at the boundary between your model definition and the execution layer, not inside it.

What this means in practice: Vulcan handles the engine-specific work (dialect translation, materialization strategy, permission requirements, DDL generation) while your **model retains full access to engine-native capabilities** when you need them.

If you need BigQuery's MERGE semantics, Snowflake's clustering keys, or Spark's partition strategies, you get them. The abstraction removes the operational burden of working across engines instead of removing their capability. You're not giving up control, but giving up the parts of engine management that have **no business being in a data product definition**.

## How Vulcan Connects Models to Engines

The interoperability model is explicit rather than implicit. Each gateway in your `config.yaml` declares an engine type and its connection parameters. Your models declare a dialect in `model_defaults`.

*Vulcan*'s transpiler resolves the gap: it takes your model definitions and materializes them against the target engine's execution semantics, handling the differences in SQL dialect, DDL syntax, and incremental strategy between engines transparently.

> **This means a single *Vulcan* project can target multiple engines across environments without branching logic.**

## Engines in *Vulcan*

[https://tmdc-io.github.io/vulcan-book/configurations/engines/](https://tmdc-io.github.io/vulcan-book/configurations/engines/)
