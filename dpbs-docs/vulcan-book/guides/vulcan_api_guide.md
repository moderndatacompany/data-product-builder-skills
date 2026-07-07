# Vulcan API guide

Your semantic models are defined, your measures and dimensions are in place, your plan is applied. Now you want to query the data from an application, a dashboard, or a BI tool.

Vulcan gives you three ways to do that: a **REST API**, a **GraphQL** endpoint, and a **MySQL wire protocol** service. All three are generated from your `models/semantics/` definitions. You don't write any API code.

This guide covers authentication, querying each surface, and wiring things up for production.

***

## Prerequisites

Three things have to be in place before the APIs work:

1. **A running Vulcan stack.** Bring it up with `make up` (see the [Get started guide](get-started.md)).
2. **At least one semantic model** in `models/semantics/` with dimensions and measures (see [Semantic models](../components/model/types/models.md)).
3. **An applied plan.** Run `vulcan plan` so Vulcan knows about your models.

### Service ports

When you run locally with Docker, the services live at:

| Service                      | Port | URL                           |
| ---------------------------- | ---- | ----------------------------- |
| REST API                     | 8000 | `http://localhost:8000`       |
| GraphQL                      | 3000 | `http://localhost:3000`       |
| MySQL wire protocol          | 3307 | `localhost:3307`              |
| Transpiler                   | 8100 | `http://localhost:8100`       |
| Interactive API docs (ReDoc) | 8000 | `http://localhost:8000/redoc` |

***

## Authentication

How you authenticate depends on where Vulcan runs.

### Local development

In a local Docker setup, authentication is usually off. Vulcan reads environment variables from `docker-compose.vulcan.yml`:

| Variable               | What it is                                                          |
| ---------------------- | ------------------------------------------------------------------- |
| `DATAOS_RUN_AS_USER`   | Your DataOS user ID                                                 |
| `DATAOS_RUN_AS_APIKEY` | Your DataOS API key                                                 |
| `HEIMDALL_URL`         | Your DataOS context URL, e.g. `https://my-context.dataos.app/heimdall` |

When `HEIMDALL_ENABLED` is `false` (the local default), requests don't need a token.

### DataOS deployment

With Heimdall enabled, every request needs a Bearer token:

```bash
curl -X GET 'https://<env-fqn>/<tenant>/vulcan/<data-product-name>/livez' \
  -H 'Authorization: Bearer <your-token>'
```

Heimdall validates the token before the request reaches Vulcan.

### MySQL wire protocol

For MySQL connections, your DataOS API key is the password:

```bash
mysql -h <host> -P <port> -u <username> -p'<api-key>' --enable-cleartext-plugin
```

Full connection details are in the [MySQL wire protocol](vulcan_api_guide.md#querying-via-mysql-wire-protocol) section below.

***

## Querying via REST API

The REST API is **asynchronous**. You submit a query, get a statement ID back immediately, then poll until the result is ready. That model is what makes caching, deduplication, and parallel execution possible.

```
POST query  -->  statement ID  -->  poll status  -->  GET result
```

For the full picture of what happens internally, see [Semantic query lifecycle](semantic_query_lifecycle.md).

### Submit a semantic query

POST a JSON body to `/api/v1/query/semantic/rest`:

{% tabs %}
{% tab title="Mac/Linux" %}
```bash
curl -X POST http://localhost:8000/api/v1/query/semantic/rest \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "measures": ["orders.total_revenue"],
      "dimensions": ["orders.region"],
      "timeDimensions": [
        {
          "dimension": "orders.order_date",
          "granularity": "month",
          "dateRange": ["2024-01-01", "2024-12-31"]
        }
      ],
      "limit": 100
    }
  }'
```
{% endtab %}

{% tab title="Windows" %}
```cmd
curl -X POST http://localhost:8000/api/v1/query/semantic/rest ^
  -H "Content-Type: application/json" ^
  -d "{\"query\": {\"measures\": [\"orders.total_revenue\"], \"dimensions\": [\"orders.region\"], \"timeDimensions\": [{\"dimension\": \"orders.order_date\", \"granularity\": \"month\", \"dateRange\": [\"2024-01-01\", \"2024-12-31\"]}], \"limit\": 100}}"
```
{% endtab %}
{% endtabs %}

### Query payload reference

```json
{
  "query": {
    "measures": ["<alias>.<measure_name>"],
    "dimensions": ["<alias>.<dimension_name>"],
    "timeDimensions": [
      {
        "dimension": "<alias>.<time_dimension>",
        "granularity": "<second|minute|hour|day|week|month|quarter|year>",
        "dateRange": ["<start_date>", "<end_date>"]
      }
    ],
    "filters": [
      {
        "member": "<alias>.<dimension_name>",
        "operator": "<equals|notEquals|contains|notContains|gt|gte|lt|lte|set|notSet|inDateRange|notInDateRange|beforeDate|afterDate>",
        "values": ["<value1>", "<value2>"]
      }
    ],
    "segments": ["<alias>.<segment_name>"],
    "order": { "<alias>.<member>": "<asc|desc>" },
    "limit": 100,
    "offset": 0,
    "timezone": "UTC",
    "renewQuery": false
  },
  "ttl_minutes": 60
}
```

| Field            | Type      | Required | Description                                            |
| ---------------- | --------- | -------- | ------------------------------------------------------ |
| `measures`       | string\[] | Yes      | Measures to calculate, e.g. `["orders.total_revenue"]` |
| `dimensions`     | string\[] | No       | Columns to group by, e.g. `["orders.region"]`          |
| `timeDimensions` | object\[] | No       | Time dimensions with granularity and date range        |
| `filters`        | object\[] | No       | Filter conditions applied to the query                 |
| `segments`       | string\[] | No       | Predefined segment filters from your semantic models   |
| `order`          | object    | No       | Sort order: `{"field": "asc"}` or `{"field": "desc"}`  |
| `limit`          | integer   | No       | Max rows returned (1-50,000, default 10,000)           |
| `offset`         | integer   | No       | Rows to skip                                           |
| `timezone`       | string    | No       | Timezone for time dimensions (default `"UTC"`)         |
| `renewQuery`     | boolean   | No       | Set to `true` to bypass the cache                      |
| `ttl_minutes`    | integer   | No       | Cache duration in minutes                              |

### Receive a statement ID

You get back HTTP 202 immediately with a statement ID:

```json
{
  "id": "stmt-abc-123",
  "status": "QUEUED",
  "strategy": "execute",
  "sql": "SELECT region, ...",
  "fingerprint": "a1b2c3...",
  "_links": {
    "self": "/api/v1/query/statement/stmt-abc-123",
    "result": "/api/v1/query/statement/stmt-abc-123/result"
  }
}
```

The `strategy` field tells you what happened:

| Strategy        | What it means                                                           |
| --------------- | ----------------------------------------------------------------------- |
| `execute`       | New execution. SQL went to the warehouse.                               |
| `from_cache`    | Cache hit. Result already exists from a previous run.                   |
| `await_primary` | Piggyback. An identical query is already running; yours is linked to it. |

### Poll for status

```bash
curl http://localhost:8000/api/v1/query/statement/stmt-abc-123
```

Poll until `status` is `SUCCESS` or `FAILED`:

```json
{
  "id": "stmt-abc-123",
  "status": "SUCCESS",
  "row_count": 1000,
  "_links": {
    "result": "/api/v1/query/statement/stmt-abc-123/result"
  }
}
```

Status lifecycle:

```
ACCEPTED --> QUEUED --> IN_PROGRESS --> SUCCESS
                                   \-> FAILED
                                   \-> CANCELLED
```

| Status        | Meaning                                  |
| ------------- | ---------------------------------------- |
| `ACCEPTED`    | Request received, not yet queued.        |
| `QUEUED`      | In the queue, waiting for a worker.      |
| `IN_PROGRESS` | A worker is running SQL on the warehouse. |
| `SUCCESS`     | Done, result is ready.                    |
| `FAILED`      | Something broke. Check `error_message`.   |
| `CANCELLED`   | Cancelled by the user.                    |

### Download the result

```bash
curl http://localhost:8000/api/v1/query/statement/stmt-abc-123/result?format=json
```

Pick the format you want:

| Format  | How to request                              | What you get                              |
| ------- | ------------------------------------------- | ----------------------------------------- |
| Parquet | Default, or `format=parquet`                | 307 redirect to a presigned download URL  |
| JSON    | `Accept: application/json` or `format=json` | Data inline as JSON                       |
| CSV     | `Accept: text/csv` or `format=csv`          | Data inline as CSV                        |
| YAML    | `Accept: application/yaml` or `format=yaml` | Data inline as YAML                       |

For JSON, CSV, and YAML you can paginate and project:

| Parameter | Description                                |
| --------- | ------------------------------------------ |
| `limit`   | Max rows to return                         |
| `offset`  | Rows to skip                               |
| `columns` | Comma-separated list of columns to include |

```
GET /api/v1/query/statement/{id}/result?format=json&limit=100&offset=0&columns=region,total_revenue
```

{% hint style="info" %}
**Parquet ignores pagination**

When you request Parquet, `limit`, `offset`, and `columns` are ignored. You get the full result file.
{% endhint %}

### Full example

End to end:

```bash
# 1. Submit query
curl -s -X POST http://localhost:8000/api/v1/query/semantic/rest \
  -H "Content-Type: application/json" \
  -d '{"query": {"measures": ["orders.total_revenue"], "dimensions": ["orders.region"]}}' \
  | jq .

# 2. Poll for status (use your actual statement ID)
curl -s http://localhost:8000/api/v1/query/statement/stmt-abc-123 | jq .

# 3. Download result as JSON
curl -s http://localhost:8000/api/v1/query/statement/stmt-abc-123/result?format=json | jq .
```

***

## Querying via GraphQL

The GraphQL service runs on port **3000**.

### Endpoint

```
http://localhost:3000/graphql
```

### Example query

```bash
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ orders(limit: 10) { region total_revenue order_date } }"
  }'
```

### GraphQL Playground

Open `http://localhost:3000` in a browser. The Playground lets you browse the schema, write queries, and see docs for every field.

### Introspection

Discover what's available programmatically:

```graphql
{
  __schema {
    types {
      name
      fields {
        name
        type { name }
      }
    }
  }
}
```

***

## Querying via MySQL wire protocol

If your BI tool speaks MySQL, point it at Vulcan. You write semantic SQL against your models; Vulcan transpiles it to native warehouse SQL.

### Connecting

{% tabs %}
{% tab title="Local" %}
```bash
mysql -h 127.0.0.1 -P 3307 -u <username> -p'<api-key>' \
  --ssl-mode=REQUIRED --enable-cleartext-plugin
```
{% endtab %}

{% tab title="Remote (DataOS)" %}
```bash
mysql -h tcp.<context>.dataos.app -P 3306 -u <username> -p'<api-key>' \
  --enable-cleartext-plugin <tenant_name>.<data_product_name>
```
{% endtab %}
{% endtabs %}

| Parameter       | What it is                                | Example                                                     |
| --------------- | ----------------------------------------- | ----------------------------------------------------------- |
| `-h <host>`     | Vulcan MySQL host                         | `127.0.0.1` (local) or `tcp.my-context.dataos.app` (remote) |
| `-P <port>`     | MySQL port                                | `3307` (local) or `3306` (remote)                           |
| `-u <username>` | Your DataOS username                      | `johndoe`                                                   |
| `-p'<api-key>'` | Your DataOS API key (no space after `-p`) | `-p'dG9rZW4xMjM0...'`                                       |
| Database        | Tenant and data product                   | `marketing.sales_analytics`                                 |

### Discovering models

Once you're connected, explore with standard MySQL commands:

```sql
-- List all semantic models
SHOW TABLES;

-- Inspect a model's columns (dimensions and measures)
DESCRIBE users;
```

### Writing queries

Semantic SQL looks like regular SQL, except measures use the `MEASURE()` wrapper:

```sql
-- Simple measure
SELECT MEASURE(total_users) FROM users;

-- Grouped by dimension
SELECT users.plan_type, MEASURE(total_users)
FROM users
GROUP BY users.plan_type;

-- With filters
SELECT MEASURE(total_arr)
FROM subscriptions
WHERE subscriptions.status = 'active';

-- With time grouping
SELECT DATE_TRUNC('month', subscriptions.start_date) AS month,
       MEASURE(total_arr)
FROM subscriptions
GROUP BY month
ORDER BY month DESC
LIMIT 5;

-- Cross-model joins
SELECT users.industry, MEASURE(total_arr)
FROM subscriptions
CROSS JOIN users
GROUP BY users.industry
ORDER BY MEASURE(total_arr) DESC;
```

{% hint style="success" %}
**BI tool integration**

Tableau, Metabase, Superset, DBeaver, and anything else that speaks MySQL connects the same way. Same host, port, username, and API key.
{% endhint %}

For a complete reference with example output, see [Transpiling semantics: MySQL payloads](transpiling_semantics.md#transpiling-mysql-payloads).

***

## Transpiling locally

Before you hit the API, preview the generated SQL with `vulcan transpile`. Nothing executes; you just see what Vulcan would send to the warehouse.

Semantic SQL:

```bash
vulcan transpile --format sql "SELECT MEASURE(total_users) FROM users"
```

REST API payloads:

```bash
vulcan transpile --format json '{"query": {"measures": ["users.total_users"]}}'
```

Useful for debugging unexpected results or verifying that a semantic definition produces the SQL you expect. See [Transpiling semantics](transpiling_semantics.md) for the full reference.

***

## Starting the API server manually

Not using Docker Compose? Start the API server directly:

```bash
vulcan api
```

| Option      | Default   | What it does                |
| ----------- | --------- | --------------------------- |
| `--host`    | `0.0.0.0` | Host to bind to             |
| `--port`    | `8000`    | Port to bind to             |
| `--reload`  | `false`   | Auto-reload on file changes |
| `--workers` | `1`       | Number of worker processes  |

See [CLI commands: api](../cli.md#api) for details.

***

## API endpoints reference

### REST API

| Endpoint                              | Method | Description                                 |
| ------------------------------------- | ------ | ------------------------------------------- |
| `/api/v1/query/semantic/rest`         | POST   | Submit a semantic query                     |
| `/api/v1/query/statement/{id}`        | GET    | Poll query status                           |
| `/api/v1/query/statement/{id}/result` | GET    | Download results (Parquet, JSON, CSV, YAML) |
| `/livez`                              | GET    | Health check                                |
| `/redoc`                              | GET    | Interactive API docs (OpenAPI)              |

### GraphQL

| Endpoint   | Method | Description             |
| ---------- | ------ | ----------------------- |
| `/graphql` | POST   | Execute GraphQL queries |
| `/`        | GET    | GraphQL Playground      |

### MySQL wire protocol

| Operation                 | Description                                  |
| ------------------------- | -------------------------------------------- |
| `SHOW TABLES`             | List available semantic models               |
| `DESCRIBE <model>`        | Show model columns (dimensions and measures) |
| `SELECT ... FROM <model>` | Query using semantic SQL with `MEASURE()`    |

***

## Deployment

In DataOS, the API runs as a long-lived service alongside your plan and run workflows. Configure it in `domain-resource.yaml`:

```yaml
api:
  replicas: 1
  logLevel: INFO
  resource:
    request:
      cpu: "200m"
      memory: "512Mi"
    limit:
      cpu: "5000m"
      memory: "4Gi"
```

The API pod runs three containers:

| Container       | Log suffix | What it does        |
| --------------- | ---------- | ------------------- |
| Main API        | `*-main`   | REST API service    |
| GraphQL sidecar | `*-sc-1`   | GraphQL interface   |
| MySQL sidecar   | `*-sc-2`   | MySQL wire protocol |

Pull logs from a specific container:

```bash
dataos-ctl resource -t Vulcan -n <resource-name> logs \
  --container-group <name>-api -c main
```

For the full deployment walkthrough, see the [Deployment guide](deployment_guide.md).

***

## Troubleshooting

### Connection refused

You see: `curl: (7) Failed to connect to localhost port 8000`.

Check whether the API container is running:

```bash
docker ps | grep vulcan-api
```

If it isn't, look at the logs:

```bash
docker logs vulcan-api
```

### Authentication errors (401 / 403)

You get `Unauthorized` or `Forbidden`.

- **Local:** Make sure `DATAOS_RUN_AS_APIKEY` is set in `docker-compose.vulcan.yml`.
- **DataOS:** Your Bearer token is probably expired. Generate a fresh one.
- **MySQL:** Confirm there's no space between `-p` and your API key.

### Query returns FAILED

Polling gives you `"status": "FAILED"`. Check `error_message` first. Common causes:

- Misspelled semantic member names. Re-check `models/semantics/*.yml`.
- Warehouse unreachable. Is the engine up?
- Bad SQL. Run `vulcan transpile` to see the generated query.

### Empty results

The query succeeds but returns zero rows. Check:

- That you've applied a plan. Models aren't materialized until `vulcan plan` runs.
- That `timeDimensions.dateRange` actually covers dates with data.
- The underlying table directly with `vulcan fetchdf`.

***

## Next

- [Semantic query lifecycle](semantic_query_lifecycle.md) - How async query, caching, and deduplication work under the hood.
- [Transpiling semantics](transpiling_semantics.md) - Full reference for `vulcan transpile` and semantic SQL syntax.
- [Semantic models](../components/model/types/models.md) - Defining dimensions, measures, and segments.
- [Business metrics](../components/semantics/business_metrics.md) - Time-series metric definitions.
- [Deployment guide](deployment_guide.md) - Deploying Vulcan on DataOS.
