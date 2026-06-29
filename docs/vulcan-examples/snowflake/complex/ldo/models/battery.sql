MODEL (
  name lenovo.ldo.battery,
  kind SEED (
    path '../seeds/battery.csv'
  ),
  grains (BATTERY_ID),
  columns (
    battery_id STRING,
    device_id STRING,
    battery_condition STRING,
    condition_reason STRING,
    battery_cycle_count INTEGER,
    battery_design_capacity INTEGER,
    battery_firstused_date STRING,
    battery_fullcharge_capacity INTEGER,
    battery_manufacture_date STRING,
    battery_manufacture_name STRING,
    battery_remaining_capacity INTEGER,
    battery_serial_number STRING,
    battery_warranty_date STRING,
    battery_warranty_status STRING
  )
);

