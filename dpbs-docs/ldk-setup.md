---
description: >-
  Set up the Local Development Kit: Python virtual environment, Vulcan, and
  engine.
---

# LDK setup

The Local Development Kit (LDK) is the local toolkit you author and test data products with. Setting it up means installing Python, creating an isolated environment, installing Vulcan, and pointing it at an engine. Do this once.

{% hint style="info" %}
Vulcan requires **Python 3.10**.
{% endhint %}

## 1. Install Python 3.10

Check first:

```sh
python3.10 --version
```

If it is not present, install it from [python.org/downloads](https://www.python.org/downloads/release/python-3100/).

## 2. Create a virtual environment

Always install Vulcan inside an isolated environment so it does not conflict with other Python projects.

```sh
python3.10 -m venv .venv
```

Activate it:

{% tabs %}
{% tab title="macOS / Linux" %}
```bash
source .venv/bin/activate
```
{% endtab %}

{% tab title="Windows" %}
```bash
.venv\Scripts\activate
```
{% endtab %}
{% endtabs %}

## 3. Install Vulcan

Vulcan ships as a Python wheel.

{% file src="../../.gitbook/assets/vulcan-0.228.1.26-py3-none-any.whl" %}

Download and place the Vulcan `.whl` file in your working directory (or use its full path), then install:

```sh
pip install "./vulcan-0.228.1.26-py3-none-any.whl"
```

If you target a specific engine, install the matching extra. Quote the path so your shell does not interpret the brackets:

{% tabs %}
{% tab title="Postgres" %}
```bash
pip install "./vulcan-0.228.1.26-py3-none-any.whl[postgres]"
```
{% endtab %}

{% tab title="Snowflake" %}
```bash
pip install "./vulcan-0.228.1.26-py3-none-any.whl[snowflake]"
```
{% endtab %}

{% tab title="Databricks" %}
```bash
pip install "./vulcan-0.228.1.26-py3-none-any.whl[databricks]"
```
{% endtab %}

{% tab title="Spark" %}
```bash
pip install "./vulcan-0.228.1.26-py3-none-any.whl[spark]"
```
{% endtab %}

{% tab title="Trino" %}
```bash
pip install "./vulcan-0.228.1.26-py3-none-any.whl[trino]"
```
{% endtab %}
{% endtabs %}

Verify:

```sh
vulcan --version
```

## 4. Initialize the project

```bash
vulcan init
```

The initializer scaffolds the project structure:

<table data-search="false"><thead><tr><th>Folder / file</th><th>What goes here</th></tr></thead><tbody><tr><td><code>config.yaml</code></td><td>Project configuration: connections, model defaults, linting.</td></tr><tr><td><code>models/</code></td><td>SQL and Python model files. Each produces a table or view.</td></tr><tr><td><code>dq/</code></td><td>Data quality rule packs (<code>kind: dq</code>). Non-blocking; monitor quality over time.</td></tr><tr><td><code>models/semantics/</code></td><td>Semantic models (<code>kind: semantic</code>). Business-friendly wrappers over physical models.</td></tr><tr><td><code>models/metrics/</code></td><td>Metric definitions (<code>kind: metric</code>). Time-series analytical definitions.</td></tr><tr><td><code>seeds/</code></td><td>CSV files loaded as static tables.</td></tr><tr><td><code>audits/</code></td><td>SQL audit files. They run at materialization and block execution if they return rows.</td></tr><tr><td><code>tests/</code></td><td>YAML unit tests. Run with <code>vulcan test</code> before touching the warehouse.</td></tr><tr><td><code>macros/</code></td><td>Reusable SQL snippets and Jinja macros.</td></tr></tbody></table>

## 5. Set up your engine

To connect Vulcan locally, use an existing engine instance or spin one up via Docker, then add its connection to `config.yaml`. For the full connection reference per engine, see [Connect engine](https://v2.dataos.info/build/productize/connect-engine).

{% tabs %}
{% tab title="Postgres" %}
Use an existing Postgres instance if you already have one. You need the host, port, database, user, and password. See the [Postgres connection options](https://v2.dataos.info/build/productize/connect-engine/postgres#connection-options) for all supported fields.

Set your password as an environment variable:

{% tabs %}
{% tab title="Mac/Linux" %}
```bash
export POSTGRES_PASSWORD='your_password'
```
{% endtab %}

{% tab title="Windows" %}
```powershell
$env:POSTGRES_PASSWORD = 'your_password'
```
{% endtab %}
{% endtabs %}

Update the connection details in `config.yaml`(sample):

```yaml
gateways:
  default:
    connection:
      type: postgres
      host: your_psql_host
      port: 5433
      database: warehouse
      user: vulcan
      password: "{{ env_var(POSTGRES_PASSWORD) }}"
```

**OR**

<details>

<summary><strong>Start Postgres locally with Docker</strong></summary>

Create the network once:

```bash
docker network create vulcan
```

Save this as `docker/docker-compose.warehouse.yml`:

```yaml
volumes:
  warehouse:
    driver: local
networks:
  vulcan:
    external: true
services:
  warehouse:
    image: postgres:17-alpine
    environment:
      POSTGRES_DB: warehouse
      POSTGRES_USER: vulcan
      POSTGRES_PASSWORD: vulcan
      POSTGRES_HOST_AUTH_METHOD: trust
    ports:
      - "5433:5432"
    volumes:
      - warehouse:/var/lib/postgresql/data
    networks:
      - vulcan
```

Start it:

```bash
docker compose -f docker/docker-compose.warehouse.yml up -d
```

</details>

Full reference: [Connect engine → Postgres](https://v2.dataos.info/build/productize/connect-engine/postgres).
{% endtab %}

{% tab title="Snowflake" %}
Use an existing Snowflake account and warehouse. No local Docker service is needed for Snowflake.

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

Update the connection details in `config.yaml`(sample):

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

```

Full reference: [Connect engine → Snowflake](https://v2.dataos.info/build/productize/connect-engine/snowflake).
{% endtab %}

{% tab title="Databricks" %}
Use an existing workspace with SQL warehouse or cluster access. No local Docker service is needed for Databricks.

Set the access token as an environment variable, then:

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

Update the connection details in `config.yaml`(sample):

```yaml
gateways:
  default:
    connection:
      type: databricks
      serverHostname: your-workspace.azuredatabricks.net
      httpPath: /sql/1.0/warehouses/your_warehouse_id
      accessToken: "{{ env_var('DATABRICKS_TOKEN') }}"
      catalog: your_catalog

```

Full reference: [Connect engine → Databricks](https://v2.dataos.info/build/productize/connect-engine/databricks).
{% endtab %}

{% tab title="Spark" %}
Use an existing Spark cluster and update `spark.master` in `config.yaml` to point to your cluster.

Update the connection details in `config.yaml`(sample):

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

modelDefaults:
  dialect: spark2
```
{% endcode %}

**OR**

<details>

<summary><strong>Start Spark locally with Docker</strong></summary>

Start a local Spark standalone cluster with MinIO and an Iceberg REST catalog.

This avoids Windows Hadoop or `winutils.exe` issues because the Spark driver runs inside Linux.

Place `vulcan-0.228.1.26-py3-none-any.whl` in your project root, then save this as `docker/docker-compose.spark.yml`:

{% code overflow="wrap" expandable="true" %}
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

</details>

Full reference: [Connect engine → Spark](https://v2.dataos.info/build/productize/connect-engine/spark).
{% endtab %}

{% tab title="Trino" %}
Use an existing Trino cluster with a configured catalog. No local Docker service is needed for Trino. Set the password only if your cluster requires it, then:

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

Update the connection details in `config.yaml`(sample):

```yaml
gateways:
  default:
    connection:
      type: trino
      host: your_trino_host
      port: 8080
      user: your_user
      catalog: your_catalog
      httpScheme: https
      password: "{{ env_var('TRINO_PASSWORD') }}"

modelDefaults:
  dialect: trino
```

Full reference: [Connect engine → Trino](https://v2.dataos.info/build/productize/connect-engine/trino).
{% endtab %}
{% endtabs %}

## 6. Verify

```bash
vulcan info # check if the connection is successful
```

A successful `vulcan info` confirms the project is ready to configure and build.

## Troubleshooting

<details>

<summary><code>... is not a supported wheel on this platform</code></summary>

Vulcan only support with Python 3.10, so recreate the environment with Python 3.10:

```sh
deactivate && rm -rf .venv
python3.10 -m venv .venv && source .venv/bin/activate
```

</details>

<details>

<summary><code>zsh: no matches found</code></summary>

Your shell is interpreting the `[engine]` brackets. Quote the wheel path: `pip install "./vulcan-...whl[snowflake]"`.

</details>

<details>

<summary>Dependency conflicts</summary>

Install into a fresh virtual environment, never the system Python. To overwrite an existing install, use `pip install --force-reinstall "./vulcan-<version>-py3-none-any.whl"`.

</details>
