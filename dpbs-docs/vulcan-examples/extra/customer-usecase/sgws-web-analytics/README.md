# SGWS Web Analytics - Snowflake

A production-ready Vulcan project delivering comprehensive web analytics and e-commerce insights through Adobe Analytics integration and EFDP sales data.

## 📋 Overview

This project provides:
- **Web Analytics**: Customer journey tracking, page views, sessions, conversions
- **E-commerce Metrics**: Checkout funnel, cart abandonment, product impressions
- **Sales Intelligence**: Revenue analysis, customer segmentation, order tracking
- **Product Analytics**: Catalog performance, brand insights, category trends

**Data Platform:** Snowflake Cloud Data Warehouse  
**Compute Engine:** Snowflake  
**Data Layers:** Seeds (32) → Bronze (32) → Silver (6) → Gold (6) → Semantics (6)  
**Schema Convention:** `web_analytics_*` (domain-prefixed for multi-tenant organization)

---

## 🚀 Quick Start

### Prerequisites
- Docker + Docker Compose
- Snowflake account with key-pair authentication configured
- Git

### 1. Clone & Setup

```bash
cd vulcan-examples/customer-usecase/sgws-web-analytics
cp .env.example .env
# Edit .env with your Snowflake credentials
```

### 2. Configure Snowflake

Create the database and schemas in Snowflake:

```bash
# See docs/setup_snowflake_database.sql for setup script
# Or run this quick setup:
snowsql -c myconnection -f docs/setup_snowflake_database.sql
```

### 3. Start Local Infrastructure

```bash
# Create Docker network (one-time)
docker network create vulcan || true

# Start Postgres state store + MinIO
docker compose -f docker/docker-compose.infra.yml up -d

# Start Vulcan services
docker compose -f docker/docker-compose.vulcan.yml up -d
```

### 4. Run Pipeline

```bash
# Using Docker alias (recommended)
alias vulcan='docker compose -f docker/docker-compose.vulcan.yml run --rm vulcan-api vulcan'

# Validate project
vulcan info

# Create execution plan
vulcan plan

# Execute pipeline
vulcan run
```

---

## 📁 Project Structure

```
sgws-web-analytics/
├── config.yaml              # Vulcan configuration (Snowflake, state store)
├── config-deploy.yaml       # DataOS deployment configuration
├── domain-resource.yaml     # DataOS resource definition
├── .env                     # Local credentials (gitignored)
├── .env.example             # Template for credentials
│
├── models/                  # SQL model definitions (76 models)
│   ├── seeds/              # SEED models - load CSV/TSV to Snowflake (32)
│   ├── bronze/             # Raw data layer with type casting (32)
│   │   ├── adobe_analytics_raw/  # Adobe lookup tables (14)
│   │   └── redshift_raw/         # Redshift/MINI_O raw extracts (18)
│   ├── silver/             # Enriched data with joins (6)
│   │   ├── adobe_analytics/      # Adobe hit enrichment (2)
│   │   └── redshift_silver/      # EFDP transformations (4)
│   └── gold/               # Business-ready analytics (6)
│
├── seeds/                   # Source data files (35 CSV/TSV files)
│   ├── hit_data_with_headers.csv  # Adobe hit data (~5k rows, 1178 cols)
│   ├── f_order_all.csv           # EFDP orders
│   ├── f_sales_all.csv           # EFDP sales
│   └── *.tsv                     # Lookup tables (browsers, countries, etc.)
│
├── checks/                  # Data quality checks (6 files)
├── semantics/               # Semantic layer definitions (6 models)
├── docker/                  # Docker Compose files
│   ├── docker-compose.infra.yml   # Postgres + MinIO
│   └── docker-compose.vulcan.yml  # Vulcan API + Transpiler
│
├── docs/                    # Documentation
│   ├── README.md                      # Migration guide & troubleshooting
│   ├── PIPELINE-ERRORS-FIXED.md      # SQL dialect fixes
│   ├── SNOWFLAKE-AUTH-SETUP.md       # Authentication setup
│   ├── SNOWFLAKE-DATABASE-SETUP.md   # Database creation
│   └── setup_snowflake_database.sql  # Setup SQL script
│
└── Makefile                 # Common commands

```

---

## 📊 Data Pipeline

```
CSV/TSV Files (35 files in seeds/)
        ↓
    web_analytics_seeds.* (32) - Load to Snowflake
        ↓
    web_analytics_bronze.* (32 models)
    ├── Adobe Analytics lookups (14) - Browser, OS, language, etc.
    └── Redshift raw data (18) - Customer, order, product, sales extracts
        ↓
    web_analytics_silver.* (6 models)
    ├── ADOBE_HITS_NAMED - Hit data with column names
    ├── ADOBE_HITS_ENRICHED - Enriched with lookups
    ├── CUSTOMER - Customer transformations (EFDP)
    ├── ORDERS - Order transformations (EFDP)
    ├── PRODUCT - Product transformations (EFDP)
    └── SALES - Sales transformations (EFDP)
        ↓
    web_analytics_gold.* (6 models)
    ├── ADOBE_CHECKOUT - Checkout funnel analysis
    ├── WEB_HEARTBEAT - Web analytics heartbeat
    ├── CUSTOMER - Customer analytics (filtered, enriched)
    ├── ORDERS - Order analytics (validated)
    ├── PRODUCT - Product analytics (deduplicated)
    └── SALES - Sales analytics (with joins)
        ↓
    SEMANTIC Layer (6 models)
    └── 100+ business metrics & KPIs exposed via GraphQL/REST
```

---

## 🛠️ Common Commands

```bash
# Using Makefile
make info         # Project validation
make plan         # Create execution plan
make run          # Execute pipeline
make query        # Interactive query mode
make logs         # View container logs
make stop         # Stop all services
make clean        # Clean up volumes & state

# Direct Docker commands
docker compose -f docker/docker-compose.vulcan.yml run --rm vulcan-api vulcan info
docker compose -f docker/docker-compose.vulcan.yml run --rm vulcan-api vulcan plan
docker compose -f docker/docker-compose.vulcan.yml run --rm vulcan-api vulcan run
```

---

## 🏗️ Schema Architecture

This project follows a **domain-prefixed schema naming convention** for better organization in multi-tenant environments:

### Schema Naming Convention

| Schema | Purpose | Example Tables |
|--------|---------|----------------|
| `web_analytics_seeds` | Reference/lookup data from CSV/TSV | `BROWSER_TYPE`, `V_D_CUSTOMER` |
| `web_analytics_bronze` | Raw data (no transformations) | `HIT_DATA`, `V_D_CUSTOMER`, `V_FACT_SALES` |
| `web_analytics_silver` | Cleaned & transformed data | `CUSTOMER`, `ORDERS`, `PRODUCT`, `SALES`, `ADOBE_HITS_ENRICHED` |
| `web_analytics_gold` | Business-ready analytics models | `CUSTOMER`, `ORDERS`, `PRODUCT`, `SALES`, `ADOBE_CHECKOUT`, `WEB_HEARTBEAT` |

### Benefits of Domain-Prefixed Schemas

✅ **Multi-Domain Support**: Easy to add other domains (e.g., `sales_analytics_*`, `marketing_analytics_*`)  
✅ **Clear Ownership**: Each domain team owns their schemas  
✅ **Access Control**: Simpler to grant permissions by domain  
✅ **Scalable**: New data products follow the same pattern  
✅ **Business-Friendly**: Users query by domain and quality level

### Example Queries

```sql
-- Query gold layer for customer analytics
SELECT * FROM web_analytics_gold.CUSTOMER WHERE sales_bucket = '$100k-$200k';

-- Query silver layer for raw sales data
SELECT * FROM web_analytics_silver.SALES WHERE posting_date >= '2024-01-01';

-- Query bronze layer for raw Adobe hits
SELECT * FROM web_analytics_bronze.HIT_DATA LIMIT 100;
```

---

## 🔍 Key Features

### Adobe Analytics Integration
- **Hit-level tracking**: ~5000 hit events with 1178 columns
- **Session analytics**: Visit tracking, bounce rate, exit pages
- **Conversion tracking**: Checkout funnel, cart abandonment
- **Product analytics**: Impressions, clicks, add-to-cart events

### EFDP Data Integration
- **Customer data**: Profiles, segments, proof eligibility
- **Order data**: Transactions, status tracking, fulfillment
- **Sales data**: Revenue, invoices, posting dates
- **Product data**: Catalog, pricing, availability

### Semantic Layer
- **50+ web metrics**: Sessions, page views, conversions, bounce rate
- **30+ sales metrics**: Revenue, invoices, wallet share, customer lifetime value
- **Order metrics**: Order counts, approval rates, rejection tracking
- **Customer metrics**: Segmentation, engagement, churn analysis

---

## 📚 Documentation

See `docs/` folder for:
- **Spark → Snowflake migration guide**
- **SQL dialect conversion patterns**
- **Authentication setup (key-pair)**
- **Database creation scripts**
- **Troubleshooting guide**

---

## 🎯 Migration & Refactoring Highlights

This project was successfully migrated from **Spark/Iceberg** to **Snowflake** and refactored to follow best practices:

### Spark → Snowflake Migration
✅ Compute engine: Apache Spark → Snowflake  
✅ SQL dialect: Spark SQL → Snowflake SQL  
✅ Data loading: S3/MinIO → SEED models  
✅ Authentication: Password → Key-pair (JWT)  
✅ Functions: `collect_set`, `btrim`, `size`, `datediff` → Snowflake equivalents  
✅ Date formats: `'yyyMMdd'` → `'YYYYMMDD'`  
✅ Type casting: `CAST` → `TRY_CAST` for safety  

### Medallion Architecture Refactoring
✅ **Removed redundant layers**: Eliminated unnecessary alias/pass-through layers  
✅ **Clear separation**: Raw (Bronze) → Transformed (Silver) → Business (Gold)  
✅ **Proper layer placement**: Moved EFDP transformations from Bronze to Silver  
✅ **Consistent naming**: All schemas follow `web_analytics_*` convention  
✅ **Source organization**: `redshift_raw` and `adobe_analytics_raw` clearly separated  
✅ **No database prefix**: Removed `DEMO.` prefix for simpler queries

### What Stayed the Same
✅ Data lineage preserved  
✅ Business logic unchanged  
✅ Semantic layer intact  
✅ Quality checks maintained  
✅ All 76 models functional  

---

## 🚀 Deployment to DataOS

For production deployment, see `config-deploy.yaml` and `domain-resource.yaml`.

```bash
# Deploy to DataOS
dataos-ctl resource apply -f domain-resource.yaml
```

---

## 📞 Support

- **Documentation**: See `docs/` folder
- **Issues**: Check `docs/PIPELINE-ERRORS-FIXED.md` for common errors
- **Team**: shreya.sikarwar@tmdc.io, kanak.gupta@tmdc.io

---

## 📝 License

Copyright © 2024-2026 TMDC.io. All rights reserved.
