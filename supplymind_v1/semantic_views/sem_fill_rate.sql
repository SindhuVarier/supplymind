-- ============================================================================
-- Semantic View: sem_fill_rate
--
-- CANONICAL DEFINITION: Fill Rate is the percentage of ordered quantity that
-- is actually fulfilled, computed volume-weighted as
--   SUM(quantity_fulfilled) / SUM(quantity_ordered) * 100
-- across the selected orders (not an average of per-order ratios).
-- ============================================================================

USE DATABASE SUPPLY_CHAIN_DEMO;
USE SCHEMA CORE;

CREATE OR REPLACE SEMANTIC VIEW SUPPLY_CHAIN_DEMO.CORE.sem_fill_rate
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
    orders.quantity_ordered AS orders.quantity_ordered
      COMMENT = 'Units ordered.',
    orders.quantity_fulfilled AS orders.quantity_fulfilled
      COMMENT = 'Units actually fulfilled.'
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
    orders.fill_rate_pct AS (SUM(orders.quantity_fulfilled) / SUM(orders.quantity_ordered)) * 100
      WITH SYNONYMS ('fill rate', 'order fill rate')
      COMMENT = 'Fill Rate %: volume-weighted SUM(quantity_fulfilled) / SUM(quantity_ordered) * 100.'
  )

  COMMENT = 'CANONICAL DEFINITION: Fill Rate is the percentage of ordered quantity fulfilled, computed as SUM(quantity_fulfilled) / SUM(quantity_ordered) * 100 (volume-weighted) across the selected orders. This is the single governed definition of Fill Rate for all downstream consumers.';
