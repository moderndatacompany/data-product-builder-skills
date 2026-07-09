AUDIT (
  name assert_positive_quantity,
);

SELECT *
FROM @this_model
WHERE l_quantity <= 0;
