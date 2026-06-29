AUDIT (
  name assert_positive_revenue,
);

SELECT *
FROM @this_model
WHERE total_revenue < 0;
