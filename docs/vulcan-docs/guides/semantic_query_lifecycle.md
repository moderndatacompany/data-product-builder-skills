# Semantic query lifecycle

How a semantic query travels through Vulcan, from POST request to result download.

---

## Overview

Semantic queries are **asynchronous**. You submit a query, get a statement ID back immediately, and poll for the result. This design lets Vulcan deduplicate identical queries, serve results from cache, and scale execution across workers.

```
POST query ──► statement ID ──► poll status ──► GET result
```

The full lifecycle has six stages:

1. **Submit:** the client sends a semantic query.
2. **Transpile:** Vulcan converts semantic references to warehouse SQL.
3. **Cache check:** Vulcan looks for an existing result before executing.
4. **Execute:** a worker runs the SQL on the data warehouse.
5. **Store:** the result is saved as a Parquet file in object storage.
6. **Fetch:** the client retrieves the result using the statement ID.

---

## 1. Submit a query

Send a `POST` to `/api/v1/query/semantic/rest` with a JSON body describing what you want:

```json
{
  "query": {
    "measures": ["<alias>.<measure_name>", ...],
    "dimensions": ["<alias>.<column_name>", ...],
    "timeDimensions": [
      {
        "dimension": "<alias>.<column_name>",
        "granularity": "<second|minute|hour|day|week|month|quarter|year>",
        "dateRange": ["<start_date>", "<end_date>"]
      }
    ],
    "filters": [...],
    "segments": ["<alias>.<segment_name>", ...],
    "order": { "<field>": "<asc|desc>" },
    "limit": <1-50000>,
    "timezone": "<timezone>"
  }
}
```

The query uses semantic names like `orders.total_revenue` and `orders.region`, defined in your `models/semantics/` YAML files. You never write SQL directly.

### Query fields

| Field | Description |
|-------|-------------|
| `measures` | List of measures to calculate (e.g. `["orders.total_revenue"]`) |
| `dimensions` | Columns to group by (e.g. `["orders.region"]`) |
| `timeDimensions` | Time-based dimensions with granularity and date ranges |
| `filters` | Filter conditions applied to the query |
| `segments` | Predefined segment filters from semantic models |
| `order` | Sort order. Dict `{"field": "asc"}` or array `[["field", "desc"]]`. |
| `limit` | Maximum rows returned (1–50,000, default 10,000) |
| `timezone` | Timezone for time dimensions (default `"UTC"`) |

---

## 2. Transpile to SQL

The warehouse doesn't understand semantic names like `orders.total_revenue`. Vulcan translates them into warehouse SQL.

```
Semantic query ──► Catalog + Transpiler ──► Warehouse SQL
```

1. Vulcan loads the project's **semantic catalog**: all models, measures, dimensions, joins, and their mappings to physical tables.
2. The catalog is exported in a schema format and sent to the **Transpiler Service** along with your query.
3. The transpiler generates warehouse-specific SQL (Snowflake SQL, DuckDB SQL, etc.) for the target engine.

The generated SQL looks something like:

```sql
SELECT
  region,
  DATE_TRUNC('month', order_date) AS order_date,
  SUM(revenue) AS total_revenue
FROM analytics.orders
WHERE order_date BETWEEN '2024-01-01' AND '2024-12-31'
GROUP BY 1, 2
ORDER BY 2
```

The transpiler handles joins, aggregations, grouping, and dialect-specific syntax automatically.

---

## 3. Cache check

Before running anything on the warehouse, Vulcan checks if it can skip execution entirely. It hashes the generated SQL into a **fingerprint** and asks three questions:

### Has this exact query been run before?

If a cached result exists for this fingerprint **and** the upstream data hasn't changed since, Vulcan returns the cached result immediately. No warehouse call needed.

### Is someone else already running this query?

If the same query is currently in-flight from another request, Vulcan **piggybacks** on it instead of running a duplicate. Your statement ID is linked to the running query's ID, and when it finishes, both requests share the same result.

### Did this query fail recently?

If the same query recently failed, Vulcan returns the error directly to avoid hammering a broken query. Use the `retry_on_recent_failure` query parameter to override this behavior.

### Cache invalidation

Cached results are invalidated when upstream models get refreshed. If your pipeline runs and updates the `orders` table, all cached results that depend on `orders` expire. The next identical query executes fresh instead of returning stale data.

---

## 4. Statement ID

Whichever path the request takes (cache hit, piggyback, or new execution), the API responds immediately with an **HTTP 202** and a statement ID:

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

The statement ID is your receipt. The API never blocks until the query finishes.

### Status lifecycle

```
ACCEPTED ──► QUEUED ──► IN_PROGRESS ──► SUCCESS
                                    └──► FAILED
                                    └──► CANCELLED
```

| Status | Meaning |
|--------|---------|
| `ACCEPTED` | Request received, before queuing |
| `QUEUED` | Job placed in the queue, waiting for a worker |
| `IN_PROGRESS` | A worker picked it up and is executing SQL on the warehouse |
| `SUCCESS` | Done. Result is available. |
| `FAILED` | Something went wrong. Error message is attached. |
| `CANCELLED` | Cancelled by the user |

**Cache hits** skip straight to `SUCCESS`. **Piggybacks** mirror the status of the primary query.

### Resolution strategies

Each statement ID records which path was taken:

| Strategy | What happened |
|----------|---------------|
| `execute` | New execution. SQL sent to the warehouse. |
| `from_cache` | Cache hit. Result returned from a previous execution. |
| `await_primary` | Piggyback. Linked to an identical query already running. |

---

## 5. Execution

For new executions, the query goes through a job queue backed by PostgreSQL (PGQueuer). A background worker picks it up and:

1. **Runs the SQL** on your data warehouse (Snowflake, Databricks, DuckDB, etc.)
2. **Saves the result** as a Parquet file in object storage (S3, MinIO, GCS)
3. **Records metadata**: row count, file size, column schema, lineage.
4. **Creates a cache entry** so the next identical query can skip execution
5. **Updates the statement status** to `SUCCESS` (or `FAILED` if something went wrong)

---

## 6. Fetch the result

Use the statement ID to check status and retrieve data.

### Poll for status

```
GET /api/v1/query/statement/{id}
```

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

Keep polling until `status` is `SUCCESS` or `FAILED`.

### Download the result

```
GET /api/v1/query/statement/{id}/result
```

The result endpoint supports multiple output formats:

| Format | How to request | Behavior |
|--------|---------------|----------|
| Parquet | Default, or `format=parquet` | Redirects (307) to a presigned download URL |
| JSON | `Accept: application/json` or `format=json` | Returns data inline as JSON |
| CSV | `Accept: text/csv` or `format=csv` | Returns data inline as CSV |
| YAML | `Accept: application/yaml` or `format=yaml` | Returns data inline as YAML |

### Pagination and projection

For JSON, CSV, and YAML formats, you can filter the result using query parameters:

| Parameter | Description |
|-----------|-------------|
| `limit` | Maximum number of rows to return |
| `offset` | Number of rows to skip |
| `columns` | Comma-separated list of columns to include |

```
GET /api/v1/query/statement/{id}/result?format=json&limit=100&offset=0&columns=region,total_revenue
```

{% hint style="info" %}
**Parquet format ignores pagination**

When requesting Parquet format, `limit`, `offset`, and `columns` parameters are ignored. You get the full result file.
{% endhint %}

---

## Putting it all together

Here's the typical client flow:

```
1.  POST /api/v1/query/semantic/rest
    Body: { "query": { "measures": [...], ... } }
    ← 202  { "id": "stmt-abc-123", "status": "QUEUED" }

2.  GET /api/v1/query/statement/stmt-abc-123
    ← 200  { "status": "IN_PROGRESS" }

3.  GET /api/v1/query/statement/stmt-abc-123
    ← 200  { "status": "SUCCESS", "row_count": 1000 }

4.  GET /api/v1/query/statement/stmt-abc-123/result?format=json
    ← 200  [ { "region": "US", "total_revenue": 42000 }, ... ]
```

---

## State tables

Vulcan persists all query metadata in four tables that live in the **state connection** database. These tables power caching, deduplication, status tracking, and saved queries.

### State connection

The state tables are stored in a PostgreSQL database configured via your project's `config.yaml`:

```yaml
gateways:
  my_gateway:
    state_connection:
      type: postgres
      host: localhost
      port: 5432
      user: vulcan
      password: ...
      database: statestore
    state_schema: vulcan    # Schema where state tables live (default: "vulcan")
```

If no `state_connection` is configured, Vulcan falls back to the warehouse connection. All `_query_*` tables are created in the `state_schema` (default `vulcan`).

### `_query_results`

Stores metadata about each query result. The data itself lives in object storage as Parquet; this table only tracks where to find it.

| Column | Type | Purpose |
|--------|------|---------|
| `result_id` | text (PK) | Unique result identifier |
| `object_store_path` | text | Parquet file path in object storage (e.g. `results/{id}.parquet`) |
| `row_count` | bigint | Number of rows in the result |
| `size_bytes` | bigint | Parquet file size in bytes |
| `columns` | jsonb | Column schema: `[{"name": "...", "type": "..."}]` |
| `sql` | text | SQL query that produced this result |
| `references` | jsonb | Field-level lineage: `{column: [[model, field], ...]}` |
| `created_ts` | bigint | When the result was stored (Unix milliseconds) |

### `_query_fingerprints`

The **cache index**. Each entry maps a SQL fingerprint (hash of normalized SQL) to a stored result. This is what makes cache hits possible.

| Column | Type | Purpose |
|--------|------|---------|
| `fingerprint` | text (PK) | SHA-256 hash of normalized SQL + params |
| `result_id` | text | Links to `_query_results.result_id` |
| `depends_on` | text[] | Model names this query touches (used for invalidation) |
| `created_ts` | bigint | When the cache entry was created (Unix ms) |
| `expires_ts` | bigint | When the entry expires (Unix ms, NULL = no TTL expiry) |
| `invalidated_by_run_id` | text | Run ID that invalidated this entry |
| `invalidated_ts` | bigint | When invalidation happened (Unix ms) |

A fingerprint is considered **stale** when `expires_ts <= now` or `invalidated_ts` is set.

### `_query_requests`

An audit log of every query submission. Every API call creates a row here, whether it ended up as a cache hit, a piggyback, or a new execution.

| Column | Type | Purpose |
|--------|------|---------|
| `request_id` | text (PK) | The statement ID returned to the client |
| `strategy` | text | Resolution path: `execute`, `from_cache`, or `await_primary` |
| `execution_status` | text | Current status: `ACCEPTED`, `QUEUED`, `IN_PROGRESS`, `SUCCESS`, `FAILED`, `CANCELLED` |
| `fingerprint` | text | Links to `_query_fingerprints.fingerprint` |
| `result_id` | text | Links to `_query_results.result_id` (set on completion) |
| `primary_request_id` | text | For `await_primary`: the statement ID of the query actually running |
| `depends_on` | text[] | Model names this query touches |
| `gateway` | text | Gateway name used for execution |
| `sql_query` | text | SQL as executed |
| `normalized_sql` | text | Normalized SQL (used for fingerprinting) |
| `rest_query` | jsonb | Original REST query payload |
| `query_type` | text | Query type (e.g. `SEMANTIC_REST`, `RAW_SQL`) |
| `pgq_job_id` | bigint | PGQueuer job ID |
| `ttl` | int | Request TTL in minutes (5–43,200) |
| `meta` | jsonb | Client metadata |
| `submitted_by` | text | Who submitted the query |
| `submitted_ts` | bigint | When submitted (Unix ms) |
| `execution_start_ts` | bigint | When the worker started executing (Unix ms) |
| `execution_end_ts` | bigint | When execution finished (Unix ms) |
| `cached_at_ts` | bigint | Set for `from_cache` strategy |
| `error_message` | text | Error details for `FAILED` requests |

### `_query_perspective`

Saved queries (perspectives) that can be refreshed automatically when underlying data changes.

| Column | Type | Purpose |
|--------|------|---------|
| `perspective_id` | text (PK) | Unique perspective identifier |
| `slug` | text | URL-friendly unique slug |
| `name` | text | Display name |
| `description` | text | Description |
| `request_id` | text | Links to latest `_query_requests.request_id` |
| `fingerprint` | text | Denormalized fingerprint for staleness checks |
| `rest_query` | jsonb | Saved query definition |
| `depends_on` | text[] | Model names (for auto-refresh) |
| `auto_refresh` | boolean | Whether to re-run when dependencies are invalidated |
| `tags` | text[] | Categorization labels |
| `owner` | text | Owner |
| `is_public` | boolean | Visibility |

### How the tables relate

```
_query_requests.fingerprint  ───►  _query_fingerprints.fingerprint
_query_fingerprints.result_id ───►  _query_results.result_id
_query_requests.result_id     ───►  _query_results.result_id
_query_perspective.request_id ───►  _query_requests.request_id
```

### How cache invalidation works

When a pipeline run refreshes upstream models (e.g. `orders` gets new data):

1. The run is recorded in the `_runs` activity table with `models_affected`
2. Vulcan finds all rows in `_query_fingerprints` where `depends_on` overlaps with `models_affected`
3. Those rows are updated: `expires_ts` and `invalidated_ts` are set to now, and `invalidated_by_run_id` records which run caused it
4. The next time someone queries the same fingerprint, `get_fingerprint_result` sees the entry is stale and treats it as a cache miss
5. The query executes fresh, and a new fingerprint entry + result replaces the old one

Cached results stay fresh as long as the underlying data hasn't changed, and expire the moment it does.

---

## Quick reference

| Component | Details |
|-----------|---------|
| Submit endpoint | `POST /api/v1/query/semantic/rest` |
| Poll endpoint | `GET /api/v1/query/statement/{id}` |
| Result endpoint | `GET /api/v1/query/statement/{id}/result` |
| Semantic definitions | `models/semantics/*.yml` in your project |
| Transpilation | Semantic JSON → Transpiler Service → warehouse SQL |
| Job queue | PostgreSQL-backed (PGQueuer) |
| Result storage | Parquet files in object storage (S3 / MinIO / GCS) |
| Caching | Fingerprint-based, auto-invalidated on model refreshes |
| Result formats | Parquet, JSON, CSV, YAML |
| State tables | `_query_results`, `_query_fingerprints`, `_query_requests`, `_query_perspective` |
| State connection | Configured via `state_connection` in gateway config (default: warehouse connection) |
| State schema | Default `vulcan`, configurable via `state_schema` |
