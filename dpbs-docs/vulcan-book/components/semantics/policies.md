---
description: >-
  Define row and column access rules per policy group for a semantic model.
---

# Policies

Policies are Vulcan's row- and column-level access control mechanism for the semantic layer. You can use the `policies` parameter within a [semantic model](README.md) to define them.

Each policy is a rule row scoped to one access group: it can restrict which rows that group can see (`filter`) and which dimensions get redacted for that group (`mask`). Groups with no matching rule get no access by default. Declare an empty rule (just `group`) to grant a group unrestricted access to the model.

```yaml
policies:
  - group: developer

  - group: operator
    mask:
      - email
      - customer_name
    filter:
      - member: customer_segment
        operator: notEquals
        values:
          - Churned
```

In this example, `developer` has full access. `operator` can query the model but never sees raw `email` or `customer_name` values, and never sees rows where `customer_segment = Churned`.

Policies match against the caller's resolved security context, specifically the `group` a root-level `afterAuthorize` hook in `config.yaml` returns after DataOS authorization. See [Plugins and auth](../../plugins-and-auth.md) for how to wire up that hook.

{% hint style="warning" %}
**Configure the auth extension first**

If you use auth-backed semantic policies or masking, `config.yaml` must include the root-level `afterAuthorize` hook, or Vulcan has no group to match policy rules against. See [Plugins and auth](../../plugins-and-auth.md) for the full setup.
{% endhint %}

***

## Parameters

### `group`

The access group this rule applies to. Required. Must be unique among a semantic model's `policies`, and, unlike every other Vulcan identifier, must be **lowercase only**, matching `^[a-z][a-z0-9_]{0,63}$`.

```yaml
policies:
  - group: analyst
```

{% hint style="warning" %}
`group`'s lowercase-only pattern is stricter than the identifier rules used elsewhere (`name` on measures, dimensions, segments, and so on, which allow mixed case). Declaring `group: Analyst` fails validation.
{% endhint %}

### `filter`

A list of row-level predicates that restrict which rows this group can see. Optional; omit it (or declare only `group`) to grant the group unrestricted row access.

Each entry is either a **unary filter** (`member`/`operator`/`values`) or a **logical filter** (`and`/`or` grouping other filters):

```yaml
policies:
  - group: operator
    filter:
      - member: customer_segment
        operator: notEquals
        values:
          - Churned

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

#### `member`

The name of a dimension, measure, or segment on the **current** semantic model. Required on a unary filter; must follow the same identifier pattern as other Vulcan names (`^[a-zA-Z_][a-zA-Z0-9_]{0,63}$`). Vulcan validates that `member` names a real field on the model. An unknown `member` fails with "references unknown filter columns."

#### `operator`

The comparison applied to `member`. Required on a unary filter; must be one of the values below.

| `equals` | `notEquals` | `contains` | `notContains` | `startsWith` | `notStartsWith` |
| -------- | ----------- | ---------- | ------------- | ------------ | ---------------- |
| `endsWith` | `notEndsWith` | `in` | `notIn` | `gt` | `gte` |
| `lt` | `lte` | `set` | `notSet` | `inDateRange` | `notInDateRange` |
| `onTheDate` | `beforeDate` | `beforeOrOnDate` | `afterDate` | `afterOrOnDate` | |

{% hint style="warning" %}
`measureFilter` is a valid filter operator elsewhere in Vulcan, but it is explicitly forbidden inside a policy `filter`, since policy filters are row-level only. Using `measureFilter` here fails validation.
{% endhint %}

#### `values`

The comparison value(s) for `operator`. Required and must be non-empty for every operator except `set` and `notSet`, which test for null/non-null and must **not** declare `values` at all.

```yaml
policies:
  - group: operator
    filter:
      - member: email
        operator: set

  - group: analyst
    filter:
      - member: plan_type
        operator: in
        values:
          - pro
          - enterprise
```

#### `and` / `or`

Nests other filter entries (unary or logical) into a boolean group. Exactly one of `and`/`or` is required per logical entry, and its list must be non-empty. Declaring both, or an empty list, fails validation.

### `mask`

A list of dimension names to redact for this group. Optional; omit it to leave every dimension visible to the group.

```yaml
policies:
  - group: operator
    mask:
      - email
      - customer_name
```

Each masked dimension is still selectable: its column isn't hidden, only its value is replaced with whatever SQL the dimension's own [`mask_expression`](dimensions.md#mask_expression) declares. A dimension with no `mask_expression` cannot be masked. Listing it in `mask` fails validation with "column_mask_expressions is not declared on the model."

{% hint style="warning" %}
`mask` accepts plain member names only. A bare wildcard (`mask: "*"`) is **not** supported. Vulcan raises "mask wildcard '\*' is not supported; list explicit member names." Inline mask expressions on the policy row are also rejected; put the substitute SQL on the dimension's own `mask_expression` instead.
{% endhint %}

***

## Validation

Vulcan validates policy definitions during `vulcan plan`. It checks that:

* `group` is required, unique among a semantic model's `policies`, and matches the lowercase-only `^[a-z][a-z0-9_]{0,63}$` pattern
* `filter` entries reference real dimensions, measures, or segments on the current semantic model by bare name
* `measureFilter` is not used as a filter operator
* Every operator except `set`/`notSet` has non-empty `values`, and `set`/`notSet` omit `values`
* A logical `and`/`or` entry has exactly one of the two keys with a non-empty list
* `mask` entries are plain member names, with no wildcard and no inline expressions
* Each masked dimension already declares a non-empty `mask_expression`

## Related pages

* [Semantic models](README.md) for how policies fit into the full spec
* [Dimensions](dimensions.md) for declaring `mask_expression` on a masked field
* [Plugins and auth](../../plugins-and-auth.md) for wiring up the `afterAuthorize` hook
