# COBS Scripts – Run Order and Usage

This folder contains **data ingestion** scripts (Snowflake) and the **COBS segmentation** pipeline (Trino/Python).

---

## Recommended: Vulcan with seed-based staging (no Snowflake ingestion)

**You do not need ONESOURCEPLUS or the ingestion scripts** to run Vulcan. The RFM models use **seed-based staging tables** in the `COBS` schema:

- **`cobs.v_d_customer_stage`** ← `seeds/v_d_customer_stage.csv`
- **`cobs.v_fact_sales_stage`** ← `seeds/v_fact_sales_stage.csv`

From `customer-usecase/cobs` with `.env` set (Snowflake key-pair auth for the depot):

```bash
source .env
vulcan plan
```

Apply the plan when prompted. No schema creation or ingestion is required.

---

## Optional: Data ingestion (Snowflake ONESOURCEPLUS)

If you later switch the RFM models to read from **schema `ONESOURCEPLUS`** (e.g. `onesourceplus.v_d_customer`, `onesourceplus.v_fact_sales`), use these scripts in order. They create the schema and tables and load sample data.

| Order | Script | Purpose |
|-------|--------|---------|
| **0** | `create_onesourceplus_schema.py` | Creates schema `ONESOURCEPLUS` in the target database (required first). |
| **1** | `insert_to_snowflake_sales.py` | Creates (if needed) and inserts rows into `onesourceplus.v_fact_sales`. |
| **2** | `fast_create_insert_customer.py` | Creates `onesourceplus.v_d_customer` and inserts from `artifacts/redshift/v_d_customer.csv`. |

**Prerequisites**

- Snowflake account and credentials; database must match Vulcan’s Snowflake depot (e.g. `GENSLER`). Set `SNOWFLAKE_DATABASE` in `.env` if needed.

**Commands**

```bash
cd customer-usecase/cobs
source .env
python scripts/create_onesourceplus_schema.py
python scripts/insert_to_snowflake_sales.py
python scripts/fast_create_insert_customer.py
```

---

## COBS segmentation pipeline (Trino + Python)

The **COBS (Customer Order Behavior Segmentation)** job reads from **Trino** (DataOS Icebase), runs clustering, and writes segment results (and optionally uploads to S3).

| File | Role |
|------|------|
| `main.py` | **Entry point.** Loads config, reads from Trino, runs COBS, writes `segment_result.csv` (and can upload to S3). |
| `clustering_utils.py` | Helpers used by `main.py`: clustering, outperformers, segment mapping. **Do not run directly.** |
| `bq_utils.py` | Provides `load_yml()` for `config.yml`. **Do not run directly.** |

**Data source**

- `main.py` reads from **Trino**: `icebase.sample.twelve_month_records`, `icebase.sample.monthly_records`.
- Set env vars: `DATAOS_FQDN`, `DATAOS_PORT`, `DATAOS_USERNAME`, `DATAOS_API_TOKEN`, `DATAOS_CLUSTER`.

**Config**

1. `cp config.yml.example config.yml`
2. Edit `config.yml`: `rfm_segment_file` (e.g. `../seeds/rfm_segment_mapping.csv`), `sales_buckets`, `segment_value_dict`, etc. (see COBS_DOCUMENTATION.md).

**Run**

```bash
cd customer-usecase/cobs/scripts
python main.py   # with config.yml and Trino env set
```

**Output:** `segment_result.csv` in the current directory (and optional S3 upload).

---

## Quick reference

| Goal | Run |
|------|-----|
| Run Vulcan (recommended; no ingestion) | From `cobs`: `source .env && vulcan plan` |
| Create ONESOURCEPLUS schema (optional) | `python scripts/create_onesourceplus_schema.py` |
| Ingest sales into Snowflake (optional) | `python scripts/insert_to_snowflake_sales.py` |
| Ingest customers into Snowflake (optional) | `python scripts/fast_create_insert_customer.py` |
| Run COBS segmentation (Trino → CSV) | `python main.py` (with `config.yml` + Trino env) |

**Dependencies**

- **Ingestion:** `snowflake-connector-python`
- **COBS:** `trino`, `pandas`, `pyyaml`, `scikit-learn`, `numpy` (and `boto3` if using S3)

```bash
pip install trino pandas pyyaml scikit-learn numpy snowflake-connector-python boto3
```
