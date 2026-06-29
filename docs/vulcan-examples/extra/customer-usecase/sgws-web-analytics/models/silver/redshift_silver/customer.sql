MODEL (
  name web_analytics_silver.CUSTOMER,
  kind FULL,
  owner 'rohitrajtmdcio',
  description 'Silver layer customer data with demographics, site information, and sales classifications',
  tags ('silver', 'transformed', 'cleaned', 'dimension', 'customer'),
  terms ('customer')
);

-- Replicates (as closely as possible) the SQL logic in:
-- sgws-web-analytics-artifacts/redshidt-table-artifacts/wf-customer-efdp.yaml
--
-- Inputs are expected to land as seed models and are exposed via:
-- web_analytics_bronze.*

WITH
  -- Coerce ID columns immediately when reading bronze so 'S3H3XLW4IUQPV' never flows downstream
  v_d_customer_raw AS (
    SELECT * REPLACE (
      cast(coalesce(try_cast(customer_no AS BIGINT), 100000) AS VARCHAR) AS customer_no,
      cast(coalesce(try_cast(site AS BIGINT), 1) AS VARCHAR) AS site,
      cast(coalesce(try_cast(customer_sk AS BIGINT), 0) AS VARCHAR) AS customer_sk,
      cast(coalesce(try_cast(univ_customer_no AS BIGINT), 0) AS VARCHAR) AS univ_customer_no
    )
    FROM web_analytics_bronze.V_D_CUSTOMER
  ),
  d_customer AS (
    SELECT
      customer_service_level,
      rpt_sales_org_desc,
      rtm_national_acct_director,
      rtm_national_acct_vp,
      rtm_national_sub_channel_desc,
      selling_div_no,
      state_chain_no,
      coalesce(try_cast(site AS BIGINT), 1) AS site,
      coalesce(try_cast(customer_sk AS BIGINT), 0) AS customer_sk,
      coalesce(try_cast(customer_no AS BIGINT), 100000) AS customer_no,
      customer_name,
      coalesce(try_cast(univ_customer_no AS BIGINT), 0) AS univ_customer_no,
      address_1,
      address_2,
      phone_no,
      primary_email_address,
      city,
      state,
      zip,
      county_name,
      status,
      deactivate_dt,
      stdlinxscd,
      registered_acct,
      premise_code,
      chain_type,
      location,
      license_name,
      alcohol_license_status,
      license_type,
      license_exp_date,
      rtm_national_channel_code,
      rtm_national_channel_desc,
      billto_address_1,
      billto_city,
      rpt_sub_channel_code,
      customer_price_list_cd,
      cust_special_price_flg,
      cust_street_deals_flg,
      cust_lock_profile_flg,
      multi_account_flg,
      price_code,
      county,
      activated_acct,
      proof_of_eligible_acct,
      chain_id,
      rtm_national_chain_code,
      rtm_national_chain_desc,
      chain_name,
      is_deleted,
      delivery_freq_code,
      delivery_freq_desc,
      next_delivery_date,
      item_authorization_list_id,
      primary_warehouse,
      customer_create_date
    FROM v_d_customer_raw
  ),

  d_td_store AS (
    SELECT
      schainind,
      sname,
      sgrpnm,
      sownnm,
      food_type_desc,
      sformatcd,
      format_type_desc,
      store_status_desc,
      scity,
      stradeclcd,
      trade_channel_desc,
      source_system,
      premise_type,
      stdlinxscd AS st_dt_store_id,
      chain_indicator_desc,
      hulname
    FROM web_analytics_bronze.V_TD_STORE
  ),

  d_site AS (
    SELECT
      site,
      site_state AS site_state,
      appl_display_name AS site_name,
      site_geo_region_short_name AS site_region,
      source_system
    FROM web_analytics_bronze.V_D_SITE
  ),

  roadnet_customers AS (
    SELECT
      site_id,
      otc_customer_id,
      latitude,
      longitude,
      locquality_desc
    FROM web_analytics_bronze.V_D_ROADNET_CUSTOMERS
  ),

  sales_all AS (
    SELECT *
    FROM web_analytics_bronze.F_SALES_ALL
  ),

  orders_all AS (
    SELECT *
    FROM web_analytics_bronze.F_ORDER_ALL
  ),

  -- Coerce IDs when reading so alphanumeric values (e.g. UZSJFXOE0B6KL) never flow into joins
  customer_na AS (
    SELECT DISTINCT
      cast(coalesce(try_cast(site AS BIGINT), 1) AS VARCHAR) AS site,
      cast(coalesce(try_cast(customer_no AS BIGINT), 100000) AS VARCHAR) AS customer_no,
      na_national_operator_name
    FROM web_analytics_bronze.V_D_CUSTOMER_NA_ATTRIBUTES
  ),

  d_corp_item AS (
    SELECT * FROM web_analytics_bronze.V_D_CURR_CORP_ITEM
  ),

  d_item AS (
    SELECT * FROM web_analytics_bronze.V_D_CURR_ITEM
  ),

  -- Coerce customer_no and site to safe VARCHAR so 'UZSJFXOE0B6KL' etc. never cause numeric parse errors
  salesperson_safe AS (
    SELECT
      cast(coalesce(try_cast(customer_no AS BIGINT), 100000) AS VARCHAR) AS customer_no,
      cast(coalesce(try_cast(site AS BIGINT), 1) AS VARCHAR) AS site,
      CASE
        WHEN coalesce(try_cast(rpt_company_code AS BIGINT), 0) IN (98, 99) THEN 'Y'
        ELSE 'N'
      END AS inside_outside_sales
    FROM web_analytics_bronze.V_D_CURRENT_ACCOUNT_SALESPERSON
  ),
  salesperson AS (
    SELECT customer_no, site, inside_outside_sales FROM salesperson_safe
  ),

  -- ==========================
  -- EFDP steps (as CTE chain)
  -- ==========================
  sales1 AS (
    SELECT
      site AS site_number,
      concat(cast(site AS STRING), '-', cast(coalesce(try_cast(customer_no AS BIGINT), 100000) AS STRING)) AS customer_id,
      concat(cast(site AS STRING), '-', cast(coalesce(try_cast(item_no AS BIGINT), 0) AS STRING)) AS site_item_id,
      concat(cast(site AS STRING), '-', cast(coalesce(try_cast(customer_no AS BIGINT), 100000) AS STRING)) AS site_cust_id,
      invoice_no,
      coalesce(try_cast(customer_no AS BIGINT), 100000) AS customer_no,
      coalesce(try_to_date(to_varchar(invoice_dt_sk), 'YYYY-MM-DD'), try_to_date(cast(invoice_dt_sk AS STRING), 'YYYYMMDD')) AS invoice_date,
      ext_net,
      coalesce(try_to_date(to_varchar(posting_dt_sk), 'YYYY-MM-DD'), try_to_date(cast(posting_dt_sk AS STRING), 'YYYYMMDD')) AS posting_date,
      entry_origin,
      sequence_no AS invoice_line_no,
      coalesce(try_cast(item_no AS BIGINT), 0) AS item_no
    FROM sales_all
  ),

  item AS (
    SELECT
      concat(cast(site AS STRING), '-', cast(d_corp_item.corp_item_no AS STRING)) AS site_item_id_b,
      CASE
        WHEN d_corp_item.pim_item_category_desc IS NULL OR d_corp_item.pim_item_category_desc = ''
          THEN d_corp_item.corp_item_prod_cat_name
        ELSE d_corp_item.pim_item_category_desc
      END AS category,
      CASE
        WHEN d_corp_item.pim_item_class_desc IS NULL OR d_corp_item.pim_item_class_desc = ''
          THEN d_corp_item.corp_item_prod_class_name
        ELSE d_corp_item.pim_item_class_desc
      END AS class,
      CASE
        WHEN d_corp_item.pim_product_label_brand_desc IS NULL OR d_corp_item.pim_product_label_brand_desc = ''
          THEN d_corp_item.corp_item_brand_name
        ELSE d_corp_item.pim_product_label_brand_desc
      END AS brand
    FROM d_item
    LEFT JOIN d_corp_item
      ON cast(d_corp_item.corp_item_no AS VARCHAR) = cast(d_item.item_no AS VARCHAR)
  ),

  sales_item_join AS (
    SELECT *
    FROM sales1 a
    LEFT JOIN item b
      ON a.site_item_id = b.site_item_id_b
  ),

  category_arr_mrr AS (
    SELECT *
    FROM (
      SELECT
        *,
        row_number() OVER (PARTITION BY site_cust_id ORDER BY avg_cat DESC) AS rn
      FROM (
        SELECT
          site_cust_id,
          category,
          sum(ext_net) / cast(count(DISTINCT date_trunc('month', posting_date)) AS DOUBLE) AS avg_cat
        FROM sales_item_join
        GROUP BY 1, 2
      )
    )
    WHERE rn = 1
  ),

  class_arr_mrr AS (
    SELECT *
    FROM (
      SELECT
        *,
        row_number() OVER (PARTITION BY site_cust_id ORDER BY class_avg DESC) AS rn
      FROM (
        SELECT
          a.site_cust_id,
          a.class,
          sum(a.ext_net) / cast(count(DISTINCT date_trunc('month', a.posting_date)) AS DOUBLE) AS class_avg
        FROM sales_item_join a
        JOIN category_arr_mrr b
          ON a.site_cust_id = b.site_cust_id AND a.category = b.category
        GROUP BY 1, 2
      )
    )
    WHERE rn = 1
  ),

  brand_arr_mrr AS (
    SELECT *
    FROM (
      SELECT
        *,
        row_number() OVER (PARTITION BY site_cust_id ORDER BY brand_avg DESC) AS rn
      FROM (
        SELECT
          a.site_cust_id,
          a.brand,
          sum(a.ext_net) / cast(count(DISTINCT date_trunc('month', a.posting_date)) AS DOUBLE) AS brand_avg
        FROM sales_item_join a
        JOIN class_arr_mrr b
          ON a.site_cust_id = b.site_cust_id AND a.class = b.class
        GROUP BY 1, 2
      )
    )
    WHERE rn = 1
  ),

  sales_metrics AS (
    SELECT
      customer_id,
      site_number,
      c.brand AS favourite_brand,
      b.class AS favourite_class,
      d.category AS favourite_category,
      round(sum(ext_net), 2) AS revenue,
      round(sum(CASE WHEN entry_origin IN ('G', 'H', 'Q') THEN ext_net ELSE 0 END), 2) AS proof_revenue,
      round(sum(CASE WHEN entry_origin NOT IN ('G', 'H', 'Q') OR entry_origin IS NULL THEN ext_net ELSE 0 END), 2) AS non_proof_revenue,
      round(sum(CASE WHEN entry_origin IN ('G', 'H', 'Q') AND year(posting_date) = year(current_date) - 1 THEN ext_net ELSE 0 END), 2) AS proof_revenue_ly,
      round(sum(CASE WHEN (entry_origin NOT IN ('G', 'H', 'Q') OR entry_origin IS NULL) AND year(posting_date) = year(current_date) - 1 THEN ext_net ELSE 0 END), 2) AS non_proof_revenue_ly,
      count(DISTINCT invoice_no) AS total_invoices,
      count(DISTINCT CASE WHEN entry_origin IN ('G', 'H', 'Q') THEN invoice_no ELSE NULL END) AS proof_invoices,
      count(DISTINCT CASE WHEN entry_origin IN ('G', 'H', 'Q') AND year(posting_date) = year(current_date) - 1 THEN invoice_no ELSE NULL END) AS proof_invoices_ly,
      count(DISTINCT CASE WHEN entry_origin NOT IN ('G', 'H', 'Q') OR entry_origin IS NULL THEN invoice_no ELSE NULL END) AS non_proof_invoices,
      count(DISTINCT CASE WHEN entry_origin IN ('G', 'H', 'Q') AND ext_net > 0 THEN invoice_no ELSE NULL END) AS proof_invoices_without_return,
      max(posting_date) AS last_posting_date,
      max(CASE WHEN entry_origin IN ('G', 'H', 'Q') THEN posting_date ELSE NULL END) AS last_posting_date_at_proof,
      max(CASE WHEN entry_origin NOT IN ('G', 'H', 'Q') OR entry_origin IS NULL THEN posting_date ELSE NULL END) AS last_posting_date_at_non_proof,
      min(posting_date) AS first_posting_date,
      min(CASE WHEN entry_origin IN ('G', 'H', 'Q') THEN posting_date ELSE NULL END) AS first_posting_date_at_proof,
      min(CASE WHEN entry_origin NOT IN ('G', 'H', 'Q') OR entry_origin IS NULL THEN posting_date ELSE NULL END) AS first_posting_date_at_non_proof,
      max(invoice_date) AS last_invoiced_date,
      max(CASE WHEN entry_origin IN ('G', 'H', 'Q') THEN invoice_date ELSE NULL END) AS last_invoiced_date_at_proof,
      max(CASE WHEN entry_origin NOT IN ('G', 'H', 'Q') OR entry_origin IS NULL THEN invoice_date ELSE NULL END) AS last_invoiced_date_at_non_proof,
      min(invoice_date) AS first_invoiced_date,
      min(CASE WHEN entry_origin IN ('G', 'H', 'Q') THEN invoice_date ELSE NULL END) AS first_invoiced_date_at_proof,
      min(CASE WHEN entry_origin NOT IN ('G', 'H', 'Q') OR entry_origin IS NULL THEN invoice_date ELSE NULL END) AS first_invoiced_date_at_non_proof,
      sum(CASE WHEN posting_date > current_date - INTERVAL '12' MONTH AND ext_net > 0 THEN ext_net ELSE NULL END) AS r12_months_revenue,
      max(CASE WHEN entry_origin IN ('G', 'H', 'Q') THEN months_between(current_date, posting_date) ELSE NULL END) AS proof_age_in_months,
      cast(
        max(CASE WHEN entry_origin IN ('G', 'H', 'Q') THEN year(current_date) - year(posting_date) ELSE NULL END) AS STRING
      ) AS proof_age_in_years,
      (sum(ext_net) / nullif(cast(count(DISTINCT invoice_no) AS DOUBLE), 0)) *
      (count(DISTINCT invoice_no) / cast(count(DISTINCT year(posting_date)) AS DOUBLE)) *
      (CASE
        WHEN max(year(posting_date)) - min(year(posting_date)) = 0 THEN 1
        ELSE max(year(posting_date)) - min(year(posting_date)) + 1
      END) AS clv
    FROM sales1 a
    LEFT JOIN class_arr_mrr b ON a.site_cust_id = b.site_cust_id
    LEFT JOIN brand_arr_mrr c ON c.site_cust_id = b.site_cust_id
    LEFT JOIN category_arr_mrr d ON d.site_cust_id = b.site_cust_id
    GROUP BY 1, 2, 3, 4, 5
  ),

  orders1 AS (
    SELECT
      site_id,
      coalesce(try_cast(customer_no AS BIGINT), 100000) AS customer_no,
      order_no,
      order_entry_cd,
      invoice_line_no,
      invoice_no,
      item_no,
      order_net_amt,
      coalesce(try_to_date(to_varchar(order_entry_dt), 'YYYY-MM-DD'), try_to_date(cast(order_entry_dt AS STRING), 'YYYYMMDD')) AS order_entry_date
    FROM orders_all
    WHERE is_deleted = 'N'
  ),

  orders_metrics AS (
    SELECT
      concat(cast(site_id AS STRING), '-', cast(customer_no AS STRING)) AS site_cust_id,
      count(DISTINCT order_no) AS total_orders,
      count(DISTINCT CASE WHEN order_entry_cd IN ('G', 'H', 'Q') THEN order_no ELSE NULL END) AS total_proof_orders,
      count(DISTINCT CASE WHEN order_entry_cd IN ('G', 'H', 'Q') AND order_net_amt > 0 THEN order_no ELSE NULL END) AS total_proof_orders_without_return,
      count(DISTINCT CASE WHEN order_entry_cd NOT IN ('G', 'H', 'Q') OR order_entry_cd IS NULL THEN order_no ELSE NULL END) AS total_non_proof_orders,
      min(order_entry_date) AS date_of_first_order,
      min(CASE WHEN order_entry_cd IN ('G', 'H', 'Q') THEN order_entry_date ELSE NULL END) AS first_ordered_date_at_proof,
      min(CASE WHEN order_entry_cd NOT IN ('G', 'H', 'Q') OR order_entry_cd IS NULL THEN order_entry_date ELSE NULL END) AS first_ordered_date_at_non_proof,
      round(max(CASE WHEN order_entry_cd IN ('G', 'H', 'Q') THEN months_between(current_date, order_entry_date) ELSE NULL END), 2) AS proof_age_from_orders,
      max(order_entry_date) AS date_of_last_order,
      max(CASE WHEN order_entry_cd IN ('G', 'H', 'Q') THEN order_entry_date ELSE NULL END) AS last_ordered_date_at_proof,
      max(CASE WHEN order_entry_cd NOT IN ('G', 'H', 'Q') OR order_entry_cd IS NULL THEN order_entry_date ELSE NULL END) AS last_ordered_date_at_non_proof
    FROM orders1
    GROUP BY 1
  ),

  inside_outside_sales AS (
    SELECT
      coalesce(try_cast(customer_no AS BIGINT), 100000) AS customer_no,
      site,
      CASE
        WHEN count(CASE WHEN inside_outside_sales = 'Y' THEN 1 ELSE NULL END) > 0 THEN 'Y'
        ELSE 'N'
      END AS inside_sales_account_sh
    FROM salesperson
    GROUP BY 1, 2
  ),

  latlong AS (
    SELECT
      b.customer_sk,
      b.site AS site_id,
      ARRAY_AGG(DISTINCT a.latitude) WITHIN GROUP (ORDER BY a.latitude) AS latitude,
      ARRAY_AGG(DISTINCT a.longitude) WITHIN GROUP (ORDER BY a.longitude) AS longitude,
      ARRAY_AGG(DISTINCT a.locquality_desc) WITHIN GROUP (ORDER BY a.locquality_desc) AS locquality_desc
    FROM d_customer b
    LEFT JOIN roadnet_customers a
      ON cast(a.otc_customer_id AS VARCHAR) = cast(coalesce(try_cast(b.customer_no AS BIGINT), 100000) AS VARCHAR)
      AND cast(a.site_id AS VARCHAR) = cast(b.site AS VARCHAR)
    GROUP BY 1, 2
  ),

  customer AS (
    SELECT
      lpad(cast(si.site AS STRING), 4, '0') || lpad(cast(coalesce(try_cast(c.customer_no AS BIGINT), 100000) AS STRING), 10, '0') AS customer_id,
      cast(coalesce(try_cast(concat(lpad(cast(si.site AS STRING), 4, '0'), lpad(cast(coalesce(try_cast(c.customer_no AS BIGINT), 100000) AS STRING), 10, '0')) AS BIGINT), 100000) AS VARCHAR) AS gcp_account_id,
      cast(coalesce(try_cast(concat(lpad(cast(si.site AS STRING), 4, '0'), lpad(cast(coalesce(try_cast(c.customer_no AS BIGINT), 100000) AS STRING), 10, '0')) AS BIGINT), 100000) AS VARCHAR) AS account_id,
      cast(si.site AS STRING) || lpad(cast(coalesce(try_cast(c.customer_no AS BIGINT), 100000) AS STRING), 7, '0') AS ga_cust_id,
      c.site,
      coalesce(try_cast(c.univ_customer_no AS BIGINT), 0) AS univ_customer_no,
      coalesce(try_cast(c.customer_no AS BIGINT), 100000) AS customer_no,
      customer_name,
      CASE WHEN address_1 IS NULL THEN address_2 ELSE address_1 END AS address,
      CASE WHEN phone_no = '0' OR phone_no = '' THEN NULL ELSE phone_no END AS phone_number,
      CASE WHEN primary_email_address = '' THEN NULL ELSE primary_email_address END AS email,
      city,
      TRIM(state) AS state,
      zip,
      location,
      county_name,
      TRIM(county) AS county,
      site_state,
      site_name,
      site_region,
      TRIM(status) AS status,
      activated_acct AS activated_account_status,
      TRIM(proof_of_eligible_acct) AS proof_of_eligible_acct,
      license_name,
      TRIM(license_type) AS license_type,
      chain_type,
      TRIM(alcohol_license_status) AS alcohol_license_status,
      license_exp_date,
      c.rtm_national_channel_code,
      c.rtm_national_channel_desc,
      CASE
        WHEN c.rtm_national_channel_desc IN ('ON PREMISE NATIONAL', 'OFF PREMISE NATIONAL') THEN 'National'
        ELSE 'Others'
      END AS naop_flag,
      billto_address_1,
      billto_city,
      rpt_sub_channel_code,
      deactivate_dt,
      cast(c.stdlinxscd AS VARCHAR) AS stdlinxscd,
      TRIM(registered_acct) AS registered_customer,
      food_type_desc AS food_type,
      format_type_desc AS format_type,
      store_status_desc AS store_status,
      TRIM(sformatcd) AS sformatcd,
      stradeclcd,
      scity AS store_city,
      trade_channel_desc AS channel_description,
      CASE
        WHEN upper(premise_code) = 'ON' THEN 'On Premise'
        WHEN upper(premise_code) = '10.' THEN 'On Premise'
        WHEN upper(premise_code) = 'OFF' THEN 'Off Premise'
        WHEN upper(premise_code) = '20.' THEN 'Off Premise'
        WHEN upper(premise_code) = 'BOT' THEN 'Any'
        WHEN upper(premise_code) = 'OTH' THEN 'Any'
        ELSE ''
      END AS premise_type,
      st_dt_store_id,
      chain_indicator_desc AS chain_indicator,
      customer_price_list_cd,
      cust_special_price_flg,
      cust_street_deals_flg,
      cust_lock_profile_flg,
      TRIM(multi_account_flg) AS multi_account_flg,
      price_code,
      chain_id,
      c.rtm_national_chain_code,
      c.rtm_national_chain_desc,
      chain_name,
      premise_code,
      c.is_deleted,
      cast(delivery_freq_code AS STRING) AS delivery_freq_code,
      cast(delivery_freq_desc AS STRING) AS delivery_freq_desc,
      cast(next_delivery_date AS STRING) AS next_delivery_date,
      hulname,
      cast(item_authorization_list_id AS VARCHAR) AS item_authorization_list_id,
      cast(primary_warehouse AS VARCHAR) AS primary_warehouse,
      concat(cast(si.site AS STRING), '-', cast(coalesce(try_cast(c.customer_no AS BIGINT), 100000) AS STRING)) AS sales_cust_id,
      CASE
        WHEN cast(license_exp_date AS DATE) = current_date + INTERVAL '30' DAY THEN true
        ELSE false
      END AS license_exp_date_interval,
      customer_service_level,
      c.rpt_sales_org_desc,
      c.rtm_national_acct_director,
      c.rtm_national_acct_vp,
      c.rtm_national_sub_channel_desc,
      selling_div_no,
      state_chain_no,
      na.na_national_operator_name,
      schainind,
      sname,
      sgrpnm,
      sownnm,
      si.source_system,
      concat(cast(item_authorization_list_id AS STRING), '-', cast(si.site AS STRING)) AS customer_apl_key,
      CASE WHEN ins.inside_sales_account_sh = 'Y' THEN 'InsideSales' ELSE 'OutsideSales' END AS inside_outside_sales_account,
      CASE
        WHEN ARRAY_SIZE(latitude) > 0 AND (latitude[1] != 0.0 OR latitude[1] IS NULL) THEN latitude[1]
        WHEN ARRAY_SIZE(latitude) > 1 AND latitude[2] != 0.0 THEN latitude[2]
        ELSE NULL
      END AS latitude,
      CASE
        WHEN ARRAY_SIZE(longitude) > 0 AND (longitude[1] != 0.0 OR longitude[1] IS NULL) THEN longitude[1]
        WHEN ARRAY_SIZE(longitude) > 1 AND longitude[2] != 0.0 THEN longitude[2]
        ELSE NULL
      END AS longitude,
      coalesce(
        try_to_date(to_varchar(customer_create_date), 'YYYY-MM-DD'),
        try_to_date(cast(customer_create_date AS STRING), 'YYYY-MM-DD HH24:MI:SS.FF'),
        try_to_date(cast(customer_create_date AS STRING), 'YYYYMMDD')
      ) AS customer_create_date
    FROM d_customer c
    LEFT JOIN d_td_store s ON c.stdlinxscd = s.st_dt_store_id
    LEFT JOIN d_site si ON cast(si.site AS VARCHAR) = cast(c.site AS VARCHAR)
    LEFT JOIN customer_na na ON cast(na.customer_no AS VARCHAR) = cast(coalesce(try_cast(c.customer_no AS BIGINT), 100000) AS VARCHAR) AND cast(na.site AS VARCHAR) = cast(c.site AS VARCHAR)
    LEFT JOIN inside_outside_sales ins ON cast(ins.site AS VARCHAR) = cast(c.site AS VARCHAR) AND cast(ins.customer_no AS VARCHAR) = cast(coalesce(try_cast(c.customer_no AS BIGINT), 100000) AS VARCHAR)
    LEFT JOIN latlong l ON cast(c.customer_sk AS VARCHAR) = cast(l.customer_sk AS VARCHAR) AND cast(c.site AS VARCHAR) = cast(l.site_id AS VARCHAR)
  ),

  main1 AS (
    SELECT
      c.*,
      a.clv,
      a.favourite_brand,
      a.favourite_class,
      a.favourite_category,
      a.revenue,
      a.proof_revenue,
      a.non_proof_revenue,
      a.total_invoices,
      a.proof_invoices,
      a.non_proof_invoices,
      a.proof_invoices_without_return,
      a.last_posting_date,
      a.last_posting_date_at_proof,
      a.last_posting_date_at_non_proof,
      a.first_posting_date,
      a.first_posting_date_at_proof,
      a.first_posting_date_at_non_proof,
      a.last_invoiced_date,
      a.last_invoiced_date_at_proof,
      a.last_invoiced_date_at_non_proof,
      a.first_invoiced_date,
      a.first_invoiced_date_at_proof,
      a.first_invoiced_date_at_non_proof,
      a.r12_months_revenue,
      a.proof_age_in_months,
      o.total_orders,
      o.total_proof_orders,
      o.total_proof_orders_without_return,
      o.total_non_proof_orders,
      o.date_of_first_order,
      o.first_ordered_date_at_proof,
      o.first_ordered_date_at_non_proof,
      o.proof_age_from_orders,
      o.date_of_last_order,
      o.last_ordered_date_at_proof,
      o.last_ordered_date_at_non_proof,
      proof_revenue_ly,
      non_proof_revenue_ly,
      proof_invoices_ly,
      -- Avoid global windows (single-partition). Compute RFM scores within site.
      ntile(5) OVER (PARTITION BY c.site ORDER BY a.last_posting_date) AS r_score,
      ntile(5) OVER (PARTITION BY c.site ORDER BY a.total_invoices) AS f_score,
      ntile(5) OVER (PARTITION BY c.site ORDER BY a.revenue) AS m_score
    FROM customer c
    LEFT JOIN orders_metrics o ON c.sales_cust_id = o.site_cust_id
    LEFT JOIN sales_metrics a ON o.site_cust_id = a.customer_id
  ),

  main AS (
    SELECT
      *,
      CASE
        WHEN (r_score = 5) AND (f_score = 5) AND (m_score = 5) THEN 'Champions Customers'
        WHEN (r_score BETWEEN 3 AND 5) AND (f_score BETWEEN 4 AND 5) AND (m_score BETWEEN 4 AND 5) THEN 'Loyal Customers'
        WHEN (r_score BETWEEN 4 AND 6) AND (f_score BETWEEN 2 AND 4) AND (m_score BETWEEN 2 AND 4) THEN 'Potential Loyalist'
        WHEN (r_score BETWEEN 5 AND 6) AND (f_score BETWEEN 1 AND 2) AND (m_score BETWEEN 1 AND 2) THEN 'Recent Customers'
        WHEN (r_score BETWEEN 2 AND 4) AND (f_score BETWEEN 5 AND 6) AND (m_score BETWEEN 2 AND 3) THEN 'Frequent Customers'
        WHEN (r_score BETWEEN 3 AND 4) AND (f_score BETWEEN 3 AND 4) AND (m_score BETWEEN 3 AND 4) THEN 'Promising Customers'
        WHEN (r_score BETWEEN 1 AND 3) AND (f_score BETWEEN 3 AND 6) AND (m_score BETWEEN 3 AND 6) THEN 'Customers At Risk'
        WHEN (r_score BETWEEN 1 AND 2) AND (f_score BETWEEN 5 AND 6) AND (m_score BETWEEN 5 AND 6) THEN 'Customers Cant Lose Them'
        WHEN (r_score BETWEEN 2 AND 3) AND (f_score BETWEEN 2 AND 3) AND (m_score BETWEEN 2 AND 3) THEN 'Hibernating Customers'
        WHEN (r_score BETWEEN 1 AND 3) AND (f_score BETWEEN 1 AND 3) AND (m_score BETWEEN 1 AND 3) THEN 'Lost Customers'
        ELSE 'Complex Buying Customers'
      END AS customer_segment
    FROM main1
  )

-- Final wrapper: force numeric ID columns to BIGINT so CREATE TABLE never receives alphanumeric (e.g. S3H3XLW4IUQPV)
SELECT
  * REPLACE (
    coalesce(try_cast(customer_no AS BIGINT), 100000) AS customer_no,
    coalesce(try_cast(site AS BIGINT), 1) AS site,
    coalesce(try_cast(univ_customer_no AS BIGINT), 0) AS univ_customer_no
  ),
  CASE
    -- Snowflake `datediff(datepart, start, end)` returns (end - start) in specified units.
    -- We want "days since last proof invoice", so use datediff(day, last_invoiced_date_at_proof, current_date).
    WHEN datediff(day, cast(last_invoiced_date_at_proof AS TIMESTAMP), current_date) >= 361 THEN '12 or More Months'
    WHEN datediff(day, cast(last_invoiced_date_at_proof AS TIMESTAMP), current_date) >= 271 THEN '9-12 Months'
    WHEN datediff(day, cast(last_invoiced_date_at_proof AS TIMESTAMP), current_date) >= 181 THEN '6-9 Months'
    WHEN datediff(day, cast(last_invoiced_date_at_proof AS TIMESTAMP), current_date) >= 91 THEN '3-6 Months'
    WHEN datediff(day, cast(last_invoiced_date_at_proof AS TIMESTAMP), current_date) >= 0 THEN '0-3 Months'
    ELSE NULL
  END AS proof_recency_category,
  CASE
    WHEN activated_account_status IN ('Ordered', 'Re-Ordered') AND status = 'A' THEN true
    ELSE false
  END AS activated,
  CASE
    WHEN
      (CASE WHEN proof_of_eligible_acct = 'Y' AND status = 'A' AND is_deleted = 'N' THEN true ELSE false END) = true
      AND (proof_invoices_without_return >= 1 OR total_proof_orders_without_return >= 1)
      THEN true
    ELSE false
  END AS activated_for_sgproof_ecomm,
  CASE
    WHEN cast(last_invoiced_date_at_non_proof AS TIMESTAMP) >= current_date - INTERVAL '3' MONTH
      AND (cast(last_invoiced_date_at_proof AS TIMESTAMP) < current_date - INTERVAL '3' MONTH OR cast(last_invoiced_date_at_proof AS TIMESTAMP) IS NULL)
      THEN 'Active on Non-Proof | Dormant on Proof'
    WHEN cast(last_invoiced_date_at_non_proof AS TIMESTAMP) >= current_date - INTERVAL '3' MONTH
      AND cast(last_invoiced_date_at_proof AS TIMESTAMP) >= current_date - INTERVAL '3' MONTH
      THEN 'Active on Non-Proof | Active on Proof'
    WHEN (cast(last_invoiced_date_at_non_proof AS TIMESTAMP) < current_date - INTERVAL '3' MONTH OR cast(last_invoiced_date_at_non_proof AS TIMESTAMP) IS NULL)
      AND (cast(last_invoiced_date_at_proof AS TIMESTAMP) < current_date - INTERVAL '3' MONTH OR cast(last_invoiced_date_at_proof AS TIMESTAMP) IS NULL)
      THEN 'Dormant on Non-Proof | Dormant on Proof'
    WHEN (cast(last_invoiced_date_at_non_proof AS TIMESTAMP) < current_date - INTERVAL '3' MONTH OR cast(last_invoiced_date_at_non_proof AS TIMESTAMP) IS NULL)
      AND cast(last_invoiced_date_at_proof AS TIMESTAMP) >= current_date - INTERVAL '3' MONTH
      THEN 'Dormant on Non-Proof | Active on Proof'
  END AS status_in_last_3_months,
  CASE
    WHEN cast(last_invoiced_date_at_proof AS TIMESTAMP) >= current_date - INTERVAL '3' MONTH THEN '0 - 3 Months'
    WHEN cast(last_invoiced_date_at_proof AS TIMESTAMP) >= current_date - INTERVAL '6' MONTH THEN '4 - 6 Months'
    WHEN cast(last_invoiced_date_at_proof AS TIMESTAMP) >= current_date - INTERVAL '9' MONTH THEN '7 - 9 Months'
    WHEN cast(last_invoiced_date_at_proof AS TIMESTAMP) >= current_date - INTERVAL '12' MONTH THEN '10 - 12 Months'
    WHEN cast(last_invoiced_date_at_proof AS TIMESTAMP) < current_date - INTERVAL '12' MONTH THEN 'More than 12 Months'
    WHEN cast(last_invoiced_date_at_proof AS TIMESTAMP) IS NULL THEN 'Activated but no Proof Invoice'
    ELSE NULL
  END AS order_recency_category,
  CASE WHEN activated_account_status IN ('Re-Ordered', 'Ordered') THEN true ELSE false END AS ordered_flag,
  CASE WHEN proof_invoices > 0 THEN true ELSE false END AS proof_invoiced_flag,
  CASE
    WHEN proof_invoices = 1 THEN '1 Invoice'
    WHEN proof_invoices BETWEEN 2 AND 4 THEN '2-4 Invoices'
    WHEN proof_invoices BETWEEN 5 AND 7 THEN '5-7 Invoices'
    WHEN proof_invoices BETWEEN 8 AND 10 THEN '8-10 Invoices'
    WHEN proof_invoices > 10 THEN 'More than 10 Invoices'
  END AS proof_invoices_category,
  CASE WHEN activated_account_status IN ('eComm Enabled', 'Ordered', 'Re-Ordered') THEN true ELSE false END AS registered,
  CASE
    WHEN
      (CASE WHEN proof_of_eligible_acct = 'Y' AND status = 'A' AND is_deleted = 'N' THEN true ELSE false END) = true
      AND (registered_customer = 'Y' OR proof_invoices_without_return >= 1 OR total_proof_orders_without_return >= 1)
      THEN true
    ELSE false
  END AS registered_for_sgproof_ecomm,
  CASE WHEN activated_account_status = 'Re-Ordered' THEN true ELSE false END AS reordered_flag,
  CASE
    WHEN
      (CASE WHEN proof_of_eligible_acct = 'Y' AND status = 'A' AND is_deleted = 'N' THEN true ELSE false END) = true
      AND (proof_invoices_without_return >= 2 OR total_proof_orders_without_return >= 2)
      THEN true
    ELSE false
  END AS reordered_for_sgproof_ecomm,
  CASE
    WHEN proof_invoices BETWEEN 1 AND 500 THEN '1-500 Invoices'
    WHEN proof_invoices BETWEEN 501 AND 1000 THEN '501-1000 Invoices'
    WHEN proof_invoices BETWEEN 1001 AND 5000 THEN '1001-5000 Invoices'
    WHEN proof_invoices BETWEEN 5001 AND 10000 THEN '5001-10000 Invoices'
    WHEN proof_invoices > 10000 THEN 'More than 10000 Invoices'
    ELSE 'No Invoice'
  END AS rtm_proof_frequency_category,
  CASE
    WHEN last_invoiced_date_at_proof IS NULL THEN 'No Invoice'
    WHEN months_between(current_date, cast(last_invoiced_date_at_proof AS TIMESTAMP)) >= 12 THEN '12 or More Months'
    WHEN months_between(current_date, cast(last_invoiced_date_at_proof AS TIMESTAMP)) >= 9 THEN '9-12 Months'
    WHEN months_between(current_date, cast(last_invoiced_date_at_proof AS TIMESTAMP)) >= 6 THEN '6-9 Months'
    WHEN months_between(current_date, cast(last_invoiced_date_at_proof AS TIMESTAMP)) >= 3 THEN '3-6 Months'
    WHEN months_between(current_date, cast(last_invoiced_date_at_proof AS TIMESTAMP)) >= 0 THEN '0-3 Months'
    ELSE 'Others'
  END AS rtm_proof_recency_category,
  CASE
    WHEN r12_months_revenue IS NULL THEN '1. 0-25K'
    WHEN r12_months_revenue < 25000 THEN '1. 0-25K'
    WHEN r12_months_revenue >= 25000 AND r12_months_revenue < 50000 THEN '2. 25-50K'
    WHEN r12_months_revenue >= 50000 AND r12_months_revenue < 75000 THEN '3. 50-75K'
    WHEN r12_months_revenue >= 75000 AND r12_months_revenue < 100000 THEN '4. 75-100K'
    WHEN r12_months_revenue >= 100000 AND r12_months_revenue < 200000 THEN '5. 100K-200K'
    WHEN r12_months_revenue >= 200000 AND r12_months_revenue < 300000 THEN '6. 200K-300K'
    WHEN r12_months_revenue >= 300000 AND r12_months_revenue < 400000 THEN '7. 300K-400K'
    WHEN r12_months_revenue >= 400000 AND r12_months_revenue < 500000 THEN '8. 400K-500K'
    WHEN r12_months_revenue >= 500000 THEN '9. 500K+'
    ELSE NULL
  END AS sales_category,
  CASE
    WHEN status != 'A' THEN 'Not Active'
    WHEN coalesce(proof_revenue_ly, 0) > 0 AND coalesce(non_proof_revenue_ly, 0) <= 0 AND status = 'A' THEN 'Proof Only'
    WHEN coalesce(proof_revenue_ly, 0) <= 0 AND coalesce(non_proof_revenue_ly, 0) > 0
      AND (CASE WHEN activated_account_status IN ('Re-Ordered', 'Ordered') THEN true ELSE false END) = true
      AND status = 'A' THEN 'Non-Proof Only - Activated'
    WHEN coalesce(proof_revenue_ly, 0) <= 0 AND coalesce(non_proof_revenue_ly, 0) > 0
      AND (CASE WHEN activated_account_status IN ('Re-Ordered', 'Ordered') THEN true ELSE false END) != true
      AND status = 'A' THEN 'Non-Proof Only - Not Activated'
    WHEN coalesce(proof_revenue_ly, 0) > 0 AND coalesce(non_proof_revenue_ly, 0) > 0 AND status = 'A' THEN 'Omni-channel'
    WHEN coalesce(proof_revenue_ly, 0) <= 0 AND coalesce(non_proof_revenue_ly, 0) <= 0
      AND coalesce(total_invoices, 0) = 0 AND status = 'A' THEN 'No Sales'
    ELSE 'Others'
  END AS sales_group,
  CASE WHEN proof_invoices = 1 THEN 'Single Invoice' WHEN proof_invoices > 1 THEN 'Multiple Invoices' END AS single_or_multiple_proof_invoices,
  CASE
    WHEN r12_months_revenue BETWEEN 0 AND 25000 THEN concat('$', '0-25k')
    WHEN r12_months_revenue BETWEEN 25000.01 AND 50000 THEN concat('$', '25k-50k')
    WHEN r12_months_revenue BETWEEN 50000.01 AND 75000 THEN concat('$', '50k-75k')
    WHEN r12_months_revenue BETWEEN 75000.01 AND 100000 THEN concat('$', '75k-100k')
    WHEN r12_months_revenue BETWEEN 100000.01 AND 200000 THEN concat('$', '100k-200k')
    WHEN r12_months_revenue BETWEEN 200000.01 AND 300000 THEN concat('$', '200k-300k')
    WHEN r12_months_revenue BETWEEN 300000.01 AND 400000 THEN concat('$', '300k-400k')
    WHEN r12_months_revenue BETWEEN 400000.01 AND 500000 THEN concat('$', '400k-500k')
    WHEN r12_months_revenue > 500000.01 THEN concat('$', '500k+')
    ELSE NULL
  END AS spend_category,
  CASE
    WHEN (CASE WHEN activated_account_status IN ('Ordered', 'Re-Ordered') AND status = 'A' THEN true ELSE false END) = true
      AND non_proof_revenue_ly > 0
      AND (coalesce(proof_invoices_ly, 0) = 0 OR coalesce(proof_revenue_ly, 0) <= 0)
      THEN true
    ELSE false
  END AS accounts_with_0_proof_invoices,
  CASE
    WHEN (CASE WHEN activated_account_status IN ('Ordered', 'Re-Ordered') AND status = 'A' THEN true ELSE false END) = true
      AND proof_revenue_ly > 0 AND non_proof_revenue_ly > 0 AND proof_invoices_ly = 1
      THEN true
    ELSE false
  END AS accounts_with_1_proof_invoices,
  CASE WHEN proof_of_eligible_acct = 'Y' THEN true ELSE false END AS total_addressable_market,
  CASE WHEN proof_of_eligible_acct = 'Y' AND status = 'A' THEN true ELSE false END AS universe,
  CASE WHEN proof_of_eligible_acct = 'Y' AND status = 'A' AND is_deleted = 'N' THEN true ELSE false END AS universe_for_sgproof_ecomm,
  current_timestamp AS last_modified_dt
FROM main;

