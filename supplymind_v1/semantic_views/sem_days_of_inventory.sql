-- ============================================================================
-- Semantic View: sem_days_of_inventory
--
-- CANONICAL DEFINITION: Days of Inventory (DOI) is the average on-hand
-- quantity divided by the average daily demand quantity, across the selected
-- inventory_snapshots rows -- i.e. how many days current stock would last at
-- observed demand. Both qty_on_hand and avg_daily_demand_qty are generated
-- per (part, plant) in data_generation/generate_supply_chain_data.py from
-- that combo's own observed shipment volume, not an unrelated random number.
-- ============================================================================

USE DATABASE SUPPLY_CHAIN_DEMO;
USE SCHEMA CORE;

CREATE OR REPLACE SEMANTIC VIEW SUPPLY_CHAIN_DEMO.CORE.sem_days_of_inventory
  TABLES (
    inventory_snapshots AS SUPPLY_CHAIN_DEMO.CORE.INVENTORY_SNAPSHOTS
      PRIMARY KEY (snapshot_id)
      WITH SYNONYMS ('inventory', 'stock snapshots')
      COMMENT = 'One row per monthly on-hand inventory snapshot for a (part, plant) combination.',
    parts AS SUPPLY_CHAIN_DEMO.CORE.PARTS
      PRIMARY KEY (part_id)
      COMMENT = 'One row per part.',
    plants AS SUPPLY_CHAIN_DEMO.CORE.PLANTS
      PRIMARY KEY (plant_id)
      COMMENT = 'One row per manufacturing plant.'
  )

  RELATIONSHIPS (
    inventory_to_parts AS inventory_snapshots (part_id) REFERENCES parts (part_id),
    inventory_to_plants AS inventory_snapshots (plant_id) REFERENCES plants (plant_id)
  )

  FACTS (
    inventory_snapshots.qty_on_hand AS inventory_snapshots.qty_on_hand
      COMMENT = 'On-hand quantity at the snapshot date.',
    inventory_snapshots.avg_daily_demand_qty AS inventory_snapshots.avg_daily_demand_qty
      COMMENT = 'Average daily demand quantity for this part/plant, as of the snapshot date.'
  )

  DIMENSIONS (
    parts.part_category AS parts.part_category
      WITH SYNONYMS ('category'),
    plants.plant_region AS plants.plant_region
      WITH SYNONYMS ('region')
  )

  METRICS (
    inventory_snapshots.days_of_inventory AS
      AVG(inventory_snapshots.qty_on_hand) / AVG(inventory_snapshots.avg_daily_demand_qty)
      WITH SYNONYMS ('DOI', 'inventory days', 'days of supply')
      COMMENT = 'Days of Inventory: AVG(qty_on_hand) / AVG(avg_daily_demand_qty) across the selected snapshots.'
  )

  COMMENT = 'CANONICAL DEFINITION: Days of Inventory (DOI) is AVG(qty_on_hand) / AVG(avg_daily_demand_qty) across the selected inventory_snapshots rows -- the number of days current stock would last at observed demand. This is the single governed definition of DOI for all downstream consumers.';
