---
description: >-
  Install Vulcan, configure the Engine, initialize the project, and understand
  the generated structure.
---

# LDK Setup

Use this page to set up your machine before you configure or build the project.

{% hint style="info" %}
Vulcan requires **Python 3.10**. Versions outside the `>=3.9, <3.11` range are not supported.
{% endhint %}

{% stepper %}
{% step %}
### Install Python 3.10

Check whether Python 3.10 is already available:

```sh
python3.10 --version
```

If the command is not found, install Python 3.10 from [python.org/downloads](https://www.python.org/downloads/) or via your system's package manager:

{% tabs %}
{% tab title="macOS (Homebrew)" %}
```bash
brew install python@3.10
```
{% endtab %}

{% tab title="Ubuntu / Debian" %}
```shellscript
sudo apt update && sudo apt install python3.10 python3.10-venv
```
{% endtab %}

{% tab title="Windows" %}
Download the installer from [python.org/downloads](https://www.python.org/downloads/) and follow the setup wizard. Make sure to check **Add Python to PATH** during installation.
{% endtab %}
{% endtabs %}
{% endstep %}

{% step %}
### Docker for local services (optional)

Install Docker if you want Vulcan to start local services for development. This is required for the local Postgres setup and the Spark Docker setup.

```bash
docker --version
docker compose version
```

If Docker is not installed, install [Docker Desktop](https://www.docker.com/products/docker-desktop/).
{% endstep %}

{% step %}
### Create a virtual environment

Always install Vulcan inside an isolated virtual environment to avoid dependency conflicts with other Python projects on your machine.

**Create the environment**

```sh
python3.10 -m venv .venv
```

**Activate the environment**

{% tabs %}
{% tab title="macOS / Linux" %}
```bash
source .venv/bin/activate
```
{% endtab %}

{% tab title="Windows" %}
```shellscript
.venv\Scripts\activate
```
{% endtab %}
{% endtabs %}

You should see `(.venv)` prepended to your terminal prompt, confirming the environment is active.
{% endstep %}

{% step %}
### Upgrade pip

```sh
python3.10 -m pip install --upgrade pip
```
{% endstep %}

{% step %}
### Install Vulcan

{% file src="../.gitbook/assets/vulcan-0.228.1.25-py3-none-any.whl" %}

Download and place the Vulcan `.whl` file in your working directory (or use its full path), then install:

```sh
pip install "./vulcan-0.228.1.25-py3-none-any.whl"
```

This installs the **core** library, which includes the DuckDB engine for local experimentation.

#### Install with engine extras

If your workflow targets a specific warehouse or execution engine, install the matching extra. Always wrap the path in quotes so your shell does not interpret the brackets:

{% tabs %}
{% tab title="Postgres" %}
```bash
pip install "./vulcan-0.228.1.25-py3-none-any.whl[postgres]"
```
{% endtab %}

{% tab title="Snowflake" %}
```bash
pip install "./vulcan-0.228.1.25-py3-none-any.whl[snowflake]"
```
{% endtab %}

{% tab title="Databricks" %}
```bash
pip install "./vulcan-0.228.1.25-py3-none-any.whl[databricks]"
```
{% endtab %}

{% tab title="Spark" %}
```bash
pip install "./vulcan-0.228.1.25-py3-none-any.whl[spark]"
```
{% endtab %}

{% tab title="Trino" %}
```bash
pip install "./vulcan-0.228.1.25-py3-none-any.whl[trino]"
```
{% endtab %}
{% endtabs %}
{% endstep %}

{% step %}
### Verify the installation

```sh
vulcan --version
```

```sh
python3.10 -c "from vulcan import Context; print('Vulcan OK')"
```

If both commands succeed, your Python environment is ready.
{% endstep %}

{% step %}
### Set up your engine

Choose the tab for your engine. If you already have a warehouse or engine instance, use it and add its connection details to `config.yaml`. If you do not have one, use the local setup only where this guide provides one.

{% tabs %}
{% tab title="Postgres" %}
**Option 1: Use an existing Postgres instance**

Use an existing Postgres instance if you already have one. You need the host, port, database, user, and password. See the [Postgres connection options](../stage-2-productize/connect-to-engine/postgres.md#connection-options) for all supported fields.

**Option 2: Start Postgres locally with Docker**

If you do not have Postgres locally, run it with Docker Compose.

Create the Docker network once:

```bash
docker network create vulcan
```

If Docker says the network already exists, continue.

Save this as `docker/docker-compose.warehouse.yml`:

```yaml
# Central Warehouse - PostgreSQL for project data
# Access: postgresql://vulcan:vulcan@localhost:5433/warehouse

x-images:
  postgres: &postgres_image "postgres:17-alpine"

volumes:
  warehouse:
    driver: local

networks:
  vulcan:
    external: true

services:
  warehouse:
    image: *postgres_image
    environment:
      POSTGRES_DB: warehouse
      POSTGRES_USER: vulcan
      POSTGRES_PASSWORD: vulcan
      POSTGRES_HOST_AUTH_METHOD: trust
    ports:
      - "5433:5432"
    volumes:
      - warehouse:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U vulcan -d warehouse"]
      interval: 5s
      timeout: 5s
      retries: 5
    restart: unless-stopped
    networks:
      - vulcan
```

Start Postgres:

```bash
docker compose -f docker/docker-compose.warehouse.yml up -d
```

Use this connection in `config.yaml`:

```yaml
gateways:
  default:
    connection:
      type: postgres
      host: localhost
      port: 5433
      database: warehouse
      user: vulcan
      password: vulcan
    state_connection:
      type: duckdb
      database: ./.state/vulcan.db

default_gateway: default

model_defaults:
  dialect: postgres
```
{% endtab %}

{% tab title="Snowflake" %}
**Option 1: Use an existing Snowflake warehouse**

Use an existing Snowflake account and warehouse. No local Docker service is needed for Snowflake.

**Option 2: Create a Snowflake warehouse**

If you do not have Snowflake available yet, create a Snowflake account and warehouse in Snowflake. This guide does not start Snowflake with Docker.

Set your password as an environment variable:

{% tabs %}
{% tab title="Mac/Linux" %}
```bash
export SNOWFLAKE_PASSWORD='your_password'
```
{% endtab %}

{% tab title="Windows" %}
```powershell
$env:SNOWFLAKE_PASSWORD = 'your_password'
```
{% endtab %}
{% endtabs %}

Use this connection in `config.yaml`:

```yaml
gateways:
  default:
    connection:
      type: snowflake
      account: your_account
      user: your_user
      password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
      warehouse: your_warehouse
      database: your_database
      role: your_role
    state_connection:
      type: duckdb
      database: ./.state/vulcan.db

default_gateway: default

model_defaults:
  dialect: snowflake
```


{% endtab %}

{% tab title="Databricks" %}
**Option 1: Use an existing Databricks workspace**

Use an existing Databricks workspace with SQL warehouse or cluster access. No local Docker service is needed for Databricks.

**Option 2: Create Databricks compute**

If you do not have Databricks available yet, create a workspace and SQL warehouse or cluster in Databricks. This guide does not start Databricks with Docker.

Set your access token as an environment variable:

{% tabs %}
{% tab title="Mac/Linux" %}
```bash
export DATABRICKS_TOKEN='your_token'
```
{% endtab %}

{% tab title="Windows" %}
```powershell
$env:DATABRICKS_TOKEN = 'your_token'
```
{% endtab %}
{% endtabs %}

Use this connection in `config.yaml`:

```yaml
gateways:
  default:
    connection:
      type: databricks
      server_hostname: your-workspace.azuredatabricks.net
      http_path: /sql/1.0/warehouses/your_warehouse_id
      access_token: "{{ env_var('DATABRICKS_TOKEN') }}"
      catalog: your_catalog
    state_connection:
      type: duckdb
      database: ./.state/vulcan.db

default_gateway: default

model_defaults:
  dialect: databricks
```
{% endtab %}

{% tab title="Spark" %}
**Option 1: Use an existing Spark cluster**

If you already have a Spark cluster, use the `vulcan-cli` service below and update `spark.master` in `config.yaml` to point to your cluster.

**Option 2: Start Spark locally with Docker**

Spark uses a dedicated Docker Compose setup in this guide. It runs a Spark standalone cluster, MinIO, an Iceberg REST catalog, and a Linux-based `vulcan-cli` container. This avoids Windows Hadoop or `winutils.exe` issues because the Spark driver runs inside Linux.

Place `vulcan-0.228.1.25-py3-none-any.whl` in your project root, then save this as `docker/docker-compose.spark.yml`:

{% code overflow="wrap" %}
```yaml
services:
  # Spark standalone cluster for running Spark executors in containers.
  spark-master:
    image: tmdcio/vulcan-spark-base:0.228.1.21
    container_name: spark-seeds-minimal-spark-master
    restart: unless-stopped
    command: ["/bin/bash", "-lc", "/opt/spark/sbin/start-master.sh --host 0.0.0.0 --port 7077 --webui-port 8080 && tail -f /opt/spark/logs/*"]
    ports:
      - "7077:7077"
      - "8080:8080"
    networks:
      - spark-seeds-minimal-net

  spark-worker:
    image: tmdcio/vulcan-spark-base:0.228.1.21
    container_name: spark-seeds-minimal-spark-worker
    restart: unless-stopped
    command: ["/bin/bash", "-lc", "/opt/spark/sbin/start-worker.sh spark://spark-master:7077 --webui-port 8081 && tail -f /opt/spark/logs/*"]
    depends_on:
      - spark-master
    ports:
      - "8081:8081"
    networks:
      - spark-seeds-minimal-net

  # MinIO for S3-compatible storage.
  minio:
    image: minio/minio:latest
    container_name: spark-seeds-minimal-minio
    restart: unless-stopped
    environment:
      - MINIO_ROOT_USER=admin
      - MINIO_ROOT_PASSWORD=password
      - MINIO_DOMAIN=minio
    ports:
      - "9000:9000"
      - "9001:9001"
    networks:
      spark-seeds-minimal-net:
        aliases:
          - minio
          - warehouse.minio
    volumes:
      - minio_data:/data
    command: server /data --console-address ":9001"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 5s
      timeout: 5s
      retries: 10

  # MinIO setup - creates warehouse bucket.
  mc:
    image: minio/mc:latest
    container_name: spark-seeds-minimal-mc
    networks:
      - spark-seeds-minimal-net
    depends_on:
      minio:
        condition: service_healthy
    entrypoint: >
      /bin/sh -c "
        mc alias set minio http://minio:9000 admin password;
        mc mb --ignore-existing minio/warehouse;
        mc anonymous set public minio/warehouse;
        exit 0;
      "

  # Iceberg REST Catalog.
  iceberg-rest:
    image: tabulario/iceberg-rest:latest
    container_name: spark-seeds-minimal-iceberg-rest
    restart: unless-stopped
    ports:
      - "8181:8181"
    networks:
      - spark-seeds-minimal-net
    environment:
      - AWS_ACCESS_KEY_ID=admin
      - AWS_SECRET_ACCESS_KEY=password
      - AWS_REGION=us-east-1
      - CATALOG_WAREHOUSE=s3://warehouse/
      - CATALOG_IO__IMPL=org.apache.iceberg.aws.s3.S3FileIO
      - CATALOG_S3_ENDPOINT=http://minio:9000
    depends_on:
      minio:
        condition: service_healthy

networks:
  spark-seeds-minimal-net:
    driver: bridge

volumes:
  minio_data:
```
{% endcode %}

Start the Spark services:

```bash
docker compose -f docker/docker-compose.spark.yml up -d
```

Verify Vulcan through the CLI container:

```bash
docker compose -f docker/docker-compose.spark.yml run --rm vulcan-cli vulcan --version
```

Use this connection in `config.yaml`:

{% code overflow="wrap" %}
```yaml
gateways:
  default:
    connection:
      type: spark
      config:
        spark.master: spark://spark-master:7077
        spark.app.name: vulcan
        spark.sql.catalog.local: org.apache.iceberg.spark.SparkCatalog
        spark.sql.catalog.local.type: rest
        spark.sql.catalog.local.uri: http://iceberg-rest:8181
        spark.sql.catalog.local.warehouse: s3://warehouse/
        spark.sql.catalog.local.io-impl: org.apache.iceberg.aws.s3.S3FileIO
        spark.sql.catalog.local.s3.endpoint: http://minio:9000
        spark.sql.catalog.local.s3.path-style-access: "true"
        spark.hadoop.fs.s3a.access.key: admin
        spark.hadoop.fs.s3a.secret.key: password
        spark.hadoop.fs.s3a.endpoint: http://minio:9000
        spark.hadoop.fs.s3a.path.style.access: "true"
    state_connection:
      type: duckdb
      database: ./.state/vulcan.db

default_gateway: default

model_defaults:
  dialect: spark2
```
{% endcode %}
{% endtab %}

{% tab title="Trino" %}
**Option 1: Use an existing Trino cluster**

Use an existing Trino cluster with a configured catalog. No local Docker service is needed for Trino in this guide.

**Option 2: Create a Trino cluster**

If you do not have Trino available yet, create a Trino cluster and catalog outside this guide. This guide does not start Trino with Docker.

Set your password only if your Trino cluster requires password authentication:

{% tabs %}
{% tab title="Mac/Linux" %}
```bash
export TRINO_PASSWORD='your_password'
```
{% endtab %}

{% tab title="Windows" %}
```powershell
$env:TRINO_PASSWORD = 'your_password'
```
{% endtab %}
{% endtabs %}

Use this connection in `config.yaml`:

```yaml
gateways:
  default:
    connection:
      type: trino
      host: your_trino_host
      port: 8080
      user: your_user
      catalog: your_catalog
      http_scheme: https
      password: "{{ env_var('TRINO_PASSWORD') }}"
    state_connection:
      type: duckdb
      database: ./.state/vulcan.db

default_gateway: default

model_defaults:
  dialect: trino
```


{% endtab %}
{% endtabs %}
{% endstep %}

{% step %}
### Initialize the Vulcan project

Run the initializer from your activated virtual environment:

```bash
vulcan init
```

The initializer creates the starter project structure for models, seeds, tests, quality checks, macros, and semantic definitions:

```
my-vulcan-project/
├── config.yaml
├── usage.yaml
├── audits/
├── dq/
│   └── full_model.yml
├── macros/
│   └── __init__.py
├── models/
│   ├── full_model.sql
│   ├── incremental_model.sql
│   ├── seed_model.sql
│   ├── metrics/
│   │   └── event_activity.yml
│   └── semantics/
│       └── incremental_model.yml
├── seeds/
│   └── seed_data.csv
└── tests/
    └── test_full_model.yaml
```

<details>

<summary><strong>Understanding the project structure</strong></summary>

| Folder / File       | What goes here                                                                                                |
| ------------------- | ------------------------------------------------------------------------------------------------------------- |
| `models/`           | Your SQL and Python model files. Each file produces a table or view in the warehouse.                         |
| `models/dq/`        | Data quality rule packs (`kind: dq`). Non-blocking; monitor quality over time.                                |
| `models/semantics/` | Semantic model definitions (`kind: semantic`). Business-friendly wrappers over physical models.               |
| `models/metrics/`   | Business metric definitions (`kind: metric`). Time-series analytical definitions.                             |
| `seeds/`            | CSV files that Vulcan loads as static tables. Useful for reference data (categories, regions, lookup tables). |
| `audits/`           | SQL assertion files. These run automatically at materialization and block execution if they return rows.      |
| `tests/`            | YAML unit tests. Run with `vulcan test` to verify model logic before touching the warehouse.                  |
| `macros/`           | Reusable SQL snippets and Jinja macros used across models.                                                    |
| `config.yaml`       | The project configuration. Covers connections, model defaults, linting, and more.                             |

</details>
{% endstep %}

{% step %}
### Verify and run

For every engine except Spark:

{% tabs %}
{% tab title="Mac/Linux" %}
```bash
vulcan info
vulcan plan
```
{% endtab %}

{% tab title="Windows" %}
```powershell
vulcan info
vulcan plan
```
{% endtab %}
{% endtabs %}

This checks your project structure and configuration. A successful output confirms the project is ready to configure and build.
{% endstep %}
{% endstepper %}

***

### Troubleshooting

<details>

<summary><code>ERROR: ... is not a supported wheel on this platform</code></summary>

Your Python version is outside the supported range (`>=3.9, <3.11`). Recreate the virtual environment using Python 3.10:

```sh
deactivate
rm -rf .venv
python3.10 -m venv .venv
source .venv/bin/activate
```

</details>

<details>

<summary><code>zsh: no matches found</code></summary>

Your shell is interpreting the `[engine]` brackets. Always quote the wheel path when using extras.

```sh
pip install "./vulcan-...whl[snowflake]"
```

</details>

<details>

<summary>Dependency conflicts</summary>

Install into a fresh virtual environment, not the system Python. Avoid using `pip install` outside an activated `.venv`.

</details>

<details>

<summary>Reinstall or upgrade</summary>

Use `--force-reinstall` to overwrite an existing Vulcan installation:

```sh
pip install --force-reinstall "./vulcan-<version>-py3-none-any.whl"
```

</details>

***
