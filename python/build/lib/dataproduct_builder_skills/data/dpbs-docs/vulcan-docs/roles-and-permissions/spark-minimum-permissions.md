---
description: >-
  Minimum DataOS Lakehouse and object-storage permissions for running Vulcan
  on Spark, across both the DataOS and cloud IAM credential layers.
---

# Spark

This page covers the minimum permissions needed to run Vulcan with Spark in DataOS. DataOS Spark supports only the DataOS Lakehouse depot type: the Vulcan Spark stack (`vulcan+spark:1.0`) skips all other depot types when generating catalog configuration. Vulcan on DataOS Spark reads and writes exclusively to Iceberg tables on the DataOS Lakehouse, an Iceberg REST catalog backed by object storage (S3, GCS, or ADLS).

{% hint style="warning" %}
This deployment model does not support generic open-source Spark running against Hive Metastore, Apache Ranger, or AWS Lake Formation. It also does not support `vde: true`: Vulcan always runs in `DEV_ONLY` mode, using a `__novde` suffix on physical tables and a virtual layer view that maps the original model name to that table.
{% endhint %}

## How DataOS Spark works

When a Vulcan domain resource uses `engine: spark`, DataOS (poros) runs the project as a Kubernetes SparkApplication through the Spark Operator CRD. The driver runs as a Kubernetes pod under the runnable service account; executors run as additional pods in the same namespace.

For each `lakehouse` depot in `spec.depots`, poros generates a catalog configuration file at `/etc/dataos/secret/<catalog_name>_config.yaml` containing the Iceberg Spark catalog properties:

```yaml
spark.sql.extensions: "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions"
spark.sql.catalog.<catalog_name>: "org.apache.iceberg.spark.SparkCatalog"
spark.sql.catalog.<catalog_name>.catalog-impl: "org.apache.iceberg.rest.RESTCatalog"
spark.sql.catalog.<catalog_name>.uri: "<iceberg_rest_endpoint>"
spark.sql.catalog.<catalog_name>.header.apikey: "<lh_access_token>"
spark.sql.catalog.<catalog_name>.warehouse: "<warehouse>"

# For S3 storage:
spark.sql.catalog.<catalog_name>.io-impl: "org.apache.iceberg.aws.s3.S3FileIO"
spark.sql.catalog.<catalog_name>.s3.access-key-id: "<aws_access_key>"
spark.sql.catalog.<catalog_name>.s3.secret-access-key: "<aws_secret_key>"

# For GCS storage:
spark.sql.catalog.<catalog_name>.io-impl: "org.apache.iceberg.gcp.gcs.GCSFileIO"

# For ADLS storage:
spark.sql.catalog.<catalog_name>.io-impl: "org.apache.iceberg.azure.adlsv2.ADLSFileIO"
spark.sql.catalog.<catalog_name>.adls.auth.shared-key.account.name: "<az_account_name>"
spark.sql.catalog.<catalog_name>.adls.auth.shared-key.account.key: "<az_account_key>"
```

All values come from the depot spec and depot secret. No manual Spark configuration is required.

## Two credential layers

Every lakehouse depot has two distinct credential layers.

### Layer 1: Iceberg REST catalog access (`lh_access_token`)

The `lh_access_token` is a DataOS API key. It is sent as `header.apikey` on every Iceberg REST catalog request. The Iceberg REST server validates this key against DataOS policies to determine which namespaces and tables the holder can read or write.

### Layer 2: Object storage access (S3 / GCS / ADLS)

Iceberg uses the storage credentials to read and write Parquet data files and Iceberg metadata files directly to object storage. These credentials must have sufficient S3, GCS, or ADLS permissions on the lakehouse bucket.

## Depot secret fields

| Secret field      | Description                                                             |
| ----------------- | ----------------------------------------------------------------------- |
| `lh_access_token` | DataOS API key for Iceberg REST catalog authentication (required)       |
| `aws_access_key`  | AWS access key ID (S3-backed lakehouse only)                            |
| `aws_secret_key`  | AWS secret access key (S3-backed lakehouse only)                        |
| `gcp_json_key`    | Base64-encoded GCP service account JSON key (GCS-backed lakehouse only) |
| `az_account_name` | Azure storage account name (ADLS-backed lakehouse only)                 |
| `az_account_key`  | Azure storage account access key (ADLS-backed lakehouse only)           |

## What Vulcan does (Spark)

### Source namespaces (read-only)

| Operation                                             | Purpose                                             |
| ----------------------------------------------------- | --------------------------------------------------- |
| `SELECT`                                              | Reads Iceberg tables and views referenced by models |
| `SHOW TABLE EXTENDED IN <namespace> LIKE '<pattern>'` | Object introspection                                |

### Model target namespace (write)

| Operation                                      | Purpose                                          |
| ---------------------------------------------- | ------------------------------------------------ |
| `CREATE OR REPLACE TABLE AS SELECT`            | Full model refresh                               |
| `DROP TABLE`                                   | Cleanup during table replacement                 |
| `CREATE VIEW`, `DROP VIEW`                     | Semantic layer views and virtual layer promotion |
| `ALTER TABLE ... ALTER COLUMN ... COMMENT`     | Column comments                                  |
| `ALTER TABLE ... ADD COLUMNS` / `DROP COLUMNS` | Schema evolution                                 |
| `INSERT OVERWRITE`                             | Incremental partition overwrite                  |
| `DELETE FROM`                                  | Incremental deletes                              |
| `TRUNCATE TABLE`                               | Empties the table for full re-evaluation         |

### Iceberg WAP (optional)

When `wap_id` is configured on a model, Vulcan also issues:

- `ALTER TABLE ... CREATE BRANCH <name>`
- `CALL <catalog>.system.cherrypick_snapshot(...)`
- `ALTER TABLE ... DROP BRANCH <name>`

## secret_name: `spark-semantic-readonly`

Use this when Vulcan only exposes lakehouse tables through the semantic layer. No models execute. No objects are created or written.

### Layer 1: DataOS policy (DataOS API key user)

The `lh_access_token` user must have read access on the source namespace(s) in the DataOS Lakehouse. Contact your DataOS administrator to grant a read-only DataOS policy on the relevant namespace.

### Layer 2: Object storage (S3 example)

```json
{
  "Effect": "Allow",
  "Action": ["s3:GetObject", "s3:ListBucket"],
  "Resource": [
    "arn:aws:s3:::<LAKEHOUSE_BUCKET>",
    "arn:aws:s3:::<LAKEHOUSE_BUCKET>/<SOURCE_NAMESPACE>/*"
  ]
}
```

**What works:** Semantic queries over external models.
**What is blocked:** Vulcan cannot create, alter, or write any Iceberg object.

## secret_name: `spark-single-catalog-full`

Use this when the source namespace and Vulcan's target namespace are in the same lakehouse catalog. Covers all Vulcan model kinds (FULL, INCREMENTAL_BY_TIME_RANGE, SCD_TYPE_2, SEED, VIEW), plus semantic layer exposure.

### Layer 1: DataOS policy

| Namespace                                                                                         | Access needed |
| ------------------------------------------------------------------------------------------------- | ------------- |
| Source namespace(s)                                                                               | Read          |
| Vulcan target namespace (where models are written)                                                | Read + Write  |
| State namespace (same as target namespace by default; apply separately if `state_schema` differs) | Read + Write  |

Contact your DataOS administrator to grant the appropriate DataOS policies.

{% hint style="info" %}
If models read from more than one source namespace, apply the same read-access grant for each additional namespace.
{% endhint %}

### Layer 2: Object storage (S3 example)

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

For read-only access on the source namespace, `s3:GetObject` and `s3:ListBucket` scoped to the source prefix is sufficient. The target and state namespace paths need full read, write, and delete access.

### Layer 2: Object storage (GCS example)

The GCP service account in `gcp_json_key` needs:

| IAM role                     | Scope                                   |
| ---------------------------- | --------------------------------------- |
| `roles/storage.objectViewer` | Source namespace path                   |
| `roles/storage.objectAdmin`  | Vulcan target and state namespace paths |

### Layer 2: Object storage (ADLS example)

The Azure account key in `az_account_key` grants full access to the storage account. Scope the storage account to only the lakehouse container.

**What works:** All Vulcan model kinds, semantic layer, and state sync within a single lakehouse catalog.

## secret_name: `spark-cross-catalog-full`

Use this when Vulcan reads from one lakehouse depot and writes to another (different REST endpoint, warehouse, or access token). Each depot has its own `spec.depots` entry and its own set of depot secrets.

### Layer 1: DataOS policy

| Depot        | Credential        | Access needed                                          |
| ------------ | ----------------- | ------------------------------------------------------ |
| Source depot | `lh_access_token` | Read on the source namespace(s)                        |
| Target depot | `lh_access_token` | Read + Write on the Vulcan target and state namespaces |

If both source and target are in the same lakehouse but different namespaces, a single API key with the appropriate namespace policies across both can be used.

{% hint style="info" %}
If models read from more than one source namespace in the source depot, apply read access for each additional source namespace.
{% endhint %}

### Layer 2: Object storage

| Depot        | Storage access                                                   |
| ------------ | ---------------------------------------------------------------- |
| Source depot | Read-only on source namespace paths                              |
| Target depot | Full read, write, and delete on target and state namespace paths |

**What works:** All Vulcan model kinds, semantic layer, and state sync across multiple source namespaces into a dedicated target lakehouse.

## Notes

`vde: true` is blocked for Spark. Vulcan always runs in `DEV_ONLY` mode. Physical tables use a `__novde` suffix and a virtual layer view maps the original model name to that table.

`SUPPORTS_GRANTS = false`: Vulcan never issues SQL `GRANT` or `REVOKE` statements through Spark.

`CREATE OR REPLACE TABLE` is supported by the Iceberg Spark integration. Vulcan uses this for full model refresh rather than DROP + CREATE.

WAP (`ALTER TABLE ... CREATE BRANCH`) requires the `lh_access_token` user to have write (alter) access on the target Iceberg table in addition to standard write namespace access.

Global temp views (`createOrReplaceGlobalTempView`) are in-memory Spark session objects and do not require any DataOS or storage permission.

The Spark driver pod runs under the Kubernetes `runnable-default` service account. No special Kubernetes RBAC changes are needed, since the service account is managed by DataOS.

## Related resources

- [Dedicated Trino minimum permissions](dedicated-trino-minimum-permissions.md): covers the same DataOS Lakehouse Iceberg REST catalog depot through the Dedicated Trino engine, useful for comparison with the Spark catalog configuration described here.
