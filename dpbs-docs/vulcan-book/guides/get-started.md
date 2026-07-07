# Get started

Install Vulcan from a pre-built Python wheel file, choose an engine, and connect it to a warehouse. This guide uses [vulcan-0.228.1.24b1-py3-none-any.whl](vulcan-0.228.1.24b1-py3-none-any.whl).

***

## Prerequisites

### Python 3.10

Vulcan requires Python 3.10 for local wheel installation.

{% tabs %}
{% tab title="Mac/Linux" %}
```bash
python3.10 --version
python3.10 -m pip install --upgrade pip
```
{% endtab %}

{% tab title="Windows" %}
```powershell
py -3.10 --version
py -3.10 -m pip install --upgrade pip
```
{% endtab %}
{% endtabs %}

### Docker for local services

Install Docker to let Vulcan start local services for development. The local Postgres setup and the Spark Docker setup in this guide require Docker.

{% tabs %}
{% tab title="Mac/Linux" %}
```bash
docker --version
docker compose version
```
{% endtab %}

{% tab title="Windows" %}
```powershell
docker --version
docker compose version
```
{% endtab %}
{% endtabs %}

If Docker is not installed, install [Docker Desktop](https://www.docker.com/products/docker-desktop/) and make sure it is running before you start any local services.

***

## Create and activate a virtual environment

Use a virtual environment for Postgres, Snowflake, Databricks, Spark, Trino, MySQL, and MSSQL.

{% hint style="info" %}
**Spark also needs Java**

For Spark, install Vulcan locally in Python 3.10 like the other engines. You also need a Java 17 SDK available from your laptop because the Spark driver runs in your local Python process.
{% endhint %}

{% tabs %}
{% tab title="Mac/Linux" %}
```bash
mkdir my-vulcan-project && cd my-vulcan-project
python3.10 -m venv .venv
source .venv/bin/activate
```
{% endtab %}

{% tab title="Windows" %}
```powershell
mkdir my-vulcan-project
cd my-vulcan-project
py -3.10 -m venv .venv
.venv\Scripts\activate
```
{% endtab %}
{% endtabs %}

After activation, your terminal prompt should include `(.venv)`.

Download [vulcan-0.228.1.24b1-py3-none-any.whl](vulcan-0.228.1.24b1-py3-none-any.whl) and place it in your project folder.

***

## Install Vulcan for your engine

Install the wheel with the extra for the engine you want to use inside the same folder.

{% hint style="warning" %}
Quote the wheel path when using extras. Shells such as `zsh` may otherwise interpret the square brackets.
{% endhint %}

{% tabs %}
{% tab title="Postgres" %}
```bash
pip install "./vulcan-0.228.1.24b1-py3-none-any.whl[postgres]"
```
{% endtab %}

{% tab title="Snowflake" %}
```bash
pip install "./vulcan-0.228.1.24b1-py3-none-any.whl[snowflake]"
```
{% endtab %}

{% tab title="Databricks" %}
```bash
pip install "./vulcan-0.228.1.24b1-py3-none-any.whl[databricks]"
```
{% endtab %}

{% tab title="Spark" %}
If you are using the Docker-based Spark setup, skip this local install step and follow the Spark instructions in [Set Up Your Engine](get-started.md#set-up-your-engine).
{% endtab %}

{% tab title="Trino" %}
```bash
pip install "./vulcan-0.228.1.24b1-py3-none-any.whl[trino]"
```
{% endtab %}
{% endtabs %}

Verify the install:

{% tabs %}
{% tab title="Mac/Linux" %}
```bash
vulcan --version
python3.10 -c "import vulcan; print(vulcan.__version__)"
```
{% endtab %}

{% tab title="Windows" %}
```powershell
vulcan --version
py -3.10 -c "import vulcan; print(vulcan.__version__)"
```
{% endtab %}
{% endtabs %}

***

## Set up your engine

Choose the tab for your engine. If you have a warehouse or engine instance, use it and add its connection details to `config.yaml`. If you don't, use the local setup only where this guide provides one.

{% tabs %}
{% tab title="Postgres" %}
**Option 1: Use an existing Postgres instance**

Use an existing Postgres instance if you already have one. You need the host, port, database, user, and password. See the [Postgres connection options](http://127.0.0.1:7000/vulcan-book/configurations/engines/postgres/postgres/#connection-options) for all supported fields.

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

To know more, checkout [Full Spark reference](../configurations/engines/spark.md).

**Common issues and troubleshooting:**

If Vulcan cannot start Spark, check that Java 17 is available in the same terminal where you run Vulcan:

```bash
java -version
echo "$JAVA_HOME"
```

If Vulcan cannot connect to Spark, confirm the Docker services are running and the Spark master is listening on `localhost:7077`:

```bash
docker compose -f docker/docker-compose.spark.yml ps
```

If Spark cannot read or write Iceberg tables, confirm MinIO and the Iceberg REST catalog are healthy:

```bash
docker compose -f docker/docker-compose.spark.yml logs minio iceberg-rest
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

[:material-book-open-variant: Full Snowflake reference](../configurations/engines/snowflake.md)
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

[:material-book-open-variant: Full Databricks reference](../configurations/engines/databricks.md)
{% endtab %}

{% tab title="Spark" %}
**Option 1: Use an existing Spark cluster**

If you already have a Spark cluster, update `spark.master` in `config.yaml` to point to your cluster.

**Option 2: Start Spark locally with Docker**

Spark uses a dedicated Docker Compose setup in this guide. It runs a Spark standalone cluster, MinIO, and an Iceberg REST catalog. Vulcan still runs locally from your Python 3.10 environment, so Java 17 must be installed and accessible from your laptop.

Confirm Java 17 is available:

```bash
java -version
```

Save this as `docker/docker-compose.spark.yml`:

<details>

<summary>Sample <code>docker-compose.spark.yml</code></summary>

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
      
# Vulcan CLI runner. The Spark driver runs in this Linux container.
 vulcan-cli:
    image: python:3.10-bookworm
    container_name: spark-seeds-minimal-vulcan-cli
    ports:
      - "8000:8000"
    restart: unless-stopped
    networks:
      - spark-seeds-minimal-net
    depends_on:
      - spark-master
      - spark-worker
      - iceberg-rest
    environment:
      - SPARK_MASTER=spark://spark-master:7077
      - ICEBERG_REST_URI=http://iceberg-rest:8181
      - MINIO_ENDPOINT=http://minio:9000
    volumes:
      - ..:/workspace
    working_dir: /workspace
    command:
      - sh
      - -lc
      - |
        set -eu

        # Java (required for Spark)
        if ! command -v java >/dev/null 2>&1; then
          apt-get update
          apt-get install -y openjdk-17-jre-headless
          rm -rf /var/lib/apt/lists/*
        fi

        # Vulcan (install from mounted wheel)
        python -m pip install -U pip setuptools wheel
        if ! command -v vulcan >/dev/null 2>&1; then
          python -m pip install --no-cache-dir "vulcan[spark,postgres] @ file:///workspace/vulcan-0.228.1.21-py3-none-any.whl"
        fi

        tail -f /dev/null
 
networks:
  spark-seeds-minimal-net:
    driver: bridge

volumes:
  minio_data:
```

</details>

Vulcan CLI alias setup:

{% tabs %}
{% tab title="Mac/Linux" %}
```bash
alias vulcan='docker exec -i spark-seeds-minimal-vulcan-cli vulcan'
```
{% endtab %}

{% tab title="Windows" %}
```powershell
function vulcan { docker exec -i spark-seeds-minimal-vulcan-cli vulcan @args }
```
{% endtab %}
{% endtabs %}

Start the Spark services:

```bash
docker compose -f docker/docker-compose.spark.yml up -d
```

Verify Vulcan locally from your activated Python 3.10 environment:

```bash
vulcan --version
```

Use this connection in `config.yaml`:

{% code overflow="wrap" %}
```yaml
gateways:
  default:
    connection:
      type: spark
      config:
        spark.master: spark://localhost:7077
        spark.app.name: vulcan
        spark.sql.catalog.local: org.apache.iceberg.spark.SparkCatalog
        spark.sql.catalog.local.type: rest
        spark.sql.catalog.local.uri: http://localhost:8181
        spark.sql.catalog.local.warehouse: s3://warehouse/
        spark.sql.catalog.local.io-impl: org.apache.iceberg.aws.s3.S3FileIO
        spark.sql.catalog.local.s3.endpoint: http://localhost:9000
        spark.sql.catalog.local.s3.path-style-access: "true"
        spark.hadoop.fs.s3a.access.key: admin
        spark.hadoop.fs.s3a.secret.key: password
        spark.hadoop.fs.s3a.endpoint: http://localhost:9000
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

[:material-book-open-variant: Full Trino reference](../configurations/engines/trino/README.md)
{% endtab %}
{% endtabs %}

***

## Initialize the Vulcan project

Run the initializer from your activated virtual environment:

{% tabs %}
{% tab title="Mac/Linux" %}
```bash
vulcan init
```
{% endtab %}

{% tab title="Windows" %}
```powershell
vulcan init
```
{% endtab %}
{% endtabs %}

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

***

## Verify and run

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

Vulcan validates your project and computes what needs to be materialized.

For a full walkthrough of what happens after `plan`, see the [Plan guide](plan/plan_guide.md).

***

## Troubleshooting

<details>

<summary>Common issues and solutions</summary>

**`ERROR: ... is not a supported wheel on this platform`**

Make sure you are using Python 3.10. Recreate the virtual environment with Python 3.10 and install the wheel again.

**`zsh: no matches found`**

Quote the wheel path when installing extras:

```bash
pip install "./vulcan-0.228.1.24b1-py3-none-any.whl[postgres]"
```

**`vulcan: command not found`**

Activate the virtual environment before running Vulcan:

source .venv/bin/activate.venv\Scripts\activate

**Postgres Docker network does not exist**

Create the network before starting the Postgres warehouse:

```bash
docker network create vulcan
```

**Spark commands fail on Windows**

Confirm Java 17 is installed and accessible from the same terminal where you run Vulcan. If local Spark still fails on Windows, use WSL2 or a Linux/macOS environment for Spark development.

**Reinstall Vulcan from the wheel**

```bash
pip install --force-reinstall "./vulcan-0.228.1.24b1-py3-none-any.whl"
```

</details>

***

## Uninstall

For virtual environment installs:

```bash
pip uninstall vulcan
```

For Spark, stop the Docker services:

```bash
docker compose -f docker/docker-compose.spark.yml down
```

***

## Related links

* [**Data Product Lifecycle**](data-product-lifecycle.md): the full path from local setup to production deployment
* [**CLI Reference**](../cli.md): all available commands and options
* [**Model Kinds**](../components/model/model_kinds.md): `FULL`, `INCREMENTAL`, `VIEW`, and more
* [**Vulcan API Guide**](vulcan_api_guide.md): query your semantic layer via REST, GraphQL, or MySQL wire protocol
