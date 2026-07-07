---
hidden: true
---

# BigQuery

Google BigQuery is a serverless cloud data warehouse that runs SQL on Google's infrastructure. Vulcan runs against BigQuery to manage transformations with version control and gated deployments.

## Local or built-in scheduler

**Engine adapter type**: `bigquery`

### Prerequisites

1. A Google Cloud Platform (GCP) project with BigQuery enabled
2. A service account with appropriate permissions (or OAuth credentials)
3. A service account key file (JSON format) for authentication

### Permissions

Vulcan requires the following BigQuery permissions:

* `bigquery.datasets.create`: to create datasets (schemas)
* `bigquery.tables.create`: to create tables and views
* `bigquery.tables.getData`: to read data from tables
* `bigquery.tables.updateData`: to insert, update, and delete data
* `bigquery.jobs.create`: to run queries

The `BigQuery Data Editor` and `BigQuery Job User` roles provide these permissions.

### Connection options

All the connection parameters you can use when setting up a BigQuery gateway:

| Option    | Description                                                                                |  Type  | Required |
| --------- | ------------------------------------------------------------------------------------------ | :----: | :------: |
| `type`    | Engine type name. Must be `bigquery`                                                       | string |     Y    |
| `method`  | Authentication method (`service-account`, `oauth`, `oauth-secrets`, `application-default`) | string |     Y    |
| `project` | The GCP project ID where BigQuery resources are located                                    | string |     Y    |
| `keyfile` | Path to the service account JSON key file (required for `service-account` method)          | string |     N    |

### Service account key file

The `keyfile` is a JSON key file downloaded from the Google Cloud Console:

1. Go to **IAM & Admin → Service Accounts**
2. Select your service account (or create a new one)
3. Go to the **Keys** tab
4. Click **Add Key → Create new key**
5. Select **JSON** and click **Create**

The downloaded file has the following structure:

```json
{
  "type": "service_account",
  "project_id": "<your-project-id>",
  "private_key_id": "<key-id>",
  "private_key": "-----BEGIN PRIVATE KEY-----\n<private-key-content>\n-----END PRIVATE KEY-----\n",
  "client_email": "<service-account-name>@<project-id>.iam.gserviceaccount.com",
  "client_id": "<client-id>",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/<service-account-name>",
  "universe_domain": "googleapis.com"
}
```

### Authentication methods

* **Service account** (`service-account`): requires `keyfile` path to JSON key file.
* **OAuth** (`oauth`): OAuth-based authentication.
* **OAuth secrets** (`oauth-secrets`): OAuth with secrets.
* **Application default** (`application-default`): uses default application credentials.

### Docker images

The following Docker images are available for running Vulcan with BigQuery:

| Image                               | Description                          |
| ----------------------------------- | ------------------------------------ |
| `tmdcio/vulcan-bigquery:0.228.1.10` | Main Vulcan API service for BigQuery |

Pull the images:

```bash
docker pull tmdcio/vulcan-bigquery:0.228.1.10
```

### Materialization strategy

BigQuery uses the following materialization strategies depending on the model kind:

| Model kind                  | Strategy                                | Description                                                                                                                                                                          |
| --------------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `INCREMENTAL_BY_TIME_RANGE` | DELETE by time range, then INSERT       | Vulcan first deletes existing records within the target time range, then inserts the new data. This ensures data consistency and prevents duplicates when reprocessing time intervals. |
| `INCREMENTAL_BY_UNIQUE_KEY` | MERGE ON unique key                     | Vulcan uses BigQuery's MERGE statement to update existing records based on the unique key or insert new ones if they do not exist.                                                   |
| `INCREMENTAL_BY_PARTITION`  | DELETE by partitioning key, then INSERT | Vulcan deletes existing records matching the partitioning key, then inserts the new data. This ensures partition-level consistency when reprocessing data.                          |
| `FULL`                      | CREATE OR REPLACE TABLE                 | Vulcan uses BigQuery's `CREATE OR REPLACE TABLE` statement to rebuild the table from scratch each time.                                                                              |

**Learn more about materialization strategies:**

* [INCREMENTAL\_BY\_TIME\_RANGE](../../components/model/model_kinds.md#materialization-strategy)
* [INCREMENTAL\_BY\_UNIQUE\_KEY](../../components/model/model_kinds.md#materialization-strategy_1)
* [INCREMENTAL\_BY\_PARTITION](../../components/model/model_kinds.md#materialization-strategy_3)
* [FULL](../../components/model/model_kinds.md#materialization-strategy_2)

{% hint style="info" %}
The `BigQuery Data Editor` and `BigQuery Job User` roles together provide the minimum permissions required for Vulcan to operate.
{% endhint %}

{% hint style="warning" %}
Never commit your keyfile to version control. Add it to `.gitignore` and store it securely.
{% endhint %}
