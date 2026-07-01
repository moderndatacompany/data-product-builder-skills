---
name: deploy-data-product
description: >-
  Deploy a Vulcan Data Product on a DataOS instance and troubleshoot deployment
  failures. Use when the user asks to deploy a Vulcan data product, configure
  config.yaml / deploy.yaml, apply a vulcan resource, or fix a deployment issue
  (repo not syncing, depot/secret/compute access, plan/run/api failures, product
  not visible in discovery).
disable-model-invocation: true
---

# Deploy a Vulcan Data Product

## Reference doc (read this first)

All deployment steps, prerequisites, permissions, the `deploy.yaml` example,
warehouse grants, verify/log commands, and the common-issues table live in:

**`docs/vulcan-book/deploy-help.md`**

**Always read `deploy-help.md` before answering or acting.** It is the single
source of truth for this workflow — do not rely on memory for command syntax,
permission names, or manifest fields.

---

## When to use this skill

- The user wants to deploy a Vulcan Data Product on a DataOS instance.
- A deployment is failing and needs troubleshooting.
- The user is preparing `config.yaml` / `deploy.yaml` or configuring Git-sync,
  Vulcan state, or object-store secrets.

---

## How to use it

1. **Read `docs/vulcan-book/deploy-help.md` in full** before responding.
2. **Deploying from scratch** — follow the numbered sections in order:
   Role → Permissions → Prerequisites → `deploy.yaml` → Warehouse grants →
   Deploy/verify → Common issues.
3. **Troubleshooting** — start from the **Symptom → where to look** table in
   the doc and jump to the matching section.
4. Use the **exact `dataos-ctl` commands** from the doc; do not invent flags or
   modify command syntax.

---

## Workflow

### Step 1 — Confirm prerequisites

Before touching any manifest, verify the checklist in Section 3 of
`deploy-help.md`:

- DataOS CLI installed and logged in (`dataos-ctl login`, `dataos-ctl version`)
- Depot with read/write access confirmed (`dataos-ctl resource -t depot get -a`)
- Valid engine stack and Compute resource available
- Git repository with the Vulcan project ready
- Git-sync Secret created (if repo is private)
- `config.yaml` and `deploy.yaml` ready or to be generated

If any prerequisite is missing, stop and help the user resolve it before
proceeding.

---

### Step 2 — Verify permissions

Check that the user has the required DataOS permissions (Section 2 of
`deploy-help.md`):

| Permission        | Needed for                                      |
| ----------------- | ----------------------------------------------- |
| `Can Use Compute` | `plan`/`run`/`api` pods                         |
| `Can Use Depot`   | Warehouse read/write                            |
| `Can Use Secret`  | Depot credentials, Git-sync, state/object-store |
| `Can Use Minerva` | Only if the product exposes a Minerva endpoint  |

If permissions are missing, tell the user exactly which ones to request from
the Tenant Admin and what they are needed for.

---

### Step 3 — Generate or review `deploy.yaml`

If not already generated:

```bash
vulcan create_deploy_yaml
```

Walk the user through filling in every placeholder field listed in Section 4 of
`deploy-help.md`:

- `name` — kebab-case, matches `config.yaml` `name:`
- `spec.runAsUser` — DataOS username
- `spec.engine` — e.g. `snowflake`, `postgres`, `trino`
- `spec.repo.url` / `syncFlags` / `baseDir` / `secret`
- `spec.depots` — e.g. `dataos://postgresDepot?purpose=rw`
- `spec.workflow.schedule.crons` — matches freshness cadence from the spec
- `spec.workflow.schedule.timezone` and `endOn`
- `spec.api.replicas`

Present the filled manifest to the user for review before applying.

---

### Step 4 — Apply warehouse grants

Before running `apply`, confirm the DB user in the Depot Secret has the grants
required by the engine (Section 5 of `deploy-help.md`):

- **Postgres**: `GRANT CREATE ON DATABASE/SCHEMA`, `USAGE`, `SELECT/INSERT/UPDATE/DELETE ON ALL TABLES`
- **Snowflake**: `USAGE` on warehouse/database/schema, `SELECT`, `CREATE TABLE/VIEW`, DML as needed
- **Lakehouse**: `depot:rw:<depot-name>`

---

### Step 5 — Deploy

```bash
dataos-ctl resource apply -f deploy.yaml
```

Then check status and logs (Section 6 of `deploy-help.md`):

```bash
dataos-ctl resource -t vulcan -n <data-product-name> get
dataos-ctl resource -t vulcan -n <data-product-name> logs
```

| Investigating                     | Log component                              |
| --------------------------------- | ------------------------------------------ |
| Model execution results           | `<name>-run-execute` `-c main`             |
| Planning / migration / auto-apply | `<name>-plan-execute` `-c main`            |
| API availability / query issues   | `<name>-api` `-c main`                     |

---

### Step 6 — Verify

After a successful apply, confirm:

- Tables/views exist in the target warehouse (`SHOW TABLES IN SCHEMA ...`)
- API is live: `curl https://<env-fqn>/vulcan/tenants/<tenant>/vulcan/<name>/livez -H 'Authorization: Bearer <token>'`
- Product appears in Product Discovery with metadata, owner, inputs/outputs, and quality signals

---

### Step 7 — Troubleshoot (if something fails)

Use the **Symptom → where to look** table at the top of `deploy-help.md` to
identify the matching section, then follow it exactly. Common issues are in
Section 7 of the doc — match the exact error before suggesting a fix.

---

## Scope

Covers **deployment only** (Vulcan resource, `type: vulcan`).
Consumption / query access is out of scope.
