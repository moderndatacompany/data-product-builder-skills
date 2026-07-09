---
hidden: true
---

# Amazon Redshift

Amazon Redshift is a managed, petabyte-scale cloud data warehouse. It uses columnar storage and massively parallel processing (MPP) for query performance on analytics and BI workloads. Vulcan runs against Redshift to manage transformations with version control and gated deployments.

## Local or built-in scheduler

**Engine adapter type**: `redshift`

### Prerequisites

1. An Amazon Redshift cluster or Redshift Serverless endpoint
2. A database user with appropriate permissions
3. Network connectivity to the Redshift cluster (VPC configuration may be required)

### Permissions

Vulcan requires the following Redshift permissions:

* `CREATE` on the target database for creating schemas
* `CREATE` on schemas for creating tables and views
* `SELECT`, `INSERT`, `UPDATE`, `DELETE` on tables
* `USAGE` on schemas

### Connection options

All the connection parameters you can use when setting up a Redshift gateway:

| Option     | Description                                                         |  Type  | Required |
| ---------- | ------------------------------------------------------------------- | :----: | :------: |
| `type`     | Engine type name. Must be `redshift`                                | string |     Y    |
| `host`     | The Redshift cluster endpoint hostname                              | string |     Y    |
| `port`     | The port number of the Redshift cluster (default: `5439`)           |   int  |     Y    |
| `user`     | The username for Redshift authentication                            | string |     Y    |
| `password` | The password for Redshift authentication                            | string |     Y    |
| `database` | The name of the database to connect to                              | string |     Y    |
| `sslmode`  | SSL mode for the connection (`require`, `verify-ca`, `verify-full`) | string |     N    |
| `timeout`  | Connection timeout in seconds                                       |   int  |     N    |

### Authentication methods

* Username/password authentication (required).
* SSL mode configuration (optional): use `sslmode: require` or higher for secure connections in production environments.

### Docker images

The following Docker images are available for running Vulcan with Redshift:

| Image                              | Description                          |
| ---------------------------------- | ------------------------------------ |
| `tmdcio/vulcan-redshift:0.228.1.6` | Main Vulcan API service for Redshift |

Pull the images:

```bash
docker pull tmdcio/vulcan-redshift:0.228.1.6
```

### Materialization strategy

Redshift uses the following materialization strategies depending on the model kind:

| Model kind                  | Strategy                                | Description                                                                                                                                                                            |
| --------------------------- | --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `INCREMENTAL_BY_TIME_RANGE` | DELETE by time range, then INSERT       | Vulcan first deletes existing records within the target time range, then inserts the new data. This ensures data consistency and prevents duplicates when reprocessing time intervals. |
| `INCREMENTAL_BY_UNIQUE_KEY` | MERGE ON unique key                     | Vulcan uses Redshift's MERGE statement to update existing records based on the unique key or insert new ones if they do not exist.                                                     |
| `INCREMENTAL_BY_PARTITION`  | DELETE by partitioning key, then INSERT | Vulcan deletes existing records matching the partitioning key, then inserts the new data. This ensures partition-level consistency when reprocessing data.                              |
| `FULL`                      | DROP TABLE, CREATE TABLE, INSERT        | Vulcan drops the existing table, creates a new one, and inserts all data. This rebuilds the table from scratch each time.                                                              |

**Learn more about materialization strategies:**

* [INCREMENTAL\_BY\_TIME\_RANGE](../../components/model/model_kinds.md#materialization-strategy)
* [INCREMENTAL\_BY\_UNIQUE\_KEY](../../components/model/model_kinds.md#materialization-strategy_1)
* [INCREMENTAL\_BY\_PARTITION](../../components/model/model_kinds.md#materialization-strategy_3)
* [FULL](../../components/model/model_kinds.md#materialization-strategy_2)

{% hint style="info" %}
Use `sslmode: require` or higher for secure connections in production environments.
{% endhint %}

{% hint style="warning" %}
Always use environment variables for passwords: `password: {{ env_var('REDSHIFT_PASSWORD') }}`
{% endhint %}
