---
description: >-
  The plugins/ folder auth extension: configuring the after_authorize hook,
  AuthExtensionContext and SecurityContext, the resolve_user_groups example, and
  how policies use resolved groups and claims.
---

# Plugins and auth

This guide explains the `plugins/` folder used by Vulcan data products, what the auth extension imports contain, and how Vulcan uses the extension for access policies.

## What is the `plugins/` folder?

The `plugins/` folder is where a data product defines small Python extension hooks that Vulcan loads at runtime.

The main use case is auth enrichment. After DataOS authorizes a request, Vulcan calls the configured auth extension function to convert DataOS user tags, headers, or other request context into policy groups and claims.

Policies then use the returned security context to decide:

* Which rows a user can access.
* Which columns to mask.
* Which group-specific rules apply.

## Required files

Create these files in the data product project:

```
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

* `plugins` is the Python package.
* `auth_ext` is the Python module.
* `resolve_user_groups` is the function Vulcan calls.

## Import library

The auth extension imports these types:

```python
from schema.auth import AuthExtensionContext, SecurityContext
```

`AuthExtensionContext` is the input object passed to the hook. It contains authorization information returned after DataOS processes the request.

In the example below, the hook reads:

```python
ctx.user_tags
```

`ctx.user_tags` contains DataOS role tags such as:

```
roles:id:operator
roles:id:developer
```

`SecurityContext` is the output object returned by the hook. Vulcan uses it while evaluating access policy files.

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
    Derive policy groups from DataOS role tags.

    Args:
        ctx: Authorization extension context returned after DataOS authorization.

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

The hook treats only tags that start with this prefix as policy roles.

This block extracts the role names:

```python
groups = [
    tag.replace(ROLE_ID_TAG_PREFIX, "", 1)
    for tag in ctx.user_tags
    if tag.startswith(ROLE_ID_TAG_PREFIX)
]
```

For example:

```
roles:id:operator -> operator
roles:id:developer -> developer
```

`POLICY_GROUP_PRIORITY` decides which group becomes the primary group when a user has multiple roles:

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

If the user has both `operator` and `developer`, the hook selects `operator` first because it appears first in `POLICY_GROUP_PRIORITY`.

Finally, the hook returns the security context:

```python
return SecurityContext(group=group, groups=GROUP_DELIMITER.join(groups))
```

## How policies use this context

Policy files use the returned `group` value. Additional `SecurityContext` fields can be referenced by row filters with `{securityContext.<key>}` placeholders.

Example:

```yaml
type: policy
name: customer_profile_access
depends_on:
  - silver.dim_customer_profile

rules:
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

* A user with `group="developer"` gets full access.
* A user with `group="operator"` can query the model, but `email` and `customer_name` are masked.
* A user with `group="operator"` cannot see rows where `customer_segment = Churned`.

For policy file syntax, row filters, and physical-model `column_mask_expressions`, see [Policies](policies.md).
