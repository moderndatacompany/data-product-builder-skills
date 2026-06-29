AUDIT (
  name assert_positive_order_keys,
);

SELECT *
FROM @this_model
WHERE o_orderkey < 0;
