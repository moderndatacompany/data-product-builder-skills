# SQLMesh Built-in Audits

Reference: [SQLMesh Auditing](https://sqlmesh.readthedocs.io/en/stable/concepts/audits/)

Built-in audits are **blocking** by default. Each has a **non-blocking** counterpart (suffix `_non_blocking`).

---

## Generic assertion audit

| Audit | Description |
|-------|-------------|
| `forall` | Ensures a set of arbitrary boolean SQL expressions evaluate to `TRUE` for all rows. |
| `forall_non_blocking` | Non-blocking version of `forall`. |

---

## Row counts and NULL value audits

| Audit | Description |
|-------|-------------|
| `number_of_rows` | Ensures the number of rows in the model's table exceeds the threshold. |
| `number_of_rows_non_blocking` | Non-blocking version. |
| `not_null` | Ensures specified columns do not contain `NULL` values. |
| `not_null_non_blocking` | Non-blocking version. |
| `at_least_one` | Ensures specified columns contain at least one non-NULL value. |
| `at_least_one_non_blocking` | Non-blocking version. |
| `not_null_proportion` | Ensures the specified column's proportion of `NULL` values is no greater than a threshold. |
| `not_null_proportion_non_blocking` | Non-blocking version. |

---

## Specific data values audits

| Audit | Description |
|-------|-------------|
| `not_constant` | Ensures specified columns are not constant (at least two non-NULL values). |
| `not_constant_non_blocking` | Non-blocking version. |
| `unique_values` | Ensures specified columns contain unique values (no duplicates). |
| `unique_values_non_blocking` | Non-blocking version. |
| `unique_combination_of_columns` | Ensures each row has a unique combination of values over the specified columns. |
| `unique_combination_of_columns_non_blocking` | Non-blocking version. |
| `accepted_values` | Ensures all rows of the specified column contain one of the accepted values. |
| `accepted_values_non_blocking` | Non-blocking version. |
| `not_accepted_values` | Ensures no rows of the specified column contain one of the not-accepted values. |
| `not_accepted_values_non_blocking` | Non-blocking version. |

---

## Numeric data audits

| Audit | Description |
|-------|-------------|
| `sequential_values` | Ensures an ordered numeric column's values are sequential (previous + interval). |
| `sequential_values_non_blocking` | Non-blocking version. |
| `accepted_range` | Ensures a column's values are in a numeric range (inclusive by default). |
| `accepted_range_non_blocking` | Non-blocking version. |
| `mutually_exclusive_ranges` | Ensures each row's numeric range does not overlap with any other row's range. |
| `mutually_exclusive_ranges_non_blocking` | Non-blocking version. |

---

## Character data audits

| Audit | Description |
|-------|-------------|
| `not_empty_string` | Ensures no rows contain an empty string `''`. |
| `not_empty_string_non_blocking` | Non-blocking version. |
| `string_length_equal` | Ensures all rows have a string with the specified number of characters. |
| `string_length_equal_non_blocking` | Non-blocking version. |
| `string_length_between` | Ensures all rows have string length in the specified range (inclusive by default). |
| `string_length_between_non_blocking` | Non-blocking version. |
| `valid_uuid` | Ensures non-NULL rows contain a string with valid UUID structure. |
| `valid_uuid_non_blocking` | Non-blocking version. |
| `valid_email` | Ensures non-NULL rows contain a string with valid email structure. |
| `valid_email_non_blocking` | Non-blocking version. |
| `valid_url` | Ensures non-NULL rows contain a string with valid URL structure. |
| `valid_url_non_blocking` | Non-blocking version. |
| `valid_http_method` | Ensures non-NULL rows contain a valid HTTP method (GET, POST, etc.). |
| `valid_http_method_non_blocking` | Non-blocking version. |
| `match_regex_pattern_list` | Ensures all non-NULL rows match at least one of the specified regex patterns. |
| `match_regex_pattern_list_non_blocking` | Non-blocking version. |
| `not_match_regex_pattern_list` | Ensures no non-NULL rows match any of the specified regex patterns. |
| `not_match_regex_pattern_list_non_blocking` | Non-blocking version. |
| `match_like_pattern_list` | Ensures all non-NULL rows are `LIKE` at least one of the specified patterns. |
| `match_like_pattern_list_non_blocking` | Non-blocking version. |
| `not_match_like_pattern_list` | Ensures no non-NULL rows are `LIKE` any of the specified patterns. |
| `not_match_like_pattern_list_non_blocking` | Non-blocking version. |

---

## Statistical audits

| Audit | Description |
|-------|-------------|
| `mean_in_range` | Ensures a numeric column's mean is in the specified range (inclusive by default). |
| `mean_in_range_non_blocking` | Non-blocking version. |
| `stddev_in_range` | Ensures a numeric column's standard deviation is in the specified range. |
| `stddev_in_range_non_blocking` | Non-blocking version. |
| `z_score` | Ensures no rows have a value whose absolute z-score exceeds the threshold. |
| `z_score_non_blocking` | Non-blocking version. |
| `kl_divergence` | Ensures symmetrised KL divergence between two columns does not exceed threshold. |
| `kl_divergence_non_blocking` | Non-blocking version. |
| `chi_square` | Ensures the chi-square statistic for two categorical columns does not exceed a critical value. |
| `chi_square_non_blocking` | Non-blocking version. |

---

## Summary count

- **Categories:** 6 (generic assertion, row/NULL, data values, numeric, character, statistical)
- **Blocking audits:** 28 unique audit types
- **Total (including non-blocking):** 56 audit names

---

## Usage in this project

Each built-in audit (blocking) is used **once** in the models under `models/`:

| Audit | Model |
|-------|--------|
| `forall` | tpch_orders_sf1 |
| `number_of_rows` | tpch_partsupp_sf1 |
| `not_null` | multiple (customer, lineitem, part, supplier, nation, region, partsupp, view_order_line_summary, seed_segment, region_daily_orders, full_customer_orders, full_active_customer_orders, customer_snapshot, stg_customer_nation) |
| `at_least_one` | tpch_nation_sf1 |
| `not_null_proportion` | tpch_supplier_sf1 |
| `not_constant` | tpch_region_sf1 |
| `unique_values` | multiple (customer, orders, supplier, region, part, nation, partsupp, view_order_line_summary, seed_segment, region_daily_orders, full_customer_orders, full_active_customer_orders, customer_snapshot, stg_customer_nation) |
| `unique_combination_of_columns` | tpch_lineitem_sf1, tpch_partsupp_sf1 |
| `accepted_values` | tpch_orders_sf1 |
| `not_accepted_values` | tpch_lineitem_sf1 |
| `sequential_values` | seed_segment_sf1 |
| `accepted_range` | tpch_part_sf1 |
| `mutually_exclusive_ranges` | tpch_nation_sf1 |
| `not_empty_string` | tpch_supplier_sf1 |
| `string_length_equal` | tpch_orders_sf1 |
| `string_length_between` | tpch_region_sf1 |
| `valid_uuid` | emb_active_customers_sf1 |
| `valid_email` | stg_customer_nation_sf1 |
| `valid_url` | full_customer_orders_sf1 |
| `valid_http_method` | full_active_customer_orders_sf1 |
| `match_regex_pattern_list` | tpch_lineitem_sf1 |
| `not_match_regex_pattern_list` | tpch_part_sf1 |
| `match_like_pattern_list` | tpch_customer_sf1 |
| `not_match_like_pattern_list` | tpch_region_sf1 |
| `mean_in_range` | view_order_line_summary_sf1 |
| `stddev_in_range` | region_daily_orders_sf1 |
| `z_score` | full_active_customer_orders_sf1 |
| `kl_divergence` | tpch_lineitem_sf1 |
| `chi_square` | tpch_orders_sf1 |
