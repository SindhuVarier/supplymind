-- ============================================================================
-- Manual spot-check queries, 3-4 per semantic view, to run after
-- snowflake_ddl/create_tables_and_load.sql and the 5 CREATE SEMANTIC VIEW
-- scripts have been run against a live Snowflake account.
--
-- NOT YET EXECUTED: this file was authored without a live Snowflake
-- connection (see conversation) -- run it yourself and fix any join/grain
-- issues it surfaces, per the Day 1 checklist's "validate queries manually"
-- step.
-- ============================================================================

USE DATABASE SUPPLY_CHAIN_DEMO;
USE SCHEMA CORE;

-- ---------------------------------------------------------------------------
-- sem_on_time_delivery
-- ---------------------------------------------------------------------------

-- 1. Overall OTD %
SELECT * FROM SEMANTIC_VIEW(
  sem_on_time_delivery
  METRICS otd_pct
);

-- 2. OTD % by supplier -- expect Supplier A ~92, B ~71 (actually ~70), C ~85
SELECT * FROM SEMANTIC_VIEW(
  sem_on_time_delivery
  DIMENSIONS supplier_name
  METRICS otd_pct
)
ORDER BY otd_pct DESC;

-- 3. OTD % by plant region
SELECT * FROM SEMANTIC_VIEW(
  sem_on_time_delivery
  DIMENSIONS plant_region
  METRICS otd_pct
);

-- 4. OTD % by carrier -- sanity check no carrier is wildly out of line
SELECT * FROM SEMANTIC_VIEW(
  sem_on_time_delivery
  DIMENSIONS carrier
  METRICS otd_pct
)
ORDER BY otd_pct ASC;

-- ---------------------------------------------------------------------------
-- sem_fill_rate
-- ---------------------------------------------------------------------------

-- 1. Overall fill rate %
SELECT * FROM SEMANTIC_VIEW(
  sem_fill_rate
  METRICS fill_rate_pct
);

-- 2. Fill rate by part category
SELECT * FROM SEMANTIC_VIEW(
  sem_fill_rate
  DIMENSIONS part_category
  METRICS fill_rate_pct
)
ORDER BY fill_rate_pct ASC;

-- 3. Fill rate by plant region
SELECT * FROM SEMANTIC_VIEW(
  sem_fill_rate
  DIMENSIONS plant_region
  METRICS fill_rate_pct
);

-- 4. Fill rate by order status -- Backordered / Partially Fulfilled should
--    show visibly lower fill rate than Fulfilled, as a logic sanity check
SELECT * FROM SEMANTIC_VIEW(
  sem_fill_rate
  DIMENSIONS order_status
  METRICS fill_rate_pct
);

-- ---------------------------------------------------------------------------
-- sem_otif
-- ---------------------------------------------------------------------------

-- 1. Overall OTIF %
SELECT * FROM SEMANTIC_VIEW(
  sem_otif
  METRICS otif_pct
);

-- 2. OTIF % by part category
SELECT * FROM SEMANTIC_VIEW(
  sem_otif
  DIMENSIONS part_category
  METRICS otif_pct
);

-- 3. OTIF % by plant region
SELECT * FROM SEMANTIC_VIEW(
  sem_otif
  DIMENSIONS plant_region
  METRICS otif_pct
);

-- 4. OTIF should be <= both OTD-style on-time rate and fill rate directionally;
--    compare against sem_fill_rate's overall number for a gut check
SELECT * FROM SEMANTIC_VIEW(
  sem_otif
  DIMENSIONS order_status
  METRICS otif_pct
);

-- ---------------------------------------------------------------------------
-- sem_days_of_inventory
-- ---------------------------------------------------------------------------

-- 1. Overall days of inventory -- expect roughly 10-90 day range (generator target band)
SELECT * FROM SEMANTIC_VIEW(
  sem_days_of_inventory
  METRICS days_of_inventory
);

-- 2. DOI by part category
SELECT * FROM SEMANTIC_VIEW(
  sem_days_of_inventory
  DIMENSIONS part_category
  METRICS days_of_inventory
)
ORDER BY days_of_inventory DESC;

-- 3. DOI by plant region
SELECT * FROM SEMANTIC_VIEW(
  sem_days_of_inventory
  DIMENSIONS plant_region
  METRICS days_of_inventory
);

-- ---------------------------------------------------------------------------
-- sem_landed_cost
-- ---------------------------------------------------------------------------

-- 1. Overall landed cost per unit
SELECT * FROM SEMANTIC_VIEW(
  sem_landed_cost
  METRICS landed_cost_per_unit
);

-- 2. Landed cost by part category -- heavier categories (Engine, Transmission)
--    should skew higher due to the weight-driven freight component
SELECT * FROM SEMANTIC_VIEW(
  sem_landed_cost
  DIMENSIONS part_category
  METRICS landed_cost_per_unit
)
ORDER BY landed_cost_per_unit DESC;

-- 3. Landed cost by supplier
SELECT * FROM SEMANTIC_VIEW(
  sem_landed_cost
  DIMENSIONS supplier_name
  METRICS landed_cost_per_unit
)
ORDER BY landed_cost_per_unit DESC;
