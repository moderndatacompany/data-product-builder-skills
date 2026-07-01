---
name: deploy-data-product
description: >-
  Deploy a Vulcan Data Product on a DataOS instance and troubleshoot deployment
  failures. Use when the user asks to deploy a Vulcan data product, configure
  config.yaml / deploy.yaml for a cloud engine, set up the required secrets, push
  the Vulcan project to a repo, apply a vulcan resource, or fix a deployment issue
  (repo not syncing, depot/secret/compute access, plan/run/api failures, product
  not visible in discovery).
disable-model-invocation: true
---

# Deploy a Vulcan Data Product

## Reference doc (read this first)

All deployment steps, prerequisites, permissions, the `deploy.yaml` example,
warehouse grants, verify/log commands, and the common-issues table live in:

**`docs/vulcan-book/deploy-help.md`**

**Always read `deploy-help.md` and follow it** before answering or acting. It is
the single source of truth for command syntax, permission names, and manifest
fields — do not rely on memory.

## When to use this skill

- The user wants to deploy a Vulcan Data Product on a DataOS instance.
- The user needs to configure `config.yaml` / `deploy.yaml` for their cloud engine.
- The user needs to know which secrets to create (or reuse) and how to reference them.
- A deployment is failing and needs troubleshooting.

## Deployment workflow (guide the user through this)

1. **Read `docs/vulcan-book/deploy-help.md`** and confirm
   role + permissions (Sections 1–2) and prerequisites (Section 3).
2. **Configure `config.yaml` for the target cloud/engine** (see below).
3. **Create or reuse the required secrets** (see below).
4. **Push the Vulcan project to the Git repo** (see below).
5. **Write `deploy.yaml`** referencing the compute, engine, depots, and secret.
6. **Apply and verify**: `dataos-ctl resource apply -f deploy.yaml`, then check
   status/logs and confirm discovery (deploy-help.md Sections 6–7).

## Configure `config.yaml` for the cloud environment

Before deploying, the user must point the Vulcan project at their cloud engine,
not local defaults.

**What to fill in `config.yaml`:**

- `name`, `display_name`, `description`, `version` — product identity.
- `discoverable: true` — so the product shows up in discovery.
- `domain` and `owners` — ownership/routing metadata.
- `model_defaults.dialect` — the target engine (`postgres`, `snowflake`,
  `bigquery`, `databricks`, `trino`, `spark`, etc.).
- `gateways.default.connection` — the DataOS Depot for that engine, e.g.
  `type: depot`, `address: dataos://<depot-name>`.
- `model_defaults.start` / `cron` — schedule defaults if applicable.
- `variables` — any env-specific values (schemas, thresholds).

**What to check:**

- `DATAOS_TENANT_ID` is provided via environment / `.env`, **not** as a YAML key.
- The depot in `gateways` exists and the user has `Can Use Depot` on it.
- `dialect` matches the actual engine of that depot.
- Run `vulcan plan` locally — it must succeed with no errors before pushing.

## What to fill in `deploy.yaml` (a.k.a. `domain_resource.yaml`)

This is the DataOS Vulcan resource manifest (`type: vulcan`). Fill:

- `name` — the Data Product / resource name.
- `spec.compute` — the Compute pool name (verify with `dataos-ctl resource -t compute get -a`).
- `spec.engine` — same engine as `config.yaml` (`postgres`, `snowflake`, …).
- `spec.repo.url` — the Git repo URL holding the Vulcan project.
- `spec.repo.syncFlags` — `--ref=<branch>` must match the branch you pushed.
- `spec.repo.baseDir` — path to the project inside the repo.
- `spec.repo.secretId` — `<workspace>:<git-sync-secret-name>` (see Secrets below).
- `spec.depots` — `dataos://<depot-name>?purpose=rw` for each source/target depot.
- `spec.workflow.schedule` — `crons`, `timezone`, `concurrencyPolicy`.
- `spec.workflow.plan` / `spec.workflow.run` — the `vulcan plan`/`run` commands.
- `spec.api` — `replicas` and resources if the product exposes an API.

**What to check before `apply`:**

- `spec.engine` matches `config.yaml` dialect and the depot's engine.
- `spec.repo.secretId` points to an existing Git-sync secret (correct workspace).
- Each depot in `spec.depots` exists and has `Can Use Depot` granted.
- `spec.compute` exists and has `Can Use Compute` granted.
- Branch in `syncFlags` and `baseDir` actually contain the pushed project.

## Secrets the user needs (create or reuse)

> **Never ask the user to share secret values, and never fill credentials
> yourself.** Credentials (access keys, passwords, tokens) must be entered
> **manually by the user** in their own secret manifest. Provide the manifest
> template with placeholders (e.g. `<your-git-token>`), instruct the user to fill
> and apply it themselves, and only reference secrets by name/path afterward.

Each secret is a separate DataOS Resource (`type: secret`). If it already exists,
**reuse it** — do not recreate; just reference it by the correct path. If it does
not exist, tell the user to create it: fill the manifest manually, then
`dataos-ctl resource apply -f <secret>.yaml` and verify with
`dataos-ctl resource get -t secret -a`. The user needs `Can Use Secret` on each.

| Secret | When needed | How it's referenced |
| --- | --- | --- |
| Git-sync secret | Private repo holding the Vulcan project | `spec.repo.secretId: <workspace>:<secret-name>` in `deploy.yaml` |
| Depot credential secret (cloud-specific: S3, ABFSS, GCS, Snowflake, Postgres, BigQuery, etc.) | Depot connects to the source/warehouse | Attached to the Depot; the Depot is referenced as `dataos://<depot>?purpose=rw` |
| `vulcan-state-connection` (Postgres) | Every Vulcan data product — holds plan/interval/snapshot state | Tenant secret, usually SRE-provisioned; confirm it exists and reuse |
| `vulcan-object-store-connection` (S3/object store) | Every Vulcan data product — query results / artifact spooling | Tenant secret, usually SRE-provisioned; confirm it exists and reuse |

**Reference path rules:**

- `secretId` uses `workspace:name` (e.g. `product-sandbox:git-sync`).
- Depot references use `dataos://<depot-name>?purpose=rw` (or `?purpose=read`).
- If a secret already exists, run `dataos-ctl resource get -t secret -a` to get its
  exact name/workspace and use that path — don't assume.

## Push the Vulcan project to the repo

- Ensure the project structure is committed (`config.yaml`, `models/`, `dq/`,
  `macros/`, `seeds/`, `semantics/`, `tests/`).
- Push to the branch DataOS will sync; that branch/ref must match
  `spec.repo.syncFlags` (`--ref=<branch>`) and `spec.repo.baseDir` in `deploy.yaml`.
- The `secretId` in `spec.repo` must point to the Git-sync secret above.

## Scope

- Covers **deployment only** (`type: vulcan`). Consumption / query access is out of scope.
- For exact commands, manifests, warehouse grants, and troubleshooting, always defer
  to **`docs/vulcan-book/deploy-help.md`**.
