# COBS: Customer Order Behavior Segmentation

## Executive Summary

**COBS (Customer Order Behavior Segmentation)** is a production-grade behavioral analytics framework that transforms raw transactional data into actionable customer intelligence for enterprise distribution businesses. By combining RFM (Recency, Frequency, Monetary) methodology with proof product adoption metrics, COBS enables data-driven customer engagement strategies through automated behavioral segmentation.

---

## Table of Contents

1. [Problem Definition](#problem-definition)
2. [What is COBS?](#what-is-cobs)
3. [COBS Framework Architecture](#cobs-framework-architecture)
4. [Data Requirements](#data-requirements)
5. [Implementation Guide](#implementation-guide)
6. [Customer Segments Explained](#customer-segments-explained)
7. [Consumption & Activation](#consumption--activation)
8. [Configuration Reference](#configuration-reference)
9. [Limitations & Considerations](#limitations--considerations)

---

## Problem Definition

### The Challenge at SGWS

Southern Glazer's Wine & Spirits (SGWS), one of North America's largest wine and spirits distributors, faced a critical challenge: they had vast amounts of customer transactional data, but no effective way to turn it into actionable business intelligence.

**Their data landscape included:**

- Years of historical sales transactions across thousands of customer accounts
- Multiple product categories with varying customer engagement patterns
- Customer data stored in Redshift with limited analytical accessibility
- Rich behavioral signals buried in transaction records—recency of purchases, order frequency, product mix, and spending patterns

**The problem:** Without a systematic way to segment customers based on actual ordering behavior, SGWS was operating with significant blind spots:

- **Marketing teams** couldn't identify which customers were at risk of churning versus which were high-performers worthy of VIP treatment
- **Sales teams** lacked visibility into which accounts showed growth potential versus those that were declining
- **Campaign efforts** were generic and undifferentiated, leading to low engagement rates and inefficient marketing spend
- **Strategic planning** decisions around territory management and resource allocation were made without behavioral insights

The absence of an automated mechanism to classify customers based on their purchase patterns, wallet-share behavior, proof product adoption, and transaction frequency meant that SGWS was essentially treating all customers the same—**missing opportunities** to retain high-value accounts, re-engage declining customers, and nurture promising prospects.

### The Solution Needed

SGWS needed a segmentation framework that could:

✅ Transform raw Redshift transactional data into meaningful behavioral insights  
✅ Automatically classify thousands of customer accounts into actionable segments  
✅ Enable tailored communication strategies for each customer cohort  
✅ Provide early warning signals for at-risk accounts  
✅ Scale reliably as a production-grade capability within their data infrastructure  

To address these challenges in a scalable and repeatable way, the organization needs a structured framework that translates raw transactional behavior into meaningful customer cohorts. **This is where the COBS (Customer Order Behavior Segmentation) framework comes in.**

---

## What is COBS?

### Understanding Proof Products at SGWS

In the wine and spirits distribution business, **"Proof" products** are SGWS's proprietary brand offerings that generate higher margins and stronger customer loyalty compared to standard distributed brands. These products are strategic to SGWS's business because:

- ✅ They **differentiate SGWS** from competitors
- ✅ They command **better profit margins**
- ✅ Customers who adopt proof products tend to have **stronger, longer-lasting relationships** with SGWS
- ✅ Proof product adoption is a **leading indicator of account health and engagement**

For SGWS, tracking "proof" transactions separately from total revenue became critical to understanding customer value and engagement depth.

### The COBS Framework for SGWS

**COBS (Customer Order Behavior Segmentation)** enables SGWS's business teams to understand and act on customer ordering behavior by combining RFM-style analytics with a specific focus on proof product transactions.

For SGWS, this meant transforming millions of transaction records into **eight distinct customer segments** that directly inform how sales and marketing teams should engage each account. Rather than treating a declining $500K hotel chain the same as a new $30K restaurant, COBS gives SGWS teams a clear, data-driven classification system.

### How COBS Works

COBS turns raw transaction data into a unified customer health and behavior layer by:

1. **Segmenting customers by revenue (sales buckets)** to respect differences between small and large accounts. A $10K account has different behavioral patterns than a $500K account, so SGWS segments into five revenue tiers:
   - `1. 0-10K`
   - `2. 10K-50K`
   - `3. 50K-100K`
   - `4. 100K-200K`
   - `5. 200K+`

2. **Scoring customers on RFM-like proof metrics:**
   - **Recency** (`proof_recency`): Days since last proof product purchase—helps identify disengagement
   - **Frequency** (`proof_frequency`): Number of proof product orders in the period—measures adoption depth
   - **Wallet share** (`proof_rev / total_rev`): Percentage of spending on proof products—indicates strategic alignment

3. **Clustering and scoring** these metrics into R-F-W scores:
   - **Recency:** 1–5 (where 1 = recent engagement, 5 = long time since proof purchase)
   - **Frequency:** 1–5 (where 5 = very frequent proof orders)
   - **Wallet share:** 1–4 (where 4 = high proof product concentration)

4. **Mapping R-F-W combinations to eight COBS segments:**
   - Outperformers
   - Web Loyalist
   - Promising
   - Newly Activated
   - Novice
   - Infrequent
   - Lapsed
   - Lost

5. **Comparing 12-month vs 1-month behavior** to detect **"Dropping"** customers—high-value accounts showing sudden declines in wallet share that require immediate sales intervention.

---

## COBS Framework Architecture

### High-Level Workflow

The COBS workflow is a multi-stage data processing and behavioral modeling pipeline executed within DataOS. It transforms 12-month transactional data into engineered RFM features, applies clustering-based scoring, assigns final customer segments, and prepares standardized outputs for downstream analytics, activation, and marketing systems.

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Redshift                             │
│                   (SGWS Source System)                           │
│  • Customer Master Data     • Transaction History                │
│  • Product Catalog          • Regional Hierarchies               │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 │ Flare Workflow (DataOS)
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                    DataOS Lakehouse                             │
│                  (S3-backed Iceberg)                            │
│  • monthly_records (1-month aggregated data)                    │
│  • twelve_month_records (12-month aggregated data)              │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 │ Minerva/Trino Query
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│              Python Segmentation Engine                         │
│  • Clustering & Scoring     • Segment Assignment                │
│  • Dropping Detection       • Output Formatting                 │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                    S3 Storage                                   │
│              (segment_result.csv)                               │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│              Consumption Layer                                  │
│  • Tableau & Superset Dashboards     • Sales Reports            │
└─────────────────────────────────────────────────────────────────┘
```

### COBS Objectives

The goal is to transform raw transactional and customer-level information into high-quality, feature-rich datasets that can reliably power segmentation models and business decision-making.

1. **Define the required data assets** for segmentation by identifying the customer, transactional, and behavioral fields necessary to support downstream modeling.

2. **Ingest and prepare** a unified 12-month transactional dataset within DataOS, ensuring clean, consistent, and analytics-ready inputs for feature engineering.

3. **Generate an RFM-based behavioral feature dataset** using Flare, transforming the curated 12-month data into a structured customer-level feature table.

4. **Train, validate, and score** the segmentation model using the engineered RFM dataset to categorize customers into behavior-based segments.

5. **Produce a standardized segmentation output dataset** containing customer identifiers and assigned segment labels for operational and analytical consumption.

6. **Enable business stakeholders** to consume segmentation results through dashboards, analytical tools, and activation workflows that support marketing, sales, and planning decisions.

---

## Data Requirements

### Source System: AWS Redshift

SGWS's segmentation model requires data from multiple systems within their existing infrastructure:

**Required Data Elements:**

- **Customer Master Data:**
  - Account ID
  - Activation date
  - Customer segment classification
  - Sales channel assignment

- **Sales Transaction Data:**
  - Invoice numbers
  - Invoice dates
  - Line-item revenue (proof vs. non-proof)
  - Product SKUs
  - Transaction types

- **Geographic Attributes:**
  - Customer site location
  - Region
  - Territory assignment

- **Temporal Coverage:**
  - Rolling 12 months of sales activity for trend analysis
  - Most recent 1 month for momentum detection

### Key Metrics Computed

| Metric | Description | Business Purpose |
|--------|-------------|------------------|
| `proof_recency` | Days since last proof product purchase | Identify disengagement early |
| `proof_frequency` | Number of proof product orders in period | Measure adoption depth |
| `wallet_share` | `proof_rev / total_rev` | Track strategic alignment |
| `recency_score` | Clustered score (1-5) for recency | Segment assignment input |
| `frequency_score` | Clustered score (1-5) for frequency | Segment assignment input |
| `wallet_score` | Clustered score (1-4) for wallet share | Segment assignment input |
| `dropping` | Boolean flag for at-risk accounts | Early warning system |

---

## Implementation Guide

### Phase 1: Data Ingestion

**Objective:** Extract 12 months and 1 month of historical customer transaction data from Redshift and load into DataOS Lakehouse (S3-backed Iceberg tables).

#### Pre-requisites

- Read and write access to DataOS Lakehouse
- Running Cluster Resource (Minerva) targeting the DataOS Lakehouse for querying
- Redshift Depot configured in DataOS

#### Steps

1. **Create a Redshift Depot** in DataOS
2. **Execute Flare jobs** for data ingestion:
   - 12-month transaction dataset → `twelve_month_records`
   - 1-month transaction dataset → `monthly_records`

3. **Validate the ingestion:**
   - Row count validation (source vs. destination)
   - Schema validation (all columns present with correct types)
   - Data quality checks (no nulls in critical fields, date ranges correct, revenue non-negative)
   - Sample data inspection (spot-check random samples)

**Output:** Consolidated 12-month and 1-month COBS datasets stored in DataOS Lakehouse, containing all customer, transaction, and proof attributes required for segmentation.

---

### Phase 2: Clustering and Scoring

**Objective:** Transform transaction data into RFM scores and assign behavioral segments using machine learning clustering.

#### Pre-requisites

- Read access to DataOS Lakehouse
- DataOS FQDN, username, token, and cluster name for Trino connection
- Python 3.10+ environment with required packages

#### Project Structure

```
segmentation-project/
├── main.py                    # Main orchestration script
├── clustering_utils.py        # Clustering and segmentation logic
├── utils.py                   # Config loader utilities
├── config.yml                 # Configuration parameters
└── rfw_segments_csv.csv       # RFW-to-segment mapping
```

#### Key Configuration Parameters

**config.yaml highlights:**

```yaml
cobs_date: '2023-10-31'              # Reference date for segmentation
recency_clust_num: 5                  # Number of bins for recency scores
frequency_clust_num: 5                # Number of bins for frequency scores
monetary_clust_num: 4                 # Number of bins for wallet share scores

sales_buckets:                        # Revenue tiers
  - 1. 0-10K
  - 2. 10K-50K
  - 3. 50K-100K
  - 4. 100K-200K
  - 5. 200K+

outperformers_sales_buckets:          # Only these can be Outperformers
  - 4. 100K-200K
  - 5. 200K+

dropping_label: Dropping              # Label for at-risk customers
num_std_devs: 1                       # Std dev threshold for outlier detection
```

#### Segmentation Logic Flow

1. **Connect to DataOS Lakehouse** via Minerva (Trino)
2. **Extract data** from `twelve_month_records` and `monthly_records`
3. **For each sales bucket:**
   - Compute activation cutoff date
   - Build KBinsDiscretizer clustering models for R/F/W metrics
   - Assign recency, frequency, and wallet scores (1-5, 1-5, 1-4)
4. **Identify special segments:**
   - **Newly Activated:** customers activated within cutoff period
   - **Outperformers:** high-frequency outliers (>1 std dev) in top revenue buckets
   - **Lapsed:** customers with zero proof revenue
5. **Map remaining customers** using RFW score combinations (via CSV lookup)
6. **Detect Dropping customers:**
   - Compare 12-month vs 1-month wallet share scores
   - Flag high-value accounts (100K+) with ≥2 point wallet score decline
7. **Clean and format output** with business-friendly column names
8. **Write final CSV** to S3 for consumption

#### Running the Pipeline

```bash
# Install dependencies
pip install pandas numpy scikit-learn trino pyyaml python-dateutil

# Set environment variables
export DATAOS_FQDN="tcp.gentle-akita.dataos.app"
export DATAOS_PORT="7432"
export DATAOS_USERNAME="your_username"
export DATAOS_API_TOKEN="your_token"
export DATAOS_CLUSTER="miniature"

# Run segmentation
python3 main.py
```

**Output:** `segment_result.csv` containing Account ID, Sales Bucket, COBS Segment, RFW scores, revenue metrics, and Dropping flag.

---

## Customer Segments Explained

### The 8 COBS Segments

| Segment | Description | Sales Action | Marketing Action |
|---------|-------------|--------------|------------------|
| **Outperformers** | Top-tier customers with exceptional proof product engagement (frequency outliers in 100K+ revenue buckets) | VIP treatment, exclusive offers, account management | Premium rewards program, early access to new products |
| **Web Loyalist** | High wallet share and consistent proof product ordering | Maintain relationship, upsell opportunities | Loyalty rewards, testimonial requests |
| **Promising** | Growing engagement with proof products, high potential | Nurture with education, proof product sampling | Targeted campaigns, case studies |
| **Newly Activated** | Recently started buying proof products (within cutoff period) | Onboarding, proof product introduction | Welcome series, educational content |
| **Novice** | Low proof engagement but active overall | Proof product education, trials | Cross-sell campaigns, product demos |
| **Infrequent** | Low frequency and/or recency, declining engagement | Re-engagement outreach, incentives | Win-back campaigns, surveys |
| **Lapsed** | Zero proof revenue in 12-month period | Urgent intervention, understand barriers | Aggressive win-back offers |
| **Lost** | No recent activity, minimal proof history | Deprioritize or archive | Minimal contact, final win-back attempt |

### Special Detection: Dropping Flag

**What it detects:** High-value customers (100K-200K or 200K+ revenue buckets) showing sudden decline in wallet share score (≥2 points) and significant segment degradation (≥5 segment value points) within the most recent month.

**Business impact:** Early warning system for at-risk VIP accounts requiring immediate sales intervention before churn occurs.

**Action required:** Priority outreach from account manager, investigate cause (competitive pressure, service issues, changing needs), develop retention plan.

---

## Consumption & Activation

### How SGWS Teams Use COBS Segments

With customer segments now generated monthly and stored in S3, SGWS operationalized this intelligence across multiple business functions.

#### Data Consumption Patterns

**Analytical Consumption:**
- **Tableau dashboards:** Executive-level segment distribution, trend analysis, segment migration tracking
- **Superset dashboards:** Operational dashboards for sales teams, territory performance by segment
- **Direct S3/Lakehouse access:** Ad-hoc analysis by data science teams, custom reporting

**Operational Activation:**
- **CRM integration:** Segment labels synced to Salesforce for account prioritization
- **Marketing automation:** Segment-based email campaigns in Marketo/HubSpot
- **Sales territory planning:** Account assignment based on segment complexity and value
- **Customer success workflows:** Automated alerts for Dropping flag triggers

#### Key Performance Indicators (KPIs)

- **Segment health metrics:** Distribution of customers across segments over time
- **Segment migration analysis:** Customers moving up/down segment hierarchy
- **Dropping detection rate:** % of high-value accounts flagged per month
- **Proof product adoption:** Wallet share trends by segment and sales bucket
- **Retention rates:** Churn prevention success by segment-specific interventions

---

## Configuration Reference

### Vulcan Config (config_dev.yaml)

**Key sections for COBS:**

```yaml
# Basic Information
name: cobs-snowflake-analytics
display_name: COBS - Customer Order Behavior Segmentation
description: COBS transforms raw transactional data into 8 behavioral customer segments...

# Tags (for discovery and governance)
tags:
  - cobs
  - customer_segmentation
  - behavioral_analytics
  - rfm_analysis
  - machine_learning
  - churn_prediction
  - dropping_detection
  # ... (see full config for complete list)

# Use Cases (documented in metadata)
metadata:
  use_cases:
    - Customer behavioral segmentation using RFM methodology
    - Churn prediction and at-risk customer identification
    - Sales territory prioritization
    - Marketing campaign personalization
    - Proof product adoption tracking
    # ... (see full config for complete list)

# Limitations (critical for users to understand)
metadata:
  limitations:
    - Requires minimum 12 months of historical data
    - Clustering model requires recalibration when patterns shift
    - Segment definitions specific to proof product business models
    - Monthly refresh cadence may not capture real-time changes
    - Python scoring engine runs outside Vulcan pipeline
    # ... (see full config for complete list)
```

### Python Config (config.yml)

**Critical parameters:**

```yaml
# Clustering configuration
recency_clust_num: 5           # Bins for recency score (1-5)
frequency_clust_num: 5         # Bins for frequency score (1-5)
monetary_clust_num: 4          # Bins for wallet share score (1-4)

# Business rules
sales_buckets:                 # Must match data and CSV mapping
  - 1. 0-10K
  - 2. 10K-50K
  - 3. 50K-100K
  - 4. 100K-200K
  - 5. 200K+

outperformers_sales_buckets:   # Eligible for Outperformer segment
  - 4. 100K-200K
  - 5. 200K+

# Thresholds
num_std_devs: 1                # Std dev for outlier detection
cutoff_months:                 # Activation period per sales bucket
  1. 0-10K: 1
  2. 10K-50K: 1
  3. 50K-100K: 1
  4. 100K-200K: 1
  5. 200K+: 1

# Segment scoring (for Dropping detection)
segment_value_dict:
  Dropping: 3
  Lost: 1
  Newly Activated: 4
  Outperformers: 8
  Web Loyalist: 7
```

---

## Limitations & Considerations

### Data Requirements

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| Requires 12 months of history | Cannot segment newly launched businesses | Use shorter windows (6 months) with adjusted thresholds |
| Assumes consistent data quality | Garbage in = garbage out | Implement upstream data validation |
| Dependent on transaction granularity | Aggregated data loses signal | Ensure line-item level transaction capture |

### Model Constraints

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| KBinsDiscretizer assumes stable distributions | Cluster boundaries drift over time | Quarterly model recalibration |
| Fixed RFW score bins (5/5/4) | May not fit all business contexts | Test alternative bin configurations |
| Static segment mapping CSV | Business rules lag behind market changes | Quarterly review of segment definitions |
| Outperformer detection via std dev | Sensitive to outliers in small buckets | Consider percentile-based thresholds |

### Operational Limitations

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| Monthly refresh cadence | Delayed reaction to rapid changes | Explore weekly scoring for high-value segments |
| Python scoring outside Vulcan | Additional orchestration complexity | Consider Flare-native ML integration |
| Output to S3 CSV | Not real-time activation ready | Build streaming pipeline for critical segments |
| No A/B testing framework | Cannot measure segment effectiveness | Implement holdout groups for validation |

### Business Logic Assumptions

| Assumption | Risk if Violated | Validation Approach |
|------------|------------------|---------------------|
| Proof products indicate engagement | May not apply to all industries | Correlate with retention/LTV data |
| Revenue buckets reflect account tiers | Large one-time orders skew classification | Consider 12-month average revenue |
| Wallet share is meaningful metric | Not relevant for mono-product businesses | Test alternative engagement metrics |
| Dropping logic (≥2 wallet score drop) | May be too sensitive or too loose | Tune thresholds with sales team feedback |

---

## Best Practices

### Implementation Recommendations

✅ **Start with a pilot:** Test COBS on a single sales region before full rollout  
✅ **Validate with sales teams:** Ensure segments align with field observations  
✅ **Document segment definitions:** Create sales playbooks for each segment  
✅ **Monitor segment stability:** Track monthly migration rates to detect model drift  
✅ **Integrate with CRM:** Make segments actionable where reps work  
✅ **Build feedback loops:** Track whether segment-based actions improve outcomes  
✅ **Schedule quarterly reviews:** Recalibrate thresholds as business evolves  

### Common Pitfalls to Avoid

❌ **Over-segmentation:** 8 segments may be too many; consider consolidation  
❌ **Ignoring edge cases:** Customers at bucket boundaries need special handling  
❌ **Static model assumptions:** Markets change; models must evolve  
❌ **Lack of sales buy-in:** Segments unused are segments wasted  
❌ **No success metrics:** Define KPIs upfront (retention rate by segment, etc.)  
❌ **Treating segments as fixed:** Customers move; update strategies accordingly  

---

## Appendix

### Key Files Reference

| File | Purpose | Owner |
|------|---------|-------|
| `config_dev.yaml` | Vulcan data product config | Data Engineering |
| `config.yml` | Python segmentation parameters | Data Science |
| `main.py` | Orchestration script | Data Science |
| `clustering_utils.py` | Segmentation logic | Data Science |
| `rfw_segments_csv.csv` | RFW-to-segment mapping | Business/Sales Ops |
| `segment_result.csv` | Final output dataset | Auto-generated |

### Glossary

- **COBS:** Customer Order Behavior Segmentation
- **RFM:** Recency, Frequency, Monetary (classic marketing analytics framework)
- **Proof Products:** Proprietary brand offerings with higher margins (SGWS-specific)
- **Wallet Share:** Percentage of customer spend on proof products vs. total spend
- **Sales Bucket:** Revenue tier classification (0-10K, 10K-50K, etc.)
- **Dropping Flag:** Binary indicator for at-risk high-value customers
- **Activation Date:** Date customer first purchased proof products
- **KBinsDiscretizer:** Scikit-learn clustering algorithm for binning continuous variables

### Support & Maintenance

**Data Engineering Team:**
- Pipeline monitoring and troubleshooting
- Lakehouse table refreshes
- Schema evolution management

**Data Science Team:**
- Model recalibration and tuning
- Segment definition updates
- Performance analysis and reporting

**Business Owner (Sales Operations):**
- Segment strategy and playbook development
- Threshold approval (bucket definitions, cutoff periods)
- Success metric tracking and ROI analysis

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2024-01-27 | Initial COBS documentation and config | Data Team |

---

**For questions or support, contact:**
- **Owner:** shreya.sikarwar@tmdc.io
- **Contributors:** kanak.gupta@tmdc.io, mukul.gupta@tmdc.io

