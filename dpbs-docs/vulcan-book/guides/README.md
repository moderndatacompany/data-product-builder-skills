# Guides

These guides walk you through Vulcan's core workflows. Each one solves a specific problem, with real examples from the Orders360 project.

If you're new, start at the top. If you're looking for something specific, jump to the section you need.

***

## Set up and first run

[Get Started](./get-started.md) - Install Vulcan, spin up a local Postgres environment with Docker, and run your first project. By the end, you'll have a working stack on your machine.

[Data Product Lifecycle](data-product-lifecycle.md) - The full path from `make up` to production. Covers every phase: infrastructure setup, model creation, testing, semantic layer configuration, and deployment.

## Day-to-day workflows

[Plan](plan/plan_guide.md) - `vulcan plan` shows you what changed before anything takes effect. This guide covers the default no-virtual-layer behavior and links to the optional virtual-layer mode.

[Vulcan Run Guide](run_and_scheduling.md) - `plan` applies changes. `run` processes new data intervals for the already applied shape.

[Models](models.md) - Add, edit, evaluate, and manage SQL and Python models. Covers the full workflow: creating a model, previewing its output with `vulcan evaluate`, and applying it with a plan.

## Going deeper

[Incremental by Time](incremental_by_time.md) - Full refreshes reprocess everything. If you have a year of sales data, that's 365 days recomputed on every run. Incremental models process only the new intervals. This guide shows you how to set that up.

[Model Selection](model_selection.md) - In large projects, you don't want to plan every model when you changed one. Selectors let you target models by name, tag, wildcard, or graph operator (`+model` for upstream, `model+` for downstream).

[Data Quality](data_quality.md) - Three layers of protection: assertions block invalid data during model runs, checks monitor quality trends without blocking, and tests validate transformations locally. This guide shows how to wire all three together.

## Semantics

[Transpiling Semantics](transpiling_semantics.md) - `vulcan transpile` converts semantic queries into executable SQL. Use it to preview, debug, and validate your semantic logic before it hits the database.

[Import Snowflake Semantic Views](import-snowflake-semantic-views.md) - Import a Snowflake-native semantic view into a Vulcan project and query it via the REST API. Covers the full workflow from project setup through `vulcan plan` and live REST queries.

[Semantic Query Lifecycle](semantic_query_lifecycle.md) - How a semantic query travels through Vulcan: from POST request, to transpilation, cache check, worker execution, and result download. Covers the async model and all six stages.

## APIs

[Vulcan API Guide](vulcan_api_guide.md) - Query your semantic layer from applications, dashboards, or BI tools. Covers the REST API (async submit, poll, download), GraphQL, and MySQL wire protocol, along with authentication, the `vulcan api` command, and production deployment config.

## Deployment

[Deployment Steps](deployment_guide.md) - Deploy your Vulcan project to a DataOS environment. Covers CLI setup, depot and compute configuration, resource manifests, and verification steps.
