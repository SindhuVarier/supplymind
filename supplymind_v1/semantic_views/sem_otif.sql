-- ============================================================================
-- Semantic View: sem_otif
--
-- CANONICAL DEFINITION: OTIF (On-Time-In-Full) is the percentage of orders
-- that are BOTH on time (fulfilled_dt within 1 calendar day of
-- requested_delivery_dt, same +/-1 day tolerance as sem_on_time_delivery)
-- AND in full (quantity_fulfilled >= quantity_ordered).
-- ============================================================================

USE DATABASE SUPPLY_CHAIN_DEMO;
USE SCHEMA CORE;

CREATE OR REPLACE SEMANTIC VIEW SUPPLY_CHAIN_DEMO.CORE.sem_otif
  TABLES (
    orders AS SUPPLY_CHAIN_DEMO.CORE.ORDERS
      PRIMARY KEY (order_id)
      WITH SYNONYMS ('customer orders')
      COMMENT = 'One row per customer order.',
    parts AS SUPPLY_CHAIN_DEMO.CORE.PARTS
      PRIMARY KEY (part_id)
      COMMENT = 'One row per part.',
    plants AS SUPPLY_CHAIN_DEMO.CORE.PLANTS
      PRIMARY KEY (plant_id)
      COMMENT = 'One row per manufacturing plant.'
  )

  RELATIONSHIPS (
    orders_to_parts AS orders (part_id) REFERENCES parts (part_id),
    orders_to_plants AS orders (plant_id) REFERENCES plants (plant_id)
  )

  FACTS (
    orders.is_otif AS
      CASE
        WHEN ABS(DATEDIFF('day', orders.requested_delivery_dt, orders.fulfilled_dt)) <= 1
         AND orders.quantity_fulfilled >= orders.quantity_ordered
        THEN 1
        ELSE 0
      END
      COMMENT = '1 if the order was both on time (within 1 day of requested_delivery_dt) and in full (quantity_fulfilled >= quantity_ordered), else 0.'
  )

  DIMENSIONS (
    parts.part_category AS parts.part_category
      WITH SYNONYMS ('category'),
    plants.plant_region AS plants.plant_region
      WITH SYNONYMS ('region'),
    orders.order_status AS orders.order_status
      WITH SYNONYMS ('status')
  )

  METRICS (
    orders.otif_pct AS AVG(orders.is_otif) * 100
      WITH SYNONYMS ('OTIF', 'on time in full')
      COMMENT = 'OTIF %, averaged over is_otif across the selected orders.'
  )

  COMMENT = 'CANONICAL DEFINITION: OTIF (On-Time-In-Full) is the percentage of orders where fulfilled_dt is within 1 calendar day of requested_delivery_dt AND quantity_fulfilled >= quantity_ordered. This is the single governed definition of OTIF for all downstream consumers.';
