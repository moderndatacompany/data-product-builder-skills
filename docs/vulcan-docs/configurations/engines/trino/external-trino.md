# External Trino

Use this path when Vulcan connects to an existing Trino-compatible endpoint. The Trino cluster is already running outside the Vulcan deployment.

External Trino includes:

* DataOS Minerva
* Starburst
* Self-hosted Trino
* Any hosted Trino-compatible endpoint

## Core settings

| Setting                 | Value                       |
| ----------------------- | --------------------------- |
| Gateway connection type | `trino`                     |
| Model dialect           | `trino`                     |
| VDE                     | `false`                     |
| Scheduler               | Local or built-in scheduler |

Do not set `vde: true` for Trino. Trino gateways must run in simple mode.

## Prerequisites

You need:

* Trino coordinator host and port.
* Trino username.
* Trino password, token, or API key.
* A target catalog, such as `s3depot`, `hive`, `iceberg`, or `delta`.
* Network access from Vulcan to the Trino coordinator.
* Permissions to create schemas, tables, and views in the target catalog.

## Connection options

Use these fields under `gateways.<name>.connection`.

| Option                    | Description                                                                                   | Required |
| ------------------------- | --------------------------------------------------------------------------------------------- | -------- |
| `type`                    | Engine type. Must be `trino`.                                                                 | Yes      |
| `host`                    | Trino coordinator host. Do not include `http://` or `https://`.                               | Yes      |
| `user`                    | Trino user. For Starburst Galaxy, this may include a role suffix.                             | Yes      |
| `catalog`                 | Default Trino catalog.                                                                        | Yes      |
| `port`                    | Trino coordinator port. Defaults depend on scheme; Minerva commonly uses `7432`.              | No       |
| `http_scheme`             | `http` or `https`. Use `https` in production.                                                 | No       |
| `method`                  | Auth method such as `basic`, `ldap`, `jwt`, `kerberos`, `certificate`, `oauth`, or `no-auth`. | No       |
| `password`                | Password or generated token for password-based auth.                                          | No       |
| `roles`                   | Catalog-to-role mapping for role-based access control.                                        | No       |
| `http_headers`            | Extra HTTP headers sent with each request.                                                    | No       |
| `session_properties`      | Trino session properties.                                                                     | No       |
| `retries`                 | Number of request retries.                                                                    | No       |
| `timezone`                | Connection timezone.                                                                          | No       |
| `schema_location_mapping` | Regex-to-location mapping for schema creation.                                                | No       |
| `catalog_type_overrides`  | Explicit connector type per catalog, for example `iceberg`, `hive`, or `delta_lake`.          | No       |

## Minimal config.yaml

```yaml
vde: false

gateways:
  default:
    connection:
      type: trino
      host: "{{ env_var('TRINO_HOST') }}"
      port: "{{ env_var('TRINO_PORT', '8080') }}"
      user: "{{ env_var('TRINO_USER') }}"
      catalog: "{{ env_var('TRINO_CATALOG') }}"
      http_scheme: "{{ env_var('TRINO_HTTP_SCHEME', 'https') }}"
      method: "{{ env_var('TRINO_METHOD', 'basic') }}"
      password: "{{ env_var('TRINO_PASSWORD') }}"
      verify: true

default_gateway: default

model_defaults:
  dialect: trino
  start: "2024-01-01"
```

## DataOS Minerva

Minerva is DataOS's Trino-based query cluster. From Vulcan's point of view, Minerva is a normal Trino endpoint, so the connection still uses `type: trino`.

### Minerva prerequisites

You need:

* A running Minerva cluster in your tenant.
* Minerva cluster name, for example `minervainfinity`.
* Minerva host, for example `tcp.<env-name>.dataos.cloud`.
* Minerva port, commonly `7432`.
* DataOS user id.
* DataOS API key.
* Tenant name.
* Catalog name, for example `s3depot`.
* A DataOS secret containing the user id and generated Minerva password.

### Check if the cluster exists

List Minerva resources:

```bash
dataos-ctl resource get -t minerva -a
```

Inspect one cluster:

```bash
dataos-ctl resource get -t minerva -n <minerva-cluster-name>
```

Use the cluster name in the Minerva password payload.

### Example Minerva resource

```yaml
version: v1alpha
type: minerva
name: ${MINERVA_CLUSTER_NAME}
tags:
  - minerva
spec:
  coordinator:
    replicas: 1
    envs:
      JVM__opts: "--add-opens=java.base/java.nio=ALL-UNNAMED"
    resources:
      requests:
        cpu: "1"
        memory: "1Gi"
      limits:
        cpu: "2"
        memory: "4Gi"
  worker:
    replicas: 2
    envs:
      # Add -Dnet.snowflake.jdbc.enableBouncyCastle=TRUE if a Snowflake depot is referenced.
      JVM__opts: "--add-opens=java.base/java.nio=ALL-UNNAMED"
    resources:
      requests:
        cpu: "1"
        memory: "1Gi"
      limits:
        cpu: "2"
        memory: "4Gi"
  compute: ${MINERVA_COMPUTE_NAME}
  depots:
    - address: "dataos://postgres?purpose=rw"
```

The `depots` list controls which DataOS depots the Minerva cluster can access.

### Generate the Minerva password

The Minerva password is a base64-encoded JSON object.

| Field     | Meaning                      |
| --------- | ---------------------------- |
| `cluster` | Minerva cluster name.        |
| `apikey`  | DataOS API key for the user. |
| `tenant`  | DataOS tenant name.          |

{% tabs %}
{% tab title="macOS or Linux" %}
```bash
echo -n '{"cluster":"<minerva-cluster-name>","apikey":"<dataos-api-key>","tenant":"<tenant-name>"}' | base64 | tr -d '\n'
```
{% endtab %}

{% tab title="Windows PowerShell" %}
```powershell
$json = '{"cluster":"<minerva-cluster-name>","apikey":"<dataos-api-key>","tenant":"<tenant-name>"}'
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
```
{% endtab %}
{% endtabs %}

Example:

```bash
echo -n '{"cluster":"minervainfinity","apikey":"abc123","tenant":"qa"}' | base64 | tr -d '\n'
```

Use the generated value as `PASSWORD` in the DataOS secret.

### Minerva secret

Store only authentication values in the secret:

```yaml
name: trino-connection-secret
version: v2alpha
type: secret
layer: user
secret:
  type: key-value
  data:
    USER_ID: "<dataos-user-id>"
    PASSWORD: "<base64-json-password>"
```

Apply it:

```bash
dataos-ctl resource apply -f trino-connection-secret.yaml
```

Verify it:

```bash
dataos-ctl resource get -t secret -n trino-connection-secret
```

### Map secret values into Vulcan

Project `USER_ID` and `PASSWORD` into the environment variables used by `config.yaml`:

```yaml
use:
  projection:
    secrets:
      - contextAlias: trn
        id: <tenant>:trino-connection-secret
    projections:
      envVars:
        - key: TRINO_USER
          template: "{{ secrets['trn'].USER_ID | base64_decode }}"
        - key: TRINO_PASSWORD
          template: "{{ secrets['trn'].PASSWORD | base64_decode }}"
```

### Minerva config.yaml

```yaml
vde: false

gateways:
  default:
    connection:
      type: trino
      host: "tcp.<env-name>.dataos.cloud"
      port: 7432
      user: "{{ env_var('TRINO_USER') }}"
      catalog: "s3depot"
      http_scheme: https
      method: basic
      password: "{{ env_var('TRINO_PASSWORD') }}"
      verify: true

default_gateway: default

model_defaults:
  dialect: trino
  start: "2024-01-01"
```

## Starburst

For Starburst, use the same external Trino pattern. Confirm whether the username needs a role suffix:

```yaml
user: "{{ env_var('STARBURST_USER') }}" # example: analyst@example.com/analyst
```

Starburst commonly uses:

```yaml
http_scheme: https
port: 443
method: basic
```

## Self-hosted Trino

For self-hosted Trino, confirm:

* Whether the endpoint uses `http` or `https`.
* Which authentication method is enabled.
* Which catalog should be used.
* Whether the catalog can infer table locations.

If the catalog cannot infer schema or table locations, configure `schema_location_mapping`:

```yaml
gateways:
  default:
    connection:
      type: trino
      host: "{{ env_var('TRINO_HOST') }}"
      user: "{{ env_var('TRINO_USER') }}"
      catalog: "{{ env_var('TRINO_CATALOG') }}"
      schema_location_mapping:
        ".*": "s3://warehouse/vulcan/@{schema_name}"
```

## Catalog and storage notes

Trino behavior depends on the catalog connector:

* Hive, Iceberg, and Delta Lake catalogs are common for Vulcan.
* Some catalogs infer table locations from a warehouse or schema location.
* If no default warehouse or schema location exists, use `schema_location_mapping`.
* Use `catalog_type_overrides` when Vulcan cannot reliably infer whether a catalog is `hive`, `iceberg`, or `delta_lake`.

Example:

```yaml
gateways:
  default:
    connection:
      type: trino
      catalog_type_overrides:
        datalake: iceberg
        analytics: hive
```

## Quick checklist

Before running `vulcan plan`, confirm:

* `vde: false` is set.
* `connection.type` is `trino`.
* `model_defaults.dialect` is `trino`.
* Trino host, port, user, catalog, and password/token are configured.
* The Trino user can create schemas, tables, and views in the target catalog.
* For Minerva, the DataOS secret is applied and projected into runtime environment variables.
