-- Seed so RFM models can run without ONESOURCEPLUS. Replace with real source when ONESOURCEPLUS exists.
MODEL (
  name cobs.v_fact_sales_stage,
  kind SEED (
    path '../seeds/v_fact_sales_stage.csv',
  ),
  columns (
    customer_no INT,
    site INT,
    posting_dt_sk INT,
    invoice_no INT,
    posting_prd INT,
    ext_net DOUBLE,
    entry_origin VARCHAR,
    cases INT
  )
);
