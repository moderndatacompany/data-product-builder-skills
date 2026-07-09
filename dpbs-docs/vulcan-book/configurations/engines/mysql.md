---
hidden: true
---

# MySQL

MySQL is an open-source relational database used for web applications, content management systems, and data warehousing. Vulcan integrates with MySQL to manage your data transformations with version control and safe deployments.

## Local or built-in scheduler

**Engine adapter type**: `mysql`

### Prerequisites

1. A MySQL server instance (version 5.7 or higher recommended)
2. A database user with appropriate permissions
3. Network connectivity to the MySQL server

### Permissions

Vulcan requires the following MySQL permissions:

* `CREATE` on the target database for creating schemas and tables
* `SELECT`, `INSERT`, `UPDATE`, `DELETE` on tables
* `ALTER` for schema modifications
* `DROP` for table cleanup during development

### Connection options

All the connection parameters you can use when setting up a MySQL gateway:

| Option     | Description                                               |  Type  | Required |
| ---------- | --------------------------------------------------------- | :----: | :------: |
| `type`     | Engine type name. Must be `mysql`                         | string |     Y    |
| `host`     | The hostname or IP address of the MySQL server            | string |     Y    |
| `port`     | The port number of the MySQL server (default: `3306`)     |   int  |     Y    |
| `user`     | The username for MySQL authentication                     | string |     Y    |
| `password` | The password for MySQL authentication                     | string |     Y    |
| `database` | The name of the database to connect to                    | string |     Y    |
| `charset`  | The character set for the connection (default: `utf8mb4`) | string |     N    |
| `ssl`      | SSL configuration options for secure connections          |  dict  |     N    |

### Authentication methods

* Username/password authentication (required).
* SSL configuration (optional): use the `ssl` option for secure connections in production environments.

### Docker images

The following Docker images are available for running Vulcan with MySQL:

| Image                           | Description                       |
| ------------------------------- | --------------------------------- |
| `tmdcio/vulcan-mysql:0.228.1.6` | Main Vulcan API service for MySQL |

Pull the images:

```bash
docker pull tmdcio/vulcan-mysql:0.228.1.6
```

### Materialization strategy

Materialization strategies for MySQL depend on the model kind and engine capabilities. For details on how different model kinds are materialized, see the [model kinds documentation](../../components/model/model_kinds.md).

**Learn more about materialization strategies:**

* [INCREMENTAL\_BY\_TIME\_RANGE](../../components/model/model_kinds.md#materialization-strategy)
* [INCREMENTAL\_BY\_UNIQUE\_KEY](../../components/model/model_kinds.md#materialization-strategy_1)
* [INCREMENTAL\_BY\_PARTITION](../../components/model/model_kinds.md#materialization-strategy_3)
* [FULL](../../components/model/model_kinds.md#materialization-strategy_2)

{% hint style="info" %}
Use MySQL 5.7 or higher. Use the `ssl` option for secure connections in production environments.
{% endhint %}

{% hint style="warning" %}
Always use environment variables for passwords: `password: {{ env_var('MYSQL_PASSWORD') }}`
{% endhint %}
