# Orders360 - Postgres Mini Example

A minimal e-commerce data product demonstrating Vulcan's core capabilities with a simple orders, customers, and products domain.

## Objective

Build a lightweight sales analytics pipeline that:
- Ingests raw transactional data (customers, orders, products)
- Transforms into daily sales aggregations
- Exposes semantic layer for BI tools and analytics

## User Story

**As a** Sales Operations Manager,  
**I want** a daily view of order volumes and revenue,  
**So that** I can track sales performance and identify trends.

### Business Context

The marketing team runs campaigns across multiple channels and needs to measure their impact on daily sales. Currently, they rely on manual spreadsheet exports that are error-prone and outdated by the time they're reviewed.

### Key Questions This Data Product Answers

1. **How many orders did we process yesterday?**  
   → Query `total_orders` from `daily_sales`

2. **What was our revenue for last week?**  
   → Use weekly granularity on `order_date` with `total_daily_revenue` measure

3. **Which days exceeded our $100 daily target?**  
   → Apply the `high_revenue_days` segment

4. **Are there any data quality issues in incoming orders?**  
   → Automated checks validate completeness, uniqueness, and value ranges

### Stakeholders

| Role | Usage |
|------|-------|
| Sales Manager | Daily dashboard for revenue tracking |
| Marketing Analyst | Campaign performance correlation |
| Finance Team | Monthly revenue reconciliation |
| Data Engineer | Pipeline health monitoring |

## Project Structure

```
postgres-mini/
├── seeds/                  # Raw CSV data files
├── models/
│   ├── seeds/              # Seed model definitions (raw data ingestion)
│   └── daily_sales.sql     # Aggregated daily sales model
├── semantics/              # Semantic layer definitions
├── checks/                 # Data quality checks (Soda-style)
├── tests/                  # Unit tests for models
├── audits/                 # Custom audit definitions
└── config.yaml             # Project configuration
```

## Data Models

### Seed Models (Raw Layer)

| Model | Description | Grain |
|-------|-------------|-------|
| `raw.raw_customers` | Customer master data | `customer_id` |
| `raw.raw_orders` | Order transactions | `order_id` |
| `raw.raw_products` | Product catalog | `product_id` |

### Transformation Models

| Model | Description | Grain | Schedule |
|-------|-------------|-------|----------|
| `sales.daily_sales` | Daily aggregated sales metrics | `order_date` | `@daily` |

**Daily Sales** aggregates orders by date with:
- `total_orders` - Count of orders per day
- `total_revenue` - Sum of order amounts per day
- `last_order_id` - Latest order ID processed

## Semantic Layer

The semantic layer (`semantics/daily_sales.yml`) provides:

**Dimensions** with time granularities:
- `order_date` (weekly, monthly, quarterly rollups)

**Measures**:
- `total_daily_orders` - Sum of orders across date range
- `total_daily_revenue` - Sum of revenue across date range

**Segments**:
- `high_revenue_days` - Days with $100+ revenue

## Data Quality

### Assertions (Model-level)
- Unique grain validation
- Not-null constraints on required columns
- Positive value checks on amounts

### Checks (Soda-style)
- Completeness checks (missing counts, row counts)
- Validity checks (negative values, data consistency)
- Anomaly detection on row counts

## Quick Start

```bash
# Start infrastructure
make setup

# plan to see changes
vulcan plan
```

## Configuration

- **Dialect**: PostgreSQL
- **State Store**: PostgreSQL

