MODEL (
  name avulcanawslh.test_new.output_model,
  kind FULL,
  grains (name),
  physical_properties (
    format = 'iceberg'
  )
);

-- read from the testawslh
SELECT name, avg(age) FROM avulcanawslh.test_new.input_model group by name;