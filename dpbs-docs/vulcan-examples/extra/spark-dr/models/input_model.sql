MODEL (
  name avulcanawslh.test_new.input_model,
  kind FULL,
  grains (increment_id),
  physical_properties (
    format = 'iceberg'
  )
);

-- read from the testawslh
SELECT increment_id, name, age, email FROM avulcanawslh.test_new.ds2_dec_final_pg_to_mongo_batch;