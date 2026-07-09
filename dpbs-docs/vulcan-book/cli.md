# CLI commands

The Vulcan CLI is your primary interface for your data pipeline. Use it to plan changes, run models, check data quality, and manage your project.

```
Usage: vulcan [OPTIONS] COMMAND [ARGS]...

  Vulcan command line tool.

Options:
  --version            Show the version and exit.
  -p, --paths TEXT     Path(s) to the Vulcan config/project.
  --config TEXT        Name of the config object. Only applicable to
                       configuration defined using Python script.
  --gateway TEXT       The name of the gateway.
  --ignore-warnings    Ignore warnings.
  --debug              Enable debug mode.
  --log-to-stdout      Display logs in stdout.
  --log-file-dir TEXT  The directory to write log files to.
  --dotenv PATH        Path to a custom .env file to load environment
                       variables.
  --help               Show this message and exit.

Commands:
  api                     Start the Vulcan API server (models, metrics,...
  audit                   Run audits for the target model(s).
  check_intervals         Show missing intervals in an environment,...
  clean                   Clears the Vulcan cache and any build artifacts.
  create_deploy_yaml      Generate a DataOS Vulcan resource deploy YAML...
  create_external_models  Create a schema file containing external model...
  create_test             Generate a unit test fixture for a given model.
  dag                     Render the DAG as an html file.
  destroy                 The destroy command removes all project resources.
  diff                    Show the diff between the local state and the...
  dlt_refresh             Attaches to a DLT pipeline with the option to...
  environments            Prints the list of Vulcan environments with its...
  evaluate                Evaluate a model and return a dataframe with a...
  fetchdf                 Run a SQL query and display the results.
  format                  Format all SQL models and audits.
  import_semantic_view    Import a Snowflake Semantic View into the current...
  info                    Print information about a Vulcan project.
  invalidate              Invalidate the target environment, forcing its...
  janitor                 Run the janitor process on-demand.
  lint                    Run the linter for the target model(s).
  migrate                 Migrate Vulcan to the current running version.
  plan                    Apply local changes to the target environment.
  render                  Render a model's query, optionally expanding...
  rollback                Rollback Vulcan to the previous migration.
  run                     Evaluate missing intervals for the target...
  state                   Commands for interacting with state
  table_diff              Show the diff between two tables or a selection...
  table_name              Prints the name of the physical table for the...
  test                    Run model unit tests.
```

## audit

Run data quality audits for your models. This command executes the audits attached to your models as assertions and reports pass/fail. Use it to validate data quality before deploying changes.

```
Usage: vulcan audit [OPTIONS]

  Run audits for the target model(s).

Options:
  --model TEXT           A model to audit. Multiple models can be audited.
  -s, --start TEXT       The start datetime of the interval for which this
                         command will be applied.
  -e, --end TEXT         The end datetime of the interval for which this
                         command will be applied.
  --execution-time TEXT  The execution time (defaults to now).
  --help                 Show this message and exit.
```

<details>
<summary>Example</summary>

```
$ vulcan audit
  Found 11 audit(s).
  unique_values on model sales.daily_sales ✅ PASS.
  not_null on model sales.daily_sales ✅ PASS.
  positive_values on model sales.daily_sales ✅ PASS.
  positive_values on model sales.daily_sales ✅ PASS.
  unique_values on model raw.raw_products ✅ PASS.
  not_null on model raw.raw_products ✅ PASS.
  unique_values on model raw.raw_customers ✅ PASS.
  not_null on model raw.raw_customers ✅ PASS.
  unique_values on model raw.raw_orders ✅ PASS.
  not_null on model raw.raw_orders ✅ PASS.
  positive_values on model raw.raw_orders ✅ PASS.

  Finished with 0 audit errors and 0 audits skipped.
  Done.
```

</details>

## check_intervals

Check which time intervals are missing for your models in a given environment. Use this to see what data needs backfilling or processing. By default, it respects signals (like upstream dependencies); disable that to see all missing intervals.

```
Usage: vulcan check_intervals [OPTIONS] [ENVIRONMENT]

  Show missing intervals in an environment, respecting signals.

Options:
  --no-signals         Disable signal checks and only show missing intervals.
  --select-model TEXT  Select specific models to show missing intervals for.
  -s, --start TEXT     The start datetime of the interval for which this
                       command will be applied.
  -e, --end TEXT       The end datetime of the interval for which this command
                       will be applied.
  --help               Show this message and exit.
```


## clean

Clear Vulcan's cache and any build artifacts. Useful for troubleshooting or starting fresh. It does not delete your models or data, only the cached files.

```
Usage: vulcan clean [OPTIONS]

  Clears the Vulcan cache and any build artifacts.

Options:
  --help  Show this message and exit.
```

## create_external_models

Generate a schema file for external models that Vulcan can reference. Use this for tables or views that live outside your Vulcan project but need to be referenced in your models.

```
Usage: vulcan create_external_models [OPTIONS]

  Create a schema file containing external model schemas.

Options:
  --help  Show this message and exit.
```
<details>
<summary>Example</summary>

```
$ vulcan create_external_models
```

</details>

## create_deploy_yaml

Generate a DataOS Vulcan resource deploy YAML file. Use this to package your Vulcan project into a deployment manifest you can apply in DataOS environments.

```
Usage: vulcan create_deploy_yaml [OPTIONS]

  Generate a DataOS Vulcan resource deploy YAML file.

Options:
  --help  Show this message and exit.
```

<details>
<summary>Example</summary>

```
$ vulcan create_deploy_yaml
```

</details>


## create_test

Generate a unit test fixture for a model. The command creates the test file structure and can generate sample data from queries you provide. Use it to set up model tests without writing the boilerplate yourself.

```
Usage: vulcan create_test [OPTIONS] MODEL

  Generate a unit test fixture for a given model.

Options:
  -q, --query <TEXT TEXT>...  Queries that will be used to generate data for
                              the model's dependencies.
  -o, --overwrite             When true, the fixture file will be overwritten
                              in case it already exists.
  -v, --var <TEXT TEXT>...    Key-value pairs that will define variables
                              needed by the model.
  -p, --path TEXT             The file path corresponding to the fixture,
                              relative to the test directory. By default, the
                              fixture will be created under the test directory
                              and the file name will be inferred based on the
                              test's name.
  -n, --name TEXT             The name of the test that will be created. By
                              default, it's inferred based on the model's
                              name.
  --include-ctes              When true, CTE fixtures will also be generated.
  --help                      Show this message and exit.
```

<details>
<summary>Example</summary>

```
$ vulcan create_test sales.daily_sales --query raw.raw_orders "SELECT * FROM raw.raw_orders"
```

</details>

## dag

Generate a visual dependency graph (DAG) of your data pipeline as an HTML file. Use it to see how models connect and how data flows through your pipeline. Open the file in any browser to explore the graph interactively.

```
Usage: vulcan dag [OPTIONS] FILE

  Render the DAG as an html file.

Options:
  --select-model TEXT  Select specific models to include in the dag.
  --help               Show this message and exit.
```

<details>
<summary>Example</summary>

```
$ vulcan dag ./dag.html
```

</details>

## destroy

⚠️ **Use with caution!** This command permanently removes all Vulcan-managed resources from your data warehouse, including state tables, the cache, and all project resources. It will delete all tables, views, and schemas that Vulcan manages, as well as any external resources created by other tools within those schemas. This is a destructive operation that can't be undone, so make sure you really want to do this before running it.

```
Usage: vulcan destroy

  Removes all state tables, the Vulcan cache and all project resources, including warehouse objects. This includes all tables, views and schemas managed by Vulcan, as well as any external resources that may have been created by other tools within those schemas.

Options:
  --help               Show this message and exit.
```

<details>
<summary>Example</summary>

```
$ vulcan destroy
[WARNING] This will permanently delete all engine-managed objects, state tables and Vulcan cache.
The operation may disrupt any currently running or scheduled plans.

Schemas to be deleted:
  • warehouse.raw
  • warehouse.sales

Snapshot tables to be deleted:
  • warehouse.vulcan__raw.raw__raw_customers__1474975870
  • warehouse.vulcan__raw.raw__raw_orders__1032938324
  • warehouse.vulcan__raw.raw__raw_products__3337559381
  • warehouse.vulcan__sales.sales__daily_sales__2671854529

This action will DELETE ALL the above resources managed by Vulcan AND
potentially external resources created by other tools in these schemas.

Are you ABSOLUTELY SURE you want to proceed with deletion? [y/n]: y
Environment 'prod' invalidated.

Deleted object warehouse.raw
Deleted object warehouse.sales
Deleted object warehouse.vulcan__raw.raw__raw_products__3337559381__dev
Deleted object warehouse.vulcan__raw.raw__raw_customers__1474975870__dev
Deleted object warehouse.vulcan__sales.sales__daily_sales__2671854529__dev
Deleted object warehouse.vulcan__sales.sales__daily_sales__2671854529
Deleted object warehouse.vulcan__raw.raw__raw_customers__1474975870
Deleted object warehouse.vulcan__raw.raw__raw_products__3337559381
Deleted object warehouse.vulcan__raw.raw__raw_orders__1032938324__dev
Deleted object warehouse.vulcan__raw.raw__raw_orders__1032938324
State tables removed.
Destroy completed successfully.
```

</details>


## dlt_refresh

```
Usage: dlt_refresh PIPELINE [OPTIONS]

  Attaches to a DLT pipeline with the option to update specific or all models of the Vulcan project.

Options:
  -t, --table TEXT  The DLT tables to generate Vulcan models from. When none specified, all new missing tables will be generated.
  -f, --force       If set it will overwrite existing models with the new generated models from the DLT tables.
  --help            Show this message and exit.
```

## diff

See what's different between your local project state and a target environment. Use it to review changes before running a plan. The output shows model changes, semantic layer changes, and quality check modifications in a clear diff format.

```
Usage: vulcan diff [OPTIONS] ENVIRONMENT

  Show the diff between the local state and the target environment.

Options:
  --help  Show this message and exit.
```

<details>
<summary>Example</summary>

```
$ vulcan diff prod

Differences from the `prod` environment:

Models:
└── Directly Modified:
    └── sales.daily_sales
        --- .../daily_sales.sql

        +++ .../daily_sales.sql

        @@ -20,10 +20,11 @@

          grains (order_date)
        )
        SELECT
          CAST(order_date AS TIMESTAMP) AS order_date,
          CAST(COUNT(order_id) AS INT) AS total_orders,
          CAST(SUM(total_amount) AS DOUBLE PRECISION) AS total_revenue,
        -  CAST(MAX(order_id) AS VARCHAR) AS last_order_id
        +  CAST(MAX(order_id) AS VARCHAR) AS last_order_id,
        +  COUNT(DISTINCT product_id) AS total_products
        FROM raw.raw_orders
        GROUP BY
          order_date
Semantics:
└── Indirectly Modified:
    ├── semantic-model:sales.daily_sales
    ├── semantic-metric:order_volume
    └── semantic-metric:revenue_trends
Quality Checks:
└── Indirectly Modified:
    ├── check-suite:sales.daily_sales:accuracy
    ├── check-suite:sales.daily_sales:timeliness
    ├── check-suite:sales.daily_sales:completeness
    └── check-suite:sales.daily_sales:validity
```

</details>

## environments

List all your Vulcan environments and see when they expire. This is helpful for managing development environments and understanding which ones might need cleanup.

```
Usage: vulcan environments [OPTIONS]

  Prints the list of Vulcan environments with its expiry datetime.

Options:
  --help             Show this message and exit.
```

<details>
<summary>Example</summary>

```
$ vulcan environments
Number of Vulcan environments are: 2
prod - No Expiry
dev - 2025-12-23 00:00:00
```

</details>

## evaluate

Preview a model's output without materializing it. Use it for debugging and quick iteration; you see what the model produces without running a full plan or run. Default limit is 1000 rows; you can adjust it.

```
Usage: vulcan evaluate [OPTIONS] MODEL

  Evaluate a model and return a dataframe with a default limit of 1000.

Options:
  -s, --start TEXT       The start datetime of the interval for which this
                         command will be applied.
  -e, --end TEXT         The end datetime of the interval for which this
                         command will be applied.
  --execution-time TEXT  The execution time (defaults to now).
  --limit INTEGER        The number of rows which the query should be limited
                         to.
  --help                 Show this message and exit.
```

<details>
<summary>Example</summary>

```
$ vulcan evaluate sales.daily_sales
   order_date  total_orders  total_revenue last_order_id  total_products
0  2024-01-05             1          70.77          O001               1
1  2024-01-10             1          44.22          O002               1
2  2024-01-15             1          65.52          O003               1
3  2024-01-20             1          79.42          O004               1
4  2024-02-01             1          91.35          O005               1
....
19 2024-05-15             1          38.38          O020               1
```

</details>

## fetchdf

Run a raw SQL query against your data warehouse and see the results. Use it for quick data exploration or debugging queries without opening a separate database client.

```
Usage: vulcan fetchdf [OPTIONS] SQL

  Run a SQL query and display the results.

Options:
  --help  Show this message and exit.
```

<details>
<summary>Example</summary>

```
$ vulcan fetchdf "select count(*) from sales.daily_sales"
┏━━━━━━━┓
┃ count ┃
┡━━━━━━━┩
│ 20    │
└───────┘
```

</details>

## format

Format all SQL models and audits according to your formatting preferences. Keeps your codebase consistent and readable. Customize options like indentation, comma placement, and function name casing.

```
Usage: vulcan format [OPTIONS]

  Format all SQL models and audits.

Options:
  --append-newline            Include a newline at the end of each file.
  --no-rewrite-casts          Preserve the existing casts, without rewriting
                              them to use the :: syntax.
  --normalize                 Whether or not to normalize identifiers to
                              lowercase.
  --pad INTEGER               Determines the pad size in a formatted string.
  --indent INTEGER            Determines the indentation size in a formatted
                              string.
  --normalize-functions TEXT  Whether or not to normalize all function names.
                              Possible values are: 'upper', 'lower'
  --leading-comma             Determines whether or not the comma is leading
                              or trailing in select expressions. Default is
                              trailing.
  --max-text-width INTEGER    The max number of characters in a segment before
                              creating new lines in pretty mode.
  --check                     Whether or not to check formatting (but not
                              actually format anything).
  --help                      Show this message and exit.
```

## import_semantic_view

Import a Snowflake Semantic View into your Vulcan project. Vulcan reads the view definition from Snowflake via `SYSTEM$READ_YAML_FROM_SEMANTIC_VIEW()` and writes one `kind: semantic` YAML file per table under `models/snowflake_semantic/<VIEW_NAME>/`. Use this to bring an existing Snowflake Semantic View into the Vulcan semantic layer without writing the YAML by hand.

```
Usage: vulcan import_semantic_view [OPTIONS] VIEW_NAME

  Import a Snowflake Semantic View into the current Vulcan project.

Options:
  --connection TEXT  The gateway connection name to use. Defaults to the
                     default gateway.
  --help             Show this message and exit.
```

<details>
<summary>Example</summary>

```
# Import by view name
$ vulcan import_semantic_view MY_SEMANTIC_VIEW --connection default

# Import using a fully qualified name
$ vulcan import_semantic_view MYDB.GOLD.MY_SEMANTIC_VIEW --connection default
```

</details>

For the full import workflow including `inputs.yaml` fixes and querying via the REST API, see [Import Snowflake Semantic Views](guides/import-snowflake-semantic-views.md).

## info

Show an overview of your Vulcan project. It reports how many models and macros you have and tests your connections to both the data warehouse and state backend. Run it first when setting up a new project or troubleshooting connection issues.

```
Usage: vulcan info [OPTIONS]

  Print information about a Vulcan project.

  Includes counts of project models and macros and connection tests for the
  data warehouse.

Options:
  --skip-connection  Skip the connection test.
  -v, --verbose      Verbose output.
  --help  Show this message and exit.
```

<details>
<summary>Example</summary>

```
$ vulcan info
Models: 4
Macros: 0
Data warehouse connection succeeded
State backend connection succeeded
```

</details>

## init

Initialize a new Vulcan project. Sets up the project structure and configuration files. Choose from templates (such as dbt or DLT) or start with an empty project.

```
Usage: vulcan init [OPTIONS] [ENGINE]

  Create a new Vulcan repository.

Options:
  -t, --template TEXT  Project template. Supported values: dbt, dlt, default,
                       empty.
  --dlt-pipeline TEXT  DLT pipeline for which to generate a Vulcan project.
                       Use alongside template: dlt
  --dlt-path TEXT      The directory where the DLT pipeline resides. Use
                       alongside template: dlt
  --help               Show this message and exit.
```

<details>
<summary>Example</summary>

```
$ vulcan init postgres
```

</details>

## invalidate

Mark an environment for deletion. The janitor process cleans it up on its next run. Use this to remove a development environment you no longer need. Deletion is asynchronous by default; use `--sync` to wait for it to complete.

```
Usage: vulcan invalidate [OPTIONS] ENVIRONMENT

  Invalidate the target environment, forcing its removal during the next run
  of the janitor process.

Options:
  -s, --sync  Wait for the environment to be deleted before returning. If not
              specified, the environment will be deleted asynchronously by the
              janitor process. This option requires a connection to the data
              warehouse.
  --help      Show this message and exit.
```

<details>
<summary>Example</summary>

```
$ vulcan invalidate dev
Environment 'dev' invalidated.
```

</details>

## janitor

Run the janitor process manually to clean up old environments and expired snapshots. The janitor runs automatically by default; trigger it manually to free space or clean up resources right away.

```
Usage: vulcan janitor [OPTIONS]

  Run the janitor process on-demand.

  The janitor cleans up old environments and expired snapshots.

Options:
  --ignore-ttl  Cleanup snapshots that are not referenced in any environment,
                regardless of when they're set to expire
  --help        Show this message and exit.
```

<details>
<summary>Example</summary>

```
$ vulcan janitor
Deleted object warehouse.sales__dev
Deleted object warehouse.raw__dev
Cleanup complete.
```

</details>

## migrate

Upgrade Vulcan's internal state to match the current version you're running. This is typically needed when you upgrade Vulcan itself. **Important:** This command affects all Vulcan users, so make sure to coordinate with your team and contact your Vulcan administrator before running it.

```
Usage: vulcan migrate [OPTIONS]

  Migrate Vulcan to the current running version.

Options:
  --help  Show this message and exit.
```

{% hint style="danger" %}
**Caution**

The `migrate` command affects all Vulcan users. Contact your Vulcan administrator before running.
{% endhint %}

## plan

Create and apply a plan that compares your local project state with a target environment and determines what changes to make. Use it to deploy model changes, add new models, and backfill data. The plan shows you exactly what will happen so you can review changes before they're applied.

```
Usage: vulcan plan [OPTIONS] [ENVIRONMENT]

  Apply local changes to the target environment.

Options:
  -s, --start TEXT                The start datetime of the interval for which
                                  this command will be applied.
  -e, --end TEXT                  The end datetime of the interval for which
                                  this command will be applied.
  --execution-time TEXT           The execution time (defaults to now).
  --create-from TEXT              The environment to create the target
                                  environment from if it doesn't exist.
                                  Default: prod.
  --skip-tests                    Skip tests prior to generating the plan if
                                  they are defined.
  --skip-linter                   Skip linting prior to generating the plan if
                                  the linter is enabled.
  -r, --restate-model TEXT        Restate data for specified models and models
                                  downstream from the one specified. For
                                  production environment, all related model
                                  versions will have their intervals wiped,
                                  but only the current versions will be
                                  backfilled. For development environment,
                                  only the current model versions will be
                                  affected.
  --no-gaps                       Ensure that new snapshots have no data gaps
                                  when comparing to existing snapshots for
                                  matching models in the target environment.
  --skip-backfill, --dry-run      Skip the backfill step and only create a
                                  virtual update for the plan.
  --empty-backfill                Produce empty backfill. Like --skip-backfill
                                  no models will be backfilled, unlike --skip-
                                  backfill missing intervals will be recorded
                                  as if they were backfilled.
  --forward-only                  Create a plan for forward-only changes.
  --allow-destructive-model TEXT  Allow destructive forward-only changes to
                                  models whose names match the expression.
  --allow-additive-model TEXT     Allow additive forward-only changes to
                                  models whose names match the expression.
  --effective-from TEXT           The effective date from which to apply
                                  forward-only changes on production.
  --no-prompts                    Disable interactive prompts for the backfill
                                  time range. Please note that if this flag is
                                  set and there are uncategorized changes,
                                  plan creation will fail.
  --auto-apply                    Automatically apply the new plan after
                                  creation.
  --no-auto-categorization        Disable automatic change categorization.
  --include-unmodified            Include unmodified models in the target
                                  environment.
  --select-model TEXT             Select specific model changes that should be
                                  included in the plan.
  --backfill-model TEXT           Backfill only the models whose names match
                                  the expression.
  --no-diff                       Hide text differences for changed models.
  --run                           Run latest intervals as part of the plan
                                  application (prod environment only).
  --enable-preview                Enable preview for forward-only models when
                                  targeting a development environment.
  --diff-rendered                 Output text differences for the rendered
                                  versions of the models and standalone
                                  audits.
  --explain                       Explain the plan instead of applying it.
  --ignore-cron                   Run all missing intervals, ignoring
                                  individual cron schedules. Only applies if
                                  --run is set.
  --min-intervals INTEGER         For every model, ensure at least this many
                                  intervals are covered by a missing intervals
                                  check regardless of the plan start date
  -v, --verbose                   Verbose output. Use -vv for very verbose
                                  output.
  --help                          Show this message and exit.
```

## api

Start Vulcan's API server. It provides programmatic access to models, metrics, lineage, and telemetry. Use it to integrate Vulcan with other tools or build custom dashboards and applications on top of your data pipeline.

```
Usage: vulcan api [OPTIONS]

  Start the Vulcan API server (models, metrics, lineage, telemetry).

Options:
  --host TEXT        Bind socket to this host. Default: 0.0.0.0
  --port INTEGER     Bind socket to this port. Default: 8000
  --reload           Enable auto-reload on file changes. Default: False
  --workers INTEGER  Number of worker processes. Default: 1
  --help             Show this message and exit.
```

## render

See the SQL Vulcan will execute for a model. Use it to debug and understand how Vulcan transforms model definitions into executable SQL. Optionally expand referenced models to see the full query with all dependencies inlined.

```
Usage: vulcan render [OPTIONS] MODEL

  Render a model's query, optionally expanding referenced models.

Options:
  -s, --start TEXT            The start datetime of the interval for which
                              this command will be applied.
  -e, --end TEXT              The end datetime of the interval for which this
                              command will be applied.
  --execution-time TEXT       The execution time (defaults to now).
  --expand TEXT               Whether or not to expand materialized models
                              (defaults to False). If True, all referenced
                              models are expanded as raw queries. Multiple
                              model names can also be specified, in which case
                              only they will be expanded as raw queries.
  --dialect TEXT              The SQL dialect to render the query as.
  --no-format                 Disable fancy formatting of the query.
  --max-text-width INTEGER    The max number of characters in a segment before
                              creating new lines in pretty mode.
  --leading-comma             Determines whether or not the comma is leading
                              or trailing in select expressions. Default is
                              trailing.
  --normalize-functions TEXT  Whether or not to normalize all function names.
                              Possible values are: 'upper', 'lower'
  --indent INTEGER            Determines the indentation size in a formatted
                              string.
  --pad INTEGER               Determines the pad size in a formatted string.
  --normalize                 Whether or not to normalize identifiers to
                              lowercase.
  --help                      Show this message and exit.
```

<details>
<summary>Example</summary>

```
$ vulcan render sales.daily_sales

SELECT
  CAST("raw_orders"."order_date" AS TIMESTAMP) AS "order_date",
  CAST(COUNT("raw_orders"."order_id") AS INT) AS "total_orders",
  CAST(SUM("raw_orders"."total_amount") AS DOUBLE PRECISION) AS "total_revenue",
  CAST(MAX("raw_orders"."order_id") AS VARCHAR) AS "last_order_id",
  COUNT(DISTINCT "raw_orders"."product_id") AS "total_products"
FROM "warehouse"."vulcan__raw"."raw__raw_orders__1032938324" AS "raw_orders" /* warehouse.raw.raw_orders */
GROUP BY
  "raw_orders"."order_date"
ORDER BY
  "order_date"
```

</details>

## rollback

Revert Vulcan's internal state to the previous migration version. This is useful if a migration caused issues and you need to go back. **Important:** Like `migrate`, this command affects all Vulcan users, so coordinate with your team and contact your Vulcan administrator before running it.

```
Usage: vulcan rollback [OPTIONS]

  Rollback Vulcan to the previous migration.

Options:
  --help  Show this message and exit.
```

{% hint style="danger" %}
**Caution**

The `rollback` command affects all Vulcan users. Contact your Vulcan administrator before running.
{% endhint %}

## run

Process missing time intervals for your models in a target environment. `run` executes scheduled work based on cron schedules; `plan` deploys changes. Use `run` to process new or missing data without changing model definitions.

```
Usage: vulcan run [OPTIONS] [ENVIRONMENT]

  Evaluate missing intervals for the target environment.

Options:
  -s, --start TEXT              The start datetime of the interval for which
                                this command will be applied.
  -e, --end TEXT                The end datetime of the interval for which
                                this command will be applied.
  --skip-janitor                Skip the janitor task.
  --ignore-cron                 Run for all missing intervals, ignoring
                                individual cron schedules.
  --select-model TEXT           Select specific models to run. Note: this
                                always includes upstream dependencies.
  --exit-on-env-update INTEGER  If set, the command will exit with the
                                specified code if the run is interrupted by an
                                update to the target environment.
  --no-auto-upstream            Do not automatically include upstream models.
                                Only applicable when --select-model is used.
                                Note: this may result in missing / invalid
                                data for the selected models.
  --help                        Show this message and exit.
```

## state

Manage Vulcan's state database. Export state for backup or migration, or import state from another environment. Use these commands for disaster recovery, environment cloning, or moving state between systems.

```
Usage: vulcan state [OPTIONS] COMMAND [ARGS]...

  Commands for interacting with state

Options:
  --help  Show this message and exit.

Commands:
  export  Export the state database to a file
  import  Import a state export file back into the state database
```

### export

Export Vulcan's state database to a file. Creates a backup of your state for recovery or to move state between environments. Export specific environments or all of them.

```
Usage: vulcan state export [OPTIONS]

  Export the state database to a file

Options:
  -o, --output-file FILE  Path to write the state export to  [required]
  --environment TEXT      Name of environment to export. Specify multiple
                          --environment arguments to export multiple
                          environments
  --local                 Export local state only. Note that the resulting
                          file will not be importable
  --no-confirm            Do not prompt for confirmation before exporting
                          existing state
  --help                  Show this message and exit.
```

### import

Import a previously exported state file back into the state database. Use it to restore from backups or copy state from one environment to another. Merges with existing state by default; use `--replace` to replace it.

```
Usage: vulcan state import [OPTIONS]

  Import a state export file back into the state database

Options:
  -i, --input-file FILE  Path to the state file  [required]
  --replace              Clear the remote state before loading the file. If
                         omitted, a merge is performed instead
  --no-confirm           Do not prompt for confirmation before updating
                         existing state
  --help                 Show this message and exit.
```

## table_diff

Compare data between two tables or models to see what's different. Use it to validate that changes produce the expected results, compare environments, or debug data discrepancies. Compare entire tables or specific models, and customize how the comparison works.

```
Usage: vulcan table_diff [OPTIONS] SOURCE:TARGET [MODEL]

  Show the diff between two tables or a selection of models when they are
  specified.

Options:
  -o, --on TEXT            The column to join on. Can be specified multiple
                           times. The model grain will be used if not
                           specified.
  -s, --skip-columns TEXT  The column(s) to skip when comparing the source and
                           target table.
  --where TEXT             An optional where statement to filter results.
  --limit INTEGER          The limit of the sample dataframe.
  --show-sample            Show a sample of the rows that differ. With many
                           columns, the output can be very wide.
  -d, --decimals INTEGER   The number of decimal places to keep when comparing
                           floating point columns. Default: 3
  --skip-grain-check       Disable the check for a primary key (grain) that is
                           missing or is not unique.
  --warn-grain-check       Warn if any selected model is missing a grain,
                           and compute diffs for the remaining models.
  --temp-schema TEXT       Schema used for temporary tables. It can be
                           `CATALOG.SCHEMA` or `SCHEMA`. Default:
                           `vulcan_temp`
  -m, --select-model TEXT  Specify one or more models to data diff. Use
                           wildcards to diff multiple models. Ex: '*' (all
                           models with applied plan diffs), 'demo.model+'
                           (this and downstream models),
                           'git:feature_branch' (models with direct
                           modifications in this branch only)
  --help                   Show this message and exit.
```

## table_name

Get the physical table name Vulcan uses for a model. Use this when you need to reference the table directly in SQL or other tools, since Vulcan's internal naming may differ from your model name.

```
Usage: vulcan table_name [OPTIONS] MODEL_NAME

  Prints the name of the physical table for the given model.

Options:
  --environment, --env TEXT  The environment to source the model version from.
  --prod                     If set, return the name of the physical table
                             that will be used in production for the model
                             version promoted in the target environment.
  --help                     Show this message and exit.
```

## test

Run unit tests for your models. Tests validate that your SQL logic works correctly with the test fixtures you've defined. Use it to catch bugs before deploying to production.

```
Usage: vulcan test [OPTIONS] [TESTS]...

  Run model unit tests.

Options:
  -k TEXT              Only run tests that match the pattern of substring.
  -v, --verbose        Verbose output.
  --preserve-fixtures  Preserve the fixture tables in the testing database,
                       useful for debugging.
  --help               Show this message and exit.
```

## lint

Run linting rules on your models to catch issues and enforce code quality standards. Lint specific models or all models in your project. Use it to keep code quality consistent and catch common mistakes early.

```
Usage: vulcan lint [OPTIONS]
  Run linter for the target model(s).

Options:
  --model TEXT           A model to lint. Multiple models can be linted.  If no models are specified, every model will be linted.
  --help                 Show this message and exit.

```
