# Deploy a Vulcan Data Product — Troubleshooting & Help Guide

> Reference this when a Vulcan Data Product deployment fails or misbehaves. Use it to check prerequisites, permissions, manifest correctness, and runtime/log signals before and during `dataos-ctl resource apply`.

## How to use this guide

1. Start with the **Symptom → where to look** table below and jump to the matching section.
2. If deployment hasn't started yet, confirm **Prerequisites** (Section 3) and **Permissions** (Section 2).
3. If `apply` succeeded but something is wrong at runtime, use **Verify & read logs** (Section 6).
4. Match the exact error against **Common issues** (Section 7).

## Symptom → where to look


| Symptom                                              | Go to                                              |
| ---------------------------------------------------- | -------------------------------------------------- |
| "access denied" / cannot create or use a resource    | Section 1 (Role), Section 2 (Permissions)          |
| CLI login fails / can't see Depot, stack, or Compute | Section 3 (Prerequisites)                          |
| Repository does not sync                             | Section 3 (Git-sync secret), Section 7             |
| Depot connection fails                               | Section 2, Section 5 (Warehouse grants), Section 7 |
| Plan / Run fails                                     | Section 6 (logs), Section 7                        |
| API not reachable                                    | Section 6 (api logs), Section 7                    |
| Tables/views missing in warehouse                    | Section 5 (Warehouse grants), Section 6            |
| Product not visible in discovery                     | Section 6, Section 7                               |


## 1. Role you need


| Role                      | What it gives you                                                                                        |
| ------------------------- | -------------------------------------------------------------------------------------------------------- |
| Instance `User` role      | Sign in to DataOS                                                                                        |
| Tenant **Data Developer** | Create/update/delete your own resources: Secrets, Depots, Vulcan resources, Workflows, Services, Workers |


The Data Developer role starts with **zero** resource access. Compute, Depot, Secret, and Minerva access must each be granted explicitly with a `Can Use` permission. Access to one resource never cascades to another.

## 2. Resource permissions to request from the Tenant Admin


| Permission        | Needed for                                                                                                                                                            |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Can Use Compute` | Runtime for the Vulcan `plan`/`run`/`api` pods                                                                                                                        |
| `Can Use Depot`   | Vulcan reads/writes the source warehouse/engine (e.g. `dataos://postgresDepot?purpose=rw`)                                                                            |
| `Can Use Secret`  | Depot credentials, the Git-sync secret, **and** the tenant `state-connection` and `object-store-connection` secrets — each Secret is separate and needs its own grant |
| `Can Use Minerva` | Only if the product exposes a query endpoint via Minerva                                                                                                              |


When you create a resource yourself, you automatically get `Can Edit` and `Can Manage Access` on it — but not usage rights on its dependencies.

## 3. Prerequisites (configure before deploying)

You should have all of these in place first:

- [ ] DataOS CLI installed and logged in
- [ ] A Depot with read/write access to the target schema/database
- [ ] A valid engine stack (e.g. `postgres`, `snowflake`, `trino`, `lakehouse`)
- [ ] A valid Compute resource
- [ ] A Git repository holding the Vulcan project (models, semantics, dq, macros, seeds, tests)
- [ ] A Git-sync Secret for repo access (if the repo is private)
- [ ] `config.yaml` — Vulcan project configuration
- [ ] `deploy.yaml` — the DataOS Vulcan resource definition
- [ ] Warehouse/engine-side grants for the DB user in the Depot's Secret

Verify access before deploying:

```bash
dataos-ctl login
dataos-ctl version

dataos-ctl resource -t depot get -a
dataos-ctl resource -t depot get -n <depot-name> -a
dataos-ctl resource -t stack get -a
dataos-ctl resource -t compute get -a
```

Create the Git-sync secret (private repos):

```bash
dataos-ctl resource apply -f git-sync-secret.yaml
```

```yaml
name: git-sync
version: v2alpha
type: secret
workspace: system
layer: user
description: "Secret for git-sync authentication"
secret:
  type: key-value
  data:
    GITSYNC_USERNAME: "<your-git-username>"
    GITSYNC_PASSWORD: "<your-git-token-or-password>"
```

## 4. Example `deploy.yaml`

`deploy.yaml` is a DataOS resource manifest of `type: vulcan`. Generate a starter manifest with `vulcan create_deploy_yaml`, or write it manually:

```yaml
version: v1alpha
type: vulcan
name: orders-analytics
tags:
  - order-analytics
  - sales-operations
  - postgres
spec:
  compute: pacific
  engine: postgres
  repo:
    url: https://bitbucket.org/rubik_/vulcan-examples
    syncFlags:
      - '--ref=shreya-examples'
      - '--submodules=off'
    baseDir: vulcan-examples/engines/postgres/new/orders-analytics
    secretId: product-sandbox:git-sync
  depots:
    - dataos://postgresDepot?purpose=rw
  workflow:
    schedule:
      crons:
        - '*/15 * * * *'
      timezone: 'US/Pacific'
      concurrencyPolicy: Forbid
    logLevel: INFO
    plan:
      command: [vulcan]
      arguments: [--log-to-stdout, plan, --auto-apply]
    run:
      command: [vulcan]
      arguments: [--log-to-stdout, run]
  api:
    replicas: 2
    logLevel: INFO
```

## 5. Warehouse / engine-level grants

The DB user referenced in the Depot's Secret needs grants in the target warehouse. (The object Vulcan creates in the warehouse is governed by the Secret's credentials, not by DataOS platform governance.)

**Postgres:**

```sql
GRANT CREATE ON DATABASE my_db TO vulcan_user;
GRANT CREATE ON SCHEMA my_schema TO vulcan_user;
GRANT USAGE ON SCHEMA my_schema TO vulcan_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA my_schema TO vulcan_user;
```

**Snowflake** (the role IS the identity): `USAGE` on warehouse/database/schema, `SELECT` on tables, `CREATE TABLE/VIEW`, and `INSERT/UPDATE/DELETE` as needed.

**Lakehouse:** `depot:rw:<lakehouse-depot-name>` for read/write.

## 6. Deploy, verify & read logs

Apply the resource:

```bash
dataos-ctl resource apply -f deploy.yaml
```

DataOS starts three runtime components:


| Component | What it does                                                  |
| --------- | ------------------------------------------------------------- |
| `plan`    | Runs `vulcan plan --auto-apply` to prepare deployment changes |
| `run`     | Executes models via `vulcan run`, usually on a schedule       |
| `api`     | Long-running API service that exposes endpoints               |


Check status and logs:

```bash
# Status
dataos-ctl resource -t vulcan -n <data-product-name> get

# Logs (whole resource)
dataos-ctl resource -t vulcan -n <data-product-name> logs

# Logs for a specific component/container
dataos-ctl resource -t vulcan -n <resource-name> logs \
  --container-group <name>-run-execute -c main
```

Which log to check:


| Investigating                     | Log                                            |
| --------------------------------- | ---------------------------------------------- |
| Model execution results           | `run` logs (`<name>-run-execute`, `-c main`)   |
| Planning / migration / auto-apply | `plan` logs (`<name>-plan-execute`, `-c main`) |
| API availability / query issues   | `api` logs (`<name>-api`, `-c main`)           |


Then confirm:

- Tables/views exist in the target warehouse (`SHOW TABLES IN SCHEMA ...`).
- The API is live: `curl https://<env-fqn>/vulcan/tenants/<tenant>/vulcan/<data-product-name>/livez -H 'Authorization: Bearer <token>'`.
- The product appears in Product discovery with metadata, owner, inputs/outputs, and quality signals.

## 7. Common issues


| Issue                    | Check                                                       |
| ------------------------ | ----------------------------------------------------------- |
| Repository does not sync | Git URL, branch/`--ref`, `baseDir`, Git-sync secret         |
| Depot connection fails   | Depot name, credentials, permissions, warehouse access      |
| Stack not found          | Engine stack name and availability                          |
| Compute not found        | Compute name and workspace                                  |
| Plan fails               | `config.yaml`, gateway, model defaults, migrations          |
| Run fails                | Model SQL, dependencies, permissions, engine logs           |
| API fails                | API resource allocation, service status, sidecar logs       |
| Product not visible      | Scanner, metadata registration, product spec, target tenant |


## Deploy sequence (summary)

```
Onboard to Tenant (Data Developer)
-> Verify CLI/Depot/stack/Compute -> Prepare repo + Git-sync Secret
-> Write config.yaml + deploy.yaml -> apply -f deploy.yaml
-> Check status -> Review logs -> Verify models -> Verify API -> Confirm discovery
```

