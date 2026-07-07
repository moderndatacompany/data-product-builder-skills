# GA4 Analytics - Vulcan Data Product

> A comprehensive GA4 data product built natively for Vulcan, inspired by the popular [dbt-ga4 package](https://github.com/Velir/dbt-ga4)

## 🚀 Quick Start

This project transforms raw GA4 BigQuery export data into analytics-ready dimensional models and fact tables.

### What's Included

- ✅ **14 SQL Models** - Complete GA4 analytics pipeline (staging + marts)
- ✅ **6 Jinja Macros** - Reusable transformations (unnest, URL parsing, channel grouping)
- ✅ **17 Quality Tests** - Checks, Audits, Signals, and Unit Tests
- ✅ **Complete Documentation** - All-in-one comprehensive guide

## 📊 Key Models

| Layer | Models | Purpose |
|-------|--------|---------|
| **Staging** | 10 models | Event flattening, key generation, URL parsing |
| **Marts** | 4 models | Analytics-ready dimensions and facts |

### Fact Tables (Ready for BI)
- `fct_ga4__sessions` - Session metrics (page views, conversions, revenue)
- `fct_ga4__pages` - Page metrics (views, users, engagement)

### Dimension Tables
- `dim_ga4__sessions` - Session attributes (device, geo, attribution)
- `dim_ga4__client_keys` - Client/device tracking

## 🛠️ Macros Available

```sql
-- Extract from GA4 arrays
{{ unnest_key('event_params', 'page_location', 'string_value') }}

-- Parse URLs
{{ extract_hostname_from_url('page_location') }}
{{ extract_page_path('page_location') }}
{{ extract_query_parameter_value('page_location', 'utm_source') }}

-- Channel grouping
{{ default_channel_grouping('source', 'medium', 'category', 'campaign') }}
```

## 🔍 Data Quality

- **5 Checks** - Schema-level quality (completeness, validity, uniqueness)
- **6 Audits** - Business logic validations (gclid detection, revenue consistency)
- **3 Signals** - Data availability checks
- **3 Unit Tests** - Model logic validation

## 📈 Sample Query

```sql
-- Top traffic sources
SELECT
  session_default_channel_grouping,
  COUNT(*) as sessions,
  AVG(total_page_views) as avg_pages
FROM ga4_analytics.fct_ga4__sessions
WHERE session_start_date >= CURRENT_DATE - 30
GROUP BY 1
ORDER BY sessions DESC;
```

---

**Built with ❤️ for the Vulcan community** | Based on [dbt-ga4](https://github.com/Velir/dbt-ga4) by Velir
