# B2B SaaS Example - PostgreSQL Infrastructure

This directory contains the infrastructure setup for running the B2B SaaS example with PostgreSQL.

## Prerequisites

- Docker
- Docker Compose

## Quick Start

### 1. Start PostgreSQL

```bash
cd examples/b2b_saas/infra
docker-compose up -d
```

Wait for PostgreSQL to be healthy:
```bash
docker-compose ps
```

You should see:
```
NAME                  STATUS
b2b_saas_postgres     Up (healthy)
```

### 2. Verify Connection

```bash
docker-compose exec postgres psql -U sqlmesh -d b2b_saas -c "SELECT version();"
```

### 3. Update SQLMesh Config

Update `examples/b2b_saas/config.yaml` to use PostgreSQL:

```yaml
gateways:
  local:
    connection:
      type: postgres
      host: localhost
      port: 5432
      user: sqlmesh
      password: sqlmesh
      database: b2b_saas
```

### 4. Run SQLMesh

```bash
cd /Users/animesh/Development/Source/dataos/vulcan/_delete_later/examples/b2b_saas
source ../../.env/bin/activate
sqlmesh plan --auto-apply
sqlmesh run
```

## Management Commands

### Stop PostgreSQL
```bash
docker-compose stop
```

### Start PostgreSQL (after stop)
```bash
docker-compose start
```

### Clean up (removes all data)
```bash
docker-compose down -v
```

### View logs
```bash
docker-compose logs -f
```

### Connect to PostgreSQL shell
```bash
docker-compose exec postgres psql -U sqlmesh -d b2b_saas
```

## Connection Details

- **Host:** localhost
- **Port:** 5432
- **Database:** b2b_saas
- **User:** sqlmesh
- **Password:** sqlmesh

## Troubleshooting

### Port already in use
If port 5432 is already in use, modify the port mapping in `docker-compose.yml`:
```yaml
ports:
  - "5433:5432"  # Use 5433 on host instead
```

Then update the `port` in `config.yaml` to `5433`.

### Check container status
```bash
docker-compose ps
docker-compose logs postgres
```

### Reset database
```bash
docker-compose down -v  # Remove all data
docker-compose up -d    # Start fresh
```




INSERT INTO vulcan_demo.orders (order_id, customer_id, order_date, warehouse_id)
VALUES
    (1, 6, '2025-11-13 09:52:45.603618', 8),
    (2, 57, '2025-11-13 20:53:54.254818', 10);
