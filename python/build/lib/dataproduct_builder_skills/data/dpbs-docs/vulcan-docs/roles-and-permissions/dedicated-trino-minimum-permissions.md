---
description: >-
  Permission model for a DataOS-managed Dedicated Trino deployment, where
  access control lives on each depot's underlying data source instead of
  Trino SQL grants.
---

# Dedicated Trino

Dedicated Trino is the Trino deployment that DataOS (poros) provisions automatically for a Vulcan domain resource when its manifest includes a `spec.trino:` block. This document defines the permission model for Dedicated Trino, where access control lives entirely at the underlying data source level instead of through Trino SQL grants.

{% hint style="info" %}
If Vulcan connects to an existing, externally hosted Trino cluster instead, see [External Trino](external-trino-minimum-permissions.md). That setup requires SQL grants on the external Trino connection user.
{% endhint %}

## How Dedicated Trino works

When `spec.trino:` is present in the domain resource, poros:

1. Deploys a Trino coordinator as a Kubernetes service (`<name>-trino`) and a worker deployment (`<name>-trino-workers`, default 2 replicas).
2. Reads each depot listed in `spec.depots` and generates a Trino catalog `.properties` file from the depot definition and its DataOS secrets.
3. Sets Vulcan's gateway connection to the internal coordinator service with `method: no-auth` and `DATAOS_VULCAN_MANAGED_TRINO: "true"`.
4. Runs a `trino-ready` init container that polls until the coordinator is active and all expected workers have joined.

There are no Trino SQL grants to configure. The Vulcan process connects to Trino over the internal Kubernetes network without authentication. Access control is entirely at the underlying data source level, through the credentials embedded in each DataOS depot secret.

## Permission model

For each depot, the credentials in the depot secret become connector-level properties in the generated `.properties` file. Whatever the credential user is permitted to do on the underlying system is what Trino can do through that catalog.

The permissions required per depot type mirror those documented in the engine-specific permission guides:

| Depot type   | Trino connector  | Credential secret fields               | Permission guide                                                    |
| ------------ | ---------------- | -------------------------------------- | ------------------------------------------------------------------- |
| `lakehouse`  | `iceberg` (REST) | `lh_access_token`, storage credentials | This document (DataOS-specific)                                     |
| `postgres`   | `postgresql`     | `username`, `password`                 | [PostgreSQL minimum permissions](postgres-minimum-permissions.md)   |
| `snowflake`  | `snowflake`      | `username`, `password` (or key auth)   | [Snowflake minimum permissions](snowflake-minimum-permissions.md)   |
| `bigquery`   | `bigquery`       | `gcp_json_key`                         | Governed by IAM roles on the service account in the depot secret    |
| `databricks` | `delta_lake`     | `token`                                | [Databricks minimum permissions](databricks-minimum-permissions.md) |
| `delta_lake` | `delta_lake`     | `aws_access_key`, `aws_secret_key`     | AWS IAM (S3 + Glue/Hive Metastore)                                  |

## DataOS Lakehouse depot (Iceberg REST catalog)

The Lakehouse depot is the only depot type that is DataOS-native and has no external permission guide. The access model is described here.

### How poros configures the Iceberg catalog

Poros generates a `.properties` file like this:

```properties
connector.name=iceberg
iceberg.catalog.type=rest
iceberg.file-format=PARQUET
iceberg.rest-catalog.uri=<lakehouse_catalog_uri>
iceberg.rest-catalog.security=OAUTH2
iceberg.rest-catalog.oauth2.token=<lh_access_token>
iceberg.rest-catalog.warehouse=<warehouse>

# For S3 storage:
fs.native-s3.enabled=true
s3.region=<region>
s3.aws-access-key=<aws_access_key>
s3.aws-secret-key=<aws_secret_key>

# For GCS storage:
fs.native-gcs.enabled=true
gcs.json-key-file-path=/usr/trino/etc/catalog/<depot>_gcp_keyfile.json

# For ADLS (Azure) storage:
fs.native-azure.enabled=true
azure.auth-type=ACCESS_KEY
azure.access-key=<az_account_key>
```

All values come from the depot spec and depot secret. No manual configuration is required.

### Depot secret fields

The Lakehouse depot secret must contain:

| Secret field      | Description                                                                                               |
| ----------------- | --------------------------------------------------------------------------------------------------------- |
| `lh_access_token` | DataOS API key used to authenticate with the Iceberg REST catalog. This is the primary access credential. |
| `aws_access_key`  | AWS access key ID (S3-backed lakehouse only)                                                              |
| `aws_secret_key`  | AWS secret access key (S3-backed lakehouse only)                                                          |
| `gcp_json_key`    | Base64-encoded GCP service account JSON key (GCS-backed lakehouse only)                                   |
| `az_account_name` | Azure storage account name (ADLS-backed lakehouse only)                                                   |
| `az_account_key`  | Azure storage account access key (ADLS-backed lakehouse only)                                             |

### What the lh_access_token user needs in DataOS

The `lh_access_token` is a DataOS API key. Access to namespaces and tables within the Iceberg REST catalog is governed by DataOS policies, not SQL grants.

The API key holder must have:

| DataOS permission                         | Required for                                                   |
| -------------------------------------------------- | -------------------------------------------------------------- |
| Read access on the source namespace(s)             | `SELECT` on source tables                                      |
| Read + Write access on the Vulcan target namespace | Creating tables, views, writing data                           |
| Read + Write access on the state namespace         | Vulcan internal metadata (`_snapshots`, `_environments`, etc.) |

{% hint style="warning" %}
DataOS policy configuration is managed by the DataOS administrator and is outside the scope of this document.
{% endhint %}

### What the storage credentials need (S3 example)

For S3-backed lakehouse, the IAM user or role identified by `aws_access_key` / `aws_secret_key` needs:

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject",
    "s3:ListBucket",
    "s3:GetBucketLocation"
  ],
  "Resource": [
    "arn:aws:s3:::<LAKEHOUSE_BUCKET>",
    "arn:aws:s3:::<LAKEHOUSE_BUCKET>/*"
  ]
}
```

For read-only (semantic-only) access on source namespaces, `s3:GetObject` and `s3:ListBucket` are sufficient.

## PostgreSQL depot

Poros generates:

```properties
connector.name=postgresql
connection-url=jdbc:postgresql://<host>:<port>/<database>
connection-user=<username>
connection-password=<password>
```

The `username` and `password` come from the depot secret. The permissions required on the PostgreSQL side are identical to those documented in [PostgreSQL minimum permissions](postgres-minimum-permissions.md). Apply the appropriate secret category (`postgres-semantic-readonly`, `postgres-single-db-full`, or `postgres-cross-db-full`) to the depot credential user on the PostgreSQL server.

## Snowflake depot

Poros generates a Snowflake JDBC connector catalog with credentials from the depot secret (`username` / `password` or key-pair authentication). The permissions required on the Snowflake side are identical to those documented in [Snowflake minimum permissions](snowflake-minimum-permissions.md). Apply the appropriate role and privilege set to the Snowflake user referenced in the depot secret.

{% hint style="warning" %}
**`role` now comes from the secret, not the depot spec**

The Snowflake `role` is read from the `role` key in the DataOS secret projection rather than the depot spec. If this catalog uses a custom Snowflake role, make sure the secret includes a `role` key.
{% endhint %}

## BigQuery depot

Poros generates:

```properties
connector.name=bigquery
bigquery.project-id=<project>
bigquery.credentials-file=/usr/trino/etc/catalog/<depot>_gcp_keyfile.json
```

The `gcp_json_key` from the depot secret is written as a JSON key file and mounted into the Trino container. BigQuery access is governed by IAM roles on the service account in the depot secret, not by Trino-level grants. The service account referenced in the JSON key must have `roles/bigquery.jobUser` at the project level and the appropriate `dataViewer` or `dataEditor` role on the relevant datasets.

## Databricks depot

Poros generates:

```properties
connector.name=delta_lake
databricks.server-hostname=<server_hostname>
databricks.http-path=<http_path>
databricks.access-token=<token>
```

The `token` comes from the depot secret. The permissions required on the Databricks Unity Catalog side are identical to those documented in [Databricks minimum permissions](databricks-minimum-permissions.md). The token's service principal must have the appropriate `USAGE`, `SELECT`, `CREATE`, `MODIFY`, and `DROP` grants on the relevant catalogs and schemas.

## Delta Lake depot (self-hosted)

Poros generates:

```properties
connector.name=delta_lake
hive.metastore.uri=<metastoreUri>   # or hive.metastore=glue for AWS Glue
fs.native-s3.enabled=true
s3.region=<region>
s3.aws-access-key=<aws_access_key>
s3.aws-secret-key=<aws_secret_key>
```

The AWS credentials come from the depot secret. The IAM user or role needs:

- S3 read/write on the Delta Lake bucket paths.
- If using AWS Glue as metastore: `glue:GetDatabase`, `glue:GetTable`, `glue:CreateTable`, `glue:UpdateTable`, and `glue:DeleteTable` on the relevant databases.
- If using a Hive Metastore: the Thrift endpoint must be reachable from the Trino worker pods with no additional authentication, or with credentials configured through `overideCatalogConfig`.

## Domain resource example

```yaml
version: v1
name: my-vulcan-app
type: domain
spec:
  engine: trino
  compute: runnable-default
  depots:
    - dataos://my-lakehouse-depot?purpose=rw
    - dataos://my-postgres-depot?purpose=rw
  trino:
    coordinator:
      resource:
        request:
          cpu: "1000m"
          memory: "2Gi"
    workers:
      replicas: 2
      resource:
        request:
          cpu: "2000m"
          memory: "4Gi"
  repo:
    url: https://github.com/my-org/my-vulcan-project
  api:
    replicas: 1
  workflow:
    ...
```

When poros processes this manifest, it creates:

- A `<name>-trino` coordinator service on port 8080.
- A `<name>-trino-workers` deployment with 2 replicas.
- One catalog `.properties` file per depot: `my-lakehouse-depot.properties` and `my-postgres-depot.properties`.
- `VULCAN__GATEWAYS__DEFAULT__CONNECTION__HOST: <name>-trino` (no authentication).

## Overriding connector properties

Use `spec.trino.overideCatalogConfig` to add or override properties in a generated catalog file, for example to set a session property or tune connection-pool settings:

```yaml
spec:
  trino:
    overideCatalogConfig:
      - name: my-postgres-depot
        properties:
          connection-pool.max-size: "10"
          postgresql.include-system-tables: "true"
```

The `name` field must match the depot name, not the full `dataos://...` reference. Properties listed here are appended after the auto-generated connector properties.

## Custom catalog secrets (full catalog config files)

To register a Trino catalog that is not backed by a DataOS depot, for example a custom connector or a catalog with complex configuration, use `spec.trino.catalog.config`:

```yaml
spec:
  trino:
    catalog:
      config:
        - "<tenant>:<secret-name>"
```

Each secret listed here is projected into `/etc/dataos/trino-catalog/` and mounted as a full `.properties` file. The file name is the secret name (the last segment after `:`). The secret must contain a key named after the catalog (for example, `my-custom-catalog`) whose value is the full Trino catalog `.properties` content.

## Notes

- Vulcan always runs in `DEV_ONLY` mode for Dedicated Trino; `vde: true` is blocked. Physical tables use a `__novde` suffix, and a virtual layer view maps the original model name to that table.
- Poros sets `DATAOS_VULCAN_MANAGED_TRINO: "true"` automatically when `spec.trino:` is present. This enables the `trino-ready` init container, which polls the coordinator until it is active and all expected workers have joined. The expected worker count comes from `spec.trino.workers.replicas` (default: 2).
- The Trino cluster is co-located in the same Kubernetes namespace as the Vulcan API and workflow pods. All coordinator-to-worker and Vulcan-to-coordinator communication is over internal cluster DNS (`<name>-trino.<namespace>.svc.cluster.local`). No external network rules or firewall openings are needed for internal Trino traffic.
- The coordinator service and worker deployment names are deterministic: `<domain-resource-name>-trino` and `<domain-resource-name>-trino-workers`. Ensure these names do not conflict with existing Kubernetes services in the target namespace.

## Related resources

| Resource                                                                    | Relationship                                                                                                  |
| --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| [External Trino minimum permissions](external-trino-minimum-permissions.md) | Permission model for Vulcan domains that connect to a client-managed Trino cluster instead of Dedicated Trino |
| [PostgreSQL minimum permissions](postgres-minimum-permissions.md)           | Permissions for the `postgres` depot type                                                                     |
| [Snowflake minimum permissions](snowflake-minimum-permissions.md)           | Permissions for the `snowflake` depot type                                                                    |
| [Databricks minimum permissions](databricks-minimum-permissions.md)         | Permissions for the `databricks` depot type                                                                   |
