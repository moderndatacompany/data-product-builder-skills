---
description: >-
  Technical reference for Vulcan access policies, row filters, column masking,
  auth plugins, and physical-model-only policy inheritance.
---

# Policies

Vulcan policies enforce row filtering and column masking on physical models. Author the policy once against the physical model; semantic and metric models inherit the policy and masks from that physical model at load and export time.

Policy enforcement spans four project locations:

| Location | You author | Purpose |
| -------- | ---------- | ------- |
| `policies/access/*.yml` | `type: policy`, one `depends_on` physical model, and `rules[]` with `group`, `mask`, and `filter` | Which groups can see which rows and which columns are masked |
| `plugins/*.py` | An `after_authorize` hook that returns a `SecurityContext` | Resolve the authenticated caller into a policy group and extra claims |
| Physical model `MODEL(...)` block | `column_mask_expressions` | Define how each masked column is replaced |
| `config.yaml` | `after_authorize: "module:callable"` | Wire the plugin hook into request authorization |

## Request flow

```text
Bearer token
  -> Authorization
  -> after_authorize hook
  -> SecurityContext(group=..., claims...)
  -> policy rule matched by SecurityContext.group
  -> row filters and column masks applied to the physical model query
```

The authorization middleware attaches the returned `SecurityContext` to `request.state`. Policy filters can reference its extra claims with `{securityContext.<key>}` placeholders.

## Policy files

Put access policy files under `policies/access/`. Use one file per physical model that needs access control.

```yaml
# policies/access/users_pii_masking.yml
type: policy
name: users_pii_masking
depends_on:
  - customer.users

rules:
  - group: executive
  - group: analyst
    mask:
      - email
      - industry
    filter:
      - member: status
        operator: equals
        values:
          - "{securityContext.status}"
```

### Schema

`type` or `kind` must resolve to `policy`, case-insensitively.

`depends_on` is a list, but exactly one entry is permitted. The entry must resolve to a physical/base model. Attaching a policy to a semantic or metric model fails with `attach policy to a physical model only`.

`rules` is a list of group-specific rules. A rule with only `group` grants that group unrestricted access to the model.

### Rule fields

| Field | Required | Description |
| ----- | -------- | ------------ |
| `group` | Yes | Access group matched against `SecurityContext.group`. Must be lowercase snake case, matching `^[a-z][a-z0-9_]{0,63}$`. |
| `mask` | No | Bare column names to mask for the group. Wildcards and inline mask-expression objects are rejected. |
| `filter` | No | Row-level filters. Values may be literals or `{securityContext.<key>}` templates resolved at query time. |

`filter` entries can be unary filters or logical filters. Unary filters use `member`, `operator`, and, for most operators, `values`. Logical filters use nested `and` or `or` lists.

```yaml
rules:
  - group: regional_manager
    filter:
      - or:
          - member: region
            operator: equals
            values:
              - west
          - member: region
            operator: equals
            values:
              - central
```

## Loading and attachment

During project load, Vulcan discovers `*.yml` and `*.yaml` files under `policies/`, parses documents whose `kind` or `type` resolves to `policy`, and validates them against the policy schema.

Vulcan then resolves the single `depends_on` target and attaches the parsed policy to that physical model. Only one policy file can target a physical model.

## Runtime behavior

At query time, Vulcan matches `SecurityContext.group` against `rules[].group`.

If no rule matches, access is denied according to the policy engine's default behavior. Author a rule for every group that should query the model.

If the matching rule has `filter`, Vulcan appends the row filter to the query. Missing `securityContext` keys referenced by filter values return `403`.

If the matching rule has `mask`, Vulcan replaces each listed column with its corresponding `column_mask_expressions` expression from the physical model.

Policy-governed query responses can include `filter_display`, a read-only summary of the active row filter for the caller's group.

## Auth plugin

The `plugins/` folder is a plain Python package. In policy projects, it usually hosts the `after_authorize` hook that converts an authenticated request into a `SecurityContext`.

```python
# plugins/auth_ext.py
from schema.auth import AuthExtensionContext, SecurityContext


async def resolve_user_groups(ctx: AuthExtensionContext) -> SecurityContext:
    if "pii-team" in ctx.user_tags:
        return SecurityContext(group="analyst", status="active")
    return SecurityContext(group="viewer")
```

The hook input is `AuthExtensionContext`, which includes `user_id`, `user_tags`, and `request_headers`.

The hook output is `SecurityContext`. Its `group` value is matched against policy rules. Any additional keyword fields become claims available to row-filter templates, such as `{securityContext.status}`.

The hook may be sync or async. If it raises, or the configured path cannot be imported, Vulcan does not attach a `SecurityContext`, so group-scoped policy rules cannot match.

## Configure `after_authorize`

Set `after_authorize` in `config.yaml` to the import path of the hook.

```yaml
after_authorize: "plugins.auth_ext:resolve_user_groups"
```

If `after_authorize` is not configured, no `SecurityContext` is produced after authorization succeeds. Any model with an attached policy should plan for that explicitly.

## Column masks

Policies decide who is masked and which columns are masked. Physical models decide how masking happens with `column_mask_expressions`.

```sql
MODEL (
  name customer.users,
  column_mask_expressions (
    signup_date = CAST(NULL AS TIMESTAMP),
    email = CONCAT('***.', SPLIT_PART(email, '.', 2)),
    industry = CONCAT('**', SUBSTRING(industry FROM 3))
  ),
  column_classifications (
    plan_type = restricted,
    company_name = internal
  )
);
```

Keys are model column names. Values are SQL expressions evaluated in place of the raw column when a caller's matching policy rule masks that column.

Expressions must use bare column names. Do not use `{model.column}` references inside `column_mask_expressions`.

Vulcan validates the contract at load time: every column listed in any policy rule's `mask` must have a matching `column_mask_expressions` entry on the physical model. Missing entries fail with `column_mask_expression is missing for proposed masking on column <name>`.

`column_classifications` is separate governance/catalog metadata. It has no runtime masking effect.

## Rollups

When `enable_rollup: true` is set, semantic rollups materialize pre-aggregated physical tables. A rollup `group by` dimension can only use a column whose mask is a constant expression, such as `CAST(NULL AS TIMESTAMP)` or a string literal.

Value-referencing masks, such as `CONCAT(LEFT(email, 2), '***')`, cannot be safely re-derived from already-aggregated rollup data and are rejected for rollup dimensions.

## Semantic and metric inheritance

Policies and column masks are physical-model-only.

Semantic models no longer author access policy or masking logic. Inline `policies:` on a semantic model is ignored with a warning, and per-dimension `mask_expression` is stripped at load time.

Metric models also cannot receive policies directly. Attach the policy to the metric's backing physical model instead.

At export time, Vulcan resolves a semantic model's physical anchor and pulls that anchor's policy and `column_mask_expressions`, so the semantic layer reflects the physical model's access rules without redeclaration.

## Migration

If a project still has inline `policies:` on a semantic model, move those rules into `policies/access/*.yml` and set `depends_on` to the underlying physical model.

If a semantic dimension still has `mask_expression`, move that SQL into the physical model's `column_mask_expressions`, then reference the column under `mask` in the policy rule.
