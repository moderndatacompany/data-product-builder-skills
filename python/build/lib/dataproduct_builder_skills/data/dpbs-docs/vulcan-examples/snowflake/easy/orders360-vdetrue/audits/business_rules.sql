AUDIT (
  name validate_customer_id
);

SELECT *
FROM @this_model
WHERE CUSTOMER_ID IS NULL
