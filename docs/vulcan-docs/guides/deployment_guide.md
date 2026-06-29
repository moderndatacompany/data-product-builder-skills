# Deployment steps

Deploy Vulcan data products in a DataOS environment.

***

## Prerequisites

Configure the following resources in your DataOS environment before deploying a Vulcan data product.

### 1. DataOS CLI

Install and configure the DataOS command-line interface (CLI):

```bash
# Verify CLI installation
ds version

# Login to your DataOS instance
ds login
```

### 2. Depot (data source connection)

Configure a depot to connect to your data warehouse (e.g., Snowflake, BigQuery, Databricks).

**List available depots:**

```bash
ds resource -t depot get -a
```

{% hint style="info" %}
The depot needs read/write permissions for your data warehouse schema.
{% endhint %}

### 3. Engine stack

An engine stack defines the execution environment for Vulcan operations (e.g., Snowflake, BigQuery, Spark).

**List available stacks:**

```bash
ds resource -t stack get -a
```

**Supported engines:**

* `snowflake`
* `bigquery`
* `databricks`
* `postgres`
* `redshift`
* `trino`
* `mysql`
* `mssql`

### 4. Compute resource

A compute resource provides the execution environment for running Vulcan workflows.

**List available compute resources:**

```bash
ds resource -t compute get -a
```

**Example compute resources:**

* `cyclone-compute` (general purpose)
* `minerva-compute` (query engine)
* Custom compute clusters

### 5. Git-sync secret

You need a secret to access your private Git repository containing Vulcan models and configurations.

**Create a git-sync secret:**

```bash
ds resource apply -f git-sync-secret.yaml
```

**Example secret configuration:**

```yaml
name: git-sync
version: v2alpha
type: secret
workspace: system
layer: user
description: "Secret for git-sync authentication (Bitbucket)"
secret:
  type: key-value
  data:
    GITSYNC_USERNAME: "<your-git-username>"
    GITSYNC_PASSWORD: "<your-git-token-or-password>"
```

{% hint style="warning" %}
Replace `GITSYNC_USERNAME` and `GITSYNC_PASSWORD` with your actual Git repository credentials or access tokens.
{% endhint %}

***

## Configuration files

Vulcan deployments require two key configuration files.

### 1. `config.yaml` - Vulcan configuration

This file holds Vulcan-specific runtime configuration: model defaults, gateways, notifications, and environment behavior. Business-facing usage guidance belongs in `usage.yaml`.

**Location:** `<project-root>/config.yaml`

**Key sections:**

#### Basic metadata

```yaml
name: <data-product-name>
display_name: <Data Product Title>
description: <Description .... >

# Catalog metadata
discoverable: true
version: 0.1.0
alignment: consumer_aligned

# Environment behaviour
vde: false   # set to true to enable Virtual Data Environments; not supported on spark/trino gateways

tags:
  - <tag1>
  - <tag2>

terms:
  - glossary.<term1>
  - glossary.<term2>

```

{% hint style="info" %}
**Tenant comes from the environment**

Set `DATAOS_TENANT_ID` in your shell or `.env`. It's no longer a YAML key.
{% endhint %}

#### Usage guidance

Business-facing usage guidance belongs in `usage.yaml`, not in `config.yaml`.

```yaml
good_for:
  - <good-use-case-1>
  - title: <good-use-case-title>
    details: <when this data product is a good fit>

not_for:
  - <not-for-use-case-1>

caveats:
  - title: <known-caveat-title>
    details: <what users should know>
    severity: medium

references:
  - title: <reference-title>
    url: <reference-url>
    type: doc
```

#### Model defaults

```yaml
model_defaults:
  dialect: <engine-dialect>          # Database dialect eg. snowflake, bigquery
  start: '2025-01-01'        # Start date for time-based models
  cron: '<cron>'             # Default scheduling cadence @daily
```

#### Gateway configuration

```yaml
gateways:
  default:
    connection:
      type: depot
      address: dataos://<depot-name>  # Reference to your depot
```

#### Users and ownership

```yaml
users:
  - username: <username1>
    github_username: <gh-username1>
    email: <username1@email.id>
    type: OWNER
  - username: <username2>
    github_username: <gh-username2>
    email: <username2@email.id>
    type: OWNER
```

`type: OWNER` marks the user as a data product owner. List one entry per owner. `github_username` drives PR/CI bot interactions; leave it out for users who don't have a GitHub account.

#### Complete config.yaml example

<details>

<summary>📋 Click to see complete config.yaml example</summary>

```yaml
name: user-engagement
display_name: User Engagement Analytics
description: User Engagement Analytics delivers insights into user engagement patterns.

# Catalog metadata
discoverable: true
version: 0.1.0
alignment: consumer_aligned

# Environment behaviour
vde: false   # set to true to enable Virtual Data Environments; not supported on spark/trino gateways

tags:
  - snowflake
  - user_engagement
  - device_analytics

terms:
  - glossary.data_product
  - glossary.analytics_platform
  - glossary.user_engagement

model_defaults:
  dialect: snowflake
  start: '2025-01-01'
  cron: '@daily'

gateways:
  default:
    connection:
      type: depot
      address: dataos://snowflakevulcan2

notification_targets:
  - type: console
    notify_on:
      - apply_failure
      - run_failure
      - dq_failure

users:
  - username: <owner-username-1>
    github_username: <owner-gh-username-1>
    email: <owner-email-1@example.com>
    type: OWNER
  - username: <owner-username-2>
    github_username: <owner-gh-username-2>
    email: <owner-email-2@example.com>
    type: OWNER
```

</details>

***

### 2. `domain-resource.yaml` - DataOS resource configuration

This file defines the DataOS-specific resource configuration for deploying Vulcan as a managed service.

**Location:** `<project-root>/domain-resource.yaml`

You can create this file manually, or generate a starter deploy manifest using the Vulcan CLI:

```bash
vulcan create_deploy_yaml
```

**Key sections:**

#### Resource metadata

```yaml
version: v1alpha
type: vulcan
name: <data-product-name>
tags:
  - <tag1>
  - <tag2>
```

#### Execution configuration

```yaml
spec:
  runAsUser: "<dataos-username>"     # DataOS user identity
  compute: <compute-name>            # Compute cluster name eg. cyclone-compute
  engine: <engine-name>              # Execution engine eg. snowflake, bigquery
```

#### Repository configuration

```yaml
  repo:
    url: <git-repository-url>                # eg. https://github.com/org/repo
    syncFlags:
      - '--ref=<branch-name>'                # Git branch eg. main
      - '--submodules=off'
    baseDir: <path-to-project-in-repo>       # Path to project folder
    secret: <workspace>:<secret>          # Git credentials secret eg. engineering:git-sync-name
```

#### Depot references

```yaml
  depots:
    - dataos://<depot-name>?purpose=rw      # Read-write depot access
```

#### Workflow configuration

```yaml
  workflow:
    schedule:
      crons:
        - '<cron-expression>'  # eg. '*/45 * * * *' (Every 45 minutes)
      endOn: '<end-date>'      # eg. '2027-01-01T00:00:00-00:00'
      timezone: '<timezone>'   # eg. 'US/Pacific'
      concurrencyPolicy: Forbid
    
    logLevel: INFO
    
    resource:                   # Resource allocation
      request:
        cpu: "<cpu-request>"   # eg. "200m"
        memory: "<memory-request>"  # eg. "512Mi"
      limit:
        cpu: "<cpu-limit>"     # eg. "1000m"
        memory: "<memory-limit>"    # eg. "1Gi"
```

#### Vulcan commands

```yaml
    plan:                       # Plan changes
      command: [vulcan]
      arguments:
        - --log-to-stdout
        - plan
        - --auto-apply
    
    run:                        # Execute models
      command: [vulcan]
      arguments:
        - --log-to-stdout
        - run
```

#### API configuration

```yaml
  api:
    replicas: <replica-count>     # eg. 1
    logLevel: INFO
    resource:
      request:
        cpu: "<cpu-request>"      # eg. "200m"
        memory: "<memory-request>"     # eg. "512Mi"
      limit:
        cpu: "<cpu-limit>"        # eg. "5000m"
        memory: "<memory-limit>"       # eg. "4Gi"
```

#### Complete domain-resource.yaml example

<details>

<summary>📋 Click to see complete domain-resource.yaml example</summary>

```yaml
version: v1alpha
type: vulcan
name: user-engagement
tags:
  - snowflake-analytics
  - user_engagement
  - device_analytics
spec:
  runAsUser: "<dataos-username>"
  compute: cyclone-compute
  engine: snowflake
  repo:
    url: https://bitbucket.org/rubik_/vulcan-examples
    syncFlags:
      - '--ref=main'
      - '--submodules=off'
    baseDir: vulcan-examples/customer-usecase/usdk
    secret: engineering:git-sync
  depots:
    - dataos://snowflakevulcan2?purpose=rw
  workflow:
    schedule:
      crons:
        - '*/45 * * * *'
      endOn: '2027-01-01T00:00:00-00:00'
      timezone: 'US/Pacific'
      concurrencyPolicy: Forbid
    logLevel: INFO
    resource:
      request:
        cpu: "200m"
        memory: "512Mi"
      limit:
        cpu: "1000m"
        memory: "1Gi"
    plan:
      command:
        - vulcan
      arguments:
        - --log-to-stdout
        - plan
        - --auto-apply
    run:
      command:
        - vulcan
      arguments:
        - --log-to-stdout
        - run
  api:
    replicas: 1
    logLevel: INFO
    resource:
      request:
        cpu: "200m"
        memory: "512Mi"
      limit:
        cpu: "5000m"
        memory: "4Gi"
```

</details>

***

## Deployment steps

### Prepare your repository

1. Create your Vulcan project structure:

```
your-project/
├── config.yaml              # Vulcan configuration
├── domain-resource.yaml     # DataOS resource definition
├── models/                  # SQL model files
│   ├── staging/
│   ├── marts/
│   ├── dq/                  # Data Quality rule packs (kind: dq)
│   ├── semantics/           # Semantic models (kind: semantic)
│   └── metrics/             # Per-metric files
├── plugins/                 # Auth extension hooks and other project plugins
├── seeds/                   # Static data files
└── audits/                  # Audit queries (blocking)
```

2. Configure `config.yaml` with your project settings
3. Generate `domain-resource.yaml` with `vulcan create_deploy_yaml` or configure it manually with your DataOS settings
4. Push your code to a Git repository

### Create required secrets

```bash
# Create git-sync secret (if not exists)
ds resource apply -f git-sync-secret.yaml
```

### Verify prerequisites

```bash
# Verify depot exists
ds resource -t depot get -n <depot-name> -a

# Verify compute exists
ds resource -t compute get -n <compute-name> -a

# Verify stack exists
ds resource -t stack get -a 
```

### Deploy Vulcan resource

```bash
# Generate the deploy manifest if you haven't created it yet
vulcan create_deploy_yaml

# Apply the domain-resource configuration
ds resource apply -f domain-resource.yaml

```

### Monitor deployment

```bash
# Get resource status
ds resource -t vulcan -n <data-product-name> get

# Check logs
ds resource -t vulcan -n <data-product-name> logs
```

### Understanding runtime entries

Vulcan doesn't run as a single container. When you deploy, DataOS splits it into three components, each with its own runtime and logs:

* **plan**: handles deployment preparation (`vulcan plan --auto-apply`)
* **run**: executes your models on schedule (`vulcan run`)
* **api**: serves queries and exposes endpoints (long-running service)

Open the **Runtime** tab in your DataOS instance and you'll see entries for all three. This is expected.

### Which log to check

| What you're investigating       | Look at       | Runtime entry pattern              |
| ------------------------------- | ------------- | ---------------------------------- |
| Model execution results         | **run** logs  | `*-r-execute`, `workflow...run...` |
| Migration, planning, auto-apply | **plan** logs | `*-mgrt-execute`, `*-plan-execute` |
| API availability, query issues  | **api** logs  | `*-api-*`, `service...api...`      |

For example, if your resource is called `orders-analytics`:

* `orders-analyticsv1-mgrt-execute` and `orders-analyticsv1-plan-execute` belong to **plan**
* `orders-analyticsv1-r-execute` and `workflowv2alpha...run...` entries belong to **run**
* `orders-analyticsv1-api-*` and `servicev2alpha...api...` entries belong to **api** (check `*-main` for API logs, `*-sc-1` for GraphQL, `*-sc-2` for MySQL)

### Fetching logs via CLI

Use the DataOS CLI to pull logs from a specific component and container:

```bash
dataos-ctl resource -t Vulcan -n <resource-name> logs \
  --container-group <container-group> -c <container-name>
```

| What you need             | `--container-group`   | `-c`   |
| ------------------------- | --------------------- | ------ |
| Planning / migration logs | `<name>-plan-execute` | `main` |
| Model execution logs      | `<name>-run-execute`  | `main` |
| API service logs          | `<name>-api`          | `main` |
| GraphQL sidecar logs      | `<name>-api`          | `sc-1` |
| MySQL sidecar logs        | `<name>-api`          | `sc-2` |

For example, to check execution logs for a resource called `orders-analytics`:

```bash
dataos-ctl resource -t Vulcan -n orders-analytics logs \
  --container-group orders-analytics-run-execute -c main
```

### Why multiple entries appear

You'll often see more than three entries:

* **Scheduled runs create new pods.** Each time the cron fires, DataOS creates a new workflow pod for the run. Five "Succeeded" entries means five completed scheduled runs. This is normal.
*   **API replicas and sidecars.** The API pod has multiple containers, each with its own logs:

    | Container          | Log suffix | Use it for                                      |
    | ------------------ | ---------- | ----------------------------------------------- |
    | Main API container | `*-main`   | Core API/service behavior                       |
    | GraphQL sidecar    | `*-sc-1`   | GraphQL-related investigation                   |
    | MySQL sidecar      | `*-sc-2`   | MySQL wire protocol or client connection issues |
* **Plan also runs as a workflow.** Migration and planning each get their own pod, so you'll see separate entries for those too.

{% hint style="success" %}
**Quick rule of thumb**

To verify a scheduled execution went through, open the **most recent** "Succeeded" run workflow pod. That has the latest `vulcan run` output.
{% endhint %}

### Spark engines: driver vs. executor logs

If your gateway uses Spark, the runtime entries above only tell half the story. Vulcan's `run` (and `plan`) pod is the **Spark driver**: it builds the query plan, ships tasks to your cluster, and collects results. The actual work runs on **executors** that live on your Spark cluster, not on DataOS.

That split changes where you go to debug:

| Symptom                                                                         | Where the log lives                                   | How to read it                                                                                  |
| ------------------------------------------------------------------------------- | ----------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| Vulcan can't reach Spark, auth errors, version mismatches, scheduler exceptions | DataOS `*-run-execute` or `*-plan-execute` pod        | `dataos-ctl resource -t Vulcan -n <name> logs --container-group <name>-run-execute -c main`     |
| Task failed inside a UDF, OOM on a worker, shuffle fetch failures               | Spark cluster, executor logs                          | Spark master UI at `http://<spark-master>:8080`, then drill into the application then executors |
| Driver-side stack trace that points into executor code                          | Both: DataOS shows the symptom, Spark shows the cause | Start in DataOS, follow the executor ID in the trace to the Spark UI                            |

A common pattern: a `vulcan run` in DataOS fails with a multi-line Java stack trace. The top frames are driver-side and visible in `*-run-execute` logs. The root cause sits in an executor and is only retrievable from the Spark UI. Don't re-run the DataOS pod when the answer is in the executor logs.

For the symmetric "is my driver Spark version the same as my cluster's?" question, see [Verifying Spark version alignment](../configurations/engines/spark.md#verifying-spark-version-alignment). A version skew is the most common reason a Spark-backed run pod fails at startup, and it surfaces as `java.io.InvalidClassException` in the `*-run-execute` logs.

{% hint style="info" %}
**Sidecars don't apply to Spark workloads**

The `sc-1` (GraphQL) and `sc-2` (MySQL) sidecars are part of the `api` pod, not `run`. Spark workloads don't add new container groups to DataOS. The driver still runs inside the existing `*-run-execute` container.
{% endhint %}

***

## Verification

### Verify models in data warehouse

Connect to your data warehouse and confirm tables/views exist:

```sql
-- For Snowflake
SHOW TABLES IN SCHEMA <database>.<schema>;

-- Check specific table
SELECT * FROM <database>.<schema>.<table-name> LIMIT 10;
```

### Access Vulcan API

```bash
# Test API (if exposed)
curl --location 'https://<env-fqn>/<tenant>/vulcan/<data-product-name>/livez' \
  --header 'Authorization: Bearer <your-token>'
```
