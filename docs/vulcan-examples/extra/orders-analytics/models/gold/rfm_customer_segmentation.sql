-- RFM (Recency, Frequency, Monetary) customer segmentation model
-- Advanced customer analytics using RFM scoring methodology for targeted marketing and retention strategies
MODEL (
    name gold_v2alpha.rfm_customer_segmentation,
    kind FULL,
    cron '*/5 * * * *',
    grains (customer_id),
    tags (
        'gold',
        'analytics',
        'customer',
        'rfm',
        'segmentation'
    ),
    terms (
        'customer.rfm_analysis',
        'analytics.customer_segmentation'
    ),
    description 'RFM customer segmentation model using Recency, Frequency, and Monetary value analysis to classify customers into actionable segments for marketing campaigns, retention programs, and customer lifecycle management',
    column_descriptions (
        customer_id = 'Unique identifier for each customer',
        customer_name = 'Customer full name',
        email = 'Customer email address',
        region_name = 'Customer home region',
        recency_days = 'Number of days since last order (lower is better)',
        frequency_orders = 'Total number of orders placed (higher is better)',
        monetary_value = 'Total lifetime revenue in USD (higher is better)',
        recency_score = 'RFM Recency score (1-5, where 5 = most recent)',
        frequency_score = 'RFM Frequency score (1-5, where 5 = most frequent)',
        monetary_score = 'RFM Monetary score (1-5, where 5 = highest value)',
        rfm_score = 'Combined RFM score (111-555)',
        rfm_segment = 'Customer segment classification based on RFM scores',
        rfm_segment_description = 'Detailed description of customer segment characteristics',
        recommended_action = 'Suggested marketing or retention action for this segment'
    ),
    column_tags (
        customer_id = (
            'primary_key',
            'identifier',
            'grain'
        ),
        customer_name = ('dimension', 'label', 'pii'),
        email = ('dimension', 'pii', 'contact'),
        region_name = ('dimension', 'label'),
        recency_days = (
            'measure',
            'metric',
            'rfm_component'
        ),
        frequency_orders = (
            'measure',
            'metric',
            'rfm_component'
        ),
        monetary_value = (
            'measure',
            'financial',
            'rfm_component'
        ),
        recency_score = (
            'measure',
            'score',
            'rfm_component'
        ),
        frequency_score = (
            'measure',
            'score',
            'rfm_component'
        ),
        monetary_score = (
            'measure',
            'score',
            'rfm_component'
        ),
        rfm_score = (
            'measure',
            'score',
            'composite'
        ),
        rfm_segment = (
            'dimension',
            'classification',
            'label'
        ),
        rfm_segment_description = (
            'dimension',
            'label',
            'description'
        ),
        recommended_action = (
            'dimension',
            'label',
            'recommendation'
        )
    ),
    column_terms (
        customer_id = (
            'customer.customer_id',
            'identity.customer_id'
        ),
        rfm_score = (
            'analytics.rfm_score',
            'segmentation.rfm_composite'
        ),
        rfm_segment = (
            'customer.segment',
            'analytics.customer_classification'
        ),
        monetary_value = (
            'customer.ltv',
            'finance.customer_lifetime_value'
        )
    ),
    assertions (
        unique_values (columns := customer_id),
        not_null (
            columns := (
                customer_id,
                customer_name,
                email
            )
        ),
        forall (
            criteria := (
                customer_id > 0,
                frequency_orders >= 0,
                monetary_value >= 0
            )
        ),
        accepted_range (
            column := recency_score,
            min_v := 1,
            max_v := 5
        ),
        accepted_range (
            column := frequency_score,
            min_v := 1,
            max_v := 5
        ),
        accepted_range (
            column := monetary_score,
            min_v := 1,
            max_v := 5
        ),
        accepted_values (
            column := rfm_segment,
            is_in := (
                'Champions',
                'Loyal Customers',
                'Potential Loyalists',
                'Recent Customers',
                'Promising',
                'Customers Needing Attention',
                'About to Sleep',
                'At Risk',
                'Cannot Lose Them',
                'Hibernating',
                'Lost'
            )
        )
    ),
    profiles (
        customer_name,
        email,
        rfm_score,
        rfm_segment,
        monetary_value
    )
);

WITH customer_rfm_metrics AS (
  SELECT
    c.customer_id,
    c.name AS customer_name,
    c.email,
    r.region_name,
    COALESCE((CURRENT_DATE - MAX(DATE(o.order_date)))::INTEGER, 9999) AS recency_days,
    COUNT(DISTINCT o.order_id) AS frequency_orders,
    COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS monetary_value
  FROM bronze_v2alpha.customers AS c
  INNER JOIN bronze_v2alpha.regions AS r
    ON c.region_id = r.region_id
  LEFT JOIN bronze_v2alpha.orders AS o
    ON c.customer_id = o.customer_id
  LEFT JOIN bronze_v2alpha.order_items AS oi
    ON o.order_id = oi.order_id
  GROUP BY c.customer_id, c.name, c.email, r.region_name
),
rfm_scores AS (
  SELECT
    customer_id,
    customer_name,
    email,
    region_name,
    recency_days,
    frequency_orders,
    monetary_value,
    -- Recency Score (5 = most recent, 1 = least recent)
    CASE
      WHEN recency_days <= 30 THEN 5
      WHEN recency_days <= 60 THEN 4
      WHEN recency_days <= 90 THEN 3
      WHEN recency_days <= 180 THEN 2
      ELSE 1
    END AS recency_score,
    -- Frequency Score (5 = most frequent, 1 = least frequent)
    CASE
      WHEN frequency_orders >= 10 THEN 5
      WHEN frequency_orders >= 7 THEN 4
      WHEN frequency_orders >= 5 THEN 3
      WHEN frequency_orders >= 3 THEN 2
      WHEN frequency_orders >= 1 THEN 1
      ELSE 0
    END AS frequency_score,
    -- Monetary Score (5 = highest value, 1 = lowest value)
    CASE
      WHEN monetary_value >= 5000 THEN 5
      WHEN monetary_value >= 2000 THEN 4
      WHEN monetary_value >= 1000 THEN 3
      WHEN monetary_value >= 500 THEN 2
      WHEN monetary_value > 0 THEN 1
      ELSE 0
    END AS monetary_score
  FROM customer_rfm_metrics
)
SELECT
  customer_id,
  customer_name,
  email,
  region_name,
  recency_days,
  frequency_orders,
  ROUND(monetary_value, 2) AS monetary_value,
  recency_score,
  frequency_score,
  monetary_score,
  -- Combined RFM Score (e.g., 555, 544, 111)
  CAST(recency_score AS TEXT) || CAST(frequency_score AS TEXT) || CAST(monetary_score AS TEXT) AS rfm_score,
  -- RFM Segment Classification
  CASE
    -- Champions: Bought recently, buy often and spend the most
    WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'
    -- Loyal Customers: Buy frequently, good monetary value
    WHEN recency_score >= 3 AND frequency_score >= 4 AND monetary_score >= 3 THEN 'Loyal Customers'
    -- Potential Loyalists: Recent customers with decent frequency
    WHEN recency_score >= 4 AND frequency_score >= 2 AND monetary_score >= 2 THEN 'Potential Loyalists'
    -- Recent Customers: Bought recently but not frequently
    WHEN recency_score >= 4 AND frequency_score <= 2 THEN 'Recent Customers'
    -- Promising: Recent shoppers with moderate spend
    WHEN recency_score >= 3 AND frequency_score <= 2 AND monetary_score >= 2 THEN 'Promising'
    -- Customers Needing Attention: Above average recency, frequency and monetary but declining
    WHEN recency_score = 3 AND frequency_score >= 2 AND monetary_score >= 2 THEN 'Customers Needing Attention'
    -- About to Sleep: Below average recency and frequency
    WHEN recency_score = 2 AND frequency_score >= 2 THEN 'About to Sleep'
    -- At Risk: Good customers who haven't purchased recently
    WHEN recency_score <= 2 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'At Risk'
    -- Cannot Lose Them: Made big purchases but long time ago
    WHEN recency_score <= 2 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Cannot Lose Them'
    -- Hibernating: Low recency, frequency and monetary
    WHEN recency_score <= 2 AND frequency_score <= 2 AND monetary_score <= 2 THEN 'Hibernating'
    -- Lost: Lowest recency, frequency and monetary
    ELSE 'Lost'
  END AS rfm_segment,
  -- Segment Descriptions
  CASE
    WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Your best customers who buy frequently and spend the most'
    WHEN recency_score >= 3 AND frequency_score >= 4 AND monetary_score >= 3 THEN 'Consistent buyers with good lifetime value'
    WHEN recency_score >= 4 AND frequency_score >= 2 AND monetary_score >= 2 THEN 'Recent customers showing promise of becoming loyal'
    WHEN recency_score >= 4 AND frequency_score <= 2 THEN 'New customers who made their first purchase recently'
    WHEN recency_score >= 3 AND frequency_score <= 2 AND monetary_score >= 2 THEN 'Customers with potential if nurtured properly'
    WHEN recency_score = 3 AND frequency_score >= 2 AND monetary_score >= 2 THEN 'Customers showing signs of declining engagement'
    WHEN recency_score = 2 AND frequency_score >= 2 THEN 'Customers at risk of becoming inactive'
    WHEN recency_score <= 2 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'Important customers who have not purchased recently'
    WHEN recency_score <= 2 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'High-value customers at serious risk of churn'
    WHEN recency_score <= 2 AND frequency_score <= 2 AND monetary_score <= 2 THEN 'Inactive customers with minimal historical engagement'
    ELSE 'Customers who have not engaged for a very long time'
  END AS rfm_segment_description,
  -- Recommended Actions
  CASE
    WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Reward them, early access to new products, VIP treatment'
    WHEN recency_score >= 3 AND frequency_score >= 4 AND monetary_score >= 3 THEN 'Upsell premium products, loyalty programs, exclusive offers'
    WHEN recency_score >= 4 AND frequency_score >= 2 AND monetary_score >= 2 THEN 'Recommend products, build relationship, cross-sell opportunities'
    WHEN recency_score >= 4 AND frequency_score <= 2 THEN 'Welcome emails, onboarding, product recommendations'
    WHEN recency_score >= 3 AND frequency_score <= 2 AND monetary_score >= 2 THEN 'Personalized communication, bundle offers, engagement campaigns'
    WHEN recency_score = 3 AND frequency_score >= 2 AND monetary_score >= 2 THEN 'Re-engagement campaigns, special offers, feedback surveys'
    WHEN recency_score = 2 AND frequency_score >= 2 THEN 'Targeted reactivation campaigns, limited-time offers'
    WHEN recency_score <= 2 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'Win-back campaigns, personalized outreach, high-value incentives'
    WHEN recency_score <= 2 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Urgent intervention, personal contact, premium win-back offers'
    WHEN recency_score <= 2 AND frequency_score <= 2 AND monetary_score <= 2 THEN 'Low-cost reactivation attempts, clearance offers'
    ELSE 'Archive or minimal marketing spend'
  END AS recommended_action
FROM rfm_scores