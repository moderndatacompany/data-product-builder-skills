#!/bin/bash
# Verify data exists in Azure PostgreSQL

echo "==================================="
echo "Verifying Azure PostgreSQL Data"
echo "==================================="

PGPASSWORD='vulcandb001' psql \
  -h modern-postgresql-server.postgres.database.azure.com \
  -p 5432 \
  -U vulcandbuser \
  -d vulcandb \
  -c "\dt vulcan_demo.*"

echo ""
echo "==================================="
echo "Checking row counts"
echo "==================================="

PGPASSWORD='vulcandb001' psql \
  -h modern-postgresql-server.postgres.database.azure.com \
  -p 5432 \
  -U vulcandbuser \
  -d vulcandb \
  -c "SELECT 'customers' as table_name, COUNT(*) as row_count FROM vulcan_demo.customers
UNION ALL
SELECT 'dim_dates', COUNT(*) FROM vulcan_demo.dim_dates
UNION ALL
SELECT 'regions', COUNT(*) FROM vulcan_demo.regions
UNION ALL
SELECT 'orders', COUNT(*) FROM vulcan_demo.orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM vulcan_demo.order_items
UNION ALL
SELECT 'products', COUNT(*) FROM vulcan_demo.products
UNION ALL
SELECT 'shipments', COUNT(*) FROM vulcan_demo.shipments
UNION ALL
SELECT 'suppliers', COUNT(*) FROM vulcan_demo.suppliers
UNION ALL
SELECT 'warehouses', COUNT(*) FROM vulcan_demo.warehouses
ORDER BY table_name;"

echo ""
echo "==================================="
echo "Sample data from failing tables"
echo "==================================="

PGPASSWORD='vulcandb001' psql \
  -h modern-postgresql-server.postgres.database.azure.com \
  -p 5432 \
  -U vulcandbuser \
  -d vulcandb \
  -c "SELECT * FROM vulcan_demo.regions LIMIT 5;"

PGPASSWORD='vulcandb001' psql \
  -h modern-postgresql-server.postgres.database.azure.com \
  -p 5432 \
  -U vulcandbuser \
  -d vulcandb \
  -c "SELECT * FROM vulcan_demo.customers LIMIT 5;"

PGPASSWORD='vulcandb001' psql \
  -h modern-postgresql-server.postgres.database.azure.com \
  -p 5432 \
  -U vulcandbuser \
  -d vulcandb \
  -c "SELECT * FROM vulcan_demo.dim_dates LIMIT 5;"

