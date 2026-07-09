MODEL (
  name cobs.rfm_segment_mapping,
  kind SEED (
    path '../seeds/rfm_segment_mapping.csv',
  ),
  columns (
    Sales_Bucket VARCHAR,
    recency_score INT,
    frequency_score INT,
    wallet_score INT,
    segment VARCHAR
  )
);
