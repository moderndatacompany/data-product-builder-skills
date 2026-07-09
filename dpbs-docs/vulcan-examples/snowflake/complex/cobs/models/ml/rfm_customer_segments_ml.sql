MODEL (
  name cobs.rfm_customer_segments_ml,
  kind FULL,
  cron '@daily',
  grain (Account_ID, date),
  tags ('rfm', 'ml', 'customer_segmentation', 'clustering'),
  description 'ML-based customer segmentation using clustering on RFM metrics. Identifies segments: Champions, Loyal, At Risk, Lapsed, Newly Activated, Outperformers, and Dropping customers',
  column_descriptions (
    Account_ID = 'Unique account identifier',
    date = 'Analysis date',
    Sales_Bucket = 'Revenue tier classification',
    segment = 'Final customer segment (Champions, Loyal, At Risk, Lapsed, Newly Activated, Outperformers, Dropping)',
    recency_score = 'Clustered recency score (1-5, lower is more recent)',
    frequency_score = 'Clustered frequency score (1-5, higher is more frequent)',
    wallet_score = 'Clustered wallet share score (1-5, higher is better)',
    R12_Proof_Rev = 'Proof revenue over 12 months',
    R12_Total_Rev = 'Total revenue over 12 months',
    R12_Non_Proof_Rev = 'Non-proof revenue over 12 months',
    R12_Proof_Invoices = 'Proof invoice count over 12 months',
    R12_Total_Invoices = 'Total invoice count over 12 months',
    R12_Non_Proof_Invoices = 'Non-proof invoice count over 12 months',
    R12_Wallet_Share = 'Wallet share over 12 months',
    R12_Order_Share = 'Order share over 12 months',
    dropping = 'Boolean flag indicating dropping wallet share trend',
    activation_date = 'Date when customer was first activated',
    activation_month = 'Month of activation',
    last_date = 'Most recent proof transaction date',
    proof_recency = 'Days since last proof transaction',
    proof_tenure = 'Days since account activation'
  )
);

-- Configuration parameters
WITH config AS (
  SELECT
    5 AS recency_clusters,
    5 AS frequency_clusters,
    5 AS monetary_clusters,
    12 AS cutoff_months,
    2 AS num_std_devs
),

-- Read segment mapping (should be loaded as a seed file)
segment_mapping AS (
  SELECT
    Sales_Bucket,
    recency_score,
    frequency_score,
    wallet_score,
    segment
  FROM cobs.rfm_segment_mapping
),

-- Get 12-month RFM data
rfm_12month_base AS (
  SELECT
    Account_ID,
    date,
    Sales_Bucket,
    activation_month,
    proof_recency,
    proof_frequency,
    wallet_share,
    order_share,
    proof_rev,
    total_rev,
    total_frequency,
    total_rev_after_activation,
    total_trans_after_activation,
    activation_date,
    last_date,
    proof_tenure,
    YEAR(activation_month) * 100 + MONTH(activation_month) AS activation_month_int
  FROM cobs.rfm_segment_12_month_data
),

-- Calculate activation cutoff for "Newly Activated" segment
rfm_12month_with_cutoff AS (
  SELECT
    r12.*,
    (YEAR(r12.date) * 100 + MONTH(r12.date)) - (SELECT cutoff_months FROM config) AS actvtn_cutoff_date
  FROM rfm_12month_base r12
),

-- Apply clustering (using NTILE for quintile-based bucketing)
rfm_12month_clustered AS (
  SELECT
    Account_ID,
    date,
    Sales_Bucket,
    activation_month,
    activation_month_int,
    actvtn_cutoff_date,
    proof_recency,
    proof_frequency,
    wallet_share,
    order_share,
    proof_rev,
    total_rev,
    total_frequency,
    total_rev_after_activation,
    total_trans_after_activation,
    activation_date,
    last_date,
    proof_tenure,
    -- Recency score (reverse order: lower recency = higher score)
    CASE
      WHEN activation_month_int < actvtn_cutoff_date AND proof_rev > 0
      THEN 6 - NTILE(5) OVER (
        PARTITION BY Sales_Bucket, 
          CASE WHEN activation_month_int < actvtn_cutoff_date AND proof_rev > 0 THEN 1 ELSE 0 END
        ORDER BY proof_recency ASC
      )
      ELSE NULL
    END AS recency_score,
    -- Frequency score (higher frequency = higher score)
    CASE
      WHEN activation_month_int < actvtn_cutoff_date AND proof_rev > 0
      THEN NTILE(5) OVER (
        PARTITION BY Sales_Bucket,
          CASE WHEN activation_month_int < actvtn_cutoff_date AND proof_rev > 0 THEN 1 ELSE 0 END
        ORDER BY proof_frequency ASC
      )
      ELSE NULL
    END AS frequency_score,
    -- Wallet share score (higher wallet share = higher score)
    CASE
      WHEN activation_month_int < actvtn_cutoff_date AND proof_rev > 0
      THEN NTILE(5) OVER (
        PARTITION BY Sales_Bucket,
          CASE WHEN activation_month_int < actvtn_cutoff_date AND proof_rev > 0 THEN 1 ELSE 0 END
        ORDER BY wallet_share ASC
      )
      ELSE NULL
    END AS wallet_score
  FROM rfm_12month_with_cutoff
),

-- Calculate outperformer statistics
outperformer_stats AS (
  SELECT
    Sales_Bucket,
    AVG(proof_frequency) AS mean_freq,
    STDDEV(proof_frequency) AS std_freq
  FROM rfm_12month_clustered
  WHERE Sales_Bucket IN ('7. 300K-400K', '8. 400K-500K', '9. 500K+')
  GROUP BY Sales_Bucket
),

-- Identify segments for 12-month data
rfm_12month_segments AS (
  SELECT
    r12.*,
    CASE
      -- Newly Activated
      WHEN r12.activation_month_int >= r12.actvtn_cutoff_date THEN 'Newly Activated'
      -- Lapsed (no proof revenue)
      WHEN r12.proof_rev = 0 THEN 'Lapsed'
      -- Outperformers (high frequency in top sales buckets)
      WHEN r12.Sales_Bucket IN ('7. 300K-400K', '8. 400K-500K', '9. 500K+')
        AND r12.proof_frequency > os.mean_freq + (SELECT num_std_devs FROM config) * os.std_freq
        THEN 'Outperformers'
      -- Map to main segment using mapping table
      ELSE COALESCE(sm.segment, 'Need Attention')
    END AS segment
  FROM rfm_12month_clustered r12
  LEFT JOIN outperformer_stats os
    ON r12.Sales_Bucket = os.Sales_Bucket
  LEFT JOIN segment_mapping sm
    ON r12.Sales_Bucket = sm.Sales_Bucket
    AND r12.recency_score = sm.recency_score
    AND r12.frequency_score = sm.frequency_score
    AND r12.wallet_score = sm.wallet_score
),

-- Get 1-month RFM data and apply same clustering
rfm_1month_base AS (
  SELECT
    Account_ID,
    date,
    Sales_Bucket,
    activation_month,
    proof_recency,
    proof_frequency,
    wallet_share,
    order_share,
    YEAR(activation_month) * 100 + MONTH(activation_month) AS activation_month_int
  FROM cobs.rfm_segment_1_month_data
),

rfm_1month_with_cutoff AS (
  SELECT
    r1.*,
    (YEAR(r1.date) * 100 + MONTH(r1.date)) - (SELECT cutoff_months FROM config) AS actvtn_cutoff_date
  FROM rfm_1month_base r1
),

rfm_1month_clustered AS (
  SELECT
    Account_ID,
    date,
    Sales_Bucket,
    activation_month_int,
    actvtn_cutoff_date,
    proof_recency,
    proof_frequency,
    wallet_share,
    order_share,
    -- Apply same clustering logic
    CASE
      WHEN activation_month_int < actvtn_cutoff_date
      THEN 6 - NTILE(5) OVER (
        PARTITION BY Sales_Bucket,
          CASE WHEN activation_month_int < actvtn_cutoff_date THEN 1 ELSE 0 END
        ORDER BY proof_recency ASC
      )
      ELSE NULL
    END AS recency_score,
    CASE
      WHEN activation_month_int < actvtn_cutoff_date
      THEN NTILE(5) OVER (
        PARTITION BY Sales_Bucket,
          CASE WHEN activation_month_int < actvtn_cutoff_date THEN 1 ELSE 0 END
        ORDER BY proof_frequency ASC
      )
      ELSE NULL
    END AS frequency_score,
    CASE
      WHEN activation_month_int < actvtn_cutoff_date
      THEN NTILE(5) OVER (
        PARTITION BY Sales_Bucket,
          CASE WHEN activation_month_int < actvtn_cutoff_date THEN 1 ELSE 0 END
        ORDER BY wallet_share ASC
      )
      ELSE NULL
    END AS wallet_score
  FROM rfm_1month_with_cutoff
),

rfm_1month_segments AS (
  SELECT
    r1.*,
    COALESCE(sm.segment, 'Need Attention') AS segment
  FROM rfm_1month_clustered r1
  LEFT JOIN segment_mapping sm
    ON r1.Sales_Bucket = sm.Sales_Bucket
    AND r1.recency_score = sm.recency_score
    AND r1.frequency_score = sm.frequency_score
    AND r1.wallet_score = sm.wallet_score
),

-- Segment value mapping for dropping detection
segment_values AS (
  SELECT 'Champions' AS segment, 1 AS segment_value UNION ALL
  SELECT 'Loyal', 2 UNION ALL
  SELECT 'Potential Loyalists', 3 UNION ALL
  SELECT 'New Customers', 4 UNION ALL
  SELECT 'Promising', 5 UNION ALL
  SELECT 'Need Attention', 6 UNION ALL
  SELECT 'About to Sleep', 7 UNION ALL
  SELECT 'At Risk', 8 UNION ALL
  SELECT 'Cannot Lose Them', 9 UNION ALL
  SELECT 'Hibernating', 10 UNION ALL
  SELECT 'Lapsed', 11 UNION ALL
  SELECT 'Newly Activated', 4 UNION ALL
  SELECT 'Outperformers', 1
),

-- Combine 12-month and 1-month data to identify dropping customers
final_segments AS (
  SELECT
    r12.Account_ID,
    r12.date,
    r12.Sales_Bucket,
    r12.segment,
    r12.recency_score,
    r12.frequency_score,
    r12.wallet_score,
    r12.proof_rev AS R12_Proof_Rev,
    r12.total_rev AS R12_Total_Rev,
    r12.total_rev - r12.proof_rev AS R12_Non_Proof_Rev,
    r12.proof_frequency AS R12_Proof_Invoices,
    r12.total_frequency AS R12_Total_Invoices,
    r12.total_frequency - r12.proof_frequency AS R12_Non_Proof_Invoices,
    r12.wallet_share AS R12_Wallet_Share,
    r12.order_share AS R12_Order_Share,
    r12.activation_date,
    r12.activation_month,
    r12.last_date,
    r12.proof_recency,
    r12.proof_tenure,
    r1.wallet_score AS wallet_score_1mo,
    r1.segment AS segment_1mo,
    sv12.segment_value AS segment_value_12mo,
    sv1.segment_value AS segment_value_1mo,
    -- Dropping condition
    CASE
      WHEN (r12.wallet_score - r1.wallet_score >= 2)
        AND (sv12.segment_value - sv1.segment_value >= 5)
        AND (sv12.segment_value >= 6)
        AND (r12.Sales_Bucket >= '5. 100K-200K')
      THEN TRUE
      ELSE FALSE
    END AS dropping
  FROM rfm_12month_segments r12
  LEFT JOIN rfm_1month_segments r1
    ON r12.Account_ID = r1.Account_ID
    AND r12.date = r1.date
  LEFT JOIN segment_values sv12
    ON r12.segment = sv12.segment
  LEFT JOIN segment_values sv1
    ON r1.segment = sv1.segment
)

-- Final output with dropping segment override
SELECT
  Account_ID,
  date,
  Sales_Bucket,
  CASE
    WHEN dropping = TRUE THEN 'Dropping'
    ELSE segment
  END AS segment,
  recency_score,
  frequency_score,
  wallet_score,
  R12_Proof_Rev,
  R12_Total_Rev,
  R12_Non_Proof_Rev,
  R12_Proof_Invoices,
  R12_Total_Invoices,
  R12_Non_Proof_Invoices,
  R12_Wallet_Share,
  R12_Order_Share,
  dropping,
  activation_date,
  activation_month,
  last_date,
  proof_recency,
  proof_tenure
FROM final_segments
ORDER BY Account_ID, date

