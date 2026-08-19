-- Seed so RFM models can run without ONESOURCEPLUS. Replace with real source when ONESOURCEPLUS exists.
MODEL (
  name cobs.v_d_customer_stage,
  kind SEED (
    path '../seeds/v_d_customer_stage.csv',
  ),
  columns (
    customer_no INT,
    site INT,
    status VARCHAR,
    activated_acct VARCHAR,
    rtm_national_channel_desc VARCHAR,
    proof_of_eligible_acct VARCHAR
  )
);
