## Orders360 — Local Docker + Transpiler + Semantic Queries

This folder is a complete, local, Docker-based Vulcan project for the **Orders360** e-commerce domain.

It includes:
- **Seed data** (`seeds/*.csv`) and seed models (`models/seeds/*.sql`)
- **Transformation models** (`models/*.sql`) into `sales.*`
- **Semantic layer** (`semantics/*.yml`) for measures/dimensions/segments
- **Checks** (`checks/*.yml`) and **unit tests** (`tests/*.yaml`)
- **A seed generator** to create ~1k+ realistic records (`scripts/generate_orders360_seeds.py`)

---

## Prerequisites

- **Docker Desktop** (or Docker Engine) with `docker compose` available
- **Make**
- **Python 3** (only needed if you want to regenerate seeds)

---

## 1) Start the local stack (infra + warehouse)

From the repo root, go to this folder:

```bash
cd orders360
```

Start the required services:

```bash
make setup
```

This does:
- Creates the external Docker network `vulcan`
- Starts:
  - **Statestore** Postgres on `localhost:5431`
  - **MinIO** on `localhost:9000` (console `localhost:9001`)
  - **Warehouse** Postgres on `localhost:5434`

---

## 2) Start Vulcan services (API + transpiler + GraphQL + MySQL wire)

```bash
make vulcan-up
```

Ports:
- **Vulcan API**: `localhost:8000` (docs: `localhost:8000/redoc`)
- **Transpiler**: `localhost:4000`
- **MySQL wire protocol**: `localhost:3306` (optional)
- **MySQL monitoring**: `localhost:8081/livez` (optional)

---

## 3) Set up the `vulcan` CLI alias (after services are up)

Once containers are running, set an alias so you can run Vulcan commands directly:

```bash
alias vulcan="docker run -it --network=vulcan --rm -v .:/workspace tmdcio/vulcan-postgres:${VERSION:-0.228.1}  vulcan"
```

Notes:
- You can override the image version via `VERSION` (otherwise it uses `0.228.1`):

```bash
export VERSION=0.228.1
```

---

## 4) Validate the project (info → plan → transpile → fetchdf)

### 4.1 Project info

```bash
vulcan info
```

### 4.2 Plan (compute local changes)

```bash
vulcan plan
```

### 4.3 Transpile a semantic query

```bash
vulcan transpile --format sql "select measure(total_orders) as discounted_orders, measure(total_discount_amount) as discount_amt from orders where discount_amount > 0"
```

### 4.4 Run a query and view results

```bash
vulcan fetchdf "select * from sales.orders limit 20"
```

---

## 5) Stop everything

From this folder:

```bash
make all-down
```

To stop everything and remove Docker volumes:

```bash
make all-clean
```

---

## Troubleshooting

- **Transpiler can’t connect**: ensure `make vulcan-up` is running and ports `4000/8000` are free.
- **Warehouse port conflict**: `docker/docker-compose.warehouse.yml` binds to `5434`. Change it if needed.
- **MySQL wire protocol auth**: `docker/docker-compose.vulcan.yml` uses Heimdall; you can ignore `vulcan-mysql` unless you specifically need MySQL connectivity.

