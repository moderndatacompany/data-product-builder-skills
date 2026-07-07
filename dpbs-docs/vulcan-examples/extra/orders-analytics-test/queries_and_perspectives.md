# Orders Analytics - Queries & Perspectives

This document contains example queries without filters and their corresponding perspective creation commands for the Orders Analytics data product.

---

## 1. RFM Customer Segmentation Analysis

### Query 1.1: Overall RFM Metrics
```graphql
query OverallRFMMetrics {
  rfm {
    total_customers_rfm
    avg_recency_score
    avg_frequency_score
    avg_monetary_score
    total_rfm_value
    champions_count
    at_risk_count
    lost_customer_count
  }
}
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
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
```graphql
query RFMSegmentationByRegion {
  rfm {
    region_name
    rfm_segment
    total_customers_rfm
    total_rfm_value
    avg_recency_score
    avg_frequency_score
    avg_monetary_score
  }
}
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
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
```graphql
query CustomerLifetimeValueAnalysis {
  rfm {
    customer_name
    email
    region_name
    monetary_value
    frequency_orders
    recency_days
    rfm_segment
    recommended_action
  }
}
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
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

## 2. Daily Sales Analysis

### Query 2.1: Daily Sales Performance Overview
```graphql
query DailySalesPerformance {
  daily_sales {
    total_daily_orders
    total_daily_revenue
    avg_order_value_across_days
    total_items_sold_agg
    total_shipments_agg
    avg_shipment_rate
  }
}
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
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
```graphql
query SalesTrendsByDate {
  daily_sales {
    order_date
    total_daily_orders
    total_daily_revenue
    avg_order_value_across_days
    total_shipments_agg
    avg_shipment_rate
  }
}
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
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
```graphql
query RegionalSalesPerformance {
  daily_sales {
    region_name
    total_daily_orders
    total_daily_revenue
    avg_order_value_across_days
    total_items_sold_agg
    avg_shipment_rate
  }
}
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
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

## 3. Sales Funnel Analysis

### Query 3.1: Complete Sales Funnel Metrics
```graphql
query CompleteSalesFunnel {
  sales_funnel {
    total_registered_customers
    total_ordering_customers
    total_orders_in_funnel
    total_orders_with_items
    total_shipped_orders
    avg_registration_conversion
    avg_order_to_shipment_conversion
    avg_overall_conversion
    total_registration_dropoff
    total_unfulfilled_orders
  }
}
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
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
```graphql
query FunnelPerformanceByRegion {
  sales_funnel {
    region_name
    total_registered_customers
    total_ordering_customers
    total_orders_in_funnel
    total_shipped_orders
    avg_registration_conversion
    avg_order_to_shipment_conversion
    avg_overall_conversion
  }
}
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
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
```graphql
query FunnelTrendsOverTime {
  sales_funnel {
    funnel_date
    total_registered_customers
    total_ordering_customers
    total_orders_in_funnel
    total_shipped_orders
    avg_overall_conversion
    total_registration_dropoff
    total_unfulfilled_orders
  }
}
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
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
```graphql
query CustomerOverviewMetrics {
  customer_profile {
    total_customers
    total_customer_revenue
    avg_customer_lifetime_value
    avg_orders_per_customer
    avg_items_per_customer
    high_value_customer_count
    churned_customer_count
  }
}
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
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
```graphql
query CustomerSegmentationAnalysis {
  customer_profile {
    customer_segment
    total_customers
    total_customer_revenue
    avg_customer_lifetime_value
    avg_orders_per_customer
  }
}
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
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

### Query 4.3: Customer Profile Details
```graphql
query CustomerProfileDetails {
  customer_profile {
    customer_name
    email
    region_name
    customer_segment
    favorite_category
    first_order_date
    last_order_date
    total_customer_revenue
    avg_orders_per_customer
  }
}
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "name": "Customer Profile Details",
  "description": "Detailed customer profiles with contact information, location, segment, purchase history, and behavioral patterns",
  "statement_id": "REPLACE_WITH_STATEMENT_ID",
  "slug": "customer-profile-details",
  "tags": ["customer", "profile", "detail"],
  "is_public": true,
  "auto_refresh": true
}'
```

---

### Query 4.4: Regional Customer Analysis
```graphql
query RegionalCustomerAnalysis {
  customer_profile {
    region_name
    total_customers
    total_customer_revenue
    avg_customer_lifetime_value
    high_value_customer_count
    churned_customer_count
  }
}
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
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

## 5. Cross-Model Analysis

### Query 5.1: Complete Business Overview
```graphql
query CompleteBusinessOverview {
  daily_sales {
    total_daily_orders
    total_daily_revenue
    avg_order_value_across_days
  }
  customer_profile {
    total_customers
    avg_customer_lifetime_value
    high_value_customer_count
  }
  sales_funnel {
    avg_overall_conversion
    total_registration_dropoff
  }
  rfm {
    champions_count
    at_risk_count
    lost_customer_count
  }
}
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "name": "Complete Business Overview",
  "description": "Executive dashboard showing key metrics across sales, customers, funnel performance, and RFM segmentation in a single view",
  "statement_id": "REPLACE_WITH_STATEMENT_ID",
  "slug": "complete-business-overview",
  "tags": ["executive", "overview", "kpi"],
  "is_public": true,
  "auto_refresh": true
}'
```

---

### Query 5.2: Revenue and Customer Health
```graphql
query RevenueAndCustomerHealth {
  daily_sales {
    total_daily_revenue
    avg_order_value_across_days
  }
  customer_profile {
    total_customer_revenue
    avg_customer_lifetime_value
    churned_customer_count
  }
  rfm {
    total_rfm_value
    champions_count
    at_risk_count
  }
}
```

**Perspective Creation:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/' \
--header 'Content-Type: application/json' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "name": "Revenue and Customer Health",
  "description": "Combined view of revenue metrics and customer health indicators showing sales performance and customer engagement status",
  "statement_id": "REPLACE_WITH_STATEMENT_ID",
  "slug": "revenue-customer-health",
  "tags": ["revenue", "customer-health", "mrr"],
  "is_public": true,
  "auto_refresh": true
}'
```

---

## Usage Instructions

### Step 1: Execute Query
First, execute the GraphQL query against your Vulcan endpoint to get the `statement_id`.

**Endpoint:**
```
POST https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/graphql
```

**Example using curl:**
```bash
curl --location 'https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/graphql' \
--header 'Content-Type: application/json' \
--header 'Cookie: connect.sid=s%3ALIeDaXoa_rmZexXG0ji89CwKV4FldUF7.hO0R0VvLMiBL1sLpuoJoBKS5LP65NkM%2F1WFZXwlB2%2B0' \
--data '{
  "query": "YOUR_GRAPHQL_QUERY_HERE"
}'
```

### Step 2: Extract Statement ID
From the response, extract the `statement_id` value. This uniquely identifies your query execution.

### Step 3: Create Perspective
Replace `REPLACE_WITH_STATEMENT_ID` in the perspective creation curl command with your actual `statement_id` and execute the command.

### Step 4: Access Your Perspective
Once created, you can access your perspective using:
```
https://desert-011726.dataos.cloud/engineering/vulcan/orders360/api/v1/perspectives/{slug}
```

---

## Notes

1. **No Filters Applied**: All queries are designed without filters to provide complete data views
2. **Auto Refresh**: All perspectives are configured with `auto_refresh: true` for real-time updates
3. **Public Access**: All perspectives are set to `is_public: true` - adjust based on your security requirements
4. **Tags**: Each perspective includes relevant tags for easy discovery and organization
5. **Statement ID**: Make sure to replace `REPLACE_WITH_STATEMENT_ID` with the actual statement ID from your query execution

---

## Additional Query Ideas

You can also create variations by:
- Combining different measures from the same model
- Adding multiple dimensions for deeper drill-downs
- Creating joined queries across customer_profile, daily_sales, and rfm models
- Building time-based comparisons using different date dimensions


