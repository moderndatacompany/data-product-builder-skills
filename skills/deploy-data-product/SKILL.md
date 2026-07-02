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
- The user needs to set up or reuse depot and secrets.
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
- CLI is logged in and version is recent.
- At least one Compute exists.
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
> Let me know when you have confirmed or received all the permissions above."

**Wait for the user to confirm before continuing.**

---

### Step 3 — Depot Readiness Check `[AGENT]`

Run:

```bash
dataos-ctl resource -t depot get -a
```

Show the output and ask the user: **"Is the depot you need in this list?"**

Then follow the matching branch below.

---

#### Branch A — Depot exists and user has `Can Use Depot`

Ask the user to confirm they have `Can Use Depot` on the depot. If yes, note the depot name and proceed to Step 4.

---

#### Branch B — Depot exists but user does NOT have `Can Use Depot` `[USER ACTION REQUIRED]`

Stop and tell the user:

> "The depot **`<depot-name>`** exists but you don't have `Can Use Depot` on it.
> Ask your **Tenant Admin** to grant you `Can Use Depot` on `<depot-name>`.
> Let me know when that's done."

**Wait for the user to confirm before continuing.**

---

#### Branch C — Depot does NOT exist `[AGENT]` then `[USER ACTION REQUIRED]`

The agent handles creating the manifests; the user fills credentials and applies.

**`[AGENT]`** — Read the relevant engine example:

```
docs/vulcan-examples/<engine>/
```

Using the depot and domain-resource examples in that folder as reference, generate two files with placeholders:

1. **`depot-secret.yaml`** — the credential secret for the engine (never fill actual values; use `<your-value>` placeholders for all credentials).
2. **`depot.yaml`** — the depot manifest referencing the secret, with the correct `spec.type` and fields for the engine.

Present both files to the user.

**`[USER ACTION REQUIRED]`** — Tell the user:

> "I've generated the depot secret and depot manifest above.
>
> You need to:
> 1. Open `depot-secret.yaml`, fill in your credentials where you see `<your-value>` placeholders. **Never share these values with the agent.**
> 2. Apply both files yourself:
>    ```bash
>    dataos-ctl resource apply -f depot-secret.yaml
>    dataos-ctl resource apply -f depot.yaml
>    ```
> 3. Verify the depot is live:
>    ```bash
>    dataos-ctl resource -t depot get -n <depot-name> -a
>    ```
> 4. Then ask your **Tenant Admin** to grant you `Can Use Depot` on the new depot.
>
> Let me know when the depot is created and permission is granted."

**Wait for the user to confirm before continuing.**

---

### Step 4 — Check required secrets `[AGENT]` then `[USER ACTION REQUIRED]`

**`[AGENT]`** — Run:

```bash
dataos-ctl resource get -t secret -a
```

For each required secret, check if it already exists:

| Secret | Purpose |
|---|---|
| Git-sync secret | Lets DataOS sync the private Git repo |
| `vulcan-state-connection` | Plan/interval/snapshot state — usually SRE-provisioned |
| `vulcan-object-store-connection` | Query results / artifact spooling — usually SRE-provisioned |

- If a secret **exists**: note its exact `workspace:name` — reuse it, do NOT recreate.
- If `vulcan-state-connection` or `vulcan-object-store-connection` is **missing**: tell the user to contact their SRE team — do not attempt to create these.
- If the **Git-sync secret** is missing: go to the `[USER ACTION REQUIRED]` block below.

**`[USER ACTION REQUIRED]`** — Git-sync secret (only if missing):

> "The Git-sync secret does not exist yet. Create it yourself — never share your credentials with the agent.
>
> 1. Create `git-sync-secret.yaml`:
> ```yaml
> name: git-sync
> version: v2alpha
> type: secret
> workspace: <your-workspace>
> layer: user
> secret:
>   type: key-value
>   data:
>     GITSYNC_USERNAME: "<your-git-username>"
>     GITSYNC_PASSWORD: "<your-git-token>"
> ```
> 2. Apply it:
> ```bash
> dataos-ctl resource apply -f git-sync-secret.yaml
> ```
> 3. Verify: `dataos-ctl resource get -t secret -a`
>
> Let me know the secret name and workspace once it's created."

**Wait for confirmation before continuing.**

---

### Step 5 — Configure `config.yaml` for the cloud environment `[AGENT]`

Update `config.yaml` to point at the cloud engine:

- `name`, `display_name`, `description`, `version` — product identity.
- `discoverable: true` — required for the product to appear in discovery.
- `domain` and `owners` — ownership/routing metadata.
- `model_defaults.dialect` — target engine (`postgres`, `snowflake`, `databricks`, `trino`, `spark`, etc.).
- `gateways.default.connection` — `type: depot`, `address: dataos://<depot-name>`.
- `model_defaults.start` / `cron` — schedule defaults if applicable.
- `variables` — any env-specific values (schemas, thresholds).

Check before moving on:
- `DATAOS_TENANT_ID` is provided via environment / `.env`, NOT as a YAML key.
- `dialect` matches the actual engine of the depot.
- Run `vulcan plan` locally — it must succeed before pushing.

```bash
vulcan plan
```

If `vulcan plan` fails, fix the errors before continuing.

---

### Step 6 — Push the Vulcan project to the Git repo `[AGENT]`

Ensure all project files are committed, then push:

```bash
git add .
git commit -m "prepare for DataOS deployment"
git push origin <branch>
```

Confirm the pushed branch and `baseDir` match what will go into `deploy.yaml`.

---

### Step 7 — Apply warehouse grants `[USER ACTION REQUIRED]`

Stop and tell the user:

> "Before deploying, the DB user in your Depot's credentials needs grants on the target warehouse.
> Ask your **DBA or warehouse admin** to run the appropriate grants:
>
> **Postgres:**
> ```sql
> GRANT CREATE ON DATABASE <db> TO <user>;
> GRANT CREATE ON SCHEMA <schema> TO <user>;
> GRANT USAGE ON SCHEMA <schema> TO <user>;
> GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA <schema> TO <user>;
> ```
>
> **Snowflake:** `USAGE` on warehouse/database/schema, `SELECT`, `CREATE TABLE/VIEW`, DML as needed.
>
> **Lakehouse:** `depot:rw:<depot-name>` access.
>
> Let me know when the grants are in place."

**Wait for the user to confirm before continuing.**

---

### Step 8 — Generate and fill `deploy.yaml` `[AGENT]`

Generate the starter manifest:

```bash
vulcan create_deploy_yaml
```

Fill in every placeholder using values confirmed in the steps above:

- `name` — kebab-case, matches `config.yaml` `name:`.
- `spec.compute` — from Step 1 output.
- `spec.engine` — same as `config.yaml` dialect.
- `spec.repo.url` — the Git repo URL.
- `spec.repo.syncFlags` — `--ref=<branch>` matching the branch pushed in Step 6.
- `spec.repo.baseDir` — path to the project inside the repo.
- `spec.repo.secret` — `<workspace>:<git-sync-secret-name>` from Step 4.
- `spec.depots` — `dataos://<depot-name>?purpose=rw` for each depot.
- `spec.workflow.schedule.crons` — matching the freshness cadence from the design spec.
- `spec.workflow.schedule.timezone` and `endOn`.
- `spec.api.replicas` — default `1`.

Reference `docs/vulcan-examples/<engine>/` for a working `domain-resource.yaml` example for this engine.

Present the completed `deploy.yaml` to the user for review. Do NOT apply until the user approves.

---

### Step 9 — Apply the resource `[AGENT]`

After user approval:

```bash
dataos-ctl resource apply -f deploy.yaml
```

Check status:

```bash
dataos-ctl resource -t vulcan -n <data-product-name> get
```

---

### Step 10 — Verify deployment `[AGENT]`

```bash
# Run logs
dataos-ctl resource -t vulcan -n <name> logs --container-group <name>-run-execute -c main

# Plan logs
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
