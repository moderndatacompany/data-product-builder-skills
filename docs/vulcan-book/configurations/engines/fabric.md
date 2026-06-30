---
hidden: true
---

# Microsoft Fabric

Microsoft Fabric is an analytics solution that combines data engineering, data science, real-time analytics, and business intelligence. Built on a lakehouse architecture, it provides one experience across your data estate. Vulcan integrates with Fabric to manage your data transformations using SQL endpoints.

## Local or built-in scheduler

**Engine adapter type**: `fabric`

### Prerequisites

1. A Microsoft Fabric workspace with a SQL endpoint
2. Azure Active Directory service principal or user credentials
3. ODBC Driver 18 for SQL Server installed on your system

### Permissions

Vulcan requires the following Microsoft Fabric permissions:

* `CREATE SCHEMA` on the target database
* `CREATE TABLE` and `CREATE VIEW` on schemas
* `SELECT`, `INSERT`, `UPDATE`, `DELETE` on tables
* Workspace Contributor or Admin role for full access

### Connection options

All the connection parameters you can use when setting up a Fabric gateway:

| Option            | Description                                                     |  Type  | Required |
| ----------------- | --------------------------------------------------------------- | :----: | :------: |
| `type`            | Engine type name. Must be `fabric`                              | string |     Y    |
| `host`            | The Fabric SQL endpoint hostname                                | string |     Y    |
| `workspace_id`    | The Microsoft Fabric workspace ID (GUID)                        | string |     Y    |
| `tenant_id`       | The Azure Active Directory tenant ID                            | string |     Y    |
| `port`            | The port number for the SQL endpoint (typically `1433`)         |   int  |     Y    |
| `user`            | The service principal client ID or username                     | string |     Y    |
| `password`        | The service principal client secret or password                 | string |     Y    |
| `database`        | The name of the database (lakehouse or warehouse) to connect to | string |     Y    |
| `driver_name`     | The ODBC driver name (default: `ODBC Driver 18 for SQL Server`) | string |     N    |
| `odbc_properties` | Additional ODBC connection properties as key-value pairs        |  dict  |     N    |

### Obtaining credentials

#### Tenant ID

1. Go to **Azure Portal → Azure Active Directory**
2. Click **Overview**
3. Copy the **Tenant ID** (GUID format)

#### Workspace ID

1. Open your workspace in the **Microsoft Fabric Portal**
2. Look at the URL: `https://app.fabric.microsoft.com/groups/<workspace-id>/...`
3. Copy the **workspace-id** (GUID format)

#### Service principal (client ID and secret)

1. Go to **Azure Portal → Azure Active Directory → App registrations**
2. Select your app (or click **New registration** to create one)
3. Copy the **Application (client) ID** : use this as `user`
4. Go to **Certificates & secrets → New client secret**
5. Copy the **Secret value** : use this as `password`

#### Host (SQL endpoint)

1. Open your workspace in the **Microsoft Fabric Portal**
2. Go to **Workspace settings**
3. Find the **SQL connection string** or **SQL endpoint**
4. Copy the hostname (for example, `your-workspace.datawarehouse.fabric.microsoft.com`)

### Authentication methods

* Service principal authentication (required): use `user` (client ID) and `password` (client secret).
* User credentials authentication (required): use `user` (username) and `password` (password).

### Docker images

The following Docker images are available for running Vulcan with Microsoft Fabric:

| Image                            | Description                        |
| -------------------------------- | ---------------------------------- |
| `tmdcio/vulcan-fabric:0.228.1.6` | Main Vulcan API service for Fabric |

Pull the images:

```bash
docker pull tmdcio/vulcan-fabric:0.228.1.6
```

### Materialization strategy

Materialization strategies for Microsoft Fabric depend on the model kind and engine capabilities. For details on how different model kinds are materialized, see the [model kinds documentation](../../components/model/model_kinds.md).

**Learn more about materialization strategies:**

* [INCREMENTAL\_BY\_TIME\_RANGE](../../components/model/model_kinds.md#materialization-strategy)
* [INCREMENTAL\_BY\_UNIQUE\_KEY](../../components/model/model_kinds.md#materialization-strategy_1)
* [INCREMENTAL\_BY\_PARTITION](../../components/model/model_kinds.md#materialization-strategy_3)
* [FULL](../../components/model/model_kinds.md#materialization-strategy_2)

{% hint style="info" %}
Make sure ODBC Driver 18 for SQL Server is installed on your system. Download it from the [Microsoft website](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server).
{% endhint %}

{% hint style="warning" %}
Never commit your client secret to version control. Use environment variables to store sensitive credentials.
{% endhint %}
