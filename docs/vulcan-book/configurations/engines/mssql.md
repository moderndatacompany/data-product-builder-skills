---
hidden: true
---

# Microsoft SQL Server

Microsoft SQL Server is a relational database used for transactional workloads, data warehousing, and BI. Vulcan runs against SQL Server to manage transformations with version control and gated deployments.

## Local or built-in scheduler

**Engine adapter type**: `mssql`

### Prerequisites

1. A SQL Server instance (on-premises, Azure SQL, or SQL Server in a container)
2. A database user with appropriate permissions
3. Network connectivity to the SQL Server instance

### Permissions

Vulcan requires the following SQL Server permissions:

* `CREATE SCHEMA` on the target database
* `CREATE TABLE` and `CREATE VIEW` on schemas
* `SELECT`, `INSERT`, `UPDATE`, `DELETE` on tables
* `ALTER` on schemas for schema modifications

### Connection options

All the connection parameters you can use when setting up a SQL Server gateway:

| Option                     | Description                                                                   |  Type  | Required |
| -------------------------- | ----------------------------------------------------------------------------- | :----: | :------: |
| `type`                     | Engine type name. Must be `mssql`                                             | string |     Y    |
| `host`                     | The hostname or IP address of the SQL Server instance                         | string |     Y    |
| `port`                     | The port number of the SQL Server instance (default: `1433`)                  |   int  |     Y    |
| `user`                     | The username for SQL Server authentication                                    | string |     Y    |
| `password`                 | The password for SQL Server authentication                                    | string |     Y    |
| `database`                 | The name of the database to connect to                                        | string |     Y    |
| `concurrent_tasks`         | Maximum number of concurrent tasks (default: `4`)                             |   int  |     N    |
| `trust_server_certificate` | Whether to trust the server certificate without validation (default: `false`) |  bool  |     N    |

### Authentication methods

* Username/password authentication (required).
* Certificate validation (optional): use the `trust_server_certificate` parameter. Only set to `true` in development environments.

### Docker images

The following Docker images are available for running Vulcan with SQL Server:

| Image                           | Description                            |
| ------------------------------- | -------------------------------------- |
| `tmdcio/vulcan-mssql:0.228.1.6` | Main Vulcan API service for SQL Server |

Pull the images:

```bash
docker pull tmdcio/vulcan-mssql:0.228.1.6
```

### Materialization strategy

Materialization strategies for Microsoft SQL Server depend on the model kind and engine capabilities. For details on how different model kinds are materialized, see the [model kinds documentation](../../components/model/model_kinds.md).

**Learn more about materialization strategies:**

* [INCREMENTAL\_BY\_TIME\_RANGE](../../components/model/model_kinds.md#materialization-strategy)
* [INCREMENTAL\_BY\_UNIQUE\_KEY](../../components/model/model_kinds.md#materialization-strategy_1)
* [INCREMENTAL\_BY\_PARTITION](../../components/model/model_kinds.md#materialization-strategy_3)
* [FULL](../../components/model/model_kinds.md#materialization-strategy_2)

{% hint style="info" %}
The `dialect` for SQL Server models should be set to `tsql` (Transact-SQL), not `mssql`.
{% endhint %}

{% hint style="warning" %}
Only set `trust_server_certificate: true` in development environments. In production, configure SSL certificates.
{% endhint %}
