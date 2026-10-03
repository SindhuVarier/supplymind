-- ============================================================================
-- Semantic View: sem_on_time_delivery
--
-- Canonical, governed definition of On-Time Delivery (OTD) for the automotive
-- supply chain demo. Every downstream consumer (Cortex Analyst semantic model,
-- Streamlit app, ad-hoc BI) should read OTD through this view rather than
-- re-deriving the DATEDIFF logic locally, so Planner / Procurement / Logistics
-- always see the same number for the same question.
--
-- Assumes SUPPLIERS, PLANTS, SHIPMENTS have already been loaded into
-- SUPPLY_CHAIN_DEMO.CORE from the CSVs produced by
-- data_generation/generate_supply_chain_data.py.
-- ============================================================================

USE DATABASE SUPPLY_CHAIN_DEMO;
USE SCHEMA CORE;

CREATE OR REPLACE SEMANTIC VIEW SUPPLY_CHAIN_DEMO.CORE.sem_on_time_delivery
  TABLES (
    shipments AS SUPPLY_CHAIN_DEMO.CORE.SHIPMENTS
      PRIMARY KEY (shipment_id)
      WITH SYNONYMS ('deliveries', 'shipment events')
      COMMENT = 'One row per shipment from a supplier to a plant.',
    suppliers AS SUPPLY_CHAIN_DEMO.CORE.SUPPLIERS
      PRIMARY KEY (supplier_id)
      WITH SYNONYMS ('vendors')
      COMMENT = 'One row per supplier.',
    plants AS SUPPLY_CHAIN_DEMO.CORE.PLANTS
      PRIMARY KEY (plant_id)
      WITH SYNONYMS ('assembly plants', 'facilities')
      COMMENT = 'One row per manufacturing plant.'
  )

  RELATIONSHIPS (
    shipments_to_suppliers AS shipments (supplier_id) REFERENCES suppliers (supplier_id),
    shipments_to_plants AS shipments (plant_id) REFERENCES plants (plant_id)
  )

  FACTS (
    shipments.is_on_time AS
      CASE
        WHEN ABS(DATEDIFF('day', shipments.confirmed_delivery_dt, shipments.actual_delivery_dt)) <= 1
        THEN 1
        ELSE 0
      END
      COMMENT = '1 if actual_delivery_dt is within 1 calendar day (inclusive, either direction) of confirmed_delivery_dt, else 0. This is the atomic unit the OTD % metric averages.'
  )

  DIMENSIONS (
    suppliers.supplier_name AS suppliers.supplier_name
      WITH SYNONYMS ('vendor name', 'supplier')
      COMMENT = 'Supplier that shipped the part.',
    plants.plant_region AS plants.plant_region
      WITH SYNONYMS ('region', 'destination region')
      COMMENT = 'Region of the receiving plant.',
    shipments.carrier AS shipments.carrier
      WITH SYNONYMS ('logistics provider', 'freight carrier')
      COMMENT = 'Carrier that physically moved the shipment.'
  )

  METRICS (
    shipments.otd_pct AS AVG(shipments.is_on_time) * 100
      WITH SYNONYMS ('OTD', 'on-time delivery rate', 'on-time delivery percentage')
      COMMENT = 'On-Time Delivery %, averaged over is_on_time across the selected shipments.'
  )

  COMMENT = 'CANONICAL DEFINITION: On-Time Delivery (OTD) is the percentage of shipments where actual_delivery_dt falls within 1 calendar day (inclusive) of confirmed_delivery_dt. This is the single governed definition of OTD for all downstream consumers (Cortex Analyst semantic model, Streamlit apps, dashboards) -- do not re-implement this logic elsewhere.';
