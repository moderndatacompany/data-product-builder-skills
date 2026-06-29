AUDIT (
  name validate_order_id
);

SELECT *
FROM @this_model
WHERE ORDER_ID IS NULL
