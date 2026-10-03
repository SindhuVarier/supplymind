-- ============================================================================
-- Semantic View: sem_landed_cost
--
-- CANONICAL DEFINITION: Landed Cost per unit is the part's unit cost plus the
-- shipment's freight and duty cost per unit:
--   unit_cost + freight_cost_per_unit + duty_cost_per_unit
-- averaged across the selected shipments.
-- ============================================================================

USE DATABASE SUPPLY_CHAIN_DEMO;
USE SCHEMA CORE;

CREATE OR REPLACE SEMANTIC VIEW SUPPLY_CHAIN_DEMO.CORE.sem_landed_cost
  TABLES (
    shipments AS SUPPLY_CHAIN_DEMO.CORE.SHIPMENTS
      PRIMARY KEY (shipment_id)
      WITH SYNONYMS ('deliveries', 'shipment events')
      COMMENT = 'One row per shipment from a supplier to a plant.',
    parts AS SUPPLY_CHAIN_DEMO.CORE.PARTS
      PRIMARY KEY (part_id)
      COMMENT = 'One row per part.',
    suppliers AS SUPPLY_CHAIN_DEMO.CORE.SUPPLIERS
      PRIMARY KEY (supplier_id)
      COMMENT = 'One row per supplier.'
  )

  RELATIONSHIPS (
    shipments_to_parts AS shipments (part_id) REFERENCES parts (part_id),
    shipments_to_suppliers AS shipments (supplier_id) REFERENCES suppliers (supplier_id)
  )

  FACTS (
    parts.unit_cost AS parts.unit_cost
      COMMENT = 'Supplier unit cost for the part.',
    shipments.freight_cost_per_unit AS shipments.freight_cost_per_unit
      COMMENT = 'Freight cost per unit for this shipment.',
    shipments.duty_cost_per_unit AS shipments.duty_cost_per_unit
      COMMENT = 'Duty cost per unit for this shipment.'
  )

  DIMENSIONS (
    parts.part_category AS parts.part_category
      WITH SYNONYMS ('category'),
    suppliers.supplier_name AS suppliers.supplier_name
      WITH SYNONYMS ('vendor', 'vendor name')
  )

  METRICS (
    shipments.landed_cost_per_unit AS
      AVG(parts.unit_cost + shipments.freight_cost_per_unit + shipments.duty_cost_per_unit)
      WITH SYNONYMS ('landed cost', 'total landed cost')
      COMMENT = 'Landed Cost per unit: AVG(unit_cost + freight_cost_per_unit + duty_cost_per_unit) across the selected shipments.'
  )

  COMMENT = 'CANONICAL DEFINITION: Landed Cost per unit is AVG(unit_cost + freight_cost_per_unit + duty_cost_per_unit) across the selected shipments. This is the single governed definition of Landed Cost for all downstream consumers.';
