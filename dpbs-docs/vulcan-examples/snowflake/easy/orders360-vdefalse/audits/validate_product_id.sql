AUDIT (
  name validate_product_id
);

SELECT *
FROM @this_model
WHERE PRODUCT_ID IS NULL
