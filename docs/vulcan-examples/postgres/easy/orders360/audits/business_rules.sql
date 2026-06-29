AUDIT (
  name validate_customer_id
);

SELECT *
FROM @this_model
WHERE customer_id IS NULL;
