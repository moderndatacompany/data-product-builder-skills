# Trino Configuration

Trino configuration for querying Iceberg lakehouses.

## Configuration Files

- **config.properties** - Trino coordinator settings
- **jvm.config** - JVM memory settings
- **node.properties** - Node configuration
- **log.properties** - Logging level
- **catalog/** - Iceberg catalog connectors
  - `iceberg_warehouse.properties` - Warehouse catalog
  - `iceberg_sample.properties` - Sample catalog

## Usage

### Start Trino
```bash
docker-compose -f docker-compose.infra.yml up -d
```

### Access CLI
```bash
docker exec -it trino trino
```

### Basic Queries
```sql
-- List catalogs
SHOW CATALOGS;

-- List schemas
SHOW SCHEMAS IN iceberg_warehouse;

-- List tables
SHOW TABLES IN iceberg_warehouse.spark;

-- Query data
SELECT * FROM iceberg_warehouse.spark.table_name LIMIT 10;
```

### Troubleshooting
```bash
# Check logs
docker logs trino

# Check health
docker exec trino trino --execute "SELECT 1"
```

## Notes

- Web UI: http://localhost:8080
- Both catalogs use Parquet format
- MinIO credentials: admin/password
- Development mode (no authentication)
