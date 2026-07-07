-- ============================================================================
-- Snowflake Database Setup for SGWS Web Analytics
-- ============================================================================
-- Run this in Snowflake before running Vulcan pipeline
-- ============================================================================

-- 1. Create the DEMO database
CREATE DATABASE IF NOT EXISTS DEMO
COMMENT = 'SGWS Web Analytics - Vulcan Project Database';

-- 2. Grant permissions to the ACCOUNTADMIN role (or your specific role)
GRANT ALL PRIVILEGES ON DATABASE DEMO TO ROLE ACCOUNTADMIN;

-- 3. Verify database creation
SHOW DATABASES LIKE 'DEMO';

-- 4. Use the database
USE DATABASE DEMO;

-- 5. Create initial schemas (Vulcan will create others automatically)
CREATE SCHEMA IF NOT EXISTS SEEDS COMMENT = 'Raw seed data from CSV/TSV files';
CREATE SCHEMA IF NOT EXISTS BRONZE COMMENT = 'Bronze layer - no transformations';
CREATE SCHEMA IF NOT EXISTS SILVER COMMENT = 'Silver layer - cleaned and enriched';
CREATE SCHEMA IF NOT EXISTS GOLD COMMENT = 'Gold layer - business-ready analytics';

-- 6. Grant schema permissions
GRANT ALL PRIVILEGES ON SCHEMA DEMO.SEEDS TO ROLE ACCOUNTADMIN;
GRANT ALL PRIVILEGES ON SCHEMA DEMO.BRONZE TO ROLE ACCOUNTADMIN;
GRANT ALL PRIVILEGES ON SCHEMA DEMO.SILVER TO ROLE ACCOUNTADMIN;
GRANT ALL PRIVILEGES ON SCHEMA DEMO.GOLD TO ROLE ACCOUNTADMIN;

-- 7. Grant future table permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA DEMO.SEEDS TO ROLE ACCOUNTADMIN;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA DEMO.BRONZE TO ROLE ACCOUNTADMIN;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA DEMO.SILVER TO ROLE ACCOUNTADMIN;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA DEMO.GOLD TO ROLE ACCOUNTADMIN;

GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA DEMO.SEEDS TO ROLE ACCOUNTADMIN;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA DEMO.BRONZE TO ROLE ACCOUNTADMIN;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA DEMO.SILVER TO ROLE ACCOUNTADMIN;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA DEMO.GOLD TO ROLE ACCOUNTADMIN;

-- ============================================================================
-- Verification Queries
-- ============================================================================

-- Check database
SELECT CURRENT_DATABASE();

-- List all schemas
SHOW SCHEMAS IN DATABASE DEMO;

-- Check permissions
SHOW GRANTS ON DATABASE DEMO;

SELECT '✅ DEMO database setup complete!' AS STATUS;
