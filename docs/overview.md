{% docs __overview__ %}

# hope4nevadaschools — A dbt Analytics Project

I spent several years teaching 5th and then 3rd grade in Clark County before making the transition into analytics engineering. Education and data have always been passions of mine, and what better way to use my furthering education than to do a deep dive into CCSD's education system.

The data comes from the same public portals I used as a teacher to understand how my school was performing — the Nevada Accountability Portal and CCSD's open data dashboard. Back then I was downloading CSVs and eyeballing numbers in Excel. Now I'm building the pipeline I wish had existed.

---

## What this project does

Transforms raw CCSD enrollment, attendance, and assessment data into clean, tested, analytics-ready models on Snowflake — structured so that a school principal, a budget analyst, or a facilities planner can all answer their questions from the same source of truth.
Seeds (CSVs)         Staging (views)          Marts (tables)

────────────   →    ─────────────────   →    ──────────────────────────

demographic         stg_enrollment           dim_schools

absenteeism         stg_attendance           fct_enrollment_trends  ← incremental

assessment          stg_assessment_scores    fct_school_performance

---

## Why I built it this way

| Decision | Why it matters |
|---|---|
| `fct_enrollment_trends` is incremental | CCSD releases enrollment data annually — no need to rebuild history on every run |
| Staging models are views | Keeps compute costs low; seeds are already persisted |
| SCD Type 2 snapshot on schools | Schools get renamed and restructured — I want to track that history |
| `var('start_year')` filter | Pre-2019 data has quality issues; easy to override when needed |
| Chronic absenteeism tier column | Translates a percentage into something a non-analyst can act on |

---

## Running the project

```bash
dbt deps
dbt build
dbt run --select fct_enrollment_trends --full-refresh
dbt snapshot
dbt docs generate && dbt docs serve
```

---

## Built with

- **dbt Core 1.11** + **dbt-snowflake**
- **Snowflake** (CCSD_DEV database)
- Data sourced from [nevadareportcard.nv.gov](https://nevardareportcard.nv.gov) and [data.ccsd.net](https://data.ccsd.net)

{% enddocs %}