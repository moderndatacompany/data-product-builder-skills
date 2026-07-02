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

---

## Step labels used in this skill

> **`[AGENT]`** — the agent runs this command or writes this file. Proceed automatically.
>
> **`[USER ACTION REQUIRED]`** — the agent cannot do this. Stop, show the user exact instructions, and **wait for their confirmation** before moving to the next step.

---

## When to use this skill

- The user wants to deploy a Vulcan Data Product on a DataOS instance.
- The user needs to configure `config.yaml` / `deploy.yaml` for their cloud engine.
- The user needs to know which secrets to create (or reuse) and how to reference them.
- A deployment is failing and needs troubleshooting.

---

## Deployment Workflow

### Step 1 — Verify CLI and available resources `[AGENT]`

Run these commands and show the output to the user:

```bash
dataos-ctl login
dataos-ctl version
dataos-ctl resource -t depot get -a
dataos-ctl resource -t compute get -a
dataos-ctl resource -t stack get -a
```

Check:
- CLI is logged in and the version is recent.
- At least one Depot and one Compute exist.
- The engine stack the user needs is available.

If any command errors, stop and troubleshoot before continuing.

---

### Step 2 — Verify permissions `[USER ACTION REQUIRED]`

The agent cannot grant permissions. Stop and tell the user:

> "Before we proceed, confirm you have the following DataOS permissions.
> If any are missing, ask your **Tenant Admin** to grant them:
>
> | Permission | Needed for |
> |---|---|
> | `Can Use Compute` | Running plan/run/api pods |
> | `Can Use Depot` | Read/write to the source warehouse |
> | `Can Use Secret` | Git-sync, depot credentials, state/object-store secrets |
> | `Can Use Minerva` | Only if the product exposes a Minerva query endpoint |
>
> You can check your current permissions in the DataOS UI under your profile.
> Let me know when you have confirmed or received all the permissions above."

**Wait for the user to confirm before continuing.**

---

### Step 3 — Check required secrets `[AGENT]` then `[USER ACTION REQUIRED]`

**`[AGENT]`** — Run to see what secrets already exist:

```bash
dataos-ctl resource get -t secret -a
```

Show the output. For each required secret below, check if it already exists:

| Secret | Purpose |
|---|---|
| Git-sync secret | Lets DataOS sync the private Git repo |
| Depot credential secret | Engine-specific credentials (Snowflake, Postgres, S3, etc.) |
| `vulcan-state-connection` | Holds plan/interval/snapshot state — usually SRE-provisioned |
| `vulcan-object-store-connection` | Query results / artifact spooling — usually SRE-provisioned |

- If a secret **exists**: note its exact `workspace:name` — reuse it, do NOT recreate.
- If `vulcan-state-connection` or `vulcan-object-store-connection` is missing: tell the user to contact their SRE team — these are tenant-level secrets the agent cannot create.
- If the **Git-sync secret** is missing: move to the `[USER ACTION REQUIRED]` block below.

**`[USER ACTION REQUIRED]`** — Git-sync secret creation (only if missing):

> "The Git-sync secret does not exist yet. You need to create it yourself — never share
> your credentials with the agent.
>
> 1. Create a file `git-sync-secret.yaml` with this template and fill in your values:
>
> ```yaml
> name: git-sync
> version: v2alpha
> type: secret
> workspace: <your-workspace>
> layer: user
> description: "Secret for git-sync authentication"
> secret:
>   type: key-value
>   data:
>     GITSYNC_USERNAME: "<your-git-username>"
>     GITSYNC_PASSWORD: "<your-git-token-or-password>"
> ```
>
> 2. Apply it yourself:
> ```bash
> dataos-ctl resource apply -f git-sync-secret.yaml
> ```
>
> 3. Verify:
> ```bash
> dataos-ctl resource get -t secret -a
> ```
>
> Let me know the secret name and workspace once it's created."

**Wait for the user to confirm the secret exists before continuing.**

---

### Step 4 — Configure `config.yaml` for the cloud environment `[AGENT]`

Update `config.yaml` to point at the cloud engine. Fill in:

- `name`, `display_name`, `description`, `version` — product identity.
- `discoverable: true` — required for the product to appear in discovery.
- `domain` and `owners` — ownership/routing metadata.
- `model_defaults.dialect` — target engine (`postgres`, `snowflake`, `databricks`, `trino`, `spark`, etc.).
- `gateways.default.connection` — the DataOS Depot, e.g. `type: depot`, `address: dataos://<depot-name>`.
- `model_defaults.start` / `cron` — schedule defaults if applicable.
- `variables` — any env-specific values (schemas, thresholds).

**Check before moving on:**
- `DATAOS_TENANT_ID` is provided via environment / `.env`, NOT as a YAML key.
- `dialect` matches the actual engine of the depot.
- The depot in `gateways` is one the user confirmed `Can Use Depot` for (Step 2).

Then run a local plan to confirm no errors:

```bash
vulcan plan
```

If `vulcan plan` fails, fix the errors before continuing.

---

### Step 5 — Push the Vulcan project to the Git repo `[AGENT]`

Ensure all project files are committed, then push:

```bash
git add .
git commit -m "prepare for DataOS deployment"
git push origin <branch>
```

Confirm:
- The branch pushed matches the `--ref=<branch>` value that will go in `deploy.yaml`.
- The project root (`config.yaml`, `models/`, etc.) is at the path that will be `spec.repo.baseDir`.

---

### Step 6 — Apply warehouse grants `[USER ACTION REQUIRED]`

The agent has no warehouse access. Stop and tell the user:

> "Before deploying, the DB user in your Depot's credentials needs grants on the target
> warehouse. Ask your **DBA or warehouse admin** to run these:
>
> **Postgres:**
> ```sql
> GRANT CREATE ON DATABASE <db> TO <user>;
> GRANT CREATE ON SCHEMA <schema> TO <user>;
> GRANT USAGE ON SCHEMA <schema> TO <user>;
> GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA <schema> TO <user>;
> ```
>
> **Snowflake:** `USAGE` on warehouse/database/schema, `SELECT` on tables,
> `CREATE TABLE/VIEW`, and DML as needed.
>
> **Lakehouse:** `depot:rw:<depot-name>` access.
>
> Let me know when the grants are in place."

**Wait for the user to confirm before continuing.**

---

### Step 7 — Generate and fill `deploy.yaml` `[AGENT]`

Generate the starter manifest:

```bash
vulcan create_deploy_yaml
```

Then fill in every placeholder field:

- `name` — kebab-case, matches `config.yaml` `name:`.
- `spec.compute` — from the `dataos-ctl resource -t compute get -a` output (Step 1).
- `spec.engine` — same as `config.yaml` dialect.
- `spec.repo.url` — the Git repo URL.
- `spec.repo.syncFlags` — `--ref=<branch>` matching the branch pushed in Step 5.
- `spec.repo.baseDir` — path to the project inside the repo.
- `spec.repo.secretId` — `<workspace>:<git-sync-secret-name>` from Step 3.
- `spec.depots` — `dataos://<depot-name>?purpose=rw` for each depot.
- `spec.workflow.schedule.crons` — matching the freshness cadence from the spec.
- `spec.workflow.schedule.timezone` and `endOn`.
- `spec.api.replicas` — default `1`.

Present the completed `deploy.yaml` to the user for review. Do NOT apply until the user approves.

---

### Step 8 — Apply the resource `[AGENT]`

After user approval of the manifest:

```bash
dataos-ctl resource apply -f deploy.yaml
```

Check status:

```bash
dataos-ctl resource -t vulcan -n <data-product-name> get
```

---

### Step 9 — Verify deployment `[AGENT]`

Check logs for each component:

```bash
# Run logs (model execution)
dataos-ctl resource -t vulcan -n <name> logs --container-group <name>-run-execute -c main

# Plan logs (migration / auto-apply)
dataos-ctl resource -t vulcan -n <name> logs --container-group <name>-plan-execute -c main

# API logs
dataos-ctl resource -t vulcan -n <name> logs --container-group <name>-api -c main
```

Confirm:
- Tables/views exist in the target warehouse.
- API is live: `curl https://<env-fqn>/vulcan/tenants/<tenant>/vulcan/<name>/livez -H 'Authorization: Bearer <token>'`
- Product appears in Product Discovery with metadata, owner, inputs/outputs, and quality signals.

If any check fails, use the **Symptom → where to look** table in `deploy-help.md` Section 7.

---

## Scope

- Covers **deployment only** (`type: vulcan`). Consumption / query access is out of scope.
- For exact commands, manifests, warehouse grants, and troubleshooting, always defer to **`docs/vulcan-book/deploy-help.md`**.
