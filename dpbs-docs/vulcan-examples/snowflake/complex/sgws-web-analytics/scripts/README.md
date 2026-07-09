# SGWS Web Analytics - Automation Scripts

This folder contains Python scripts used to enhance and generate the SGWS Web Analytics data product.

---

## 📁 Data Generation Scripts

### 1. `generate_seed_data.py`
**Purpose**: Generate comprehensive realistic seed data for all dimension and fact tables

**Features**:
- Generates 10,000 realistic US-based customers
- Creates ~200K sales transactions
- Generates ~50K order records
- Realistic alcohol distributor data (SGWS context)
- US addresses, phone numbers, business names
- Product catalogs with alcohol-specific attributes

**Usage**:
```bash
cd /Users/rohitraj/Dataos/rubik-labs/vulcan-examples/customer-usecase/sgws-web-analytics
python3 scripts/generate_seed_data.py
```

**Generates**:
- `seeds/v_d_customer.csv` (10,000 customers)
- `seeds/v_d_curr_item.csv` (product catalog)
- `seeds/v_d_curr_corp_item.csv` (corporate items)
- Multiple dimension tables (salesperson, attributes, pricing, etc.)

---

### 2. `generate_site_store_data.py`
**Purpose**: Generate realistic distribution sites and retail store locations

**Features**:
- 50 SGWS distribution centers across USA
- 500 retail locations (bars, restaurants, liquor stores)
- Realistic addresses and contact information
- Chain affiliations and store types

**Usage**:
```bash
python3 scripts/generate_site_store_data.py
```

**Generates**:
- `seeds/v_d_site.csv` (50 distribution centers)
- `seeds/v_td_store.csv` (500 retail stores)

---

### 3. `generate_transactions.py`
**Purpose**: Generate high-volume realistic transaction data

**Features**:
- 50,000 sales transactions
- 25,000 order records
- Realistic pricing and quantities
- Date distributions across recent periods
- Valid foreign key relationships

**Usage**:
```bash
python3 scripts/generate_transactions.py
```

**Generates**:
- `seeds/f_sales_all.csv` (50,000 sales records)
- `seeds/f_order_all.csv` (25,000 order records)

---

## 🏷️ Metadata Enhancement Scripts

### 4. `add_model_metadata.py`
**Purpose**: Automatically add comprehensive metadata to Silver and Bronze layer models

**Features**:
- Adds `owner`, `description`, `tags`, `terms`
- Infers column descriptions from names
- Adds column tags based on patterns
- Processes 44 Bronze/Silver models

**Usage**:
```bash
python3 scripts/add_model_metadata.py
```

**Processes**:
- `models/bronze/*/` - All Bronze models
- `models/silver/*/` - All Silver models

---

### 5. `convert_seed_models.py`
**Purpose**: Convert seed models from `SELECT *` to explicit column listings

**Features**:
- Reads CSV headers to extract columns
- Infers data types from column names and values
- Generates explicit SELECT statements
- Adds model-level metadata

**Usage**:
```bash
python3 scripts/convert_seed_models.py
```

**Processes**: All 32 seed models in `models/seeds/`

---

### 6. `update_seed_columns_syntax.py`
**Purpose**: Update seed models to use `columns()` syntax following gensler-qualitrics pattern

**Features**:
- Extracts column info from descriptions
- Builds `columns()` block with types
- Follows Vulcan best practices
- Processes all columns (including 1,178-column hit_data model)

**Usage**:
```bash
python3 scripts/update_seed_columns_syntax.py
```

**Result**: All 32 seeds updated with proper `columns()` definitions

---

### 7. `final_seed_cleanup.py`
**Purpose**: Final cleanup - remove duplicate blocks and standardize types

**Features**:
- Removes duplicate `column_types` blocks
- Changes `STRING` → `VARCHAR` (matches gensler pattern)
- Fixes column_descriptions commas
- Final validation

**Usage**:
```bash
python3 scripts/final_seed_cleanup.py
```

**Result**: Clean, production-ready seed models

---

## 🧹 Utility Scripts

### 8. `clean_seed_models.py`
**Purpose**: Earlier attempt to clean up duplicate blocks (superseded by final_seed_cleanup.py)

### 9. `add_column_types.py`
**Purpose**: Earlier attempt to add column_types (superseded by update_seed_columns_syntax.py)

---

## 📊 Script Execution Order

For a fresh setup, run scripts in this order:

```bash
# 1. Generate all seed data
python3 scripts/generate_seed_data.py
python3 scripts/generate_site_store_data.py
python3 scripts/generate_transactions.py

# 2. Add metadata to models
python3 scripts/add_model_metadata.py

# 3. Convert seed models
python3 scripts/convert_seed_models.py
python3 scripts/update_seed_columns_syntax.py
python3 scripts/final_seed_cleanup.py
```

---

## ✅ Final Output

After running all scripts:
- ✅ **76 models** with comprehensive metadata
- ✅ **3,394 columns** explicitly typed in 32 seed models
- ✅ **~300K seed records** across all CSV files
- ✅ **Production-ready** data product

---

## 📝 Notes

- All scripts are idempotent (safe to re-run)
- Scripts use Python 3.10+ standard library (minimal dependencies)
- Faker library used for realistic data generation
- Scripts follow PEP 8 style guidelines

**Owner**: rohitrajtmdcio  
**Last Updated**: January 30, 2026
