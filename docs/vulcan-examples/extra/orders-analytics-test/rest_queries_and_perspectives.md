# Orders Analytics - REST API Queries & Perspectives

This document contains REST API queries without filters and their corresponding perspective creation commands for the Orders Analytics data product.

**Base URL:** `https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/query/semantic/rest`

---

## 1. RFM Customer Segmentation Analysis

### Query 1.1: Overall RFM Metrics
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/query/semantic/rest' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
    "query": {
      "measures": [
        "rfm.total_customers_rfm",
        "rfm.avg_recency_score",
        "rfm.avg_frequency_score",
        "rfm.avg_monetary_score",
        "rfm.total_rfm_value",
        "rfm.champions_count",
        "rfm.at_risk_count",
        "rfm.lost_customer_count"
      ],
      "dimensions": [],
      "limit": 1
    },
    "ttl_minutes": 60
}'
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "name": "Overall RFM Metrics Dashboard",
  "description": "Complete view of RFM customer segmentation metrics including recency, frequency, monetary scores and customer counts across all segments",
  "statement_id": "REPLACE_WITH_STATEMENT_ID",
  "slug": "overall-rfm-metrics",
  "tags": ["rfm", "customer-segmentation", "analytics"],
  "is_public": true,
  "auto_refresh": true
}'
```

---

### Query 1.2: RFM Segmentation by Region
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/query/semantic/rest' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
    "query": {
      "measures": [
        "rfm.total_customers_rfm",
        "rfm.total_rfm_value",
        "rfm.avg_recency_score",
        "rfm.avg_frequency_score",
        "rfm.avg_monetary_score"
      ],
      "dimensions": [
        "rfm.region_name",
        "rfm.rfm_segment"
      ],
      "order": {
        "rfm.total_rfm_value": "desc"
      },
      "limit": 100
    },
    "ttl_minutes": 60
}'
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "name": "RFM Segmentation by Region",
  "description": "Regional breakdown of customer RFM segments showing customer counts, lifetime value, and RFM scores by geographic region",
  "statement_id": "REPLACE_WITH_STATEMENT_ID",
  "slug": "rfm-regional-analysis",
  "tags": ["rfm", "regional", "segmentation"],
  "is_public": true,
  "auto_refresh": true
}'
```

---

### Query 1.3: Customer Lifetime Value Analysis
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/query/semantic/rest' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
    "query": {
      "measures": [
        "rfm.total_rfm_value"
      ],
      "dimensions": [
        "rfm.customer_name",
        "rfm.email",
        "rfm.region_name",
        "rfm.monetary_value",
        "rfm.frequency_orders",
        "rfm.recency_days",
        "rfm.rfm_segment",
        "rfm.recommended_action"
      ],
      "order": {
        "rfm.monetary_value": "desc"
      },
      "limit": 100
    },
    "ttl_minutes": 60
}'
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "name": "Customer Lifetime Value Detail",
  "description": "Detailed customer-level view of lifetime value, purchase frequency, recency, and recommended actions for customer engagement",
  "statement_id": "REPLACE_WITH_STATEMENT_ID",
  "slug": "customer-ltv-detail",
  "tags": ["ltv", "customer", "engagement"],
  "is_public": true,
  "auto_refresh": true
}'
```

---

### Query 1.4: RFM Segment Distribution
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/query/semantic/rest' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
    "query": {
      "measures": [
        "rfm.total_customers_rfm",
        "rfm.total_rfm_value",
        "rfm.avg_recency_score",
        "rfm.avg_frequency_score",
        "rfm.avg_monetary_score"
      ],
      "dimensions": [
        "rfm.rfm_segment"
      ],
      "order": {
        "rfm.total_customers_rfm": "desc"
      },
      "limit": 20
    },
    "ttl_minutes": 60
}'
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "name": "RFM Segment Distribution",
  "description": "Distribution of customers across RFM segments with associated metrics and scores",
  "statement_id": "REPLACE_WITH_STATEMENT_ID",
  "slug": "rfm-segment-distribution",
  "tags": ["rfm", "segmentation", "distribution"],
  "is_public": true,
  "auto_refresh": true
}'
```

---

## 2. Daily Sales Analysis

### Query 2.1: Daily Sales Performance Overview
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/query/semantic/rest' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
    "query": {
      "measures": [
        "daily_sales.total_daily_orders",
        "daily_sales.total_daily_revenue",
        "daily_sales.avg_order_value_across_days",
        "daily_sales.total_items_sold_agg",
        "daily_sales.total_shipments_agg",
        "daily_sales.avg_shipment_rate"
      ],
      "dimensions": [],
      "limit": 1
    },
    "ttl_minutes": 60
}'
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "name": "Daily Sales Performance Overview",
  "description": "Comprehensive daily sales metrics including orders, revenue, AOV, items sold, shipments, and fulfillment rates",
  "statement_id": "REPLACE_WITH_STATEMENT_ID",
  "slug": "daily-sales-overview",
  "tags": ["sales", "daily", "performance"],
  "is_public": true,
  "auto_refresh": true
}'
```

---

### Query 2.2: Sales Trends by Date
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/query/semantic/rest' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
    "query": {
      "measures": [
        "daily_sales.total_daily_orders",
        "daily_sales.total_daily_revenue",
        "daily_sales.avg_order_value_across_days",
        "daily_sales.total_shipments_agg",
        "daily_sales.avg_shipment_rate"
      ],
      "dimensions": [
        "daily_sales.order_date"
      ],
      "order": {
        "daily_sales.order_date": "desc"
      },
      "limit": 100
    },
    "ttl_minutes": 60
}'
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "name": "Sales Trends Timeline",
  "description": "Time-series view of daily sales performance showing orders, revenue, AOV, and shipment trends over time",
  "statement_id": "REPLACE_WITH_STATEMENT_ID",
  "slug": "sales-trends-timeline",
  "tags": ["sales", "trends", "timeseries"],
  "is_public": true,
  "auto_refresh": true
}'
```

---

### Query 2.3: Regional Sales Performance
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/query/semantic/rest' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
    "query": {
      "measures": [
        "daily_sales.total_daily_orders",
        "daily_sales.total_daily_revenue",
        "daily_sales.avg_order_value_across_days",
        "daily_sales.total_items_sold_agg",
        "daily_sales.avg_shipment_rate"
      ],
      "dimensions": [
        "daily_sales.region_name"
      ],
      "order": {
        "daily_sales.total_daily_revenue": "desc"
      },
      "limit": 50
    },
    "ttl_minutes": 60
}'
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "name": "Regional Sales Performance",
  "description": "Regional breakdown of sales metrics comparing orders, revenue, AOV, and fulfillment rates across different geographic regions",
  "statement_id": "REPLACE_WITH_STATEMENT_ID",
  "slug": "regional-sales-performance",
  "tags": ["sales", "regional", "comparison"],
  "is_public": true,
  "auto_refresh": true
}'
```

---

### Query 2.4: Sales by Region and Date
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/query/semantic/rest' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
    "query": {
      "measures": [
        "daily_sales.total_daily_orders",
        "daily_sales.total_daily_revenue",
        "daily_sales.avg_order_value_across_days"
      ],
      "dimensions": [
        "daily_sales.region_name",
        "daily_sales.order_date"
      ],
      "order": {
        "daily_sales.order_date": "desc",
        "daily_sales.total_daily_revenue": "desc"
      },
      "limit": 200
    },
    "ttl_minutes": 60
}'
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "name": "Sales by Region and Date",
  "description": "Detailed sales breakdown by region and date showing orders, revenue, and AOV trends",
  "statement_id": "REPLACE_WITH_STATEMENT_ID",
  "slug": "sales-region-date",
  "tags": ["sales", "regional", "daily", "trends"],
  "is_public": true,
  "auto_refresh": true
}'
```

---

## 3. Sales Funnel Analysis

### Query 3.1: Complete Sales Funnel Metrics
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/query/semantic/rest' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
    "query": {
      "measures": [
        "sales_funnel.total_registered_customers",
        "sales_funnel.total_ordering_customers",
        "sales_funnel.total_orders_in_funnel",
        "sales_funnel.total_orders_with_items",
        "sales_funnel.total_shipped_orders",
        "sales_funnel.avg_registration_conversion",
        "sales_funnel.avg_order_to_shipment_conversion",
        "sales_funnel.avg_overall_conversion",
        "sales_funnel.total_registration_dropoff",
        "sales_funnel.total_unfulfilled_orders"
      ],
      "dimensions": [],
      "limit": 1
    },
    "ttl_minutes": 60
}'
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "name": "Complete Sales Funnel Analysis",
  "description": "End-to-end sales funnel metrics from customer registration through order fulfillment, including conversion rates and drop-off analysis",
  "statement_id": "REPLACE_WITH_STATEMENT_ID",
  "slug": "complete-sales-funnel",
  "tags": ["funnel", "conversion", "analytics"],
  "is_public": true,
  "auto_refresh": true
}'
```

---

### Query 3.2: Funnel Performance by Region
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/query/semantic/rest' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
    "query": {
      "measures": [
        "sales_funnel.total_registered_customers",
        "sales_funnel.total_ordering_customers",
        "sales_funnel.total_orders_in_funnel",
        "sales_funnel.total_shipped_orders",
        "sales_funnel.avg_registration_conversion",
        "sales_funnel.avg_order_to_shipment_conversion",
        "sales_funnel.avg_overall_conversion"
      ],
      "dimensions": [
        "sales_funnel.region_name"
      ],
      "order": {
        "sales_funnel.avg_overall_conversion": "desc"
      },
      "limit": 50
    },
    "ttl_minutes": 60
}'
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "name": "Regional Funnel Performance",
  "description": "Regional comparison of sales funnel performance showing conversion rates and customer progression through each funnel stage by region",
  "statement_id": "REPLACE_WITH_STATEMENT_ID",
  "slug": "regional-funnel-performance",
  "tags": ["funnel", "regional", "conversion"],
  "is_public": true,
  "auto_refresh": true
}'
```

---

### Query 3.3: Funnel Trends Over Time
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/query/semantic/rest' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
    "query": {
      "measures": [
        "sales_funnel.total_registered_customers",
        "sales_funnel.total_ordering_customers",
        "sales_funnel.total_orders_in_funnel",
        "sales_funnel.total_shipped_orders",
        "sales_funnel.avg_overall_conversion",
        "sales_funnel.total_registration_dropoff",
        "sales_funnel.total_unfulfilled_orders"
      ],
      "dimensions": [
        "sales_funnel.funnel_date"
      ],
      "order": {
        "sales_funnel.funnel_date": "desc"
      },
      "limit": 100
    },
    "ttl_minutes": 60
}'
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "name": "Funnel Trends Over Time",
  "description": "Time-series analysis of sales funnel performance showing customer progression and conversion trends across different time periods",
  "statement_id": "REPLACE_WITH_STATEMENT_ID",
  "slug": "funnel-trends-timeline",
  "tags": ["funnel", "trends", "timeseries"],
  "is_public": true,
  "auto_refresh": true
}'
```

---

## 4. Customer Profile Analysis

### Query 4.1: Customer Overview Metrics
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/query/semantic/rest' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
    "query": {
      "measures": [
        "customer_profile.total_customers",
        "customer_profile.total_customer_revenue",
        "customer_profile.avg_customer_lifetime_value",
        "customer_profile.avg_orders_per_customer",
        "customer_profile.avg_items_per_customer",
        "customer_profile.high_value_customer_count",
        "customer_profile.churned_customer_count"
      ],
      "dimensions": [],
      "limit": 1
    },
    "ttl_minutes": 60
}'
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "name": "Customer Overview Dashboard",
  "description": "Comprehensive customer metrics including total customers, revenue, lifetime value, purchase behavior, and segmentation counts",
  "statement_id": "REPLACE_WITH_STATEMENT_ID",
  "slug": "customer-overview-dashboard",
  "tags": ["customer", "overview", "metrics"],
  "is_public": true,
  "auto_refresh": true
}'
```

---

### Query 4.2: Customer Segmentation Analysis
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/query/semantic/rest' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
    "query": {
      "measures": [
        "customer_profile.total_customers",
        "customer_profile.total_customer_revenue",
        "customer_profile.avg_customer_lifetime_value",
        "customer_profile.avg_orders_per_customer"
      ],
      "dimensions": [
        "customer_profile.customer_segment"
      ],
      "order": {
        "customer_profile.total_customer_revenue": "desc"
      },
      "limit": 20
    },
    "ttl_minutes": 60
}'
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "name": "Customer Segmentation Analysis",
  "description": "Breakdown of customers by segment (High Value, Medium Value, Churned, New) with revenue and behavioral metrics for each segment",
  "statement_id": "REPLACE_WITH_STATEMENT_ID",
  "slug": "customer-segmentation-analysis",
  "tags": ["customer", "segmentation", "analysis"],
  "is_public": true,
  "auto_refresh": true
}'
```

---

### Query 4.3: Regional Customer Analysis
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/query/semantic/rest' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
    "query": {
      "measures": [
        "customer_profile.total_customers",
        "customer_profile.total_customer_revenue",
        "customer_profile.avg_customer_lifetime_value",
        "customer_profile.high_value_customer_count",
        "customer_profile.churned_customer_count"
      ],
      "dimensions": [
        "customer_profile.region_name"
      ],
      "order": {
        "customer_profile.total_customer_revenue": "desc"
      },
      "limit": 50
    },
    "ttl_minutes": 60
}'
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "name": "Regional Customer Analysis",
  "description": "Regional breakdown of customer metrics showing customer counts, revenue, lifetime value, and churn patterns by geographic region",
  "statement_id": "REPLACE_WITH_STATEMENT_ID",
  "slug": "regional-customer-analysis",
  "tags": ["customer", "regional", "analysis"],
  "is_public": true,
  "auto_refresh": true
}'
```

---

### Query 4.4: Customer Profile by Region and Segment
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/query/semantic/rest' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
    "query": {
      "measures": [
        "customer_profile.high_value_customer_count",
        "customer_profile.total_customer_revenue",
        "customer_profile.avg_orders_per_customer"
      ],
      "dimensions": [
        "customer_profile.region_name",
        "customer_profile.favorite_category"
      ],
      "order": {
        "customer_profile.total_customer_revenue": "desc"
      },
      "limit": 100
    },
    "ttl_minutes": 60
}'
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "name": "Customer Profile by Region and Category",
  "description": "Cross-dimensional analysis of customers showing regional preferences and favorite product categories with revenue metrics",
  "statement_id": "REPLACE_WITH_STATEMENT_ID",
  "slug": "customer-region-category",
  "tags": ["customer", "regional", "category", "preferences"],
  "is_public": true,
  "auto_refresh": true
}'
```

---

## 5. Cross-Model Combined Analysis

### Query 5.1: Executive Business Overview
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/query/semantic/rest' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
    "query": {
      "measures": [
        "daily_sales.total_daily_orders",
        "daily_sales.total_daily_revenue",
        "daily_sales.avg_order_value_across_days",
        "customer_profile.total_customers",
        "customer_profile.avg_customer_lifetime_value",
        "customer_profile.high_value_customer_count",
        "rfm.champions_count",
        "rfm.at_risk_count"
      ],
      "dimensions": [],
      "limit": 1
    },
    "ttl_minutes": 60
}'
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "name": "Executive Business Overview",
  "description": "High-level executive dashboard showing key metrics across sales, customers, and RFM segmentation in a single view",
  "statement_id": "REPLACE_WITH_STATEMENT_ID",
  "slug": "executive-business-overview",
  "tags": ["executive", "overview", "kpi", "dashboard"],
  "is_public": true,
  "auto_refresh": true
}'
```

---

### Query 5.2: Revenue and Customer Health
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/query/semantic/rest' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
    "query": {
      "measures": [
        "daily_sales.total_daily_revenue",
        "daily_sales.avg_order_value_across_days",
        "customer_profile.total_customer_revenue",
        "customer_profile.avg_customer_lifetime_value",
        "customer_profile.churned_customer_count",
        "rfm.total_rfm_value",
        "rfm.champions_count",
        "rfm.at_risk_count",
        "rfm.lost_customer_count"
      ],
      "dimensions": [],
      "limit": 1
    },
    "ttl_minutes": 60
}'
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "name": "Revenue and Customer Health Dashboard",
  "description": "Combined view of revenue metrics and customer health indicators showing sales performance and customer engagement status",
  "statement_id": "REPLACE_WITH_STATEMENT_ID",
  "slug": "revenue-customer-health",
  "tags": ["revenue", "customer-health", "mrr", "dashboard"],
  "is_public": true,
  "auto_refresh": true
}'
```

---

### Query 5.3: Regional Performance Comparison
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/query/semantic/rest' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
    "query": {
      "measures": [
        "daily_sales.total_daily_revenue",
        "daily_sales.total_daily_orders",
        "customer_profile.total_customers",
        "customer_profile.avg_customer_lifetime_value",
        "sales_funnel.avg_overall_conversion",
        "rfm.champions_count"
      ],
      "dimensions": [
        "daily_sales.region_name"
      ],
      "order": {
        "daily_sales.total_daily_revenue": "desc"
      },
      "limit": 50
    },
    "ttl_minutes": 60
}'
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
--header 'apikey: YXBpX25pbHVzX3Rva2VuX3NocmV5YS5mZDYyY2E3MS1mZTgxLTQ4ZTMtOWNmZi1lODk5MDZhMjkwMWM0ZTNmN2FlYTlhNmQwMTczYmExMDA3MTFmY2M5YWE4Mw==' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "name": "Regional Performance Comparison",
  "description": "Comprehensive regional comparison across sales, customer metrics, funnel conversion, and customer quality",
  "statement_id": "REPLACE_WITH_STATEMENT_ID",
  "slug": "regional-performance-comparison",
  "tags": ["regional", "comparison", "performance", "analytics"],
  "is_public": true,
  "auto_refresh": true
}'
```

---

## Usage Instructions

### Step 1: Execute the REST Query
Run the curl command to execute the query. The response will contain a `statement_id`.

**Example Response:**
```json
{
  "statement_id": "abc123def456...",
  "data": [...],
  "metadata": {...}
}
```

### Step 2: Extract Statement ID
Copy the `statement_id` from the response.

### Step 3: Create Perspective
Replace `REPLACE_WITH_STATEMENT_ID` in the perspective creation command with your actual `statement_id` and execute it.

### Step 4: Verify Perspective Creation
The API will return the created perspective with its details:
```json
{
  "id": "perspective_id",
  "name": "Your Perspective Name",
  "slug": "your-slug",
  "statement_id": "abc123def456...",
  ...
}
```

### Step 5: Access Your Perspective
Access via:
```
https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/{slug}
```

---

## Quick Reference: Available Models and Measures

### RFM Model (`rfm`)
**Measures:**
- `total_customers_rfm`
- `avg_recency_score`
- `avg_frequency_score`
- `avg_monetary_score`
- `total_rfm_value`
- `champions_count`
- `at_risk_count`
- `lost_customer_count`

**Dimensions:**
- `customer_id`, `customer_name`, `email`, `region_name`
- `recency_days`, `frequency_orders`, `monetary_value`
- `recency_score`, `frequency_score`, `monetary_score`
- `rfm_score`, `rfm_segment`, `recommended_action`

---

### Daily Sales Model (`daily_sales`)
**Measures:**
- `total_daily_orders`
- `total_daily_revenue`
- `avg_order_value_across_days`
- `total_items_sold_agg`
- `total_shipments_agg`
- `avg_shipment_rate`

**Dimensions:**
- `order_date`, `region_id`, `region_name`
- `customer_id`, `product_id`

---

### Sales Funnel Model (`sales_funnel`)
**Measures:**
- `total_registered_customers`
- `total_ordering_customers`
- `total_orders_in_funnel`
- `total_orders_with_items`
- `total_shipped_orders`
- `avg_registration_conversion`
- `avg_order_to_shipment_conversion`
- `avg_overall_conversion`
- `total_registration_dropoff`
- `total_unfulfilled_orders`

**Dimensions:**
- `funnel_date`, `region_id`, `region_name`

---

### Customer Profile Model (`customer_profile`)
**Measures:**
- `total_customers`
- `total_customer_revenue`
- `avg_customer_lifetime_value`
- `avg_orders_per_customer`
- `avg_items_per_customer`
- `high_value_customer_count`
- `churned_customer_count`

**Dimensions:**
- `customer_id`, `customer_name`, `email`
- `region_id`, `region_name`
- `first_order_date`, `last_order_date`
- `customer_segment`, `favorite_category`

---

## Notes

1. **No Filters**: All queries have no filters applied to provide complete data views
2. **TTL**: Set to 60 minutes for caching - adjust as needed
3. **Limits**: Configured appropriately per query type (1 for aggregates, 50-200 for dimensional)
4. **Ordering**: Results are ordered by the most relevant metric (usually revenue or customer count)
5. **API Key**: Replace with your actual API key in production
6. **Cross-Model Queries**: Some queries combine measures from multiple models for comprehensive analysis

---

## Tips for Creating Custom Queries

1. **Aggregate Queries**: Use `"limit": 1` with no dimensions for overall metrics
2. **Dimensional Analysis**: Add dimensions and increase limit for breakdowns
3. **Multi-Dimensional**: Combine 2-3 dimensions for deeper insights
4. **Ordering**: Use `"order"` object with `"asc"` or `"desc"` to sort results
5. **Cross-Model**: Mix measures from different models for comprehensive views
6. **Performance**: Keep TTL high for frequently accessed queries to improve performance

