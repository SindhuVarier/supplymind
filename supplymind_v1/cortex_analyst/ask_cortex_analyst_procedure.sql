-- ============================================================================
-- SQL-callable wrapper around Cortex Analyst, for use from a plain SQL
-- worksheet (not just from Streamlit).
--
-- Uses _snowflake.send_snow_api_request() to call the Cortex Analyst REST
-- endpoint internally — no External Access Integration, PAT, or network
-- rule required.  Works on trial accounts.
-- ============================================================================

USE DATABASE SUPPLY_CHAIN_DEMO;
USE SCHEMA CORE;

CREATE OR REPLACE PROCEDURE SUPPLY_CHAIN_DEMO.CORE.ASK_CORTEX_ANALYST(question STRING)
  RETURNS VARIANT
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.11'
  PACKAGES = ('snowflake-snowpark-python')
  HANDLER = 'run'
  COMMENT = 'SQL-callable Cortex Analyst: CALL SUPPLY_CHAIN_DEMO.CORE.ASK_CORTEX_ANALYST(''What is OTD for Supplier B?'');'
AS
$$
import _snowflake
import json

SEMANTIC_VIEW = "SUPPLY_CHAIN_DEMO.CORE.SUPPLY_CHAIN_UNIFIED"

def run(question: str):
    body = json.dumps({
        "messages": [{"role": "user", "content": [{"type": "text", "text": question}]}],
        "semantic_view": SEMANTIC_VIEW,
    })

    resp = _snowflake.send_snow_api_request(
        "POST",
        "/api/v2/cortex/analyst/message",
        {}, # headers — session auth is automatic
        body,
    )
    content = json.loads(resp["content"])

    answer_text, sql = "", None
    for item in content.get("message", {}).get("content", []):
        if item.get("type") == "text":
            answer_text += item.get("text", "")
        elif item.get("type") == "sql":
            sql = item.get("statement")
    return {"text": answer_text, "sql": sql}
$$;

-- Example usage:
-- CALL SUPPLY_CHAIN_DEMO.CORE.ASK_CORTEX_ANALYST('What is OTD for Supplier B?');
