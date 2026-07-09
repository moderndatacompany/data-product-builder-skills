# GA4 Analytics - Vulcan Data Product

> A comprehensive GA4 data product built natively for Vulcan, inspired by the popular [dbt-ga4 package](https://github.com/Velir/dbt-ga4)

## 🚀 Quick Start

This project transforms raw GA4 BigQuery export data into analytics-ready dimensional models and fact tables.

### What's Included

- ✅ **14 SQL Models** - Complete GA4 analytics pipeline (staging + marts)
- ✅ **6 Jinja Macros** - Reusable transformations (unnest, URL parsing, channel grouping)
- ✅ **17 Quality Tests** - Checks, Audits, Signals, and Unit Tests
- ✅ **Complete Documentation** - All-in-one comprehensive guide

## 📚 Complete Documentation

**👉 See [DOCUMENTATION.md](DOCUMENTATION.md) for the complete guide including:**

1. **Project Overview** - Architecture, models, and features
2. **Quick Start Guide** - 5-minute setup with step-by-step instructions
3. **Project Structure** - Model dependencies and file organization
4. **Macros Documentation** - All available Jinja macros with examples
5. **Data Quality & Testing** - Checks, Audits, Signals, and Unit Tests
6. **Project Summary** - Statistics and achievements

## ⚡ 30-Second Setup

```bash
# 1. Update configuration
vim config.yaml              # Add your GCP project
vim external_models.yaml     # Add your BigQuery table

# 2. Deploy and run
vulcan plan
vulcan apply
vulcan run
```

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

## 🎯 Next Steps

1. **Setup**: Follow the Quick Start Guide in [DOCUMENTATION.md](DOCUMENTATION.md#2-quick-start-guide)
2. **Explore**: Review available models in [Project Structure](DOCUMENTATION.md#3-project-structure)
3. **Customize**: Learn about macros in [Macros Documentation](DOCUMENTATION.md#4-macros-documentation)
4. **Test**: Understand quality checks in [Data Quality](DOCUMENTATION.md#5-data-quality--testing)

---

**📖 For complete documentation, troubleshooting, and examples:**  
**→ [DOCUMENTATION.md](DOCUMENTATION.md)**

---

**Built with ❤️ for the Vulcan community** | Based on [dbt-ga4](https://github.com/Velir/dbt-ga4) by Velir

