# Data Warehousing Concepts — Interview Question Bank

> Format: Question · Answer · Follow-ups · Difficulty

---

### Q1: What's the difference between OLTP and OLAP systems?

**Answer:**
| | OLTP | OLAP |
|---|---|---|
| Purpose | Run the business: orders, payments, bookings | Analyze the business: trends, KPIs, reporting |
| Workload | Many small reads and writes, single rows | Few large queries scanning millions of rows |
| Schema | Normalized (3NF) to avoid update anomalies | Denormalized (star schema) for fast reads |
| Storage | Row-oriented | Usually column-oriented |
| Data | Current state | History over time |
| Examples | PostgreSQL, MySQL, Cloud SQL, Spanner | BigQuery, Snowflake, Redshift, Synapse |

Data engineers move data **from OLTP to OLAP** (batch or CDC) so analytics doesn't slow down the operational system.

**Follow-ups:**
- Why is running heavy reports on the production OLTP database a bad idea?
- What is HTAP, and where does it fit?

**Difficulty:** Easy

---

### Q2: What are the types of Slowly Changing Dimensions?

**Answer:**
| Type | Behavior on change | History kept |
|---|---|---|
| **0** | Never change (e.g. original signup date) | Original value only |
| **1** | Overwrite the old value | None |
| **2** | Insert a new row; close the old one (`valid_from`, `valid_to`, `is_current`) | Full history |
| **3** | Keep current and previous value in separate columns | One previous value |
| **4** | Current table plus a separate history table | Full, kept separately |
| **6** | Hybrid of 1 + 2 + 3: history rows plus a "current value" column on every row | Full, plus current |

Type 2 is the most common for attributes that affect reporting (customer segment, region); Type 1 for corrections (typo fixes). Facts join to the dimension row that was valid at the time of the event, via a surrogate key.

**Follow-ups:**
- Why do SCD Type 2 dimensions need surrogate keys?
- How would you implement Type 2 in BigQuery or dbt?

**Difficulty:** Medium

---

### Q3: What is a data mart, and how does it relate to a data warehouse and a data lake?

**Answer:**
- **Data lake:** raw and semi-structured data in cheap object storage (Cloud Storage), schema-on-read. It stores everything, including data not yet modeled.
- **Data warehouse:** integrated, cleaned and modeled data across the whole organization, used for consistent reporting.
- **Data mart:** a **subject-specific subset** of the warehouse for one team or domain (sales, finance, marketing), modeled for that team's questions.

Marts can be **dependent** (built from the warehouse, the usual approach today, often as dbt models or authorized views) or **independent** (built straight from sources, which risks inconsistent numbers). In BigQuery, marts are typically separate datasets with their own access controls.

**Follow-ups:**
- How do you keep metrics consistent across several marts?
- When would you give a team a mart instead of direct warehouse access?

**Difficulty:** Easy
