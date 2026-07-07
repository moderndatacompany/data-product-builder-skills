-- Upstream: cobs.v_d_customer_stage and cobs.v_fact_sales_stage (seeds). For production, point to onesourceplus when available.
MODEL (
  name cobs.rfm_segment_12_month_data,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column date
  ),
  cron '@daily',
  grain (Account_ID, date),
  tags ('rfm', 'customer_segmentation', 'web_segment', 'sales_analytics', 'annual'),
  terms ('customer.segmentation', 'rfm.analysis', 'sales.analytics'),
  description 'RFM (Recency, Frequency, Monetary) customer segmentation analysis based on 12-month (1-year) rolling window. Delivers customer behavior insights including wallet share, order share, and proof transaction metrics for customer engagement and retention strategies',
  column_descriptions (
    Sales_Bucket = 'Revenue tier classification based on total sales (0-25K, 25-50K, 50-75K, 75-100K, 100K-200K, 200K-300K, 300K-400K, 400K-500K, 500K+)',
    Account_ID = 'Unique account identifier',
    activation_date = 'Date when customer account was first activated with proof transactions',
    activation_month = 'Month of account activation',
    last_date = 'Most recent proof transaction date',
    last_trans_month = 'Most recent transaction month',
    recency = 'Days since last transaction (any type)',
    proof_recency = 'Days since last proof transaction',
    total_monetary = 'Average total revenue per transaction',
    proof_monetary = 'Average proof revenue per transaction',
    total_frequency = 'Total number of transactions',
    proof_frequency = 'Total number of proof transactions (entry_origin G or H)',
    total_rev = 'Total revenue across all transactions',
    proof_rev = 'Total revenue from proof transactions',
    total_rev_after_activation = 'Total revenue after account activation',
    total_trans_after_activation = 'Total transactions after account activation',
    wallet_share = 'Proof revenue divided by total revenue after activation (overall)',
    order_share = 'Proof transactions divided by total transactions after activation',
    wallet_share_mnth = 'Proof revenue divided by total revenue after activation (current month only)',
    proof_tenure = 'Days since account activation date',
    date = 'Analysis date (start of 12-month window)'
  ),
  column_tags (
    Sales_Bucket = ('dimension', 'classification', 'tier'),
    Account_ID = ('identifier', 'primary_key', 'grain'),
    activation_date = ('temporal', 'date', 'milestone'),
    activation_month = ('temporal', 'date', 'milestone'),
    last_date = ('temporal', 'date'),
    last_trans_month = ('temporal', 'date'),
    recency = ('measure', 'metric', 'behavioral'),
    proof_recency = ('measure', 'metric', 'behavioral'),
    total_monetary = ('measure', 'monetary', 'average'),
    proof_monetary = ('measure', 'monetary', 'average'),
    total_frequency = ('measure', 'count'),
    proof_frequency = ('measure', 'count'),
    total_rev = ('measure', 'monetary', 'revenue'),
    proof_rev = ('measure', 'monetary', 'revenue'),
    total_rev_after_activation = ('measure', 'monetary', 'revenue'),
    total_trans_after_activation = ('measure', 'count'),
    wallet_share = ('measure', 'ratio', 'percentage'),
    order_share = ('measure', 'ratio', 'percentage'),
    wallet_share_mnth = ('measure', 'ratio', 'percentage'),
    proof_tenure = ('measure', 'metric', 'tenure'),
    date = ('temporal', 'date', 'grain')
  ),
  column_terms (
    Sales_Bucket = ('classification.revenue_tier', 'customer.segment'),
    Account_ID = ('customer.account_id', 'entity.identifier'),
    activation_date = ('customer.activation', 'event.first_transaction'),
    recency = ('rfm.recency', 'behavioral.metric'),
    total_frequency = ('rfm.frequency', 'behavioral.metric'),
    total_monetary = ('rfm.monetary', 'revenue.metric'),
    wallet_share = ('customer.wallet_share', 'metric.share'),
    proof_tenure = ('customer.tenure', 'metric.duration')
  )
);

-- Main RFM Segmentation Query - 12 Month Rolling Window
WITH params_filters AS (
  SELECT
    DATEADD(MONTH, -1, end_date)::DATE AS date,
    start_date,
    end_date,
    TO_NUMBER(TO_CHAR(DATEADD(MONTH, -1, end_date), 'YYYYMM')) AS last_month_str,
    TO_NUMBER(TO_CHAR(DATEADD(MONTH, -1, start_date), 'YYYYMM')) AS cutoff_months,
    DATEADD(MONTH, -1, start_date)::DATE AS actvtn_cutoff_date
  FROM (
    SELECT
      DATEADD(YEAR, -1, CURRENT_DATE())::DATE AS start_date,
      CURRENT_DATE() AS end_date
  )
),

cust AS (
  SELECT
    customer_no,
    site,
    STATUS,
    CASE
      WHEN activated_acct IN ('Re-Ordered', 'Ordered') THEN 'Y'
      ELSE 'N'
    END AS order_flag,
    CASE
      WHEN rtm_national_channel_desc IN ('ON PREMISE NATIONAL', 'OFF PREMISE NATIONAL') THEN 'National'
      ELSE 'Others'
    END naop_flag,
    CASE
      WHEN proof_of_eligible_acct = 'Y' THEN TRUE
      ELSE FALSE
    END tam
  FROM cobs.v_d_customer_stage
),

trans AS (
  SELECT
    sales.customer_no,
    TO_VARCHAR(
      CASE
        WHEN sales.site = 55 THEN 
          LPAD(sales.site::VARCHAR, 4, '0') || LPAD(sales.customer_no::VARCHAR, 10, '0')
        ELSE 
          LPAD(sales.site::VARCHAR, 4, '0') || 
          CASE
            WHEN LENGTH(sales.customer_no::VARCHAR) <= 7 THEN LPAD(sales.customer_no::VARCHAR, 7, '0')
            ELSE LPAD(sales.customer_no::VARCHAR, 10, '0')
          END
      END
    ) AS Account_ID,
    CASE
      WHEN sales.site = 55 THEN 
        (LPAD(sales.site::VARCHAR, 4, '0') || LPAD(sales.customer_no::VARCHAR, 10, '0'))::BIGINT
      ELSE 
        (LPAD(sales.site::VARCHAR, 4, '0') || 
        CASE
          WHEN LENGTH(sales.customer_no::VARCHAR) <= 7 THEN LPAD(sales.customer_no::VARCHAR, 7, '0')
          ELSE LPAD(sales.customer_no::VARCHAR, 10, '0')
        END)::BIGINT
    END AS GCP_Account_ID,
    TO_DATE(posting_dt_sk::VARCHAR, 'YYYYMMDD') AS posting_date,
    sales.site,
    invoice_no,
    posting_prd,
    ext_net,
    entry_origin,
    CASE
      WHEN entry_origin IN ('G', 'H') THEN 'Proof'
      ELSE 'Non-proof'
    END source,
    cases,
    order_flag,
    naop_flag,
    STATUS
  FROM cobs.v_fact_sales_stage AS sales
  LEFT JOIN cust 
    ON sales.customer_no = cust.customer_no
    AND sales.site = cust.site
  WHERE
    TO_DATE(posting_dt_sk::VARCHAR, 'YYYYMMDD') < (SELECT end_date FROM params_filters)
    AND ext_net > 0
    AND order_flag = 'Y'
    AND naop_flag != 'National'
    AND STATUS = 'A'
    AND tam = TRUE
),

actv_dts AS (
  SELECT
    customer_no,
    site,
    MIN(TO_DATE(posting_dt_sk::VARCHAR, 'YYYYMMDD')) AS activation_date
  FROM cobs.v_fact_sales_stage
  WHERE
    entry_origin IN ('H', 'G')
    AND ext_net > 0
  GROUP BY
    customer_no,
    site
),

proof_transaction_items AS (
  SELECT
    trans.customer_no,
    trans.Account_ID,
    trans.invoice_no,
    trans.site,
    GCP_Account_ID,
    CASE
      WHEN (trans.source = 'Proof')
      AND (trans.posting_date >= (SELECT start_date FROM params_filters))
      THEN 1
      ELSE 0
    END proof_trans,
    CASE
      WHEN (trans.source = 'Non-proof')
      AND (trans.posting_date >= (SELECT start_date FROM params_filters))
      THEN 1
      ELSE 0
    END non_proof_trans,
    IFF(
      trans.posting_date >= (SELECT start_date FROM params_filters),
      1,
      0
    ) total_trans,
    IFF(
      posting_date >= '2022-11-01'::DATE,
      ext_net,
      0
    ) total_rev,
    CASE
      WHEN trans.source = 'Proof'
      AND (trans.posting_date >= (SELECT start_date FROM params_filters))
      THEN trans.ext_net
      ELSE 0
    END proof_rev,
    CASE
      WHEN trans.source = 'Non-proof'
      AND (trans.posting_date >= (SELECT start_date FROM params_filters))
      THEN trans.ext_net
      ELSE 0
    END non_proof_rev,
    IFF(
      trans.posting_date >= (SELECT start_date FROM params_filters),
      trans.posting_date,
      NULL
    ) posting_date,
    CASE
      WHEN trans.source = 'Proof'
      AND (trans.posting_date >= (SELECT start_date FROM params_filters))
      THEN trans.posting_date
      ELSE NULL
    END proof_posting_date,
    actv_dts.activation_date,
    IFF(
      trans.posting_prd = (SELECT last_month_str FROM params_filters),
      trans.ext_net,
      0
    ) total_rev_mnth,
    CASE
      WHEN trans.source = 'Proof'
      AND (trans.posting_prd = (SELECT last_month_str FROM params_filters))
      THEN trans.ext_net
      ELSE 0
    END proof_rev_mnth
  FROM trans
  LEFT JOIN actv_dts 
    ON trans.customer_no = actv_dts.customer_no
    AND trans.site = actv_dts.site
  WHERE
    posting_date < (SELECT end_date FROM params_filters)
    AND trans.ext_net > 0
),

proof_transactions AS (
  SELECT
    invoice_no,
    Account_ID,
    site,
    customer_no,
    GCP_Account_ID,
    COALESCE(MAX(proof_trans), 0) proof_trans,
    COALESCE(MAX(non_proof_trans), 0) AS non_proof_trans,
    COALESCE(MAX(total_trans), 0) total_trans,
    SUM(total_rev) total_rev,
    SUM(proof_rev) proof_rev,
    SUM(non_proof_rev) AS non_proof_rev,
    SUM(
      CASE
        WHEN posting_date >= activation_date THEN total_rev
        ELSE 0
      END
    ) total_rev_after_activation,
    SUM(
      CASE
        WHEN posting_date >= activation_date THEN total_trans
        ELSE 0
      END
    ) total_trans_after_activation,
    SUM(proof_rev_mnth) AS proof_rev_mnth,
    SUM(
      CASE
        WHEN posting_date >= activation_date THEN total_rev_mnth
        ELSE 0
      END
    ) total_rev_after_activation_mnth,
    MAX(posting_date) posting_date,
    MAX(proof_posting_date) proof_posting_date,
    MAX(activation_date) activation_date
  FROM proof_transaction_items
  GROUP BY
    invoice_no,
    Account_ID,
    site,
    customer_no,
    GCP_Account_ID
),

rfm_data AS (
  SELECT
    Account_ID,
    site,
    customer_no,
    GCP_Account_ID,
    CASE
      WHEN SUM(total_rev) < 25000 THEN '1. 0-25K'
      WHEN SUM(total_rev) >= 25000 AND SUM(total_rev) < 50000 THEN '2. 25-50K'
      WHEN SUM(total_rev) >= 50000 AND SUM(total_rev) < 75000 THEN '3. 50-75K'
      WHEN SUM(total_rev) >= 75000 AND SUM(total_rev) < 100000 THEN '4. 75-100K'
      WHEN SUM(total_rev) >= 100000 AND SUM(total_rev) < 200000 THEN '5. 100K-200K'
      WHEN SUM(total_rev) >= 200000 AND SUM(total_rev) < 300000 THEN '6. 200K-300K'
      WHEN SUM(total_rev) >= 300000 AND SUM(total_rev) < 400000 THEN '7. 300K-400K'
      WHEN SUM(total_rev) >= 400000 AND SUM(total_rev) < 500000 THEN '8. 400K-500K'
      ELSE '9. 500K+'
    END AS sales_bucket,
    MAX(proof_posting_date) last_date,
    DATE_TRUNC('MONTH', MAX(proof_posting_date))::DATE as last_trans_month,
    DATEDIFF('DAY', MAX(posting_date), (SELECT end_date FROM params_filters)) AS recency,
    DATEDIFF('DAY', MAX(proof_posting_date), (SELECT end_date FROM params_filters)) as proof_recency,
    AVG(total_rev) total_monetary,
    AVG(proof_rev) proof_monetary,
    SUM(total_trans) total_frequency,
    SUM(proof_trans) proof_frequency,
    SUM(non_proof_trans) AS non_frequency,
    SUM(total_rev) total_rev,
    SUM(proof_rev) proof_rev,
    SUM(non_proof_rev) AS non_proof_rev,
    SUM(total_rev_after_activation) total_rev_after_activation,
    SUM(total_trans_after_activation) total_trans_after_activation,
    CASE
      WHEN SUM(total_rev_after_activation) > 0 THEN SUM(proof_rev) / SUM(total_rev_after_activation)
      ELSE NULL
    END wallet_share,
    CASE
      WHEN SUM(total_trans_after_activation) > 0 THEN SUM(proof_trans) / SUM(total_trans_after_activation)
      ELSE NULL
    END order_share,
    CASE
      WHEN SUM(total_rev_after_activation_mnth) > 0 THEN SUM(proof_rev_mnth) / SUM(total_rev_after_activation_mnth)
      ELSE NULL
    END wallet_share_mnth,
    MIN(activation_date) activation_date,
    DATE_TRUNC('MONTH', MIN(activation_date))::DATE AS activation_month,
    DATEDIFF('DAY', MIN(activation_date), (SELECT end_date FROM params_filters)) AS proof_tenure
  FROM proof_transactions
  WHERE activation_date IS NOT NULL
  GROUP BY
    Account_ID,
    site,
    customer_no,
    GCP_Account_ID
)

SELECT
  sales_bucket AS Sales_Bucket,
  Account_ID,
  activation_date,
  activation_month,
  last_date,
  last_trans_month,
  COALESCE(recency, 0) AS recency,
  COALESCE(proof_recency, 0) AS proof_recency,
  total_monetary,
  proof_monetary,
  total_frequency,
  proof_frequency,
  total_rev,
  proof_rev,
  total_rev_after_activation,
  total_trans_after_activation,
  wallet_share,
  order_share,
  wallet_share_mnth,
  proof_tenure,
  (SELECT date FROM params_filters) AS date
FROM rfm_data

