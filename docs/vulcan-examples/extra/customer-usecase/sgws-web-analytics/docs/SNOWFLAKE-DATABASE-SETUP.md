# 🔧 Snowflake Database Setup Required

## ❌ Current Error

```
Database 'DEMO' does not exist or not authorized.
SQL compilation error: Object does not exist, or operation cannot be performed.
```

## 🎯 Root Cause

Vulcan is trying to create schemas in the `DEMO` database, but **the database hasn't been created yet in Snowflake**.

## ✅ Solution

### Option 1: Run SQL Script (Recommended)

1. **Open Snowflake Web UI** or SnowSQL CLI

2. **Run the setup script**:
   ```bash
   # Using SnowSQL CLI
   snowsql -a EQZOTUQ-JCA67320 -u SHREYA --private-key-path snowflake_key.p8 -f setup_snowflake_database.sql
   
   # Or copy-paste from setup_snowflake_database.sql into Snowflake UI
   ```

3. **Quick manual setup** (minimum required):
   ```sql
   -- Connect as ACCOUNTADMIN
   USE ROLE ACCOUNTADMIN;
   
   -- Create database
   CREATE DATABASE IF NOT EXISTS DEMO;
   
   -- Grant permissions
   GRANT ALL PRIVILEGES ON DATABASE DEMO TO ROLE ACCOUNTADMIN;
   
   -- Verify
   SHOW DATABASES LIKE 'DEMO';
   ```

### Option 2: Using Docker + Snowflake CLI

```bash
# Install snowflake-cli if not already installed
pip install snowflake-cli-labs

# Run setup
snow sql -q "CREATE DATABASE IF NOT EXISTS DEMO;" \
  --account EQZOTUQ-JCA67320 \
  --user SHREYA \
  --private-key-path snowflake_key.p8
```

### Option 3: Snowflake Web UI (Manual)

1. Go to https://app.snowflake.com/
2. Login with your credentials
3. Run in a worksheet:
   ```sql
   CREATE DATABASE DEMO;
   ```

## 🚀 After Database Creation

Once the `DEMO` database is created, run:

```bash
# Test connection
vulcan info

# Expected output:
# ✅ Data warehouse connection succeeded
# ✅ Models: 84

# Run plan
vulcan plan

# Run pipeline
vulcan run
```

## 📋 What Gets Created

### Database Structure
```
DEMO                           (Database)
├── SEEDS                      (Schema - Raw data from CSV/TSV)
├── BRONZE                     (Schema - No transformations)
├── BRONZE_EFDP               (Schema - EFDP source data)
├── BRONZE_MINI_O             (Schema - MinIO source data)
├── SILVER                     (Schema - Cleaned & enriched)
├── GOLD                       (Schema - Business-ready analytics)
└── vulcan__*                  (Schema - Vulcan metadata schemas)
```

### Permission Requirements

Your `ACCOUNTADMIN` role needs:
- ✅ CREATE DATABASE
- ✅ CREATE SCHEMA
- ✅ CREATE TABLE
- ✅ INSERT/SELECT/UPDATE/DELETE on tables

## 🔍 Verification

After running the setup, verify:

```sql
-- 1. Check database exists
SHOW DATABASES LIKE 'DEMO';

-- 2. Use database
USE DATABASE DEMO;

-- 3. List schemas
SHOW SCHEMAS;

-- 4. Check permissions
SHOW GRANTS ON DATABASE DEMO;
```

Expected output:
```
✅ DEMO database exists
✅ ACCOUNTADMIN has ALL PRIVILEGES
✅ Can create schemas and tables
```

## 🐛 Troubleshooting

### Error: "Insufficient privileges to operate on database 'DEMO'"

**Solution**: Grant yourself permissions:
```sql
USE ROLE ACCOUNTADMIN;
GRANT ALL PRIVILEGES ON DATABASE DEMO TO ROLE ACCOUNTADMIN;
```

### Error: "Database already exists"

**Solution**: This is fine! Just grant permissions:
```sql
GRANT ALL PRIVILEGES ON DATABASE DEMO TO ROLE ACCOUNTADMIN;
```

### Error: "Cannot create database"

**Check**:
1. Are you using `ACCOUNTADMIN` role?
2. Does your account have sufficient credits?
3. Is the warehouse running?

```sql
-- Check current role
SELECT CURRENT_ROLE();

-- Switch to ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;

-- Check warehouse
SHOW WAREHOUSES;

-- Start warehouse if needed
ALTER WAREHOUSE COMPUTE_WH RESUME IF SUSPENDED;
```

## ✅ Summary

| Step | Command | Status |
|------|---------|--------|
| 1. Create Database | `CREATE DATABASE DEMO;` | ⏳ Required |
| 2. Grant Permissions | `GRANT ALL PRIVILEGES...` | ⏳ Required |
| 3. Test Connection | `vulcan info` | ⏳ Pending |
| 4. Run Plan | `vulcan plan` | ⏳ Pending |
| 5. Execute Pipeline | `vulcan run` | ⏳ Pending |

**Once the database is created, your entire pipeline will work!** 🎉
