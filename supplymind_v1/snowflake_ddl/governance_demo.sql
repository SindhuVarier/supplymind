-- ============================================================================
-- "Rejected raw query" demo: a real Snowflake role that can query the 5
-- governed semantic views, but was never granted SELECT on the 6 raw tables.
-- This is a genuine authorization boundary (RBAC), not an app-side guard --
-- a raw SELECT under this role fails with Snowflake's own permission error.
--
-- Run as a role with MANAGE GRANTS / CREATE ROLE privilege (e.g. SECURITYADMIN).
-- Replace <YOUR_USERNAME> below with the Snowflake user who will run the demo.
-- ============================================================================

USE DATABASE SUPPLY_CHAIN_DEMO;
USE SCHEMA CORE;

CREATE ROLE IF NOT EXISTS DEMO_ANALYST_ROLE
  COMMENT = 'Can query the governed semantic views only. Deliberately NOT granted SELECT on raw tables -- used to demonstrate that ungoverned direct SQL fails while governed questions succeed.';

GRANT USAGE ON DATABASE SUPPLY_CHAIN_DEMO TO ROLE DEMO_ANALYST_ROLE;
GRANT USAGE ON SCHEMA SUPPLY_CHAIN_DEMO.CORE TO ROLE DEMO_ANALYST_ROLE;

-- Governed access: the 5 canonical semantic views.
GRANT SELECT ON SEMANTIC VIEW SUPPLY_CHAIN_DEMO.CORE.sem_on_time_delivery  TO ROLE DEMO_ANALYST_ROLE;
GRANT SELECT ON SEMANTIC VIEW SUPPLY_CHAIN_DEMO.CORE.sem_fill_rate         TO ROLE DEMO_ANALYST_ROLE;
GRANT SELECT ON SEMANTIC VIEW SUPPLY_CHAIN_DEMO.CORE.sem_otif              TO ROLE DEMO_ANALYST_ROLE;
GRANT SELECT ON SEMANTIC VIEW SUPPLY_CHAIN_DEMO.CORE.sem_days_of_inventory TO ROLE DEMO_ANALYST_ROLE;
GRANT SELECT ON SEMANTIC VIEW SUPPLY_CHAIN_DEMO.CORE.sem_landed_cost       TO ROLE DEMO_ANALYST_ROLE;

-- Deliberately NOT granted: SELECT on SUPPLIERS, PARTS, PLANTS, SHIPMENTS,
-- ORDERS, INVENTORY_SNAPSHOTS. Snowflake privileges are deny-by-default, so
-- simply never granting SELECT on these tables is what makes the raw query
-- fail -- no REVOKE needed unless this role (or PUBLIC) was granted broader
-- access elsewhere.

GRANT ROLE DEMO_ANALYST_ROLE TO USER CSINDHU;
GRANT ROLE DEMO_ANALYST_ROLE TO USER "KAVITA.CHEGARADDI";

-- To run the Streamlit governance demo tab as this role: either (a) set this
-- role as your default role / switch to it in Snowsight before opening the
-- app, or (b) when creating the Streamlit object, set its run-as role to
-- DEMO_ANALYST_ROLE so every viewer sees the governed experience:
--   CREATE STREAMLIT SUPPLY_CHAIN_DEMO.CORE.supply_chain_app
--     ROOT_LOCATION = '@SUPPLY_CHAIN_DEMO.CORE.STREAMLIT_APPS'
--     MAIN_FILE = 'app.py'
--     QUERY_WAREHOUSE = <your_warehouse>;
--   -- then grant USAGE on it to DEMO_ANALYST_ROLE instead of a privileged role.

-- Expected result once this role is active:
--   SELECT * FROM SUPPLY_CHAIN_DEMO.CORE.SHIPMENTS LIMIT 10;
--     -> 002003 (42501): SQL access control error: Insufficient privileges...
--   SELECT * FROM SEMANTIC_VIEW(SUPPLY_CHAIN_DEMO.CORE.sem_on_time_delivery METRICS otd_pct);
--     -> succeeds, returns the governed OTD number.
