# Postgres

PostgreSQL is an open-source relational database that works with Vulcan. Use it for smaller projects, development environments, or when you want full control over your database infrastructure.

## Local or built-in scheduler

**Engine adapter type**: `postgres`

### Prerequisites

1. A PostgreSQL server instance (version 12 or higher recommended)
2. A database user with appropriate permissions
3. Network connectivity to the PostgreSQL server

### Permissions

Vulcan requires the following PostgreSQL permissions:

* `CREATE` on the target database for creating schemas
* `CREATE` on schemas for creating tables and views
* `SELECT`, `INSERT`, `UPDATE`, `DELETE` on tables
* `USAGE` on schemas

### Connection options

All the connection parameters you can use when setting up a PostgreSQL gateway:

| Option             | Description                                                                     |  Type  | Required |
| ------------------ | ------------------------------------------------------------------------------- | :----: | :------: |
| `type`             | Engine type name. Must be `postgres`                                            | string |     Y    |
| `host`             | The hostname of the Postgres server                                             | string |     Y    |
| `user`             | The username to use for authentication with the Postgres server                 | string |     Y    |
| `password`         | The password to use for authentication with the Postgres server                 | string |     Y    |
| `port`             | The port number of the Postgres server                                          |   int  |     Y    |
| `database`         | The name of the database instance to connect to                                 | string |     Y    |
| `keepalives_idle`  | The number of seconds between each keepalive packet sent to the server.         |   int  |     N    |
| `connect_timeout`  | The number of seconds to wait for the connection to the server. (Default: `10`) |   int  |     N    |
| `role`             | The role to use for authentication with the Postgres server                     | string |     N    |
| `sslmode`          | The security of the connection to the Postgres server                           | string |     N    |
| `application_name` | The name of the application to use for the connection                           | string |     N    |

### Authentication methods

* Username/password authentication (required).
* SSL mode configuration (optional): use `sslmode: require` for secure connections in production environments.

### Docker images

The following Docker images are available for running Vulcan with PostgreSQL:

| Image                               | Description                            |
| ----------------------------------- | -------------------------------------- |
| `tmdcio/vulcan-postgres:0.228.1.19` | Main Vulcan API service for PostgreSQL |

Pull the images:

```bash
docker pull tmdcio/vulcan-postgres:0.228.1.19
```

### Materialization strategy

PostgreSQL uses the following materialization strategies depending on the model kind:

| Model kind                  | Strategy                                | Description                                                                                                                                                                            |
| --------------------------- | --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `INCREMENTAL_BY_TIME_RANGE` | DELETE by time range, then INSERT       | Vulcan first deletes existing records within the target time range, then inserts the new data. This ensures data consistency and prevents duplicates when reprocessing time intervals. |
| `INCREMENTAL_BY_UNIQUE_KEY` | MERGE ON unique key                     | Vulcan uses PostgreSQL's MERGE (UPSERT) functionality to update existing records based on the unique key or insert new ones if they do not exist.                                       |
| `INCREMENTAL_BY_PARTITION`  | DELETE by partitioning key, then INSERT | Vulcan deletes existing records matching the partitioning key, then inserts the new data. This ensures partition-level consistency when reprocessing data.                              |
| `FULL`                      | DROP TABLE, CREATE TABLE, INSERT        | Vulcan drops the existing table, creates a new one, and inserts all data. This rebuilds the table from scratch each time.                                                              |

**Learn more about materialization strategies:**

* [INCREMENTAL\_BY\_TIME\_RANGE](../../components/model/model_kinds.md#materialization-strategy)
* [INCREMENTAL\_BY\_UNIQUE\_KEY](../../components/model/model_kinds.md#materialization-strategy_1)
* [INCREMENTAL\_BY\_PARTITION](../../components/model/model_kinds.md#materialization-strategy_3)
* [FULL](../../components/model/model_kinds.md#materialization-strategy_2)

{% hint style="info" %}
Use `sslmode: require` for secure connections in production environments.
{% endhint %}

{% hint style="warning" %}
Always use environment variables for passwords: `password: {{ env_var('POSTGRES_PASSWORD') }}`
{% endhint %}
