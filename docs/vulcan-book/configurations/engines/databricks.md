# Databricks

Databricks is an Apache Spark-based analytics platform with notebooks, managed clusters, and a SQL engine. Vulcan runs against Databricks to manage transformations using Unity Catalog and Delta Lake.

## Local or built-in scheduler

**Engine adapter type**: `databricks`

### Prerequisites

1. A Databricks workspace with SQL warehouse or cluster access
2. A personal access token or service principal credentials
3. The HTTP path to your SQL warehouse or cluster

### Permissions

Vulcan requires the following Databricks permissions:

* `USE CATALOG` on the target catalog
* `USE SCHEMA` and `CREATE SCHEMA` on the target schemas
* `CREATE TABLE` and `CREATE VIEW` on schemas
* `SELECT`, `INSERT`, `UPDATE`, `DELETE` on tables

### Connection options

All the connection parameters you can use when setting up a Databricks gateway:

| Option            | Description                                                                    |  Type  | Required |
| ----------------- | ------------------------------------------------------------------------------ | :----: | :------: |
| `type`            | Engine type name. Must be `databricks`                                         | string |     Y    |
| `server_hostname` | The Databricks workspace hostname (for example, `adb-xxxxx.azuredatabricks.net`) | string |     Y    |
| `http_path`       | The HTTP path to the SQL warehouse or cluster                                  | string |     Y    |
| `access_token`    | Personal access token or service principal token for authentication            | string |     Y    |
| `catalog`         | The Unity Catalog name to use as the default catalog                           | string |     Y    |

### Authentication methods

* Personal access token authentication (required): use the `access_token` parameter.
* Service principal token authentication (required): use the `access_token` parameter with a service principal token.

### Docker images

The following Docker images are available for running Vulcan with Databricks:

| Image                                 | Description                            |
| ------------------------------------- | -------------------------------------- |
| `tmdcio/vulcan-databricks:0.228.1.19` | Main Vulcan API service for Databricks |

Pull the images:

```bash
docker pull tmdcio/vulcan-databricks:0.228.1.19
```

### Materialization strategy

Databricks uses the following materialization strategies depending on the model kind:

| Model kind                  | Strategy                                  | Description                                                                                                                                                                                                                                                        |
| --------------------------- | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `INCREMENTAL_BY_TIME_RANGE` | INSERT OVERWRITE by time column partition | Vulcan overwrites the entire partition that corresponds to the time column, rather than deleting and inserting individual records. This is more efficient for partitioned data and uses Databricks' native partitioning capabilities with Delta Lake. |
| `INCREMENTAL_BY_UNIQUE_KEY` | MERGE ON unique key                       | Vulcan uses Databricks' MERGE statement (with Delta Lake) to update existing records based on the unique key or insert new ones if they do not exist. This provides ACID transactions and efficient upserts.                                                       |
| `INCREMENTAL_BY_PARTITION`  | REPLACE WHERE by partitioning key         | Vulcan uses Databricks' `REPLACE WHERE` clause to replace data within specific partitions based on the partitioning key, using Delta Lake's capabilities.                                                                                              |

\| `FULL` | INSERT OVERWRITE | Vulcan uses Databricks' `INSERT OVERWRITE` statement to replace the table contents each time. Compatible with Delta Lake. |

**Learn more about materialization strategies:**

* [INCREMENTAL\_BY\_TIME\_RANGE](../../components/model/model_kinds.md#materialization-strategy)
* [INCREMENTAL\_BY\_UNIQUE\_KEY](../../components/model/model_kinds.md#materialization-strategy_1)
* [INCREMENTAL\_BY\_PARTITION](../../components/model/model_kinds.md#materialization-strategy_3)
* [FULL](../../components/model/model_kinds.md#materialization-strategy_2)

{% hint style="info" %}
The `http_path` can be found in your Databricks workspace under **SQL Warehouses → \[Your Warehouse] → Connection Details**.
{% endhint %}

{% hint style="warning" %}
Never commit your access token to version control. Use environment variables: `access_token: {{ env_var('DATABRICKS_TOKEN') }}`
{% endhint %}
