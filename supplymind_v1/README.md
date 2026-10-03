# SupplyMind — Automotive Supply Chain Cortex Agent Demo

**Thesis:** today, Planner / Procurement / Logistics each compute metrics like
On-Time Delivery in their own spreadsheet, with their own formula, and get
three different answers to the same question. This repo builds one governed
semantic layer on Snowflake so all three personas ask the same question in
plain English and get the identical, provably-governed number back.

## How it fits together

```
generate_supply_chain_data.py
        |
        v  (6 CSVs)
snowflake_ddl/create_tables_and_load.sql   -- CREATE TABLE + COPY INTO
        |
        v  (6 raw tables in SUPPLY_CHAIN_DEMO.CORE)
semantic_views/sem_*.sql                   -- 5 CREATE SEMANTIC VIEW objects,
        |                                     one canonical definition each
        v
cortex_analyst/supply_chain_semantic_model.yaml  -- Cortex Analyst semantic
        |                                            model; every metric's
        |                                            expr reads a semantic view
        v
streamlit_app/app.py  (Streamlit in Snowflake)
  - Tab 1: Planner / Procurement / Logistics each ask Cortex Analyst
  - Tab 2: Metric Registry (the governed vocabulary, on display)
  - Tab 3: Governance demo (raw table access denied, semantic view access works)

snowflake_ddl/governance_demo.sql          -- DEMO_ANALYST_ROLE: SELECT on the
                                               5 semantic views, nothing on
                                               the 6 raw tables (real RBAC)

cortex_analyst/ask_cortex_analyst_procedure.sql  -- SQL-callable wrapper
                                               (CALL ASK_CORTEX_ANALYST(...))
                                               for use outside Streamlit
```

## Repo structure

```
data_generation/
  generate_supply_chain_data.py   Faker + pandas generator for all 6 tables
  output/                         generated CSVs land here (gitignored)
snowflake_ddl/
  create_tables_and_load.sql      CREATE TABLE + stage + COPY INTO, all 6 tables
  governance_demo.sql             DEMO_ANALYST_ROLE with semantic-view-only access
semantic_views/
  sem_on_time_delivery.sql        OTD: within 1 day of confirmed_delivery_dt
  sem_fill_rate.sql               Fill Rate: SUM(fulfilled)/SUM(ordered) * 100
  sem_otif.sql                    OTIF: on time AND in full
  sem_days_of_inventory.sql       DOI: AVG(qty_on_hand)/AVG(avg_daily_demand_qty)
  sem_landed_cost.sql             Landed Cost: unit_cost + freight + duty
  validate_queries.sql            3-4 spot-check queries per view
cortex_analyst/
  supply_chain_semantic_model.yaml   Cortex Analyst semantic model (6 entities, 5 metrics)
  ask_cortex_analyst_procedure.sql   SQL-callable Cortex Analyst wrapper
streamlit_app/
  app.py                          3-tab Streamlit-in-Snowflake app
demo/
  demo_script.md                  5-minute demo narrative + talking points
requirements.txt                  local dev deps (data generator + YAML checks only)
```

## Prerequisites

- Python 3.10+ locally, for generating data and validating the YAML:
  ```
  pip install -r requirements.txt
  ```
- A Snowflake account with Cortex Analyst enabled, and a role with rights to
  create databases/schemas/tables/stages/semantic views (e.g. `SYSADMIN`).
- For the governance demo and the SQL-callable Cortex Analyst wrapper:
  a role with `CREATE ROLE` / `CREATE INTEGRATION` privilege (e.g.
  `SECURITYADMIN` / `ACCOUNTADMIN`).
- A running virtual warehouse for `COPY INTO` and querying.

## Execution steps

### 1. Generate the data

```
cd data_generation
python generate_supply_chain_data.py
```

Produces 6 CSVs in `data_generation/output/`: `suppliers.csv` (50),
`parts.csv` (200), `plants.csv` (10), `shipments.csv` (5000), `orders.csv`
(8000), `inventory_snapshots.csv` (24000). Deterministic — reruns are
identical (seeded with 42). The script prints an OTD/DOI/landed-cost sanity
check after writing the files.

### 2. Create the database/tables and load the CSVs

Run `snowflake_ddl/create_tables_and_load.sql` in a Snowflake worksheet. It
creates `SUPPLY_CHAIN_DEMO.CORE`, a file format, a stage, all 6 tables, and
the `COPY INTO` statements — but you must get the CSVs onto the stage first,
either via Snowsight (**Data > Add Data > Load files into a stage**) or
with SnowSQL from `data_generation/output/`:

```
PUT file://suppliers.csv            @SUPPLY_CHAIN_DEMO.CORE.supply_chain_stage AUTO_COMPRESS=TRUE;
PUT file://parts.csv                @SUPPLY_CHAIN_DEMO.CORE.supply_chain_stage AUTO_COMPRESS=TRUE;
PUT file://plants.csv               @SUPPLY_CHAIN_DEMO.CORE.supply_chain_stage AUTO_COMPRESS=TRUE;
PUT file://shipments.csv            @SUPPLY_CHAIN_DEMO.CORE.supply_chain_stage AUTO_COMPRESS=TRUE;
PUT file://orders.csv               @SUPPLY_CHAIN_DEMO.CORE.supply_chain_stage AUTO_COMPRESS=TRUE;
PUT file://inventory_snapshots.csv  @SUPPLY_CHAIN_DEMO.CORE.supply_chain_stage AUTO_COMPRESS=TRUE;
```

The script ends with a row-count check across all 6 tables.

### 3. Create the 5 semantic views

Run each file in `semantic_views/` once the tables are loaded:
`sem_on_time_delivery.sql`, `sem_fill_rate.sql`, `sem_otif.sql`,
`sem_days_of_inventory.sql`, `sem_landed_cost.sql`. Each is a standalone
`CREATE OR REPLACE SEMANTIC VIEW` with its canonical definition in a
`COMMENT`. Then run `semantic_views/validate_queries.sql` and eyeball the
3-4 spot checks per view (e.g. OTD by supplier should show Supplier A/B/C
near 92%/71%/85%).

### 4. Set up Cortex Analyst

1. Upload `cortex_analyst/supply_chain_semantic_model.yaml` to a stage, e.g.
   `@SUPPLY_CHAIN_DEMO.CORE.SEMANTIC_MODELS/` (create the stage if needed).
   This path must match `SEMANTIC_MODEL_FILE` in `streamlit_app/app.py` and
   `ask_cortex_analyst_procedure.sql`.
2. (Optional) To call Cortex Analyst from a plain SQL worksheet instead of
   only from Streamlit, run `cortex_analyst/ask_cortex_analyst_procedure.sql`.
   It needs one-time manual setup that can't be scripted: generate a
   Programmatic Access Token (Snowsight → your user menu → Settings →
   Authentication → Programmatic access tokens), and fill in your account
   hostname and that token where the file says `<YOUR_ACCOUNT_LOCATOR>` and
   `<YOUR_PAT_TOKEN>`. Then:
   ```sql
   CALL SUPPLY_CHAIN_DEMO.CORE.ASK_CORTEX_ANALYST('What is OTD for Supplier B?');
   ```

### 5. Set up the governance demo (optional but recommended)

Run `snowflake_ddl/governance_demo.sql` (as `SECURITYADMIN` or similar),
filling in `<YOUR_USERNAME>`. This creates `DEMO_ANALYST_ROLE`, grants it
`SELECT` on the 5 semantic views, and deliberately grants nothing on the 6
raw tables — real RBAC, not an app-side check. View the Streamlit app under
this role to see Tab 3 ("Governance Demo") behave as intended: a raw
`SELECT` fails with Snowflake's own authorization error, while the governed
`SEMANTIC_VIEW(...)` query succeeds.

### 6. Deploy the Streamlit app

Create a Streamlit object in Snowflake pointing at `streamlit_app/app.py`,
e.g.:

```sql
CREATE STREAMLIT SUPPLY_CHAIN_DEMO.CORE.supply_chain_app
  ROOT_LOCATION = '@SUPPLY_CHAIN_DEMO.CORE.STREAMLIT_APPS'
  MAIN_FILE = 'app.py'
  QUERY_WAREHOUSE = <your_warehouse>;
```

Upload `app.py` to that stage location, then open the app in Snowsight. It
has 3 tabs: **Ask Cortex Analyst** (Planner/Procurement/Logistics chat,
all three should agree on every answer), **Metric Registry** (the 5
canonical metric definitions), and **Governance Demo** (raw-query-denied /
semantic-view-allowed, from step 5).

### 7. Run the demo

Follow `demo/demo_script.md` — a 5-minute narrative with exact questions to
type into the chat panels, plus backup questions and known rough edges to
mention if asked.

## Status / known limitations

- Everything in this repo has been **syntax- and logic-checked locally**
  (Python compiles, YAML parses, SQL parens/quotes balance, column names
  cross-checked between the DDL, semantic views, and YAML) but has **not
  been executed against a live Snowflake account** — there was no Snowflake
  CLI/connector/credentials available in the environment this was built in.
  Run the steps above against your own account and fix anything that
  surfaces.
- `Days of Inventory` and `Landed Cost` are computed from data the generator
  adds specifically for this demo (`inventory_snapshots` table,
  `freight_cost_per_unit`/`duty_cost_per_unit` on `shipments`) — not from a
  real ERP feed.
- Customers are modeled as `customer_id`/`customer_name` columns on `orders`,
  not a standalone table.
- `cortex_analyst/ask_cortex_analyst_procedure.sql` needs a manually-created
  Programmatic Access Token and your account hostname — this step can't be
  scripted or committed to source control.
