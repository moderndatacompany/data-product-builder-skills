AUDIT (
  name positive_values,
);

SELECT *
FROM @this_model
WHERE @column < 0;

