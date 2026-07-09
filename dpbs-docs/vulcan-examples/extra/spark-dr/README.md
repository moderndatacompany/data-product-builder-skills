# Spark + Iceberg Example

This example demonstrates Vulcan running with Apache Spark as the query engine and Apache Iceberg for table management. It uses MinIO for object storage and PostgreSQL for state management.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Docker Network: vulcan                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐  │
│  │ vulcan-api  │  │ transpiler  │  │  graphql    │  │   mysql    │  │
│  │   :8000     │  │   :4000     │  │   :3000     │  │   :3306    │  │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └─────┬──────┘  │
│         │                │                │               │          │
│         └────────────────┴────────────────┴───────────────┘          │
│                                   │                                  │
│  ┌────────────────────────────────┴────────────────────────────┐    │
│  │                      Spark Cluster                           │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │    │
│  │  │ spark-master │  │ spark-worker │  │ spark-worker │       │    │
│  │  │    :7077     │  │              │  │              │       │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘       │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                   │                                  │
│  ┌────────────────────────────────┴────────────────────────────┐    │
│  │                     Infrastructure                           │    │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐             │    │
│  │  │ statestore │  │   minio    │  │iceberg-rest│             │    │
│  │  │   :5431    │  │   :9000    │  │   :8181    │             │    │
│  │  └────────────┘  └────────────┘  └────────────┘             │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Quick Start

```bash
# 1. Setup everything (network + infra + spark)
make setup

# 2. Start Vulcan services
make vulcan-up

# 3. Test the API
curl http://localhost:8000/api/v1/livez
curl http://localhost:8000/api/v1/meta
```

## Setup

You can use `make` commands for convenience, or run the docker compose commands directly.

### Step 1: Create External Network

```bash
make network
```

Or directly:
```bash
docker network create vulcan
```

### Step 2: Start Infrastructure

Start the infrastructure services that Vulcan depends on:

```bash
make infra
```

**What gets started:**
- **statestore** (PostgreSQL:5431): Vulcan's internal state storage
- **warehouse** (PostgreSQL:5433): Sample data warehouse
- **minio-warehouse** (MinIO:9000): Object storage for query results
- **minio-sample** (MinIO:9002): Secondary object storage
- **iceberg-rest-warehouse** (:8181): Iceberg REST catalog for warehouse
- **iceberg-rest-sample** (:8182): Iceberg REST catalog for sample data

### Step 3: Start Spark Cluster

```bash
make spark
```

**What gets started:**
- **spark-master** (:7077, UI :8080): Spark cluster master
- **spark-worker-1**: Spark executor (4 cores, 2GB RAM)
- **spark-worker-2**: Spark executor (4 cores, 2GB RAM)

### Quick Setup

Run all setup steps at once:
```bash
make setup
```

## Getting Started with Vulcan

### Option 1: Using Docker CLI

Create a shell alias for the Vulcan CLI:

```bash
alias vulcan="docker run -it --network=vulcan --rm \
  -v .:/workspace \
  -v ~/.ivy2:/home/vulcan/.ivy2 \
  -v ~/.m2:/home/vulcan/.m2 \
  tmdcio/vulcan-spark:0.228.2 vulcan"
```

**Note:** The `.ivy2` and `.m2` volume mounts cache Spark dependencies, avoiding repeated downloads.

Then use Vulcan commands:
```bash
vulcan plan              # Plan changes
vulcan plan --auto-apply # Plan and apply
vulcan info              # Show project info
```

### Option 2: Start API Services

Start the full Vulcan service stack:

```bash
make vulcan-up
```

This starts:
- **vulcan-api** (:8000): REST API for semantic queries
- **vulcan-transpiler** (:4000): Semantic SQL transpilation
- **vulcan-graphql** (:3000): GraphQL API
- **vulcan-mysql** (:3306): MySQL wire protocol for BI tools

### Test the API

```bash
# Health check
curl http://localhost:8000/api/v1/livez

# Get metadata
curl http://localhost:8000/api/v1/meta

# Run a semantic query
curl -X POST http://localhost:8000/api/v1/query/semantic/rest \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "measures": ["products.total_products", "products.average_price"],
      "dimensions": ["products.category"]
    }
  }'
```

## Semantic Model

This example includes a sample products semantic model:

### Available Measures
- `products.total_products` - Total number of products
- `products.available_products` - Products currently in stock
- `products.out_of_stock_products` - Products out of stock
- `products.premium_products` - Premium tier products
- `products.average_price` - Average product price
- `products.total_inventory_value` - Total value of available inventory
- `products.min_price` / `products.max_price` - Price range

### Available Dimensions
- `products.product_id`
- `products.product_name`
- `products.category`
- `products.price`
- `products.price_tier`
- `products.in_stock`
- `products.stock_status`

### Available Segments
- `products.premium_tier` - Premium products ($200+)
- `products.standard_tier` - Standard products ($50-$199)
- `products.budget_tier` - Budget products (under $50)
- `products.electronics` - Electronic products
- `products.accessories` - Accessory products

## Connect via MySQL Protocol

Connect using any MySQL-compatible client:

```bash
mysql -h localhost -P 3306 -u <dataos-user> -p'<api-key>' --enable-cleartext-plugin
```

Once connected:
```sql
SHOW TABLES;
SELECT * FROM products LIMIT 10;
```

**Note:** Configure `HEIMDALL_URL` environment variable for authentication. Use your DataOS API key as the password.

## Spark Web UI

Access the Spark Web UI to monitor jobs:
- **Spark Master UI**: http://localhost:8080
- **Spark Application UI**: http://localhost:4040 (when a job is running)

## Stopping Services

```bash
make vulcan-down  # Stop Vulcan services only
make spark-down   # Stop Spark cluster only
make infra-down   # Stop infrastructure only
make all-down     # Stop all services
make all-clean    # Stop all and remove volumes
```

## Makefile Commands

For a full list of available commands:

```bash
make help
```

## Troubleshooting

### Spark JAR Downloads

On first run, Spark downloads Iceberg and other dependencies. These are cached in `~/.ivy2` and `~/.m2` via volume mounts to avoid repeated downloads.

### Java Temp Directory Warning

The warning `java.io.tmpdir directory does not exist` is harmless - Spark creates the directory automatically.

### Native Hadoop Library Warning

The warning `Unable to load native-hadoop library` is expected when running in Docker. Spark uses Java-based implementations instead.

## Project Structure

```
examples/spark/
├── config.yaml              # Vulcan configuration (Spark connection, object store, etc.)
├── Makefile                 # Build and run commands
├── README.md                # This file
├── docker/
│   ├── docker-compose.infra.yml    # Infrastructure (PostgreSQL, MinIO, Iceberg)
│   ├── docker-compose.spark.yml    # Spark cluster
│   ├── docker-compose.vulcan.yml   # Vulcan services
│   ├── init-postgres.sql           # Database initialization
│   └── ssl/                        # SSL certificates (for MySQL)
├── models/
│   ├── sample_products.sql         # Products model
│   ├── sample_users.sql            # Users model
│   └── users_seed.sql              # Seed data
├── semantics/
│   └── sample_products.yml         # Semantic layer definition
└── checks/
    ├── sample_products.yml         # Data quality checks
    └── sample_users.yml            # Data quality checks
```

