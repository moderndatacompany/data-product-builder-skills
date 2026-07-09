AUDIT (
  name assert_valid_order_status,
);

SELECT *
FROM @this_model
WHERE o_orderstatus NOT IN ('F', 'O', 'P');
