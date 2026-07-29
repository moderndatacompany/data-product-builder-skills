---
description: >-
  Define relationships between semantic models for cross-model analysis.
---

# Joins

Joins define relationships between semantic models so consumers can analyze across tables. You can use the `joins` parameter within a [semantic model](README.md) to define joins to other semantic models. Each join entry's `name` must match the `name` of another declared semantic model in the project, and must not equal the current model's own `name`.

```yaml
joins:
  - name: subscription_plans
    type: many_to_one
    expression: "{subscriptions.plan_id} = {subscription_plans.plan_id}"

  - name: usage_sessions
    type: one_to_many
    expression: "{subscriptions.subscription_id} = {usage_sessions.subscription_id}"

  - name: users
    type: many_to_one
    expression: "{subscriptions.user_id} = {users.user_id}"
```

After joins are declared, measures and segments can reference and filter on columns from joined semantic models, and Vulcan resolves the join path automatically using the declared cardinality:

```yaml
measures:
  - name: total_seats
    type: sum
    expression: "{subscriptions.seats}"
    filters:
      - "{subscriptions.status} = 'active'"
```

This is what lets a `subscriptions` semantic model expose `subscription_plans`- and `users`-scoped fields to any consumer querying it, without the consumer having to write the join itself.

{% hint style="warning" %}
**Joins do not accept metadata**

Joins do not support `description`, `tags`, `terms`, or `public`. Extra keys fail validation.
{% endhint %}

***

## Parameters

### `name`

The identifier of the join, which must match the `name` of an existing semantic model in the project. It does not need to match the target's physical `depends_on` model, but it must differ from the declaring semantic model's own `name`. The target must also resolve to a linked physical model; a join to a semantic model name that never links to a physical table fails validation.

```yaml
joins:
  - name: subscription_plans
    type: many_to_one
    on: plan_id
```

### `type`

The join cardinality. Required; must be one of the values below.

| Type | Cardinality | Example |
| ---- | ----------- | ------- |
| `one_to_one` | One row matches one row | User to user profile |
| `one_to_many` | One row matches many rows | User to subscriptions |
| `many_to_one` | Many rows match one row | Subscriptions to subscription plans |

```yaml
joins:
  - name: usage_events
    type: one_to_many
    expression: "{users.user_id} = {usage_events.user_id}"
```

{% hint style="warning" %}
`many_to_many` is not a supported cardinality. Model many-to-many relationships through an intermediate join model that wraps the bridge table, then chain two joins.
{% endhint %}

### `on`

A structured equi-join predicate: a small boolean tree that compiles into `expression` at load time. Set exactly one of `on` or `expression`; setting both, or neither, is a validation error.

The simplest form is a single dimension name shared by both sides:

```yaml
joins:
  - name: subscriptions
    type: one_to_many
    on: user_id
```

This compiles to `{users.user_id} = {subscriptions.user_id}`. A bare list is an implicit AND of multiple shared dimensions:

```yaml
joins:
  - name: subscriptions
    type: one_to_many
    on:
      - tenant_id
      - user_id
```

Use a nested two-item list (block-list syntax, not inline `[a, b]`) for an asymmetric pair where the column is named differently on each side:

```yaml
joins:
  - name: subscription_plans
    type: many_to_one
    on:
      - tenant_id
      - - plan_id
        - subscription_plan_id
```

Use explicit `and:` / `or:` for grouped conditions:

```yaml
joins:
  - name: subscriptions
    type: one_to_many
    on:
      or:
        - user_id
        - legacy_id
```

{% hint style="info" %}
`on` never combines `and` and `or` on the same node, and an empty `and:`/`or:` list is rejected. **AND** tightens the match (every leaf must agree). **OR** widens it (any leaf is enough, so watch for fan-out). Downstream code always reads the compiled `expression`; Vulcan does not reconstruct `on` from a hand-written `expression`.
{% endhint %}

Every dimension named in `on` must already be declared on both sides of the join: the source-side dimension must exist on the declaring semantic model, and the target-side dimension must exist on the semantic model named by `name`. A dimension unknown on either side fails validation with the offending column and model named.

### `expression`

A raw SQL join predicate referencing both sides as `{model_a.column} = {model_b.column}`. Use this escape hatch for casts, functions, non-equality comparisons, literals, or joins that don't fit the `on` tree shape. Set exactly one of `on` or `expression`.

```yaml
joins:
  - name: subscriptions
    type: one_to_many
    expression: "{subscriptions.user_id} = {users.user_id}"
```

When you author `on` instead, Vulcan compiles it into `expression` for you, and `expression` is always populated after load. Vulcan never reconstructs `on` from a hand-written `expression`, so downstream tooling should read `expression`.

A hand-written `expression` is parsed and checked the same way `on` is: every qualified reference in it must use only the declaring model's name or the join target's name as its table, and each referenced column must be a declared dimension on that respective model.

### `ai_context`

Structured hints for AI/LLM consumers on this join: `instructions`, `synonyms`, `caveats`, and worked `examples`. See [AI context](ai-context.md) for the full field reference.

```yaml
joins:
  - name: usage_events
    type: one_to_many
    expression: "{users.user_id} = {usage_events.user_id}"
    ai_context:
      instructions: Join to usage_events for product engagement and DAU.
      synonyms:
        - usage join
```

### `fqn`

The fully qualified name of the join target semantic model. Engine-set; not meant to be authored by hand in YAML.

***

## Setting a primary key

Vulcan does not use a per-dimension `primary_key` flag. Instead, the primary key is declared once, on the underlying **physical** Vulcan model, via its `grains (...)` property. Each grain column is automatically injected into the semantic model as an implicit dimension (with an `identifier`-style role, deduped against any dimension you declare explicitly by the same name). If no measure named `count` is declared, Vulcan also injects an implicit `count` measure. Joins rely on these grain-backed dimensions to resolve cardinality correctly, so there is nothing further to declare on the semantic model itself.

```
MODEL (
  name customer.users,
  kind FULL,
  grains [user_id, email],
  ...
);
```

The physical model backing a semantic model must define `grains`; a missing `grains` property is always flagged. If the semantic model also declares `joins`, that missing-grains condition is flagged a second time as specifically breaking the joins, since a join needs a grained physical base to resolve cardinality. Declare `grains` on the physical model before adding `joins` to its semantic layer.

***

## Reciprocal joins and cycles

By default, a project rejects **reciprocal** join pairs: semantic model `A` declaring a join to `B` while `B` also declares a join back to `A`. Pick one direction and let the other model reach its counterpart through the join graph instead of redeclaring the edge:

```yaml
# users.yml
joins:
  # Reciprocal join disabled by default; subscriptions already joins users.
  # - name: subscriptions
  #   type: one_to_many
  #   on: user_id
```

To allow both directions between the same pair of models, set `allow_reciprocal_joins: true` in the project's `config.yaml`:

```yaml
# config.yaml
allow_reciprocal_joins: true
```

Longer directed cycles (three or more models chained back to the starting model, for example `A → B → C → A`) are always rejected, regardless of `allow_reciprocal_joins`.

***

## Validation

Vulcan validates join definitions during `vulcan plan`. It checks that:

* `name` matches another declared semantic model, differs from the declaring model's own name, and resolves to a linked physical model
* `type` is required and is one of `one_to_one`, `one_to_many`, or `many_to_one`. `many_to_many` is rejected outright
* Exactly one of `on` or `expression` is set
* An `on` tree never mixes `and` and `or` on the same node, and no `and:`/`or:` list is empty
* Every dimension referenced by `on` or `expression`, on either side, is declared on the corresponding semantic model
* The physical model behind a joined semantic model defines `grains`
* Reciprocal join pairs between two models are rejected unless the project sets `allow_reciprocal_joins: true`
* Longer directed cycles are rejected regardless of `allow_reciprocal_joins`
* Joins do not declare `description`, `tags`, `terms`, or `public`. Metadata belongs on the dimensions, measures, and segments the join makes reachable, not on the join itself

## Related pages

* [Semantic models](README.md) for how a join fits into the full spec
* [Dimensions](dimensions.md) for the grain and identifier fields joins resolve cardinality against
* [Business metrics](../business-metrics.md) for how metrics reach across joined models
