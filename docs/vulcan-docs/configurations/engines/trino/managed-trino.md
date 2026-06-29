# Managed Trino

Managed Trino means the Trino cluster is attached to, or managed with, your data product deployment. Vulcan provisions the coordinator and workers and generates Trino catalogs from the depots you declare.

This is different from external Trino:

| Mode | Cluster ownership | How Vulcan connects |
|---|---|---|
| External Trino | The cluster already exists outside the data product. | Vulcan points to the Trino coordinator host and port. |
| Managed Trino | The cluster is attached to the data product deployment. | The `vulcan-dg-trino` resource provisions and owns the cluster. |

## Core settings

| Setting | Value |
|---|---|
| Resource type | `vulcan-dg-trino` |
| Engine field | `spec.engine: trino` |
| Model dialect | `trino` |
| VDE | `false` (not supported on Trino) |
| Catalog source | Generated from `spec.depots[]` and `spec.trino.catalog.config[]` |

## Catalog priority

The default catalog determines where unqualified model names resolve and where the gateway connects by default.

| Catalogs present | Default catalog |
|---|---|
| Depot catalogs only | First depot in `spec.depots[]` |
| Secret catalogs only | First secret catalog in `spec.trino.catalog.config[]` |
| Both depot and secret catalogs | First secret catalog (takes priority over depot catalogs) |

Secret catalogs take priority over depot catalogs. If both are present, the first secret catalog becomes the default. Order each list deliberately.

Set the default catalog explicitly using `use.projection` to inject `TRINO_CATALOG` as an environment variable. The `config.yaml` gateway reads it via `{{ env_var('TRINO_CATALOG') }}`.

```yaml
use:
  projection:
    projections:
      envVars:
        - key: TRINO_CATALOG
          template: "<catalog-name>"   # depot name or secret catalog name
```

The value must match an actual catalog name from your depot list or secret catalog list.

## config.yaml

The gateway connection is templated from environment variables the stack injects at runtime.

```yaml
name: my-trino-dp
display_name: "My Managed Trino DP"
tenant: "<tenant>"
description: "Managed Trino data product."
version: "0.1.0"

gateways:
  default:
    connection:
      type: trino
      catalog: "{{ env_var('TRINO_CATALOG') }}"
default_gateway: default

model_defaults:
  dialect: trino
  start: <YYYY-MM-DD>
  cron: "@daily"

linter:
  enabled: true
  rules:
    - ambiguousorinvalidcolumn
    - invalidselectstarexpansion
    - noambiguousprojections

ignore_patterns:
  - "trino-server-deploy.yaml"
```

Add the deploy manifest filename to `ignore_patterns`. Without this entry, Vulcan will try to parse it as a model.

## Deploy manifest

The `vulcan-dg-trino` resource provisions the Trino cluster and the Vulcan plan and run workflows.

```yaml
version: v1alpha
type: vulcan-dg-trino
name: my-trino-dp
owner: <owner>
description: "Managed Trino data product."
spec:
  runAsUser: "<owner>"
  compute: <trino-compute-pool>
  engine: trino
  repo:
    url: <https://your-vcs/your-repo>
    syncFlags:
      - "--ref=<branch>"
      - "--submodules=off"
    baseDir: <path/to/my-trino-dp>
    secret: <tenant>:<git-sync-secret>

  depots:
    - dataos://<lakehousedepot>?purpose=rw
    - dataos://<postgresdepot>?purpose=rw

  trino:
    coordinator:
      trinoServerConfig:
        jvmConfig: |
          -server
          -Xmx4G
          -XX:+UseG1GC
          -XX:G1HeapRegionSize=32M
        logProperties: |
          io.trino=INFO
    workers:
      replicas: 1
      trinoServerConfig:
        jvmConfig: |
          -server
          -Xmx4G
          -XX:+UseG1GC
          -XX:G1HeapRegionSize=32M
        logProperties: |
          io.trino=INFO

  workflow:
    logLevel: INFO
    schedule:
      crons: ["0 */6 * * *"]
      endOn: "<YYYY-01-01T00:00:00-00:00>"
      timezone: "UTC"
      concurrencyPolicy: Forbid
    resource:
      request: { cpu: "1000m", memory: "2Gi" }
      limit:   { cpu: "2000m", memory: "4Gi" }
    plan:
      command: [vulcan]
      arguments: ["--log-to-stdout", "plan", "--auto-apply"]
    run:
      command: [vulcan]
      arguments: ["--log-to-stdout", "run"]

  use:
    projection:
      projections:
        envVars:
          - key: TRINO_CATALOG
            template: "<lakehousedepot>"

  api:
    replicas: 1
    resource:
      request: { cpu: "1000m", memory: "2Gi" }
      limit:   { cpu: "2000m", memory: "4Gi" }
```

### spec.depots

| Field | Description |
|---|---|
| Order matters | The first depot becomes the default catalog and materialization target. Make it a writable lakehouse depot. |
| Catalog name | The catalog name is derived from the depot name. |
| `?purpose=rw` | Required for depots that Vulcan writes to. Use `?purpose=r` for read-only sources. |

### spec.trino

| Field | Description |
|---|---|
| `coordinator.trinoServerConfig.jvmConfig` | Full content of `jvm.config` for the coordinator. Set `-Xmx` to fit the pod memory limit. |
| `workers.trinoServerConfig.jvmConfig` | Full content of `jvm.config` for workers. Set the same `-Xmx` as the coordinator. |
| `workers.replicas` | Number of worker pods. Default is 2. Add workers for more query parallelism. |
| `catalog.config` | List of secret-backed catalogs in `<tenant>:<secret>` format. |
| `overideCatalogConfig` | Per-catalog property overrides appended to the generated `.properties` file. |

### JVM heap

Set `-Xmx` in `jvmConfig` for both the coordinator and every worker. If the heap is left unmanaged, it can exceed the pod memory limit and workers will fail to register. The cluster will form with 0 active workers.

`4G` is the validated value for a `4Gi` pod memory limit. Size yours to match your actual limit.

### spec.workflow.schedule

| Field | Description |
|---|---|
| `crons` | Standard cron expression for the run schedule. |
| `endOn` | Date after which the schedule stops. Set this one to two years out. Expired schedules stop silently. |
| `timezone` | Use `UTC` to avoid daylight saving time shifts. |
| `concurrencyPolicy` | Use `Forbid` to prevent overlapping runs writing to the same Iceberg target. |

## Secret-backed catalog

A secret catalog lets you define Trino catalog properties via a DataOS secret instead of a depot. The secret keys must be valid Trino catalog property names.

```yaml
name: postgresrr
version: v2alpha
type: secret
layer: user
description: "Trino PostgreSQL catalog properties."
secret:
  type: key-value
  data:
    connector.name:
    connection-url:
    connection-user:
    connection-password:
```

Reference it in the deploy manifest:

```yaml
spec:
  trino:
    catalog:
      config:
        - "<tenant>:postgresrr"
  use:
    projection:
      projections:
        envVars:
          - key: TRINO_CATALOG
            template: "postgresrr"
```

The catalog name is the secret name. A data product can run with only secret catalogs and no depots.

## What stays the same

Managed Trino uses the same model, semantic, metric, and DQ syntax as any other Trino-backed Vulcan project.

* `connection.type` stays `trino`.
* `model_defaults.dialect` stays `trino`.
* `vde: true` is not supported for Trino.
* Fully-qualified three-part names (`catalog.schema.name`) are required for all model names, source reads, and DQ `depends_on` references.
* Catalog behavior depends on the underlying Trino connector: Iceberg, Postgres, Snowflake, and others.

## Quick checklist

Before applying the resource, confirm:

* `spec.engine` is `trino`.
* The first depot in `spec.depots[]` is a writable lakehouse depot.
* `-Xmx` is set in `jvmConfig` for both coordinator and workers.
* `endOn` is set one to two years out.
* `TRINO_CATALOG` in `use.projection` matches an actual catalog name.
* The deploy manifest filename is in `ignore_patterns` in `config.yaml`.
* `concurrencyPolicy: Forbid` is set in the workflow schedule.
