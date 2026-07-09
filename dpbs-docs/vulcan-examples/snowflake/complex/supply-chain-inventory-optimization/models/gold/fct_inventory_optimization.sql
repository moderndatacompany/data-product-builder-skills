MODEL (
  name ERP_PLATFORM.GOLD.FCT_INVENTORY_OPTIMIZATION,
  kind FULL,
  cron '@daily',
  owner 'shreyasikarwartmdcio',
  grains [INVENTORY_OPT_KEY],
  description 'Inventory optimization analytics with ABC classification, turnover ratios, stockout risk scoring. Aggregation (totals, averages, weighted metrics) is handled by the semantic layer.',
  tags ('gold', 'fact', 'inventory-optimization', 'abc-analysis'),
  terms ('abc-classification', 'reorder-points', 'safety-stock'),
  columns (
    inventory_opt_key VARCHAR(100),
    material_number VARCHAR(50),
    material_description VARCHAR(200),
    plant_code VARCHAR(10),
    current_inventory_qty INTEGER,
    current_inventory_value_usd DECIMAL(15,2),
    abc_classification VARCHAR(1),
    annual_usage_qty INTEGER,
    annual_usage_value_usd DECIMAL(15,2),
    inventory_turnover_ratio DECIMAL(10,2),
    days_inventory_outstanding INTEGER,
    reorder_point INTEGER,
    safety_stock_level INTEGER,
    stockout_risk_score DECIMAL(5,2),
    excess_inventory_flag BOOLEAN,
    days_since_last_movement INTEGER,
    primary_supplier_id VARCHAR(20),
    calculated_at TIMESTAMP
  ),

  column_descriptions (
    inventory_opt_key = 'Surrogate key (material_number || plant_code)',
    material_number = 'Product material number',
    material_description = 'Product description from inventory master',
    plant_code = 'Plant location code',
    current_inventory_qty = 'Current quantity on hand',
    current_inventory_value_usd = 'Current inventory value in USD',
    abc_classification = 'ABC classification: A (top 80% value), B (next 15%), C (remaining 5%)',
    annual_usage_qty = 'Annualized usage quantity based on PO history',
    annual_usage_value_usd = 'Annualized usage value in USD',
    inventory_turnover_ratio = 'Inventory turnover ratio (annual usage / avg inventory)',
    days_inventory_outstanding = 'Days of inventory on hand at current usage rate',
    reorder_point = 'Recommended reorder point based on lead time and usage',
    safety_stock_level = 'Recommended safety stock quantity',
    stockout_risk_score = 'Stockout risk score (0-100): higher = more risk',
    excess_inventory_flag = 'True if inventory exceeds 2x safety stock + reorder point',
    days_since_last_movement = 'Days since last inventory movement',
    primary_supplier_id = 'Primary supplier (highest PO value) for this material',
    calculated_at = 'Record calculation timestamp'
  ),

  column_tags (
    inventory_opt_key = ('identifier', 'primary-key', 'surrogate-key', 'grain'),
    material_number = ('material', 'dimension', 'product'),
    material_description = ('description', 'dimension'),
    plant_code = ('plant', 'dimension', 'location'),
    current_inventory_qty = ('quantity', 'measure', 'inventory'),
    current_inventory_value_usd = ('value', 'measure', 'financial'),
    abc_classification = ('classification', 'dimension', 'abc'),
    annual_usage_qty = ('quantity', 'measure', 'usage'),
    annual_usage_value_usd = ('value', 'measure', 'financial'),
    inventory_turnover_ratio = ('ratio', 'kpi', 'efficiency'),
    days_inventory_outstanding = ('duration', 'kpi', 'inventory'),
    reorder_point = ('quantity', 'threshold', 'planning'),
    safety_stock_level = ('quantity', 'threshold', 'safety'),
    stockout_risk_score = ('score', 'kpi', 'risk'),
    excess_inventory_flag = ('flag', 'indicator', 'excess'),
    days_since_last_movement = ('duration', 'measure', 'activity'),
    primary_supplier_id = ('foreign-key', 'supplier', 'identifier'),
    calculated_at = ('temporal', 'audit', 'metadata')
  ),

  assertions (
    not_null(columns := (inventory_opt_key, material_number, plant_code, current_inventory_qty)),
    forall(criteria := (current_inventory_qty >= 0, stockout_risk_score >= 0, stockout_risk_score <= 100))
  ),

  profiles (INVENTORY_OPT_KEY, MATERIAL_NUMBER, MATERIAL_DESCRIPTION, PLANT_CODE, CURRENT_INVENTORY_QTY, CURRENT_INVENTORY_VALUE_USD, ABC_CLASSIFICATION, ANNUAL_USAGE_QTY, ANNUAL_USAGE_VALUE_USD, INVENTORY_TURNOVER_RATIO, DAYS_INVENTORY_OUTSTANDING, REORDER_POINT, SAFETY_STOCK_LEVEL, STOCKOUT_RISK_SCORE, EXCESS_INVENTORY_FLAG, DAYS_SINCE_LAST_MOVEMENT, PRIMARY_SUPPLIER_ID, CALCULATED_AT)
);

WITH usage_stats AS (
  -- Calculate annualized usage from purchase orders (6-month data * 2)
  SELECT
    po."material_number"::VARCHAR(50) AS material_number,
    po."plant_code"::VARCHAR(10) AS plant_code,
    SUM(po."order_quantity"::INTEGER) * 2 AS annual_usage_qty,
    SUM(po."po_value_usd"::DECIMAL(15,2)) * 2 AS annual_usage_value_usd
  FROM ERP_PLATFORM.BRONZE.PURCHASE_ORDER_HISTORY po
  WHERE po."po_status" != 'Cancelled'
  GROUP BY po."material_number", po."plant_code"
),
primary_suppliers AS (
  -- Identify primary supplier per material (highest total PO value)
  SELECT
    po."material_number"::VARCHAR(50) AS material_number,
    po."supplier_id"::VARCHAR(20) AS supplier_id,
    ROW_NUMBER() OVER (PARTITION BY po."material_number" ORDER BY SUM(po."po_value_usd"::DECIMAL(15,2)) DESC) AS rn
  FROM ERP_PLATFORM.BRONZE.PURCHASE_ORDER_HISTORY po
  WHERE po."po_status" != 'Cancelled'
  GROUP BY po."material_number", po."supplier_id"
),
abc_ranked AS (
  -- ABC classification based on cumulative inventory value
  SELECT
    inv."material_number"::VARCHAR(50) AS material_number,
    inv."plant_code"::VARCHAR(10) AS plant_code,
    inv."inventory_value_usd"::DECIMAL(15,2) AS inventory_value_usd,
    SUM(inv."inventory_value_usd"::DECIMAL(15,2)) OVER (ORDER BY inv."inventory_value_usd"::DECIMAL(15,2) DESC) AS cumulative_value,
    SUM(inv."inventory_value_usd"::DECIMAL(15,2)) OVER () AS total_value
  FROM ERP_PLATFORM.BRONZE.CURRENT_INVENTORY inv
)
SELECT
  (inv."material_number" || '-' || inv."plant_code")::VARCHAR(100) AS inventory_opt_key,
  inv."material_number"::VARCHAR(50) AS material_number,
  inv."material_description"::VARCHAR(200) AS material_description,
  inv."plant_code"::VARCHAR(10) AS plant_code,
  inv."quantity_on_hand"::INTEGER AS current_inventory_qty,
  inv."inventory_value_usd"::DECIMAL(15,2) AS current_inventory_value_usd,
  -- ABC classification
  CASE
    WHEN abc.cumulative_value / NULLIF(abc.total_value, 0) <= 0.80 THEN 'A'
    WHEN abc.cumulative_value / NULLIF(abc.total_value, 0) <= 0.95 THEN 'B'
    ELSE 'C'
  END::VARCHAR(1) AS abc_classification,
  COALESCE(us.annual_usage_qty, 0)::INTEGER AS annual_usage_qty,
  COALESCE(us.annual_usage_value_usd, 0)::DECIMAL(15,2) AS annual_usage_value_usd,
  -- Inventory turnover ratio
  ROUND(COALESCE(us.annual_usage_value_usd, 0) / NULLIF(inv."inventory_value_usd"::DECIMAL(15,2), 0), 2) AS inventory_turnover_ratio,
  -- Days inventory outstanding
  CASE
    WHEN COALESCE(us.annual_usage_qty, 0) > 0
    THEN ROUND(inv."quantity_on_hand"::INTEGER * 365.0 / us.annual_usage_qty, 0)::INTEGER
    ELSE 999
  END AS days_inventory_outstanding,
  -- Reorder point (avg daily usage * avg lead time * 1.5 safety factor)
  CASE
    WHEN COALESCE(us.annual_usage_qty, 0) > 0
    THEN ROUND(us.annual_usage_qty / 365.0 * 14 * 1.5, 0)::INTEGER  -- 14-day avg lead time
    ELSE 0
  END AS reorder_point,
  -- Safety stock (avg daily usage * lead time variability)
  CASE
    WHEN COALESCE(us.annual_usage_qty, 0) > 0
    THEN ROUND(us.annual_usage_qty / 365.0 * 7, 0)::INTEGER  -- 7-day safety buffer
    ELSE 0
  END AS safety_stock_level,
  -- Stockout risk score (0-100)
  ROUND(CASE
    WHEN inv."quantity_available"::INTEGER <= 0 THEN 100.0
    WHEN COALESCE(us.annual_usage_qty, 0) = 0 THEN 0.0
    WHEN inv."quantity_available"::INTEGER < (us.annual_usage_qty / 365.0 * 7) THEN 90.0
    WHEN inv."quantity_available"::INTEGER < (us.annual_usage_qty / 365.0 * 14) THEN 70.0
    WHEN inv."quantity_available"::INTEGER < (us.annual_usage_qty / 365.0 * 30) THEN 40.0
    ELSE 10.0
  END, 2) AS stockout_risk_score,
  -- Excess inventory flag
  CASE
    WHEN COALESCE(us.annual_usage_qty, 0) > 0
      AND inv."quantity_on_hand"::INTEGER > (us.annual_usage_qty / 365.0 * 14 * 1.5 + us.annual_usage_qty / 365.0 * 7) * 2
    THEN TRUE
    ELSE FALSE
  END AS excess_inventory_flag,
  -- Days since last movement
  DATEDIFF('day', inv."last_movement_date"::DATE, CURRENT_DATE())::INTEGER AS days_since_last_movement,
  -- Primary supplier
  ps.supplier_id::VARCHAR(20) AS primary_supplier_id,
  CURRENT_TIMESTAMP() AS calculated_at
FROM ERP_PLATFORM.BRONZE.CURRENT_INVENTORY inv
LEFT JOIN usage_stats us ON inv."material_number" = us.material_number AND inv."plant_code" = us.plant_code
LEFT JOIN abc_ranked abc ON inv."material_number" = abc.material_number AND inv."plant_code" = abc.plant_code
LEFT JOIN primary_suppliers ps ON inv."material_number" = ps.material_number AND ps.rn = 1
ORDER BY abc_classification, inventory_turnover_ratio DESC;


