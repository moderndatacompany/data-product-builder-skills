MODEL (
  name web_analytics_silver.PRODUCT,
  kind FULL,
  owner 'rohitrajtmdcio',
  description 'Silver layer product catalog data with brand, classification, and supplier information',
  tags ('silver', 'transformed', 'cleaned', 'dimension', 'product'),
  terms ('product')
);

-- Replicates (as closely as possible) the SQL logic in:
-- sgws-web-analytics-artifacts/redshidt-table-artifacts/wf-product-efdp.yaml

WITH
  d_item_dataos AS (
    SELECT * FROM web_analytics_bronze.V_D_CURR_ITEM
  ),
  f_npw_pricing AS (
    SELECT * FROM web_analytics_bronze.V_F_NPW_PRICING
  ),
  d_corp_item_dataos AS (
    SELECT * FROM web_analytics_bronze.V_D_CURR_CORP_ITEM
  ),
  d_site_dataos AS (
    SELECT * FROM web_analytics_bronze.V_D_SITE
  ),
  sales_tempdata AS (
    SELECT * FROM web_analytics_bronze.V_FACT_SALES
  ),
  bestseller_badge AS (
    SELECT * FROM web_analytics_bronze.BESTSELLER_BADGE
  ),
  new_badge AS (
    SELECT * FROM web_analytics_bronze.NEW_BADGE
  ),
  trending_badge AS (
    SELECT * FROM web_analytics_bronze.TRENDING_BADGE
  ),
  product_details AS (
    SELECT * FROM web_analytics_bronze.PRODUCT_DETAILS
  ),
  site_product_details AS (
    SELECT * FROM web_analytics_bronze.SITE_PRODUCT_DETAILS
  ),

  product AS (
    SELECT
      i.site AS site_number,
      concat(cast(i.site AS STRING), '-', cast(i.item_no AS STRING)) AS site_item_pk_product,
      ci.producer AS ci_producer,
      s.appl_display_name AS site_name,
      s.site_state AS site_code,
      cast(item_premise_type_sold_at AS STRING) AS site_product_premise,
      cast(ci.pim_premise_type AS STRING) AS product_premise,
      ci.corp_item_desc,
      initcap(ci.pim_product_name) AS pim_product_name,
      replace(initcap(ci.corp_item_suppl_name), 'Usa', 'USA') AS supplier,
      ci.pim_item_long_desc,
      coalesce(try_cast(ci.corp_item_no AS BIGINT), 0) AS itemnumber,
      ci.pim_item_category_desc,
      ci.corp_item_region_name,
      CASE
        WHEN ci.corp_item_region_name LIKE 'DNA%' THEN ''
        ELSE initcap(ci.corp_item_region_name)
      END AS region,
      ci.pim_country_of_origin,
      ci.corp_item_size,
      ci.closure,
      ci.bot_type,
      ci.corp_item_bttls_pcas AS corp_bpc,
      ci.corp_item_brand_name,
      ci.corp_item_suppl_name,
      ci.type_desc,
      ci.subtyp_desc,
      ci.pim_item_varietal_desc,
      initcap(ci.pim_item_varietal_desc) AS varietal,
      ci.corp_item_appel_name,
      CASE
        WHEN ci.corp_item_appel_name LIKE 'DNA%' THEN ''
        ELSE initcap(ci.corp_item_appel_name)
      END AS appellation,
      ci.corp_item_cnty_name AS country,
      i.division_desc,
      i.division_cd,
      ci.corp_item_upc AS corp_item_upc,
      ci.pim_product_num AS productnumber,
      i.group_desc,
      ci.corp_item_status AS status,
      i.status AS item_status,
      cast(i.frontline_price AS DECIMAL(18, 2)) AS frontline1_case_price,
      cast(npw.frontline_case_price2 AS DECIMAL(18, 2)) AS frontline2_case_price,
      i.bottles_case AS site_bpc,
      i.item_reserve_flag,
      ci.corp_item_pack_case AS pack_size,
      i.publish_item_ind,
      ci.corp_item_prod_cat_name,
      ci.corp_item_alcoh_perc AS alcohol_by_volume,
      ci.ready_to_drink_ind AS ready_to_drink_rtd,
      i.suppl_name,
      i.brand_name,
      ci.pim_sub_region_desc,
      i.item_portal_visibility AS proof_flag_item,
      i.otc_portal_community_visibility_cd,
      ci.apel_villg,
      ci.corp_item_vintage,
      ci.national_service_model,
      ci.pim_service_category,
      ci.corp_item_proof,
      ci.corp_item_flavor,
      cast(i.item_status_cd AS STRING) AS item_status_cd,
      i.item_status_descr,
      i.item_status_reason_desc,
      cast(i.item_reason_cd AS STRING) AS item_reason_cd,
      i.item_active_reason_desc,
      ci.pim_replacement_item_effective_dt,
      ci.pim_replacement_id,
      IF(ci.pim_product_num IS NULL, 0, count(ci.pim_product_num) OVER (PARTITION BY i.site, ci.pim_product_num)) AS liquiditemcount,
      ci.corp_item_prod_class_name AS class,
      ci.pim_item_sub_class_desc AS sub_class,
      ci.proprietary,
      i.item_innovation_desc,
      i.item_closeout_ind,
      i.rpt_company_desc,
      ci.brand_ownership_type_desc,
      ci.packge_dsc,
      initcap(ci.pim_product_name) AS liquidname,
      ci.pim_romantic_desc AS romantic_description,
      i.suppl_no,
      i.brand_no,
      ci.varietal_code,
      ci.marketing_desc,
      i.price_group_1_no AS pricegrp1_promobrandnumber,
      i.price_group_1_name AS pricegrp1_promobrandname,
      i.price_group_2_no AS pricegrp2_promohousebrandnumber,
      i.price_group_2_name AS pricegrp2_promohousebrandname,
      i.item_sales_company AS item_sales_company,
      i.item_separate_pricing_ind AS item_separate_pricing_ind,
      i.effective_from_dt AS effective_from_dt,
      i.effective_thru_dt AS effective_thru_dt,
      ci.corp_item_brand AS corp_item_brand_no,
      i.sub_group_desc,
      ci.corp_item_prod_super_group_name AS product_super_group_name,
      ci.corp_item_prod_sb_nm,
      ci.corp_item_prod_cat_cd,
      ci.corp_item_prod_class,
      i.price_tiers,
      CASE
        WHEN concat(
          coalesce(new_badge.badge, ''),
          CASE
            WHEN trending_badge.badge IS NOT NULL AND new_badge.badge IS NOT NULL THEN concat(';', trending_badge.badge)
            ELSE coalesce(trending_badge.badge, '')
          END,
          CASE
            WHEN bestseller_badge.badge IS NOT NULL AND (trending_badge.badge IS NOT NULL OR new_badge.badge IS NOT NULL)
              THEN concat(';', bestseller_badge.badge)
            ELSE coalesce(bestseller_badge.badge, '')
          END
        ) = '' THEN NULL
        ELSE concat(
          coalesce(new_badge.badge, ''),
          CASE
            WHEN trending_badge.badge IS NOT NULL AND new_badge.badge IS NOT NULL THEN concat(';', trending_badge.badge)
            ELSE coalesce(trending_badge.badge, '')
          END,
          CASE
            WHEN bestseller_badge.badge IS NOT NULL AND (trending_badge.badge IS NOT NULL OR new_badge.badge IS NOT NULL)
              THEN concat(';', bestseller_badge.badge)
            ELSE coalesce(bestseller_badge.badge, '')
          END
        )
      END AS product_badge,
      pd.rating,
      pd.rating_source,
      pd.inner_packs_per_case,
      pd.units_per_inner_pack,
      pd.outer_packaging,
      pd.special_container,
      pd.corp_item_scc,
      pd.level_1_hierarchy_revised,
      spd.required_license,
      spd.excluded_county_numbers,
      spd.control_state_item_id,
      spd.street_deal_no_on,
      spd.street_deal_no_off,
      spd.street_deal_no_any,
      spd.item_sold_by_desc,
      spd.item_sold_by_cases_ind,
      coalesce(try_cast(ci.corp_item_suppl AS BIGINT), 0) AS supplier_number_corporate,
      ci.pim_9l_case_conversion
    FROM d_item_dataos i
    JOIN d_corp_item_dataos ci
      ON cast(i.corp_item_no AS VARCHAR) = cast(ci.corp_item_no AS VARCHAR)
    LEFT JOIN d_site_dataos s
      ON i.site = s.site
    LEFT JOIN f_npw_pricing npw
      ON cast(npw.item_no AS VARCHAR) = cast(i.item_no AS VARCHAR)
      AND npw.site_id = i.site
      AND coalesce(
          try_to_date(cast(pricing_end_date_sk AS VARCHAR), 'YYYY-MM-DD HH24:MI:SS.FF'),
          try_to_date(cast(pricing_end_date_sk AS VARCHAR), 'YYYY-MM-DD'),
          try_to_date(cast(pricing_end_date_sk AS VARCHAR), 'YYYYMMDD')
        ) >= current_date
      AND coalesce(
          try_to_date(cast(pricing_start_date_sk AS VARCHAR), 'YYYY-MM-DD HH24:MI:SS.FF'),
          try_to_date(cast(pricing_start_date_sk AS VARCHAR), 'YYYY-MM-DD'),
          try_to_date(cast(pricing_start_date_sk AS VARCHAR), 'YYYYMMDD')
        ) <= current_date
      AND frontline_case_price2 <> 0
      AND pricing_type_sk = 4
    LEFT JOIN bestseller_badge
      ON cast(i.corp_item_no AS VARCHAR) = cast(bestseller_badge.corp_item_no AS VARCHAR) AND i.site = bestseller_badge.site
    LEFT JOIN new_badge
      ON cast(i.corp_item_no AS VARCHAR) = cast(new_badge.corp_item_no AS VARCHAR) AND i.site = new_badge.site
    LEFT JOIN trending_badge
      ON cast(i.corp_item_no AS VARCHAR) = cast(trending_badge.corp_item_no AS VARCHAR) AND i.site = trending_badge.site
    LEFT JOIN product_details pd
      ON cast(i.item_no AS VARCHAR) = cast(pd.itemnumber AS VARCHAR)
    LEFT JOIN site_product_details spd
      ON cast(i.item_no AS VARCHAR) = cast(spd.itemnumber AS VARCHAR) AND i.site = spd.site_number
  ),

  sec AS (
    SELECT
      min(coalesce(
        try_to_date(to_varchar(posting_dt_sk), 'YYYY-MM-DD'),
        try_to_date(cast(posting_dt_sk AS VARCHAR), 'YYYYMMDD')
      )) AS posting_date,
      site,
      coalesce(try_cast(item_no AS BIGINT), 0) AS item_no
    FROM sales_tempdata
    GROUP BY site, coalesce(try_cast(item_no AS BIGINT), 0)
  )

SELECT
  product.*,
  min(posting_date) OVER (PARTITION BY supplier) AS first_posting_date_supplier,
  IF(pim_sub_region_desc LIKE '%DNA%', '', initcap(pim_sub_region_desc)) AS sub_region,
  initcap(class) AS item_class,
  initcap(corp_item_desc) AS product_name_sc,
  initcap(pim_product_name) AS product_name_cust,
  ('https://cdn1.southernglazers.com/assets/items/' || cast(itemnumber AS STRING) || '/images/front-full-bottle/small-(375x375)' || '/' ||
    'eyJhbGciOiJIUzI1NiJ9.eyJrZXkiOiJrZXkzIiwicmVmZXJlciI6Ii5zYWxlc2ZvcmNlLmNvbSwgLmZvcmNlLmNvbSJ9.XPvGxSMn6TqWRPEH5cPj9SX8st0zvY7gDXjTUBmTISo'
  ) AS imageurl,
  CASE
    WHEN lower(pim_item_category_desc) NOT IN ('spirits', 'wine', 'beer')
      THEN 'https://cdn2.southernglazers.com/assets/default-images/de/other/medium-(750x750).png'
    ELSE concat(' https://cdn2.southernglazers.com/assets/default-images/de/', lower(pim_item_category_desc), '/medium-(750x750).png')
  END AS defaultimageurl,
  initcap(pim_country_of_origin) AS country_of_origin,
  replace(
    CASE
      WHEN corp_item_size LIKE '%.0%' THEN replace(corp_item_size, '.0', '')
      WHEN corp_item_size LIKE '%Z%' THEN replace(corp_item_size, 'Z', 'OZ')
      ELSE corp_item_size
    END,
    ' ',
    ''
  ) AS size,
  initcap(IF(closure = 'UNSPECIFIED CORK TYP', 'CORK', closure)) AS closuretype,
  initcap(bot_type) AS containertype,
  concat_ws('-', initcap(corp_item_desc), cast(itemnumber AS STRING)) AS itemnamenbr,
  replace(initcap(corp_item_brand_name), concat(cast(chr(39) AS STRING), 'S'), concat(cast(chr(39) AS STRING), 's')) AS brand,
  initcap(pim_item_category_desc) AS category,
  IF(type_desc LIKE '%DNA%', ' ', initcap(type_desc)) AS corporate_item_type,
  IF(subtyp_desc LIKE '%DNA%', '', initcap(subtyp_desc)) AS corporate_item_subtype,
  initcap(group_desc) AS group_description,
  (frontline1_case_price / nullif(cast(site_bpc AS DECIMAL(18, 2)), 0)) AS frontline1_price_per_bottle,
  CASE WHEN frontline2_case_price IS NULL THEN NULL ELSE (frontline2_case_price / nullif(cast(site_bpc AS DECIMAL(18, 2)), 0)) END AS frontline2_price_per_bottle,
  CASE
    WHEN item_reserve_flag = 'E' THEN 'Exclusive'
    WHEN item_reserve_flag = 'P' THEN 'Partial'
    WHEN item_reserve_flag = 'F' THEN 'Full'
    WHEN item_reserve_flag = 'G' THEN 'Govern'
    ELSE 'Unreserve'
  END AS reserve_type,
  CASE
    WHEN site_product_premise = '1' THEN 'ON'
    WHEN site_product_premise = '2' THEN 'OFF'
    WHEN site_product_premise = 'A' THEN 'ANY'
    ELSE NULL
  END AS premise,
  CASE
    WHEN corp_item_prod_cat_name IN ('BEER', 'WINE') THEN
      CASE
        WHEN alcohol_by_volume BETWEEN 0 AND 6.59 THEN 'Alcohol_0-6.59 %'
        WHEN alcohol_by_volume BETWEEN 6.6 AND 11.99 THEN 'Alcohol_6.6-11.99 %'
        WHEN alcohol_by_volume BETWEEN 12 AND 13.99 THEN 'Alcohol_12-13.99 %'
        WHEN alcohol_by_volume >= 14 THEN 'Alcohol_14+ %'
      END
    WHEN corp_item_prod_cat_name = 'SPIRITS' THEN NULL
    ELSE cast(alcohol_by_volume AS STRING)
  END AS alcohol_by_volume_bucket,
  IF(apel_villg LIKE '%DNA%', '', initcap(apel_villg)) AS vineyard,
  IF(corp_item_prod_cat_name IN ('SPIRITS'), cast(corp_item_proof AS STRING), NULL) AS proof,
  IF(cast(corp_item_vintage AS STRING) LIKE '0%', NULL, corp_item_vintage) AS vintage,
  CASE
    WHEN corp_item_prod_cat_name = 'SPIRITS' THEN concat(
      initcap(corp_item_prod_cat_name),
      IF(type_desc LIKE '%DNA%', ' ', concat(';', initcap(corp_item_prod_cat_name), '|', initcap(type_desc))),
      IF(subtyp_desc LIKE '%DNA%', ' ', concat(';', initcap(corp_item_prod_cat_name), '|', initcap(type_desc), '|', initcap(subtyp_desc)))
    )
    WHEN corp_item_prod_cat_name = 'WINE' THEN concat(
      initcap(corp_item_prod_cat_name),
      IF(class LIKE '%DNA%', ' ', concat(';', initcap(corp_item_prod_cat_name), '|', initcap(class))),
      IF(varietal LIKE '%DNA%', ' ', concat(';', initcap(corp_item_prod_cat_name), '|', initcap(class), '|', initcap(varietal)))
    )
    ELSE concat(
      initcap(corp_item_prod_cat_name),
      IF(type_desc LIKE '%DNA%', ' ', concat(';', initcap(corp_item_prod_cat_name), '|', initcap(type_desc))),
      IF(subtyp_desc LIKE '%DNA%', ' ', concat(';', initcap(corp_item_prod_cat_name), '|', initcap(type_desc), '|', initcap(subtyp_desc)))
    )
  END AS level_1_hierarchy,
  concat(
    initcap(pim_country_of_origin),
    IF(corp_item_region_name LIKE '%DNA%', ' ', concat(';', initcap(pim_country_of_origin), '|', initcap(corp_item_region_name))),
    IF(pim_sub_region_desc LIKE '%DNA%', ' ', concat(';', initcap(pim_country_of_origin), '|', initcap(corp_item_region_name), '|', initcap(pim_sub_region_desc))),
    IF(corp_item_appel_name LIKE '%DNA%', ' ', concat(';', initcap(pim_country_of_origin), '|', initcap(corp_item_region_name), '|', initcap(pim_sub_region_desc), '|', initcap(corp_item_appel_name))),
    IF(apel_villg LIKE '%DNA%', ' ', concat(';', initcap(pim_country_of_origin), '|', initcap(corp_item_region_name), '|', initcap(pim_sub_region_desc), '|', initcap(corp_item_appel_name), '|', initcap(apel_villg)))
  ) AS level_2_region_hierarchy_extended,
  IF(ci_producer = 'NA - NOT AVAILABLE', NULL, initcap(ci_producer)) AS producer,
  CASE WHEN site_bpc = 0 THEN NULL ELSE site_bpc END AS site_bottles_per_case,
  concat(
    IF(corp_item_suppl_name LIKE '%DNA%', '', supplier),
    IF(corp_item_brand_name LIKE '%DNA%', '', concat(';', supplier, '|', replace(initcap(corp_item_brand_name), 'Usa', 'USA')))
  ) AS level_2_supplier_hierarchy,
  concat(
    initcap(pim_country_of_origin),
    IF(corp_item_region_name LIKE '%DNA%', ' ', concat(';', initcap(pim_country_of_origin), '|', initcap(corp_item_region_name))),
    IF(corp_item_appel_name LIKE '%DNA%', ' ', concat(';', initcap(pim_country_of_origin), '|', initcap(corp_item_region_name), '|', initcap(corp_item_appel_name)))
  ) AS level_2_region_hierarchy,
  initcap(pim_item_long_desc) AS pim_long_desc_item,
  CASE
    WHEN publish_item_ind = 'X' THEN 'Super Blind'
    WHEN publish_item_ind = 'T' THEN 'Exclude from ETS & TOPAZ'
    WHEN publish_item_ind = 'E' THEN 'Exclude from ETS interface'
    WHEN publish_item_ind = 'Y' THEN 'Yes Publish Item'
    WHEN publish_item_ind = 'N' THEN 'No Do not Publish Item'
    WHEN publish_item_ind = 'P' THEN 'Publish'
    WHEN publish_item_ind = 'U' THEN 'Unpublished'
    WHEN publish_item_ind = 'B' THEN 'Blind'
    WHEN publish_item_ind = 'R' THEN 'Restaurant'
    WHEN publish_item_ind = 'Z' THEN 'Closeout'
    WHEN publish_item_ind = 'O' THEN 'Opportunity Buys'
    ELSE ' '
  END AS publish_flag,
  cast(frontline1_case_price AS DECIMAL(18, 2)) AS flprice1,
  initcap(corp_item_flavor) AS flavor,
  initcap(proprietary) AS product_proprietary,
  IF(productnumber IS NOT NULL AND productnumber != '' AND packge_dsc = 'VALUE ADDED PACK', 'Y', 'N') AS value_added_pack,
  initcap(rpt_company_desc) AS division,
  initcap(division_desc) AS item_division_description,
  -- Keep original complex diet_specialty cleanup from EFDP
  replace(
    replace(
      replace(
        replace(
          replace(
            initcap(replace(regexp_replace(marketing_desc,
              ', ANTIOXIDANT|ANTIOXIDANT,|ANTIOXIDANT|, CERTIFIED GREEN|CERTIFIED GREEN,|CERTIFIED GREEN|, CRAFT BEER|CRAFT BEER,|CRAFT BEER|, CRAFT SPIRIT|CRAFT SPIRIT,|CRAFT SPIRIT|, FAIR TRADE|FAIR TRADE,|FAIR TRADE|, FIFTH GROWTH BORDEAUX|FIFTH GROWTH BORDEAUX,|FIFTH GROWTH BORDEAUX|, FIRST GROWTH BORDEAUX|FIRST GROWTH BORDEAUX,|FIRST GROWTH BORDEAUX|, FOURTH GROWTH BORDEAUX|FOURTH GROWTH BORDEAUX,|FOURTH GROWTH BORDEAUX|, IMPROVED FORMULA|IMPROVED FORMULA,|IMPROVED FORMULA|, LOW FAT|LOW FAT,|LOW FAT|, NATURAL|NATURAL,|NATURAL|, NON-GMO|NON-GMO,|NON-GMO|, NOUVEAU|NOUVEAU,|NOUVEAU|, ORANGE WINE/SKIN CONTACT WHITE|ORANGE WINE/SKIN CONTACT WHITE,|ORANGE WINE/SKIN CONTACT WHITE|, SECOND GROWTH BORDEAUX|SECOND GROWTH BORDEAUX,|SECOND GROWTH BORDEAUX|, SECOND LABEL|SECOND LABEL,|SECOND LABEL|, SINGLE BARREL PROGRAM|SINGLE BARREL PROGRAM,|SINGLE BARREL PROGRAM|, THIRD GROWTH BORDEAUX|THIRD GROWTH BORDEAUX,|THIRD GROWTH BORDEAUX|, THIRD LABEL|THIRD LABEL,|THIRD LABEL',
              ''), '-', '- ')),
            '- ', '-'
          ),
          ' (certified For Passover Diet)', ''
        ),
        'Organic Vegan', 'Vegan'
      ),
      'Sustainable Vegan', 'Vegan'
    ),
    ',', ';'
  ) AS diet_specialty,
  CASE
    WHEN item_innovation_desc = 'New Item' THEN 'Y'
    WHEN item_innovation_desc IN ('N', '') THEN 'N'
    WHEN item_innovation_desc IS NULL THEN 'N'
  END AS innovation_item,
  CASE
    WHEN type_desc = 'AGAVE'
      AND subtyp_desc IN ('AGAVE-OTHER', 'FLAVORED TEQUILA', 'MEZCAL', 'SOTOL', 'TEQUILA')
      AND productnumber LIKE '%Prod%' THEN
        CASE
          WHEN proprietary RLIKE 'ABOCADO' THEN 'Abocado (flavored)'
          WHEN proprietary RLIKE 'CRISTA' THEN 'Cristalino'
          WHEN proprietary RLIKE 'EXTRA ANEJO' THEN 'Extra Anejo'
          WHEN proprietary RLIKE 'ANJEJO' THEN 'Anejo'
          WHEN proprietary RLIKE 'ANEJO' THEN 'Anejo'
          WHEN proprietary RLIKE 'BLANCO' THEN 'Blanco'
          WHEN proprietary RLIKE 'FLAVORED' THEN 'Flavored'
          WHEN proprietary RLIKE 'GOLD' THEN 'Gold'
          WHEN proprietary RLIKE 'JOVEN' THEN 'Joven'
          WHEN proprietary RLIKE 'MADURADO' THEN 'Madurado en Vidrio'
          WHEN proprietary RLIKE 'MEZQUILA' THEN 'Mezquila'
          WHEN proprietary RLIKE 'ORO' THEN 'Gold'
          WHEN proprietary RLIKE 'PLATA' THEN 'Blanco'
          WHEN proprietary RLIKE 'REPOS' THEN 'Reposado'
          WHEN proprietary RLIKE 'SILVER' THEN 'Blanco'
          WHEN proprietary RLIKE 'WHITE' THEN 'Blanco'
          ELSE 'Other'
        END
    ELSE NULL
  END AS style,
  initcap(national_service_model) AS service_category_in_pim,
  CASE
    WHEN productnumber IS NOT NULL
      AND productnumber != ''
      AND (otc_portal_community_visibility_cd != 'E' OR otc_portal_community_visibility_cd IS NULL)
      THEN true
    ELSE false
  END AS advanced_search_flag,
  current_timestamp() AS last_modified_dt
FROM product
LEFT JOIN sec
  ON cast(sec.item_no AS VARCHAR) = cast(product.itemnumber AS VARCHAR) AND sec.site = product.site_number;

