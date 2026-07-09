# Plugins auth extension guide

This guide explains the `plugins/` folder used by Vulcan data products, what the auth extension imports contain, and how the extension is used for OSI GA policies and masking.

## What is the `plugins/` folder?

The `plugins/` folder is where a data product defines small Python extension hooks that Vulcan loads at runtime.

For OSI GA, the main use case is auth enrichment. After Heimdall authorizes a request, Vulcan can call a configured auth extension function to convert Heimdall user tags into policy groups.

Semantic model policies then use those policy groups to decide:

- Which rows a user can access.
- Which dimensions should be masked.
- Which group-specific rules should apply.

## Required files

Create these files in the data product project:

```text
plugins/
  __init__.py
  auth_ext.py
```

`plugins/__init__.py` marks the folder as a Python package. It can be empty, but it is required so Vulcan can import the hook path.

`plugins/auth_ext.py` contains the auth extension function.

## Configure the hook

In `config.yaml`, configure the hook using the root-level `after_authorize` field:

```yaml
after_authorize: "plugins.auth_ext:resolve_user_groups"
```

This path means:

- `plugins` is the Python package.
- `auth_ext` is the Python module.
- `resolve_user_groups` is the function Vulcan should call.

## Import library

The auth extension imports these types:

```python
from schema.auth import AuthExtensionContext, SecurityContext
```

`AuthExtensionContext` is the input object passed to the hook. It contains authorization information returned after Heimdall processes the request.

In the example below, the hook reads:

```python
ctx.user_tags
```

`ctx.user_tags` contains Heimdall role tags such as:

```text
roles:id:operator
roles:id:developer
```

`SecurityContext` is the output object returned by the hook. Vulcan uses it while evaluating policies in semantic model files.

Example return value:

```python
SecurityContext(
    group="operator",
    groups="operator,developer",
)
```

`group` is the primary group used for policy matching.

`groups` contains all resolved groups as a comma-separated string.

## Example: `plugins/auth_ext.py`

```python
from __future__ import annotations

from schema.auth import AuthExtensionContext, SecurityContext

ROLE_ID_TAG_PREFIX = "roles:id:"
GROUP_DELIMITER = ","
POLICY_GROUP_PRIORITY = ("operator", "developer")


async def resolve_user_groups(ctx: AuthExtensionContext) -> SecurityContext:
    """
    Derive policy groups from Heimdall role tags.

    Args:
        ctx: Authorization extension context returned after Heimdall authorization.

    Returns:
        Security context containing the primary group and all role groups.
    """

    groups = [
        tag.replace(ROLE_ID_TAG_PREFIX, "", 1)
        for tag in ctx.user_tags
        if tag.startswith(ROLE_ID_TAG_PREFIX)
    ]

    group = next(
        (policy_group for policy_group in POLICY_GROUP_PRIORITY if policy_group in groups),
        groups[0] if groups else "",
    )
    return SecurityContext(group=group, groups=GROUP_DELIMITER.join(groups))
```

## How the example works

The hook starts with the role tag prefix:

```python
ROLE_ID_TAG_PREFIX = "roles:id:"
```

Only tags that start with this prefix are treated as policy roles.

This block extracts the role names:

```python
groups = [
    tag.replace(ROLE_ID_TAG_PREFIX, "", 1)
    for tag in ctx.user_tags
    if tag.startswith(ROLE_ID_TAG_PREFIX)
]
```

For example:

```text
roles:id:operator -> operator
roles:id:developer -> developer
```

`POLICY_GROUP_PRIORITY` decides which group should become the primary group when a user has multiple roles:

```python
POLICY_GROUP_PRIORITY = ("operator", "developer")
```

This block picks the primary group:

```python
group = next(
    (policy_group for policy_group in POLICY_GROUP_PRIORITY if policy_group in groups),
    groups[0] if groups else "",
)
```

If the user has both `operator` and `developer`, `operator` is selected first because it appears first in `POLICY_GROUP_PRIORITY`.

Finally, the hook returns the security context:

```python
return SecurityContext(group=group, groups=GROUP_DELIMITER.join(groups))
```

## How policies use this context

Semantic model policies use the returned `group` value.

Example:

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

In this example:

- A user with `group="developer"` gets full access.
- A user with `group="operator"` can query the model, but `email` and `customer_name` are masked.
- A user with `group="operator"` cannot see rows where `customer_segment = Churned`.

## Masked dimensions

Columns listed in a policy `mask` should define a `mask_expression` in the semantic model dimensions.

Example:

```yaml
dimensions:
  - name: customer_name
    mask_expression: "CAST(NULL AS TEXT)"

  - name: email
    mask_expression: "CAST(NULL AS TEXT)"
```

Alternative redaction:

```yaml
dimensions:
  - name: email
    mask_expression: "'***'"
```

`mask_expression` controls what restricted users see instead of the raw value.


