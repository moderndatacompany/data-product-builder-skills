AUDIT (
  name validate_customer_id,
  standalone true,
  blocking false
);

SELECT *
FROM @this_model
WHERE customer_id IS NULL;
