# Advance Features

Advanced features help you extend Vulcan beyond standard model definitions.

Use them when built-in behavior is close, but not enough.

## What this section covers

Use this section when you need to:

* make SQL more dynamic with macros
* delay model execution until external conditions are ready
* control how models materialize in the warehouse

## Quick selection guide

Start with **Macros** when you want reusable SQL patterns.

Use **Signals** when schedule timing depends on data readiness.

Use **Custom materializations** when built-in model kinds do not fit.

{% hint style="warning" %}
These features add flexibility, but they also add maintenance overhead. Use them only when the standard workflow is not enough.
{% endhint %}

## Choose a feature

<table data-view="cards"><thead><tr><th></th><th data-card-target data-type="content-ref"></th></tr></thead><tbody><tr><td><strong>Macros</strong><br>Use variables, built-ins, and templating to generate reusable SQL.</td><td><a href="macros/">macros</a></td></tr><tr><td><strong>Signals</strong><br>Add custom readiness checks before scheduled models run.</td><td><a href="signals.md">signals.md</a></td></tr><tr><td><strong>Custom materializations</strong><br>Define custom insert and lifecycle behavior for special execution patterns.</td><td><a href="custom_materializations.md">custom_materializations.md</a></td></tr></tbody></table>

## When to use each feature

### Use macros when

* SQL repeats across multiple models
* values depend on execution context
* templating keeps logic clearer than copy-paste

### Use signals when

* upstream data arrives late or irregularly
* schedules alone are not enough
* model execution must wait for custom checks

### Use custom materializations when

* built-in kinds cannot express the write behavior
* the engine needs custom DDL or DML logic
* you are prepared to maintain Python extension code

## Best practices

Prefer built-in model kinds and scheduling first.

Keep macros small, predictable, and easy to test.

Use signals and custom materializations only for clear operational needs.
