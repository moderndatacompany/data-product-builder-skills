# Snowflake

Snowflake is a cloud data warehouse with separated storage and compute. Vulcan runs against Snowflake to manage transformations with version control and gated deployments.

## Local or built-in scheduler

**Engine adapter type**: `snowflake`

### Prerequisites

1. A Snowflake account with valid credentials
2. A warehouse available for running computations

### Permissions

Vulcan requires the following Snowflake permissions:

* `USAGE` on a warehouse to execute computations
* `CREATE SCHEMA` on the target database
* `CREATE TABLE` and `CREATE VIEW` on schemas
* `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE` on tables

### Connection options

All the connection parameters you can use when setting up a Snowflake gateway:

| Option                   | Description                                                                |  Type  | Required |
| ------------------------ | -------------------------------------------------------------------------- | :----: | :------: |
| `type`                   | Engine type name. Must be `snowflake`                                      | string |     Y    |
| `account`                | The Snowflake account identifier (for example, `org-name-account-name`)    | string |     Y    |
| `user`                   | The username to use for authentication with the Snowflake server      | string |     Y    |
| `password`               | The password to use for authentication with the Snowflake server      | string |     Y    |
| `warehouse`              | The name of the Snowflake warehouse to use for running computations   | string |     Y    |
| `database`               | The name of the Snowflake database instance to connect to             | string |     Y    |
| `role`                   | The role to use for authentication with the Snowflake server          | string |     N    |
| `authenticator`          | The Snowflake authenticator method (for example, `externalbrowser`, `oauth`) | string |     N    |
| `token`                  | The Snowflake OAuth 2.0 access token for authentication               | string |     N    |
| `private_key_path`       | The path to the private key file to use for authentication            | string |     N    |
| `private_key_passphrase` | The passphrase to decrypt the private key (if encrypted)              | string |     N    |

### Authentication methods

* Username/password authentication (required).
* OAuth 2.0 token authentication (optional): use the `token` parameter.
* External browser authentication (optional): use `authenticator: externalbrowser`.
* Private key authentication (optional): use `private_key_path` and `private_key_passphrase`.
* Role-based authentication (optional): use the `role` parameter.

### Docker images

The following Docker images are available for running Vulcan with Snowflake:

| Image                                | Description                           |
| ------------------------------------ | ------------------------------------- |
| `tmdcio/vulcan-snowflake:0.228.1.19` | Main Vulcan API service for Snowflake |

Pull the images:

```bash
docker pull tmdcio/vulcan-snowflake:0.228.1.19
```

### Materialization strategy

Snowflake uses the following materialization strategies depending on the model kind:

| Model kind                  | Strategy                                | Description                                                                                                                                                                            |
| --------------------------- | --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `INCREMENTAL_BY_TIME_RANGE` | DELETE by time range, then INSERT       | Vulcan first deletes existing records within the target time range, then inserts the new data. This ensures data consistency and prevents duplicates when reprocessing time intervals. |
| `INCREMENTAL_BY_UNIQUE_KEY` | MERGE ON unique key                     | Vulcan uses Snowflake's MERGE statement to update existing records based on the unique key or insert new ones if they do not exist.                                                    |
| `INCREMENTAL_BY_PARTITION`  | DELETE by partitioning key, then INSERT | Vulcan deletes existing records matching the partitioning key, then inserts the new data. This ensures partition-level consistency when reprocessing data.                              |
| `FULL`                      | CREATE OR REPLACE TABLE                 | Vulcan uses Snowflake's `CREATE OR REPLACE TABLE` statement to rebuild the table from scratch each time.                                                                               |

**Learn more about materialization strategies:**

* [INCREMENTAL\_BY\_TIME\_RANGE](../../components/model/model_kinds.md#materialization-strategy)
* [INCREMENTAL\_BY\_UNIQUE\_KEY](../../components/model/model_kinds.md#materialization-strategy_1)
* [INCREMENTAL\_BY\_PARTITION](../../components/model/model_kinds.md#materialization-strategy_3)
* [FULL](../../components/model/model_kinds.md#materialization-strategy_2)

### Identifier casing in semantics

Snowflake stores unquoted identifiers in **uppercase** by default. When Snowflake is the engine behind your semantic layer, the warehouse only resolves column references that match its stored casing. Dimension lists, measure expressions, filters, and join clauses must all use uppercase column names.

```yaml
dimensions:
  - USER_ID
  - SIGNUP_DATE
  - PLAN_TYPE

measures:
  - name: active_users
    type: count
    filters:
      - "{users.STATUS} = 'active'"
```

Lowercase examples elsewhere in the docs assume a case-insensitive engine like Postgres or DuckDB. Always match the casing your warehouse uses.

See the [semantic models guide](../../components/model/types/models.md#dimensions) for the full tip and additional context.

{% hint style="info" %}
The `account` identifier format is `<org-name>-<account-name>` (for example, `myorg-myaccount`). Find it in your Snowflake URL.
{% endhint %}

{% hint style="warning" %}
Always use environment variables for sensitive credentials: `password: {{ env_var('SNOWFLAKE_PASSWORD') }}`
{% endhint %}
