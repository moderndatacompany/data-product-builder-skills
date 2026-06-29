# Spark

Apache Spark is a unified analytics engine for large-scale data processing. Vulcan integrates with Spark to manage your data transformations with version control and safe deployments.

{% hint style="warning" %}
**VDE is not supported on Spark**

Setting `vde: true` in `config.yaml` is rejected by validation when the gateway type is `spark`. Spark gateways must run in simple mode (`vde: false`, which is the default). See [`vde`](../README.md#environment--schema-management) for details.
{% endhint %}

## Local or built-in scheduler

**Engine adapter type**: `spark`

### Prerequisites

1. A running Spark cluster (standalone, YARN, or Kubernetes)
2. Spark 3.x or higher (3.4+ recommended for catalog support)
3. Network connectivity to the Spark master node

### Permissions

Vulcan requires the following Spark permissions:

* Access to create and manage tables in the configured catalog
* Read/write access to the configured storage (S3, HDFS, and so on)
* Permission to submit Spark applications

### Connection options

All the connection parameters you can use when setting up a Spark gateway:

| Option       | Description                                        |  Type  | Required |
| ------------ | -------------------------------------------------- | :----: | :------: |
| `type`       | Engine type name. Must be `spark`                  | string |     Y    |
| `config_dir` | Value to set for `SPARK_CONFIG_DIR`                | string |     N    |
| `catalog`    | The catalog to use when issuing commands           | string |     N    |
| `config`     | Key/value pairs to set for the Spark configuration |  dict  |     N    |

### Authentication methods

* Configuration-based authentication: authentication credentials are typically configured through Spark configuration (`config` parameter) or the `SPARK_CONFIG_DIR` environment variable.
* Catalog-based authentication: depends on the underlying catalog (S3, HDFS, and so on) configured in Spark.

### Catalog support

Vulcan's Spark integration is designed for single catalog usage. All models must be defined with a single catalog.

If `catalog` is not set, the behavior depends on the Spark version:

| Spark version | Default catalog behavior              |
| ------------- | ------------------------------------- |
| >= 3.4        | Default catalog determined at runtime |
| < 3.4         | Default catalog is `spark_catalog`    |

### Docker images

The following Docker images are available for running Vulcan with Spark:

| Image                                     | Description                                          |
| ----------------------------------------- | ---------------------------------------------------- |
| `tmdcio/vulcan-spark-base:0.228.1.19`     | Spark-ready base layer used by `vulcan-spark` builds |
| `tmdcio/vulcan-spark:0.228.1.19`          | Main Vulcan API service for Spark                    |
| `tmdcio/vulcan-transpiler-semantic:0.0.5` | Semantic query transpiler engine                     |
| `tmdcio/vulcan-transpiler-api:0.0.5`      | Transpiler API service                               |

#### Image contents

Most users only need `vulcan-spark` plus the two transpiler images (`vulcan-transpiler-semantic` and `vulcan-transpiler-api`). For local development, you can also pull `vulcan-spark-base` for spark-master and spark-worker.

`vulcan-spark-base` is the Spark runtime foundation that makes the engine Spark-ready.

Pull the images:

```bash
docker pull tmdcio/vulcan-spark-base:0.228.1.19
docker pull tmdcio/vulcan-spark:0.228.1.19
docker pull tmdcio/vulcan-transpiler-semantic:0.0.5
docker pull tmdcio/vulcan-transpiler-api:0.0.5
```

### Managing external or extra dependencies

#### Java dependencies

**Maven**

See: [https://maven.apache.org/plugins/maven-jar-plugin/usage](https://maven.apache.org/plugins/maven-jar-plugin/usage)

```bash
mvn -DskipTests package
ls -1 target/*.jar
```

**Gradle**

See: \<https://docs.gradle.org/current/userguide/building\_java\_projects.html, https://docs.gradle.org/current/userguide/java\_plugin.html>

```bash
./gradlew shadowJar
ls -1 build/libs/*.jar
```

Place JARs at your project root under `dependencies/java/` so they are available inside the container at `/workspace/dependencies/java`. Nested folders under `dependencies/java/` are not supported (for example, `dependencies/java/lib/*.jar` is not picked up).

If you have multiple JAR folders, include all of them in Spark config via `spark.driver.extraClasspath`:

```properties
spark.driver.extraClasspath=/workspace/dependencies/java:/workspace/third_party/jars
```

On Windows, use `;` instead of `:` to separate multiple paths.

To _use_ classes from your JAR in a Python model, register the Java UDF by fully-qualified class name, then call it in SQL expressions:

```java
context.spark.udf.registerJavaFunction(
    "my_udf_name",
    "com.yourorg.udf.YourUdfClass",
    types.StringType(),
)
```

If the UDF runs on executors (most do), make sure workers can also see the same JARs (for example, by also setting `spark.executor.extraClasspath` or baking/mounting the JARs into worker containers).

### Materialization strategy

Spark uses the following materialization strategies depending on the model kind:

| Model kind                  | Strategy                                  | Description                                                                                                                                                                                                                                |
| --------------------------- | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `INCREMENTAL_BY_TIME_RANGE` | INSERT OVERWRITE by time column partition | Vulcan overwrites the entire partition that corresponds to the time column, rather than deleting and inserting individual records. This is more efficient for partitioned data and uses Spark's native partitioning capabilities. |
| `INCREMENTAL_BY_UNIQUE_KEY` | Not supported                             | Spark does not support `INCREMENTAL_BY_UNIQUE_KEY` models. Use `INCREMENTAL_BY_TIME_RANGE` or `INCREMENTAL_BY_PARTITION` instead.                                                                                                   |
| `INCREMENTAL_BY_PARTITION`  | INSERT OVERWRITE by partitioning key      | Vulcan overwrites the entire partition based on the partitioning key. This uses Spark's native partitioning for efficient data management.                                                                                                 |
| `FULL`                      | INSERT OVERWRITE                          | Vulcan uses Spark's `INSERT OVERWRITE` statement to replace the table contents each time.                                                                                                                                           |

**Learn more about materialization strategies:**

* [INCREMENTAL\_BY\_TIME\_RANGE](../../components/model/model_kinds.md#materialization-strategy)
* [INCREMENTAL\_BY\_UNIQUE\_KEY](../../components/model/model_kinds.md#materialization-strategy_1)
* [INCREMENTAL\_BY\_PARTITION](../../components/model/model_kinds.md#materialization-strategy_3)
* [FULL](../../components/model/model_kinds.md#materialization-strategy_2)

{% hint style="info" %}
Do not use Spark for the Vulcan state connection. Use a transactional database such as PostgreSQL for the `state_connection`.
{% endhint %}

{% hint style="warning" %}
Always use environment variables for sensitive credentials in your Spark configuration (S3 keys, database passwords, and so on).
{% endhint %}
