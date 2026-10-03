-- ============================================================================
-- Create database/schema/tables and load the 6 CSVs produced by
-- data_generation/generate_supply_chain_data.py into SUPPLY_CHAIN_DEMO.CORE.
--
-- Prerequisite: the 6 CSVs must already be sitting on the stage created
-- below. Either upload them in Snowsight (Data > Add Data > Load files into
-- a stage) or, with SnowSQL installed, from the data_generation/output
-- directory:
--   PUT file://suppliers.csv            @SUPPLY_CHAIN_DEMO.CORE.supply_chain_stage AUTO_COMPRESS=TRUE;
--   PUT file://parts.csv                @SUPPLY_CHAIN_DEMO.CORE.supply_chain_stage AUTO_COMPRESS=TRUE;
--   PUT file://plants.csv               @SUPPLY_CHAIN_DEMO.CORE.supply_chain_stage AUTO_COMPRESS=TRUE;
--   PUT file://shipments.csv            @SUPPLY_CHAIN_DEMO.CORE.supply_chain_stage AUTO_COMPRESS=TRUE;
--   PUT file://orders.csv               @SUPPLY_CHAIN_DEMO.CORE.supply_chain_stage AUTO_COMPRESS=TRUE;
--   PUT file://inventory_snapshots.csv  @SUPPLY_CHAIN_DEMO.CORE.supply_chain_stage AUTO_COMPRESS=TRUE;
-- ============================================================================

CREATE DATABASE IF NOT EXISTS SUPPLY_CHAIN_DEMO;
CREATE SCHEMA IF NOT EXISTS SUPPLY_CHAIN_DEMO.CORE;

USE DATABASE SUPPLY_CHAIN_DEMO;
USE SCHEMA CORE;

CREATE OR REPLACE FILE FORMAT SUPPLY_CHAIN_DEMO.CORE.CSV_STANDARD
  TYPE = CSV
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('', 'NULL')
  EMPTY_FIELD_AS_NULL = TRUE;

CREATE STAGE IF NOT EXISTS SUPPLY_CHAIN_DEMO.CORE.supply_chain_stage
  FILE_FORMAT = SUPPLY_CHAIN_DEMO.CORE.CSV_STANDARD
  COMMENT = 'Landing stage for the 6 supply chain demo CSVs before COPY INTO.';

-- ----------------------------------------------------------------------------
-- Tables
-- ----------------------------------------------------------------------------

CREATE OR REPLACE TABLE SUPPLY_CHAIN_DEMO.CORE.SUPPLIERS (
  supplier_id         VARCHAR(10)   NOT NULL,
  supplier_name       VARCHAR(200)  NOT NULL,
  supplier_region     VARCHAR(50),
  country             VARCHAR(100),
  reliability_tier    VARCHAR(20),
  otd_target_pct      NUMBER(5,2),
  lead_time_days_avg  NUMBER(5,2),
  created_dt          DATE,
  PRIMARY KEY (supplier_id)
);

CREATE OR REPLACE TABLE SUPPLY_CHAIN_DEMO.CORE.PARTS (
  part_id       VARCHAR(10)   NOT NULL,
  part_name     VARCHAR(200)  NOT NULL,
  part_category VARCHAR(50),
  supplier_id   VARCHAR(10),
  unit_cost     NUMBER(10,2),
  weight_kg     NUMBER(10,2),
  uom           VARCHAR(10),
  PRIMARY KEY (part_id)
);

CREATE OR REPLACE TABLE SUPPLY_CHAIN_DEMO.CORE.PLANTS (
  plant_id      VARCHAR(10)   NOT NULL,
  plant_name    VARCHAR(200)  NOT NULL,
  plant_region  VARCHAR(50),
  plant_country VARCHAR(100),
  plant_city    VARCHAR(100),
  PRIMARY KEY (plant_id)
);

CREATE OR REPLACE TABLE SUPPLY_CHAIN_DEMO.CORE.SHIPMENTS (
  shipment_id             VARCHAR(12) NOT NULL,
  supplier_id             VARCHAR(10),
  part_id                 VARCHAR(10),
  plant_id                VARCHAR(10),
  carrier                 VARCHAR(50),
  ship_dt                 DATE,
  confirmed_delivery_dt   DATE,
  actual_delivery_dt      DATE,
  quantity_shipped        NUMBER(10,0),
  freight_cost_per_unit   NUMBER(10,2),
  duty_cost_per_unit      NUMBER(10,2),
  status                  VARCHAR(20),
  PRIMARY KEY (shipment_id)
);

CREATE OR REPLACE TABLE SUPPLY_CHAIN_DEMO.CORE.ORDERS (
  order_id               VARCHAR(12) NOT NULL,
  customer_id            VARCHAR(10),
  customer_name          VARCHAR(200),
  plant_id               VARCHAR(10),
  part_id                VARCHAR(10),
  order_dt               DATE,
  requested_delivery_dt  DATE,
  fulfilled_dt           DATE,
  quantity_ordered       NUMBER(10,0),
  quantity_fulfilled     NUMBER(10,0),
  unit_price             NUMBER(10,2),
  order_status           VARCHAR(30),
  PRIMARY KEY (order_id)
);

CREATE OR REPLACE TABLE SUPPLY_CHAIN_DEMO.CORE.INVENTORY_SNAPSHOTS (
  snapshot_id           VARCHAR(12) NOT NULL,
  part_id               VARCHAR(10),
  plant_id              VARCHAR(10),
  snapshot_dt           DATE,
  qty_on_hand           NUMBER(10,1),
  avg_daily_demand_qty  NUMBER(10,2),
  PRIMARY KEY (snapshot_id)
);

-- ----------------------------------------------------------------------------
-- Load
-- ----------------------------------------------------------------------------

COPY INTO SUPPLY_CHAIN_DEMO.CORE.SUPPLIERS
  FROM @SUPPLY_CHAIN_DEMO.CORE.supply_chain_stage/suppliers.csv
  FILE_FORMAT = (FORMAT_NAME = SUPPLY_CHAIN_DEMO.CORE.CSV_STANDARD)
  ON_ERROR = ABORT_STATEMENT;

COPY INTO SUPPLY_CHAIN_DEMO.CORE.PARTS
  FROM @SUPPLY_CHAIN_DEMO.CORE.supply_chain_stage/parts.csv
  FILE_FORMAT = (FORMAT_NAME = SUPPLY_CHAIN_DEMO.CORE.CSV_STANDARD)
  ON_ERROR = ABORT_STATEMENT;

COPY INTO SUPPLY_CHAIN_DEMO.CORE.PLANTS
  FROM @SUPPLY_CHAIN_DEMO.CORE.supply_chain_stage/plants.csv
  FILE_FORMAT = (FORMAT_NAME = SUPPLY_CHAIN_DEMO.CORE.CSV_STANDARD)
  ON_ERROR = ABORT_STATEMENT;

COPY INTO SUPPLY_CHAIN_DEMO.CORE.SHIPMENTS
  FROM @SUPPLY_CHAIN_DEMO.CORE.supply_chain_stage/shipments.csv
  FILE_FORMAT = (FORMAT_NAME = SUPPLY_CHAIN_DEMO.CORE.CSV_STANDARD)
  ON_ERROR = ABORT_STATEMENT;

COPY INTO SUPPLY_CHAIN_DEMO.CORE.ORDERS
  FROM @SUPPLY_CHAIN_DEMO.CORE.supply_chain_stage/orders.csv
  FILE_FORMAT = (FORMAT_NAME = SUPPLY_CHAIN_DEMO.CORE.CSV_STANDARD)
  ON_ERROR = ABORT_STATEMENT;

COPY INTO SUPPLY_CHAIN_DEMO.CORE.INVENTORY_SNAPSHOTS
  FROM @SUPPLY_CHAIN_DEMO.CORE.supply_chain_stage/inventory_snapshots.csv
  FILE_FORMAT = (FORMAT_NAME = SUPPLY_CHAIN_DEMO.CORE.CSV_STANDARD)
  ON_ERROR = ABORT_STATEMENT;

-- ----------------------------------------------------------------------------
-- Row count check
-- ----------------------------------------------------------------------------

SELECT 'SUPPLIERS' AS table_name, COUNT(*) AS row_count FROM SUPPLY_CHAIN_DEMO.CORE.SUPPLIERS
UNION ALL
SELECT 'PARTS', COUNT(*) FROM SUPPLY_CHAIN_DEMO.CORE.PARTS
UNION ALL
SELECT 'PLANTS', COUNT(*) FROM SUPPLY_CHAIN_DEMO.CORE.PLANTS
UNION ALL
SELECT 'SHIPMENTS', COUNT(*) FROM SUPPLY_CHAIN_DEMO.CORE.SHIPMENTS
UNION ALL
SELECT 'ORDERS', COUNT(*) FROM SUPPLY_CHAIN_DEMO.CORE.ORDERS
UNION ALL
SELECT 'INVENTORY_SNAPSHOTS', COUNT(*) FROM SUPPLY_CHAIN_DEMO.CORE.INVENTORY_SNAPSHOTS;


CREATE STAGE IF NOT EXISTS SUPPLY_CHAIN_DEMO.CORE.SEMANTIC_MODELS;
CREATE STAGE IF NOT EXISTS SUPPLY_CHAIN_DEMO.CORE.STREAMLIT_APPS;