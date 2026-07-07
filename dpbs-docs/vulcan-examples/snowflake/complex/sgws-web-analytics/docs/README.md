# SGWS Web Analytics - Snowflake Migration

Complete reference guide for the Spark → Snowflake migration and ongoing maintenance.

## 📁 Documentation

- **[PIPELINE-ERRORS-FIXED.md](PIPELINE-ERRORS-FIXED.md)** - Spark → Snowflake SQL dialect fixes and troubleshooting
- **[PRD-web-heartbeat.md](PRD-web-heartbeat.md)** - Product requirements for Web Heartbeat model

---

## 🎯 Quick Reference

### Common Spark → Snowflake Conversions

| Spark Pattern | Snowflake Equivalent |
|---------------|---------------------|
| `'yyyMMdd'` / `'yyyyMMdd'` | `'YYYYMMDD'` |
| `'yyyMM'` | `'YYYYMM'` |
| `collect_set(col)` | `ARRAY_AGG(DISTINCT col)` |
| `btrim(col)` | `TRIM(col)` |
| `size(array)` | `ARRAY_SIZE(array)` |
| `datediff(end, start)` | `datediff(day, start, end)` |
| `CAST(x AS INT)` | `TRY_CAST(x AS INT)` |
| `AS STRING` | `AS VARCHAR` (preferred) |

### Project Structure

```
sgws-web-analytics/
├── config.yaml              # Main configuration
├── config-deploy.yaml       # DataOS deployment config
├── domain-resource.yaml     # DataOS resource definition
├── .env                     # Local credentials
├── models/
│   ├── seeds/              # SEED models (32 files)
│   ├── bronze/             # Bronze layer (43 models)
│   ├── silver/             # Silver layer (5 models)
│   └── gold/               # Gold layer (6 models)
├── seeds/                  # CSV/TSV data files (35 files)
├── checks/                 # Data quality checks (6 files)
├── semantics/              # Semantic layer (6 models)
└── docs/                   # Documentation
```

---

## 🚀 Migration Summary

### ✅ Completed

| Layer | Status | Count | Details |
|-------|--------|-------|---------|
| **Seeds** | ✅ Complete | 32 models | CSV/TSV files loaded to Snowflake |
| **Bronze** | ✅ Complete | 43 models | Raw data with type casting |
| **Silver** | ✅ Complete | 5 models | Enriched/joined data |
| **Gold** | ✅ Complete | 6 models | Business-ready analytics |
| **Checks** | ✅ Complete | 6 checks | Quality validations |
| **Semantics** | ✅ Complete | 6 models | Semantic layer definitions |

### Key Fixes Applied

1. **Date Format Conversions** - All date format strings updated to uppercase YYYY
2. **Function Compatibility** - Replaced Spark-specific functions (collect_set, btrim, size, datediff)
3. **Type Safety** - Added TRY_CAST for graceful error handling
4. **Column Headers** - Added headers to TSV lookup files for proper column mapping
5. **Encoding** - Converted TSV files to UTF-8
6. **Authentication** - Configured key-pair auth for Snowflake
7. **Dialect Specification** - Added explicit `dialect: snowflake` to EFDP models
8. **Semantic Mapping** - Converted all column references to UPPERCASE

---

## 📊 Data Pipeline

```
CSV/TSV Files (seeds/)
        ↓
    SEED Models (32)
        ↓
    Bronze Layer (43)
    ├── Bronze lookups (13)
    ├── Bronze MINI_O (19)
    ├── Bronze EFDP (4)
    └── Bronze compat (7)
        ↓
    Silver Layer (5)
    ├── adobe_hits_named
    ├── adobe_hits_enriched
    ├── customer
    ├── orders
    ├── product
    └── sales
        ↓
    Gold Layer (6)
    ├── adobe_checkout
    ├── web_heartbeat
    ├── customer
    ├── orders
    ├── product
    └── sales
        ↓
    Semantic Layer (6)
    └── Business metrics & KPIs
```

---

## 🔧 Troubleshooting

### Issue: Date format errors
**Solution:** See [PIPELINE-ERRORS-FIXED.md](PIPELINE-ERRORS-FIXED.md)

### Issue: Semantic validation errors
**Solution:** Ensure all column references in semantic YAMLs are UPPERCASE to match Snowflake's identifier handling
