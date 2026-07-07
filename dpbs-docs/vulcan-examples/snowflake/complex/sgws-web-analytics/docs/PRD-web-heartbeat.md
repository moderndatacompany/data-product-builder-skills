# PRD: SGWS Web Analytics - Web Heartbeat Data Product

> **Version**: 1.0  
> **Status**: Draft  
> **Owner**: Rohit & SGWS Team  
> **Domain**: Analytics  
> **Created**: January 2026  
> **Stack**: Vulcan + Spark + Medallion Architecture + Iceberg

---

## 1. Business Context

### 1.1 Goal & Outcomes

Build a **production-grade web analytics data product** that provides unified metrics for SGWS's "Proof" e-commerce platform. The product enables cross-functional teams to:

- **Analyze user session behavior** across Web and Mobile App platforms
- **Track conversion funnels**: Page Views → Add to Cart → Checkout
- **Measure search effectiveness** and product discovery patterns
- **Evaluate campaign attribution** and marketing ROI
- **Compare device/platform performance**: Desktop vs Mobile Web vs Mobile App
- **Monitor product list effectiveness**: Favorites, Ready to Reorder, Customers Like You

### 1.2 Success Metrics

| KPI | Target | Current |
|-----|--------|---------|
| Session-to-Checkout Conversion | > 3% | TBD |
| Search Conversion Rate | > 5% | TBD |
| Bounce Rate | < 40% | TBD |
| Page Load Time | < 3 sec | TBD |
| Data Freshness SLA | T+1 (24 hours) | ✅ |

### 1.3 Consumers & Consumption Modes

| Consumer | Use Case | Access Method |
|----------|----------|---------------|
| **Marketing Team** | Campaign performance, user acquisition, UTM attribution, email campaign effectiveness | Dashboards, REST API |
| **Product Team** | Feature engagement, search performance, UX insights, page load metrics, list type effectiveness | Dashboards, REST API |
| **Finance Team** | Revenue metrics, checkout cart values, add-to-cart revenue, conversion attribution | Dashboards |
| **Sales Team** | Customer behavior insights, account engagement patterns, sales bucket analysis | Dashboards |
| **Data Science** | Predictive modeling, customer segmentation, recommendation optimization | REST API, Direct SQL |
| **Downstream Apps** | Real-time personalization, alerting systems | REST/GraphQL APIs |

---

## 2. Vulcan-First Specification

### 2.1 Grain

**Hit/Event Level** — Each row represents a single user interaction on the Proof e-commerce platform:
- Page views
- Clicks (product clicks, navigation clicks)
- Add to cart events
- Checkout completions
- Search queries
- Impressions

This grain allows aggregation to:
- **Session level** (via `sessionid`)
- **Visitor level** (via `visitorid`)
- **Account level** (via `account_unique_id`)
- **Daily level** (via `date`)

### 2.2 Entities

| Entity | Primary Key | Type | Description |
|--------|-------------|------|-------------|
| **web_heartbeat** | `uuid` | Fact | Core fact table with Adobe Analytics hit-level data, derived session metrics, list classifications, device categorization, and business event flags |
| **customer** | `customer_id` | Dimension | Customer attributes: account details, sales bucket, premise type, geographic info, Proof eligibility |
| **product** | `product_id` | Dimension | Product hierarchy, brand attributes, status information |
| **sales** | `sales_id` | Fact | Sales transactional data with revenue metrics |
| **orders** | `order_number` | Fact | Order-level transaction details |

### 2.3 Entity Relationships

```
web_heartbeat (fact)
    │
    ├──► customer (dimension)
    │    JOIN: account_unique_id = accountid
    │    Relationship: many_to_one
    │
    └──► product (dimension)
         JOIN: site_item_key = site_item_pk_product
         Relationship: many_to_one
```

### 2.4 Primary Time

| Field | Type | Description |
|-------|------|-------------|
| `date_time` | TIMESTAMP | When the session or specific event took place |

**Partitioning**: Partitioned by `day(date_time)` for efficient querying and storage optimization.

### 2.5 Dimensions

#### Time Dimensions
| Dimension | Type | Description |
|-----------|------|-------------|
| `date` | time | Date when the session occurred |
| `date_time` | time | Full timestamp of the event |
| `campaign_launchdate` | time | Campaign launch date for attribution |

#### Identity Dimensions
| Dimension | Type | Description |
|-----------|------|-------------|
| `uuid` | string | Primary key for web_heartbeat |
| `hitid` | string | Unique identifier for each hit on site |
| `sessionid` | string | Unique session identifier (derived from visid_high, visid_low, visit_num) |
| `visitorid` | string | Visitor identifier for cross-session tracking |
| `account_unique_id` | string | Unique account identifier linking to customer |
| `adobe_ecid` | string | Adobe Experience Cloud ID |
| `cart_id` | string | Shopping cart identifier |
| `order_number` | string | Unique order identifier |

#### Page & Navigation Dimensions
| Dimension | Type | Description |
|-----------|------|-------------|
| `page_type` | string | Classification: sgwshomepage, productdetails, myfavoritespage, ready2reorder, etc. |
| `page_url` | string | Full URL of the visited page |
| `pagename` | string | Human-readable page label |
| `previous_page_type` | string | Previous page in the journey |

#### Event Dimensions
| Dimension | Type | Description |
|-----------|------|-------------|
| `event_name` | string | Name of the tracked event/action |
| `event_category` | string | Category grouping for events |
| `event_action` | string | Specific action performed |
| `event_label` | string | Additional event context |
| `event_list` | string | Comma-separated list of event codes |

#### Device & Platform Dimensions
| Dimension | Type | Description |
|-----------|------|-------------|
| `device_category` | string | Desktop, Tablet, Mobile App, Mobile Web |
| `digital_platform` | string | App or Web |
| `operating_system` | string | User's operating system |

#### Behavioral Dimensions
| Dimension | Type | Description |
|-----------|------|-------------|
| `is_authenticated` | boolean | Whether visitor is logged in |
| `isbounce` | boolean | Single-page session indicator |
| `isexit` | boolean | Exit page indicator |
| `islandingpage` | boolean | Entry page indicator |
| `new_user_label` | string | New user vs repeating user |
| `authentication_status` | string | Logged in, guest, etc. |

#### List & Recommendation Dimensions
| Dimension | Type | Description |
|-----------|------|-------------|
| `list_type` | string | Favorites, My List, Previously Purchased, Ready to Reorder, Customers Like You, Frequently Bought Together |
| `list_sub_type` | string | List Page or Other Page (recommendation context) |
| `list_algorithmic_type` | string | Algorithmic vs Non-Algorithmic classification |

#### Campaign & Attribution Dimensions
| Dimension | Type | Description |
|-----------|------|-------------|
| `campaign_name` | string | Marketing campaign name from UTM parameters |
| `utm_content` | string | UTM content parameter for A/B testing |
| `deals_type` | string | Solid Deals, Combo Deals, Assorted Deals, Mix & Match |

#### Search Dimensions
| Dimension | Type | Description |
|-----------|------|-------------|
| `search_keywords` | string | Search terms entered by users |
| `post_search_keywords` | string | Processed search keywords |

#### Customer Dimensions (via join)
| Dimension | Type | Description |
|-----------|------|-------------|
| `customer_premise` | string | On Premise, Off Premise, Any |
| `sales_bucket` | string | Revenue tier: $0-25k, $25k-$50k, ..., $500k+ |
| `channel` | string | Customer channel from TDLinx |
| `subchannel` | string | Customer sub-channel |
| `site_name` | string | Site/location name |
| `site_region` | string | Geographic region |

### 2.6 Measures

#### Session Measures
| Measure | SQL | Description |
|---------|-----|-------------|
| `account_sessions` | `COUNT(DISTINCT sessionid)` | Total sessions recorded |
| `authenticated_account_sessions` | `COUNT(DISTINCT sessionid) FILTER(WHERE account_unique_id IS NOT NULL OR authentication_status = 'logged in')` | Sessions from authenticated users |
| `unique_users` | `COUNT(DISTINCT adobe_ecid)` | Total unique visitors |
| `total_accounts_visiting` | `COUNT(DISTINCT account_unique_id)` | Unique accounts visiting |

#### Engagement Measures
| Measure | SQL | Description |
|---------|-----|-------------|
| `total_page_views` | `COUNT(DISTINCT CASE WHEN page_event = 0 THEN hitid END)` | Total page views |
| `total_hits` | `COUNT(DISTINCT hitid)` | Total hits/interactions |
| `total_impressions` | `COUNT(DISTINCT CASE WHEN event_list LIKE '%201%' THEN hitid END)` | Product impressions |
| `total_product_impressions` | `COUNT(DISTINCT CASE WHEN event_list LIKE '%201%' THEN product_id || hitid END)` | Impressions per product |
| `total_clicks` | `COUNT(DISTINCT CASE WHEN event_list LIKE '%202%' OR '%20170%' THEN hitid END)` | Click events |
| `total_product_clicks` | `COUNT(DISTINCT CASE WHEN event_list LIKE '%279%' THEN hitid END)` | Product clicks |

#### Conversion Measures
| Measure | SQL | Description |
|---------|-----|-------------|
| `total_addtocart` | `COUNT(DISTINCT CASE WHEN event_list LIKE '%12%' THEN hitid END)` | Add to cart events |
| `total_checkouts` | `COUNT(DISTINCT CASE WHEN event_list LIKE '%1%' THEN hitid END)` | Checkout completions |
| `total_orders_placed` | `COUNT(DISTINCT order_number)` | Unique orders placed |
| `pdp_views` | `SUM(CASE WHEN page_type = 'productdetails' THEN 1 ELSE 0 END)` | Product detail page views |

#### Revenue Measures
| Measure | SQL | Description |
|---------|-----|-------------|
| `total_atc_cart_value` | `SUM(atc_rev)` | Revenue from add-to-cart events |
| `total_checkout_cart_value` | `SUM(revenues)` | Revenue from checkouts |
| `total_payment_amount` | `SUM(payment_amount)` | Total payment amounts |

#### Quality Measures
| Measure | SQL | Description |
|---------|-----|-------------|
| `bounce_hit` | `COUNT(DISTINCT CASE WHEN isbounce THEN hitid END)` | Bounced hits |
| `total_landingpage_hits` | `COUNT(DISTINCT CASE WHEN islandingpage THEN hitid END)` | Landing page hits |
| `time_spent` | `SUM(date_diff('second', post_cust_hit_time_gmt, next_hit_cust_hit_time))` | Time spent on site (seconds) |

#### Search Measures
| Measure | SQL | Description |
|---------|-----|-------------|
| `total_searches` | `COUNT(DISTINCT CASE WHEN event_list LIKE '%205%' THEN hitid END)` | Search hits |
| `search_sessions` | `COUNT(DISTINCT CASE WHEN event_list LIKE '%205%' THEN sessionid END)` | Sessions with search |
| `search_purchase_session` | `COUNT(DISTINCT sessionid) FILTER(WHERE checkout AND post_search_keywords IS NOT NULL)` | Search sessions that converted |

### 2.7 Metrics (Derived)

| Metric | Formula | Description |
|--------|---------|-------------|
| **conversion_rate** | `checkout_sessions / authenticated_sessions` | Purchase conversion rate |
| **bounce_rate** | `bounce_hit / total_landingpage_hits` | Single-page visit percentage |
| **exit_rate** | `exit_hits / total_page_views` | Exit rate from pages |
| **click_through_rate** | `total_product_clicks / total_product_impressions` | Product click-through rate |
| **search_conversion_rate** | `search_purchase_session / search_sessions` | Search effectiveness |
| **avg_page_speed_in_sec** | `AVG(total_page_load_time) / 1000` | Average page load time |
| **avg_time_spent_by_user** | `time_spent / unique_users` | Average time per user |
| **orders_per_sessions** | `total_orders_placed / authenticated_sessions` | Orders per authenticated session |

---

## 3. Sources & Lineage

### 3.1 Source Systems

| Source | System | Location | Format | Volume | Refresh |
|--------|--------|----------|--------|--------|---------|
| **Adobe Analytics** | S3 | `sglakehouse:adobe_analytics_data/adobe_analytics_data__2026` | Iceberg (Parquet) | 100M+ rows/day | Daily |
| **Customer** | Redshift | `onelakehouse:flash/customer` | Iceberg | ~500K records | Daily |
| **Product** | Redshift | `onelakehouse:flash/product` | Iceberg | ~100K records | Daily |
| **Sales** | Redshift | `onelakehouse:flash/sales` | Iceberg | ~10M rows/day | Daily |
| **Orders** | Redshift | `onelakehouse:flash/orders` | Iceberg | ~5M rows/day | Daily |
| **SFMC Click** | Redshift | `onesourceplus:ent_staging_sf/v_tbl_sfmc_click_stg` | Iceberg | Campaign data | Daily |
| **User Agent Lookup** | S3 | `sglakehouse:adobe_analytics_data/` | Iceberg | Reference | Weekly |

### 3.2 Data Lineage (Medallion Architecture)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DATA LINEAGE                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  SOURCES              BRONZE              SILVER              GOLD           │
│  ════════             ══════              ══════              ════           │
│                                                                              │
│  S3 Adobe ─────────► adobe_raw ────────► adobe_cleaned ────► web_heartbeat  │
│  Analytics            (External)          (Incremental)       (Incremental) │
│                       - Raw data          - Dedupe            - Business    │
│                       - Append-only       - Type cast           logic       │
│                                           - Nullify           - Joins       │
│                                           - Standardize       - Aggregations│
│                                                                              │
│  Redshift ─────────► customer_raw ─────► customer_cleaned ──► customer_dim  │
│  Customer             (External)          (Incremental)       (Full)        │
│                       - Active only       - Sales bucket                    │
│                       - Proof eligible    - Premise type                    │
│                                                                              │
│  Redshift ─────────► product_raw ──────► product_cleaned ───► product_dim   │
│  Product              (External)          (Full)              (Full)        │
│                                                                              │
│  SFMC Click ───────► Campaign attribution joins in Gold layer               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Key Transformations

| Transform | Example | Use Case |
|-----------|---------|----------|
| `regex` | `REGEXP_EXTRACT(linkcontent, 'utm_campaign=([^&]+)', 1)` | Campaign extraction |
| `explode` | `LATERAL VIEW EXPLODE(post_product_list)` | Product list explosion |
| `split_part` | `split(product_list, ';')[1]` | Field extraction |
| `case` | `CASE WHEN is_mobile THEN 'Mobile' END` | Classification |
| `concat` | `CONCAT(visid_high, '-', visid_low, '-', visit_num)` | Session ID derivation |
| `nullify` | `CASE WHEN field = '' THEN NULL END` | Data cleaning |

---

## 4. Freshness & Backfill

### 4.1 Data Freshness

| Attribute | Value |
|-----------|-------|
| **Cadence** | Daily (T+1) |
| **Schedule** | 9:50 AM daily (`cron: '50 09 * * *'`) |
| **SLA** | Data available by 12:00 PM for previous day |
| **Timezone** | UTC |

### 4.2 Backfill Requirements

| Attribute | Value |
|-----------|-------|
| **Historical Window** | 180 days rolling |
| **Backfill Strategy** | Incremental by day partition |
| **Recovery Process** | Re-run from Bronze layer |

### 4.3 Data Quality Checks

| Check Type | Table | Column | Rule |
|------------|-------|--------|------|
| NOT NULL | web_heartbeat | uuid | Primary key required |
| UNIQUE | web_heartbeat | uuid | No duplicates |
| NOT NULL | web_heartbeat | sessionid | Session required |
| FRESHNESS | web_heartbeat | date_time | Within 24 hours of current time |
| REFERENTIAL | web_heartbeat | account_unique_id | Exists in customer (when not null) |

---

## 5. Technical Architecture

### 5.1 Vulcan Project Structure

```
web_analytics/
├── config.yaml                    # Gateway & project configuration
│
├── models/
│   ├── bronze/                    # Raw layer (External/Managed)
│   │   ├── adobe_raw.sql
│   │   ├── customer_raw.sql
│   │   ├── product_raw.sql
│   │   ├── sales_raw.sql
│   │   └── orders_raw.sql
│   │
│   ├── silver/                    # Cleaned layer (Incremental)
│   │   ├── adobe_cleaned.sql
│   │   ├── customer_cleaned.sql
│   │   ├── product_cleaned.sql
│   │   ├── sales_cleaned.sql
│   │   └── orders_cleaned.sql
│   │
│   └── gold/                      # Business layer (Incremental)
│       ├── web_heartbeat.sql
│       ├── customer_dim.sql
│       ├── product_dim.sql
│       ├── sales_fact.sql
│       └── orders_fact.sql
│
├── semantics/                     # Semantic Layer (Lens)
│   ├── web_heartbeat.yml          # 40+ dimensions, 30+ measures
│   ├── customer.yml
│   ├── product.yml
│   └── sales.yml
│
├── tests/                         # Automated Tests
│   ├── test_web_heartbeat.yaml
│   ├── test_customer.yaml
│   └── test_sales.yaml
│
├── audits/                        # Custom Audit Queries
│   ├── validate_session_integrity.sql
│   └── validate_revenue_totals.sql
│
├── checks/                        # Data Quality Checks
│   ├── freshness.yml
│   ├── completeness.yml
│   └── uniqueness.yml
│
└── macros/                        # Reusable SQL Macros
    ├── date_utils.sql
    └── session_utils.sql
```

### 5.2 Resource Configuration

```yaml
compute: navigator-compute  # (64 CPU / 512 GB)
resources:
  requests:
    cpu: '8'
    memory: 70Gi
replicas: 1

spark:
  sql.files.maxPartitionBytes: 128MB
  sql.adaptive.enabled: true
  default.parallelism: 512
```

### 5.3 API Exposure

| API Type | Endpoint | Use Case |
|----------|----------|----------|
| REST | `/api/v1/web_heartbeat` | Programmatic access |
| GraphQL | `/graphql` | Flexible querying |
| SQL | Port 5433 (Flash) | Direct SQL access |

---

## 6. Data Products

| Product | Description | API | Consumers |
|---------|-------------|-----|-----------|
| **Web Heartbeat** | Core analytics data product | REST/GraphQL/SQL | All teams |
| **MRR List** | Monthly recurring revenue metrics | REST | Finance, Sales |
| **Adobe List** | Raw web analytics metrics | REST/GraphQL | Marketing, Product |
| **Web Search** | Search behavior analytics | REST/GraphQL | Product, UX |

---

## 7. Open Questions / TODO

- [ ] Define specific data quality thresholds (e.g., completeness > 99%)
- [ ] Document PII/governance requirements
- [ ] Confirm A/B testing dimension requirements
- [ ] Define alerting thresholds for anomaly detection
- [ ] Confirm mobile app vs web parity metrics
- [ ] Document excluded use cases (if any)

---

## 8. Appendix

### 8.1 Event Codes Reference

| Event Code | Event Name | Description |
|------------|------------|-------------|
| 0 | page_view | Page view event |
| 1 | purchase | Checkout completion |
| 12 | add_to_cart | Add to cart event |
| 201 | impression | Product impression |
| 202 | click | Click event |
| 205 | search | Search query |
| 257 | show_deal | Deal view |
| 279 | product_click | Product click |
| 289 | login | Login event |
| 20140 | bulk_add_to_cart | Bulk add to cart |

### 8.2 List Type Classifications

| List Type | Algorithmic Type | Description |
|-----------|------------------|-------------|
| Favorites | Non-Algorithmic | User-saved favorites |
| My List | Non-Algorithmic | User-created lists |
| Previously Purchased | Non-Algorithmic | Purchase history |
| Ready to Reorder | Algorithmic | ML-based recommendations |
| Customers Like You | Algorithmic | Collaborative filtering |
| Frequently Bought Together | Algorithmic | Association rules |

### 8.3 Sales Bucket Classifications

| Bucket | Revenue Range |
|--------|---------------|
| $0-25k | $0 - $25,000 |
| $25k-$50k | $25,000.01 - $50,000 |
| $50k-$75k | $50,000.01 - $75,000 |
| $75k-$100k | $75,000.01 - $100,000 |
| $100k-$200k | $100,000.01 - $200,000 |
| $200k-$300k | $200,000.01 - $300,000 |
| $300k-$400k | $300,000.01 - $400,000 |
| $400k-$500k | $400,000.01 - $500,000 |
| $500k+ | > $500,000.01 |

---

## 9. References

- [Vulcan Documentation](https://tmdc-io.github.io/vulcan-book/)
- [Models Overview](https://tmdc-io.github.io/vulcan-book/Components/Model/Overview/)
- [Semantic Models](https://tmdc-io.github.io/vulcan-book/Components/Semantics/Overview/)
- [Tests](https://tmdc-io.github.io/vulcan-book/Components/Tests/)
- [Audits](https://tmdc-io.github.io/vulcan-book/Components/Audits/)
- [Checks](https://tmdc-io.github.io/vulcan-book/Components/Checks/)
- [Spark Engine](https://tmdc-io.github.io/vulcan-book/Configurations/Engines/Spark/)

---

**Document History**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Jan 2026 | Rohit & SGWS Team | Initial PRD |
