"""
SupplyMind — Streamlit in Snowflake demo app.

Three personas, one governed answer. The Cortex Agent (SUPPLY_CHAIN_AGENT)
is backed by a unified semantic view (SUPPLY_CHAIN_UNIFIED) so every persona
gets the same number for the same question — that agreement is the point of
the demo.

Runtime: Uses SNOWFLAKE.CORTEX.DATA_AGENT_RUN() via Snowpark SQL session.
"""

import json
import re

import streamlit as st
from snowflake.snowpark.context import get_active_session

AGENT_FQN = "SUPPLY_CHAIN_DEMO.CORE.SUPPLY_CHAIN_AGENT"
PANELS = ["Planner", "Procurement", "Logistics"]
PANEL_META = {
    "Planner":     {"icon": "📊", "color": "#1d4ed8", "border": "#93c5fd"},
    "Procurement": {"icon": "🛒", "color": "#7c3aed", "border": "#c4b5fd"},
    "Logistics":   {"icon": "🚛", "color": "#0f766e", "border": "#99f6e4"},
}
SUGGESTED_QUESTIONS = [
    "What is our on-time delivery rate?",
    "What is the current fill rate?",
    "What is our OTIF percentage?",
    "How many days of inventory do we have?",
    "What is the average landed cost per unit?",
]
METRIC_REGISTRY = [
    {"metric": "On-Time Delivery (OTD)", "definition": "Percentage of shipments within 1 day of confirmed date.", "formula": "ABS(DATEDIFF) ≤ 1", "semantic_view": "SUPPLY_CHAIN_UNIFIED"},
    {"metric": "Fill Rate", "definition": "Volume-weighted % of ordered quantity fulfilled.", "formula": "SUM(fulfilled) / SUM(ordered) × 100", "semantic_view": "SUPPLY_CHAIN_UNIFIED"},
    {"metric": "OTIF (On-Time-In-Full)", "definition": "% of orders both on time and in full.", "formula": "on_time AND fulfilled ≥ ordered", "semantic_view": "SUPPLY_CHAIN_UNIFIED"},
    {"metric": "Days of Inventory (DOI)", "definition": "On-hand stock / average daily demand.", "formula": "AVG(qty_on_hand) / AVG(daily_demand)", "semantic_view": "SUPPLY_CHAIN_UNIFIED"},
    {"metric": "Landed Cost", "definition": "True per-unit cost incl. freight and duties.", "formula": "AVG(unit_cost + freight + duty)", "semantic_view": "SUPPLY_CHAIN_UNIFIED"},
]

st.set_page_config(page_title="SupplyMind", page_icon="🔗", layout="wide")
session = get_active_session()

if "panel_results" not in st.session_state:
    st.session_state.panel_results = {}
if "last_question" not in st.session_state:
    st.session_state.last_question = None

st.markdown("""<style>
.sm-header { padding: 16px 0 20px; border-bottom: 2px solid #e5e7eb; margin-bottom: 24px; }
.sm-brand { font-size: 28px; font-weight: 800; color: #1f2328; letter-spacing: -0.5px; }
.sm-brand span { color: #3b82d4; }
.sm-tagline { font-size: 14px; color: #57606a; margin-top: 4px; font-style: italic; }
.sm-badges { display: flex; gap: 8px; margin-top: 10px; flex-wrap: wrap; }
.sm-badge { background: #f0f0f0; border: 1px solid #e0e0e0; border-radius: 4px; padding: 2px 10px; font-size: 11px; font-weight: 600; color: #57606a; }
.callout-problem { background: #fffbeb; border-left: 4px solid #f59e0b; border-radius: 0 8px 8px 0; padding: 14px 18px; margin: 12px 0 20px; }
.callout-problem .label { font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.6px; color: #d97706; margin-bottom: 6px; }
.callout-problem p { font-size: 13px; color: #78350f; margin: 0; line-height: 1.6; }
.persona-hdr-bar { padding: 10px 16px; font-size: 14px; font-weight: 700; color: white; border-radius: 8px 8px 0 0; }
.agree-banner { background: #ecfdf5; border: 2px solid #6ee7b7; border-radius: 8px; padding: 14px 20px; margin: 16px 0 8px; font-size: 15px; font-weight: 700; color: #065f46; text-align: center; }
.metric-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 12px; margin: 16px 0; }
.metric-card { background: white; border: 1px solid #e5e7eb; border-radius: 8px; padding: 16px; }
.metric-card .m-name { font-size: 14px; font-weight: 700; color: #1f2328; margin-bottom: 6px; }
.metric-card .m-def { font-size: 12px; color: #57606a; line-height: 1.5; margin-bottom: 8px; }
.metric-card .m-formula { font-size: 11px; font-family: monospace; color: #3b82d4; background: #eff6ff; border-radius: 4px; padding: 4px 8px; display: inline-block; }
.metric-card .m-view { font-size: 11px; color: #9ca3af; margin-top: 8px; }
.entity-flow { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; margin: 16px 0 24px; font-size: 12px; }
.entity-node { background: white; border: 1.5px solid #3b82d4; border-radius: 6px; padding: 6px 14px; color: #3b82d4; font-weight: 600; }
.entity-arrow { color: #9ca3af; font-size: 16px; }
.gov-panel { border-radius: 10px; overflow: hidden; margin-bottom: 8px; }
.gov-panel.fail { border: 2px solid #fca5a5; } .gov-panel.pass { border: 2px solid #86efac; }
.gov-hdr { padding: 10px 16px; font-weight: 700; font-size: 13px; }
.gov-hdr.fail { background: #fef2f2; color: #991b1b; } .gov-hdr.pass { background: #f0fdf4; color: #065f46; }
.gov-body { padding: 16px; background: white; }
.role-badge { display: inline-block; background: #eff6ff; border: 1px solid #93c5fd; border-radius: 4px; padding: 3px 10px; font-size: 12px; font-weight: 600; color: #1d4ed8; }
</style>""", unsafe_allow_html=True)

st.markdown("""<div class="sm-header">
    <div class="sm-brand">Supply<span>Mind</span></div>
    <div class="sm-tagline">One question, one answer — across planning, procurement, and logistics</div>
    <div class="sm-badges">
        <span class="sm-badge">Snowflake Native</span>
        <span class="sm-badge">Cortex Agent</span>
        <span class="sm-badge">Semantic Views</span>
        <span class="sm-badge">RBAC Governed</span>
    </div>
</div>""", unsafe_allow_html=True)


# ── backend ──────────────────────────────────────────────────────────────────


def send_message_to_cortex(question: str) -> dict:
    request_body = json.dumps({"messages": [{"role": "user", "content": [{"type": "text", "text": question}]}]})
    row = session.sql("SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(?, ?) AS resp", params=[AGENT_FQN, request_body]).collect()
    raw = row[0]["RESP"]
    body = json.loads(raw) if isinstance(raw, str) else raw
    answer_text, sql = "", None
    def _walk(items):
        nonlocal answer_text, sql
        if not isinstance(items, list):
            return
        for item in items:
            if not isinstance(item, dict):
                continue
            t = item.get("type", "")
            if t == "text":
                answer_text += item.get("text", "")
            elif t == "sql":
                sql = sql or item.get("statement")
            elif t == "tool_results":
                sub = item.get("tool_results", {})
                if isinstance(sub, dict):
                    _walk(sub.get("content", []))
                _walk(item.get("content", []))
    _walk(body.get("content", []))
    return {"text": answer_text.strip(), "sql": sql}


def run_sql(sql: str):
    return session.sql(sql).to_pandas()


def process_question(question):
    results = {}
    for panel in PANELS:
        try:
            result = send_message_to_cortex(question)
            df = run_sql(result["sql"]) if result["sql"] else None
        except Exception as exc:
            result = {"text": f"Error: {exc}", "sql": None}
            df = None
        results[panel] = {"text": result["text"], "sql": result["sql"], "df": df}
    st.session_state.panel_results = results
    st.session_state.last_question = question


# ── Tab 1: Ask Cortex Agent ─────────────────────────────────────────────────


def render_agent_tab():
    st.markdown("""<div class="callout-problem"><div class="label">The Problem</div>
    <p>Ask <em>"What is our on-time delivery rate?"</em> and three teams return three different answers —
    <strong>73%</strong> from Planning, <strong>81%</strong> from Procurement, <strong>68%</strong> from Logistics.
    <strong>SupplyMind fixes this.</strong></p></div>""", unsafe_allow_html=True)

    st.markdown("##### Try a question")
    pending_question = None
    sq_cols = st.columns(len(SUGGESTED_QUESTIONS))
    for i, q in enumerate(SUGGESTED_QUESTIONS):
        with sq_cols[i]:
            label = METRIC_REGISTRY[i]["metric"] if i < len(METRIC_REGISTRY) else q
            if st.button(label, key=f"sq_{i}", use_container_width=True):
                pending_question = q

    with st.form(key="ask_form", clear_on_submit=True):
        user_typed = st.text_input("Or type your own question:", placeholder="e.g. What is the OTD rate for Supplier X?")
        submitted = st.form_submit_button("Ask all three personas")
    if submitted and user_typed:
        pending_question = user_typed

    if pending_question:
        with st.spinner("Querying Cortex Agent for all three personas..."):
            process_question(pending_question)

    if st.session_state.last_question:
        st.markdown(f"**Question:** *{st.session_state.last_question}*")
        st.divider()

        results = st.session_state.panel_results
        cols = st.columns(3)

        for panel, col in zip(PANELS, cols):
            meta = PANEL_META[panel]
            r = results.get(panel, {})

            with col:
                st.markdown(
                    f'<div class="persona-hdr-bar" style="background:{meta["color"]}">'
                    f'{meta["icon"]}  {panel}</div>',
                    unsafe_allow_html=True,
                )
                if r.get("text"):
                    st.markdown(r["text"])
                else:
                    st.caption("_(no answer returned)_")
                if r.get("sql"):
                    with st.expander("Generated SQL"):
                        st.code(r["sql"], language="sql")
                if r.get("df") is not None:
                    with st.expander("Result data"):
                        st.dataframe(r["df"], use_container_width=True)

        # ── check if all three answers match ──
        texts = [r.get("text", "") for r in results.values()]
        nums = []
        for t in texts:
            m = re.search(r"\$\s*([\d,]+\.?\d*)", t)
            if m:
                nums.append(round(float(m.group(1).replace(",", "")), 2))
                continue
            m = re.search(r"([\d,]+\.?\d*)\s*%", t)
            if m:
                nums.append(round(float(m.group(1).replace(",", "")), 2))
                continue
            m = re.search(r"(?<![.\w])(\d+\.?\d+)(?![.\w])", t)
            if m:
                nums.append(round(float(m.group(1)), 2))

        if len(nums) == len(PANELS) and len(set(nums)) == 1:
            st.markdown(
                f'<div class="agree-banner">✓ All three panels agree: '
                f'<strong>{nums[0]}</strong> — one governed metric, three personas</div>',
                unsafe_allow_html=True,
            )
    else:
        cols = st.columns(3)
        for panel, col in zip(PANELS, cols):
            meta = PANEL_META[panel]
            with col:
                st.markdown(
                    f'<div class="persona-hdr-bar" style="background:{meta["color"]}">'
                    f'{meta["icon"]}  {panel}</div>',
                    unsafe_allow_html=True,
                )
                st.caption("Ask a question to see the answer")


# ── Tab 2: Metric Registry ──────────────────────────────────────────────────


def render_metrics_tab():
    st.markdown("Every metric the agent can answer with, its canonical definition, and the Semantic View that owns it.")
    st.markdown("##### Supply Chain Entity Graph")
    st.markdown("""<div class="entity-flow">
        <div class="entity-node">Supplier</div><span class="entity-arrow">→</span>
        <div class="entity-node">Part / SKU</div><span class="entity-arrow">→</span>
        <div class="entity-node">Plant</div><span class="entity-arrow">→</span>
        <div class="entity-node" style="border-color:#7c3aed;color:#7c3aed">Shipment</div><span class="entity-arrow">→</span>
        <div class="entity-node">Order</div><span class="entity-arrow">→</span>
        <div class="entity-node">Inventory</div></div>""", unsafe_allow_html=True)
    st.markdown("##### Governed Metrics — Defined Once, Used Everywhere")
    cards = '<div class="metric-grid">'
    for m in METRIC_REGISTRY:
        cards += f'<div class="metric-card"><div class="m-name">{m["metric"]}</div><div class="m-def">{m["definition"]}</div><div class="m-formula">{m["formula"]}</div><div class="m-view">→ {m["semantic_view"]}</div></div>'
    cards += "</div>"
    st.markdown(cards, unsafe_allow_html=True)


# ── Tab 3: Governance Demo ───────────────────────────────────────────────────


def render_governance_tab():
    st.markdown("Governance is architectural, not a policy document. Under `DEMO_ANALYST_ROLE`, raw tables are inaccessible — the governed Semantic View is the **only door in**.")
    try:
        role = session.sql("SELECT CURRENT_ROLE()").collect()[0][0]
        st.markdown(f'Current role: <span class="role-badge">{role}</span>', unsafe_allow_html=True)
    except Exception:
        pass
    col1, col2 = st.columns(2)
    with col1:
        st.markdown('<div class="gov-panel fail"><div class="gov-hdr fail">✕ FAIL — Direct raw table access</div><div class="gov-body"><p style="font-size:12px;color:#57606a">Under DEMO_ANALYST_ROLE this should be denied.</p></div></div>', unsafe_allow_html=True)
        st.code("SELECT * FROM SUPPLY_CHAIN_DEMO.CORE.SHIPMENTS LIMIT 10;", language="sql")
        if st.button("Run raw query", key="gov_raw"):
            try:
                df = session.sql("SELECT * FROM SUPPLY_CHAIN_DEMO.CORE.SHIPMENTS LIMIT 10").to_pandas()
                st.warning("Query succeeded — broader access than intended.")
                st.dataframe(df, use_container_width=True)
            except Exception as exc:
                st.error(f"Access denied, as expected:\n\n{exc}")
    with col2:
        st.markdown('<div class="gov-panel pass"><div class="gov-hdr pass">✓ PASS — Governed Semantic View</div><div class="gov-body"><p style="font-size:12px;color:#57606a">Same data, through the governed path.</p></div></div>', unsafe_allow_html=True)
        st.code("SELECT * FROM SEMANTIC_VIEW(\n  SUPPLY_CHAIN_DEMO.CORE.SUPPLY_CHAIN_UNIFIED\n  METRICS OTD_PCT\n);", language="sql")
        if st.button("Run governed query", key="gov_sem"):
            try:
                df = session.sql("SELECT * FROM SEMANTIC_VIEW(SUPPLY_CHAIN_DEMO.CORE.SUPPLY_CHAIN_UNIFIED METRICS OTD_PCT)").to_pandas()
                st.success("Succeeded — the governed path works.")
                st.dataframe(df, use_container_width=True)
            except Exception as exc:
                st.error(f"Unexpected failure: {exc}")


tab1, tab2, tab3 = st.tabs(["🤖 Ask Cortex Agent", "📐 Metric Registry", "🔒 Governance Demo"])
with tab1:
    render_agent_tab()
with tab2:
    render_metrics_tab()
with tab3:
    render_governance_tab()
