# Options

Use options in `config.yaml` to control project-wide behavior.

This section covers defaults, runtime values, hooks, alerts, and linting.

`model_defaults` is required. The other options are optional.

## What you configure here

Use this section when you want to:

* set default behavior for every model
* inject reusable values without hardcoding secrets
* run setup or cleanup SQL automatically
* send run and data quality alerts
* enforce SQL quality rules

## Example

This example shows the most common options together:

```yaml
model_defaults:
  dialect: postgres
  start: 2024-01-01
  cron: '@daily'

variables:
  warehouse_schema: analytics
  refresh_window_days: 7

before_all:
  - file: ./statements/setup.sql

after_all:
  - "@grant_select_privileges()"

notification_targets:
  - type: console
    notify_on:
      - run_failure
      - dq_failure

linter:
  enabled: true
  rules:
    - ambiguousorinvalidcolumn
    - invalidselectstarexpansion
```

## Choose the right option

<table data-view="cards"><thead><tr><th></th></tr></thead><tbody><tr><td><strong>Model defaults</strong><br>Set shared model behavior like dialect, schedule, and owners.</td></tr><tr><td><strong>Variables</strong><br>Store reusable values and keep secrets out of the config file.</td></tr><tr><td><strong>Execution hooks</strong><br>Run setup or cleanup SQL before and after plan or run commands.</td></tr><tr><td><strong>Notifications</strong><br>Send run, plan, and data quality events to your chosen targets.</td></tr><tr><td><strong>Linter</strong><br>Catch SQL issues early and enforce project-wide standards.</td></tr></tbody></table>

## Best practices

Keep connection settings under `gateways`.

Keep business usage guidance in `usage.yaml`.

Use environment variables for secrets and per-environment overrides.
