# Linter

Linting checks your model definitions against your team's best practices and catches common mistakes before they cause problems.

When you create a Vulcan plan, each model's code is checked against the linting rules you have configured. If any rules are violated, Vulcan tells you so you can fix the issues before deploying.

Vulcan includes built-in rules that catch common SQL mistakes and enforce good practices. You can also write custom rules that match your team's specific requirements. This maintains code quality and catches issues early, when they are easier to fix.

## Rules

Linting rules are pattern detectors. Each rule looks for a specific pattern (or lack of a pattern) in your model code.

Some rules check that a pattern is not present, such as the `NoSelectStar` rule that prevents `SELECT *` in your outermost query. Other rules check that a pattern is present, such as making sure every model has an `owner` field specified. Both types keep your code consistent and maintainable.

Rules are written in Python. Each rule is a Python class that inherits from Vulcan's `Rule` base class. You define the logic for detecting the pattern, and Vulcan handles the rest.

When you create a custom rule, implement four things:

1. Name: the class name becomes the rule's name (converted to lowercase with underscores).
2. Description: a docstring that explains what the rule checks and why it matters.
3. Pattern validation logic: the `check_model()` method that checks your model code. You can access any attribute of the `Model` object.
4. Rule violation logic: if the pattern is not valid, return a `RuleViolation` object with a message that tells the user what is wrong and how to fix it.

```python
# Class name used as rule's name
class Rule:
    # Docstring provides rule's description
    """The base class for a rule."""

    # Pattern validation logic goes in `check_model()` method
    @abc.abstractmethod
    def check_model(self, model: Model) -> t.Optional[RuleViolation]:
        """The evaluation function that checks for a violation of this rule."""

    # Rule violation object returned by `violation()` method
    def violation(self, violation_msg: t.Optional[str] = None) -> RuleViolation:
        """Return a RuleViolation instance if this rule is violated"""
        return RuleViolation(rule=self, violation_msg=violation_msg or self.summary)
```

### Built-in rules

Vulcan includes built-in rules that catch common SQL mistakes and enforce good coding practices. These rules catch real issues seen in production.

For example, the `NoSelectStar` rule prevents using `SELECT *` in your outermost query. `SELECT *` makes it unclear what columns your model produces, which can break downstream models and make debugging harder.

The `NoSelectStar` rule looks like this, with annotations showing how it is structured:

```python
# Rule's name is the class name `NoSelectStar`
class NoSelectStar(Rule):
    # Docstring explaining rule
    """Query should not contain SELECT * on its outer most projections, even if it can be expanded."""

    def check_model(self, model: Model) -> t.Optional[RuleViolation]:
        # If this model does not contain a SQL query, there is nothing to validate
        if not isinstance(model, SqlModel):
            return None

        # Use the query's `is_star` property to detect the `SELECT *` pattern.
        # If present, call the `violation()` method to return a `RuleViolation` object.
        return self.violation() if model.query.is_star else None
```

All of Vulcan's built-in linting rules:

| Name                         | Check type  | Explanation                                                                                                             |
| ---------------------------- | ----------- | ----------------------------------------------------------------------------------------------------------------------- |
| `ambiguousorinvalidcolumn`   | Correctness | Vulcan found duplicate columns or was unable to determine whether a column is duplicated or not                         |
| `invalidselectstarexpansion` | Correctness | The query's top-level selection may be `SELECT *`, but only if Vulcan can expand the `SELECT *` into individual columns |
| `noselectstar`               | Stylistic   | The query's top-level selection may not be `SELECT *`, even if Vulcan can expand the `SELECT *` into individual columns |
| `nomissingaudits`            | Governance  | Vulcan did not find any `audits` in the model's configuration to test data quality.                                     |

### User-defined rules

Built-in rules are useful, but every team has different standards. Write custom rules that enforce your team's specific best practices.

For example, make sure every model has an `owner` field so you know who is responsible for it:

```python
import typing as t

from vulcan.core.linter.rule import Rule, RuleViolation
from vulcan.core.model import Model

class NoMissingOwner(Rule):
    """Model owner should always be specified."""

    def check_model(self, model: Model) -> t.Optional[RuleViolation]:
        # Rule violated if the model's owner field (`model.owner`) is not specified
        return self.violation() if not model.owner else None

```

Put your custom rules in the `linter/` directory of your project. Vulcan automatically finds and loads any classes that inherit from `Rule` in that directory.

Vulcan runs every configured rule automatically when:

* You create a plan with `vulcan plan`
* You run the `vulcan lint` command

If a model violates a rule, Vulcan stops and tells you which models have problems. In this example, `full_model.sql` is missing an owner, so the plan stops:

```bash
$ vulcan plan

Linter errors for .../models/full_model.sql:
 - nomissingowner: Model owner should always be specified.

Error: Linter detected errors in the code. Please fix them before proceeding.
```

You can also run linting on its own for faster iteration during development:

```bash
$ vulcan lint

Linter errors for .../models/full_model.sql:
 - nomissingowner: Model owner should always be specified.

Error: Linter detected errors in the code. Please fix them before proceeding.
```

Use `vulcan lint --help` for more information.

## Applying linting rules

Specify which linting rules a project should apply in the project's [configuration file](../README.md).

List which rules to run under the `linter` key. Globally turn linting on or off with the `enabled` key (defaults to `false`, so you need to turn it on).

{% hint style="warning" %}
Set `enabled: true`. Otherwise, Vulcan does not run any linting rules, even if you have specified them.
{% endhint %}

### Specific linting rules

Use a few specific rules. List them in the `rules` array. This example enables two built-in rules:

{% tabs %}
{% tab title="YAML" %}
```yaml
linter:
  enabled: true
  rules: ["ambiguousorinvalidcolumn", "invalidselectstarexpansion"]
```
{% endtab %}

{% tab title="Python" %}
```python
from vulcan.core.config import Config, LinterConfig

config = Config(
    linter=LinterConfig(
        enabled=True,
        rules=["ambiguousorinvalidcolumn", "invalidselectstarexpansion"]
    )
)
```
{% endtab %}
{% endtabs %}

### All linting rules

Turn on all rules with `"ALL"` instead of listing them individually. This runs every built-in rule plus any custom rules you have defined:

{% tabs %}
{% tab title="YAML" %}
```yaml
linter:
  enabled: True
  rules: "ALL"
```
{% endtab %}

{% tab title="Python" %}
```python
from vulcan.core.config import Config, LinterConfig

config = Config(
    linter=LinterConfig(
        enabled=True,
        rules="all",
    )
)
```
{% endtab %}
{% endtabs %}

Sometimes you want almost everything, but one or two rules do not fit your workflow. Use `"ALL"` and exclude specific rules with `ignored_rules`:

{% tabs %}
{% tab title="YAML" %}
```yaml
linter:
  enabled: True
  rules: "ALL" # apply all built-in and user-defined rules and error if violated
  ignored_rules: ["noselectstar"] # but don't run the `noselectstar` rule
```
{% endtab %}

{% tab title="Python" %}
```python
from vulcan.core.config import Config, LinterConfig

config = Config(
    linter=LinterConfig(
        enabled=True,
        # apply all built-in and user-defined linting rules and error if violated
        rules="all",
         # but don't run the `noselectstar` rule
        ignored_rules=["noselectstar"]
    )
)
```
{% endtab %}
{% endtabs %}

### Exclude a model from linting

Sometimes a model legitimately needs to violate a rule, such as a legacy model you are migrating, or a special case. Exclude specific models from specific rules (or all rules) by adding `ignored_rules` to the model's `MODEL` block.

This example excludes one model from one rule:

```sql
MODEL(
  name docs_example.full_model,
  ignored_rules ["invalidselectstarexpansion"] # or "ALL" to turn off linting completely
);
```

### Rule violation behavior

By default, when a rule is violated, Vulcan treats it as an error and stops execution. This makes sure you fix issues before they reach production.

Sometimes you want a rule to be a suggestion rather than a hard requirement. For style preferences that are nice to have but not critical, put the rule in `warn_rules` instead of `rules`. Violations are still reported, but they do not stop execution:

{% tabs %}
{% tab title="YAML" %}
```yaml
linter:
  enabled: True
  # error if `ambiguousorinvalidcolumn` rule violated
  rules: ["ambiguousorinvalidcolumn"]
  # but only warn if "invalidselectstarexpansion" is violated
  warn_rules: ["invalidselectstarexpansion"]
```
{% endtab %}

{% tab title="Python" %}
```python
from vulcan.core.config import Config, LinterConfig

config = Config(
    linter=LinterConfig(
        enabled=True,
        # error if `ambiguousorinvalidcolumn` rule violated
        rules=["ambiguousorinvalidcolumn"],
        # but only warn if "invalidselectstarexpansion" is violated
        warn_rules=["invalidselectstarexpansion"],
    )
)
```
{% endtab %}
{% endtabs %}

Vulcan raises an error if the same rule appears in more than one of the `rules`, `warn_rules`, and `ignored_rules` keys, since they should be mutually exclusive.
