# ETL / ELT — Interview Question Bank

> Format: Question · Answer · Follow-ups · Difficulty

---

### Q1: What's the difference between ETL and ELT, and why has ELT become more common?

**Answer:**
**ETL** (Extract, Transform, Load): data is transformed in a separate processing engine *before* loading into the target warehouse. **ELT** (Extract, Load, Transform): raw data is loaded first, and transformation happens *inside* the target system (e.g., BigQuery/Snowflake SQL) afterward. ELT became more common because modern cloud warehouses have cheap, elastic, highly parallel compute — it's often simpler and faster to push transformation logic into SQL running on the warehouse than to maintain a separate transformation cluster, and it keeps raw data available for reprocessing if transformation logic changes.

**Follow-ups:**
- When is ETL still the better choice?
- What role does dbt play in ELT?

**Difficulty:** Easy

---

### Q2: What is data modeling, and what's the difference between a fact table and a dimension table?

**Answer:**
Data modeling is designing how data is structured for storage/querying. In dimensional modeling: a **fact table** holds measurable, quantitative events (order amount, click count) at a specific grain, with foreign keys to dimensions. A **dimension table** holds descriptive context (customer attributes, product attributes, date attributes) that facts are analyzed by/grouped by. Getting the fact table's **grain** (what one row represents — e.g., "one row per order line item") right up front is the most important early modeling decision.

**Follow-ups:**
- What's the grain of a fact table?
- What are additive, semi-additive and non-additive measures?

**Difficulty:** Easy

---

### Q3: What does "idempotent pipeline" mean, and why is it critical for production ETL?

**Answer:**
A pipeline is idempotent if running it multiple times with the same input produces the same end result — no duplicated rows, no corrupted state — regardless of how many times a step is retried. This matters because orchestrators (Airflow) and distributed systems routinely retry failed tasks; a non-idempotent pipeline (e.g., blind `INSERT` without dedup) will silently duplicate data on every retry. Achieved via `MERGE`/upsert patterns, overwriting a specific partition rather than appending, or using deterministic natural keys the load step can dedupe on.

**Follow-ups:**
- How do you make an append-only load idempotent?
- How does partition overwrite help?

**Difficulty:** Medium

---

### Q4: Batch vs streaming processing — how do you decide which a given use case needs?

**Answer:**
**Batch**: data processed in scheduled chunks (hourly/daily) — appropriate when some latency (minutes to hours) is acceptable and it simplifies reasoning about complete, consistent datasets (e.g., daily financial reporting). **Streaming**: data processed continuously as it arrives, low latency (seconds) — needed when decisions must be made near-real-time (fraud detection, live dashboards, alerting). Streaming systems are inherently more complex (need to handle out-of-order/late data, windowing, exactly-once semantics) — don't reach for streaming unless the latency requirement actually demands it.

**Follow-ups:**
- What's micro-batching?
- How do you quantify the business value of lower latency?

**Difficulty:** Easy

---

### Q5: What is a data lake, and how does it differ from a data warehouse and a "lakehouse"?

**Answer:**
- **Data lake**: cheap, schema-flexible storage (e.g., GCS/S3) holding raw data in native/semi-structured formats — good for storing everything cheaply, but lacks the transaction guarantees, indexing, and query performance of a warehouse.
- **Data warehouse**: structured, schema-enforced, optimized for fast analytical SQL queries — but typically more expensive per byte and less flexible for unstructured/raw data.
- **Lakehouse** (Delta Lake, Iceberg, Hudi, BigLake): adds warehouse-like features (ACID transactions, schema enforcement, time travel, indexing) on top of lake storage — aiming to get both cheap flexible storage and reliable, performant querying without maintaining two separate copies of data.

**Follow-ups:**
- What problems do lakehouses solve that data lakes have?
- What's the medallion architecture?

**Difficulty:** Easy

---

### Q6: Why is Parquet commonly preferred for data lake storage over CSV/JSON?

**Answer:**
Parquet is **columnar** (only relevant columns are read for a query, reducing I/O), **compressed** (smaller storage/network footprint via efficient columnar compression), and **self-describing** (embeds schema and column statistics, enabling predicate pushdown — skipping row groups that can't match a filter). CSV/JSON are row-oriented, uncompressed by default, and require full-file scans/parsing even when only a few columns or filtered rows are needed.

**Follow-ups:**
- What's the difference between Parquet and Avro?
- How do compression codecs compare?

**Difficulty:** Easy

---

### Q7: What is Delta Lake / Apache Iceberg, and what problem do they solve on top of plain Parquet files in a lake?

**Answer:**
Plain Parquet files in a lake have no transaction log — concurrent writers can corrupt state, there's no atomic multi-file commit, no schema evolution tracking, and no easy way to see historical versions. Delta Lake and Iceberg add a **transaction log/metadata layer** on top of Parquet files, providing: ACID transactions (safe concurrent reads/writes), schema evolution, **time travel** (query a table as of a past version/timestamp), and efficient upserts/deletes (`MERGE`) directly on lake files — bringing warehouse-like reliability to lake storage.

**Follow-ups:**
- What is time travel, and how is it used?
- How do Delta and Iceberg handle concurrent writers?

**Difficulty:** Medium

---

### Q8: How would you design an incremental load pattern (only process new/changed data, not the whole table every run)?

**Moved:** this question was asked in real interviews, so its answer now lives in [`real-world-asked/scenario-based.md`](../real-world-asked/scenario-based.md).

---

### Q9: What is a data quality framework, and what kinds of checks would you build into one?

**Answer:**
A systematic way to validate data meets expectations *before* (or as) it flows downstream, catching issues early rather than letting bad data silently corrupt reports/models. Typical checks: **schema** (expected columns/types present), **completeness** (null rate within acceptable bounds for required fields), **uniqueness** (no duplicate keys), **referential integrity** (foreign keys actually exist in the referenced dimension), **range/format validation** (values within expected bounds, valid email/date formats), and **freshness** (data arrived within an expected SLA window). Tools: Great Expectations, dbt tests, custom assertions embedded in pipeline code.

**Follow-ups:**
- Which tools would you use, e.g. Great Expectations or dbt tests?
- What happens when a check fails — block or warn?

**Difficulty:** Medium

---

### Q10: How would you handle schema evolution in an ETL pipeline (source adds/removes/renames a column)?

**Answer:**
- Design downstream steps to be resilient to **additive** changes (new columns) by default — e.g., select needed columns explicitly rather than `SELECT *`, so a new upstream column doesn't silently break things but also doesn't get silently ignored if it should be tracked.
- For **breaking** changes (column removed/renamed/retyped), use schema validation as an early pipeline step that fails loudly (rather than pipeline breaking downstream in a confusing way), and version the pipeline logic alongside schema changes.
- Formats like Avro/Parquet with an embedded schema, or Iceberg/Delta's schema evolution support, make additive/compatible changes much safer than raw CSV.

**Follow-ups:**
- How do you handle a column rename?
- What's a schema registry?

**Difficulty:** Medium

---

### Q11: What's the difference between a full load and an incremental (delta) load, and what are the tradeoffs?

**Answer:**
**Full load**: reprocess/reload the entire source dataset every run — simple, self-healing (naturally corrects any missed updates), but expensive and slow at scale. **Incremental load**: only process what's new/changed since the last run — much cheaper/faster, but more complex to implement correctly (must reliably identify "what changed") and can silently miss data if the change-detection logic has a gap (e.g., a source system backdating an update). A common compromise: incremental loads day-to-day, with a periodic full reconciliation/backfill to catch drift.

**Follow-ups:**
- How would you periodically reconcile an incremental table?
- When is a full load acceptable?

**Difficulty:** Easy

---

### Q12: How would you design a pipeline to be observable — how do you know it's working correctly without manually checking every day?

**Answer:**
- **Logging**: structured logs with context (record counts, timings, errors) at each pipeline stage.
- **Metrics**: row counts in/out per stage, processing duration, error rates — pushed to a monitoring system (Cloud Monitoring, Datadog) with dashboards.
- **Data quality checks** as an explicit pipeline step (see Q9), not an afterthought — failing the pipeline (or at least alerting) on violated expectations.
- **Alerting**: on pipeline failure, SLA misses (data not ready by expected time), and anomalous volume (e.g., row count suddenly drops 90%, suggesting an upstream break).
- **Lineage/audit trail**: knowing which source data/version produced a given output, for debugging and reprocessing.

**Follow-ups:**
- What are the main data observability metrics (freshness, volume, schema, distribution)?
- How do you avoid alert fatigue?

**Difficulty:** Medium

---

### Q13: What is a "dead-letter queue" pattern, and why use it in ETL pipelines?

**Answer:**
Instead of letting a single malformed/unexpected record crash an entire batch or block a streaming pipeline, records that fail validation/parsing are routed to a separate "dead-letter" location (a table, topic, or GCS path) for later inspection/reprocessing, while the rest of the pipeline continues processing valid records. Balances **robustness** (one bad record doesn't take down the whole pipeline) with **not silently dropping data** (bad records are still captured somewhere for investigation, not just discarded).

**Follow-ups:**
- How do you reprocess records from the DLQ?
- How do you monitor the size of the DLQ?

**Difficulty:** Medium

---

### Q14: How would you approach backfilling historical data after fixing a bug in transformation logic?

**Answer:**
1. Fix and thoroughly test the corrected logic against a known sample first.
2. Determine the affected date range/partitions.
3. Run the corrected pipeline against historical raw data for that range, writing to the same partitioned target so it **overwrites** (not appends) the affected partitions — this is why idempotent, partition-based writes matter.
4. Validate output against expected row counts/spot checks before/after, and communicate to downstream consumers that historical numbers may shift.
5. In Airflow, this is typically a manual `backfill` command or a parameterized DAG run over the affected date range.

**Follow-ups:**
- How do you backfill without affecting the live SLA?
- How do you validate the backfilled output?

**Difficulty:** Hard

---

### Q15: What's the difference between "schema-on-write" and "schema-on-read"?

**Answer:**
**Schema-on-write** (traditional data warehouses): schema is enforced at load time — data must conform before it's accepted, catching issues early but requiring more upfront modeling. **Schema-on-read** (data lakes, raw storage): data is stored as-is, and schema is applied/interpreted only when it's *queried* — more flexible for evolving/varied raw sources, but issues (type mismatches, missing fields) surface later, at query time, rather than at ingestion.

**Follow-ups:**
- Which suits a data lake?
- How do schema-on-read failures show up?

**Difficulty:** Easy

---

### Q16: How do you handle late-arriving data in a daily batch pipeline (e.g., a source system backfills yesterday's records today)?

**Answer:**
Options, roughly in increasing complexity: (1) accept a short grace period — don't finalize "yesterday's" partition until a few hours into today, giving stragglers time to arrive; (2) reprocess a rolling window (e.g., always reprocess the last 3 days, not just yesterday) so late data gets picked up on a subsequent run; (3) for streaming, use watermarks + `allowed_lateness` (Beam/Dataflow) to bound how long the pipeline waits before considering a window complete. The right choice depends on how tolerant downstream consumers are of numbers changing after initial publication.

**Follow-ups:**
- How do you choose a lookback window?
- How do event time and processing time affect partitioning?

**Difficulty:** Medium

---

### Q17: What are the key design decisions when choosing a partitioning strategy for a data lake/warehouse table?

**Answer:**
- **Partition column**: usually a date/timestamp for time-series data — should match the most common filter pattern in downstream queries.
- **Partition granularity**: daily is common; too fine-grained (hourly on a huge cluster) causes many small files; too coarse (yearly) means queries scan far more data than needed.
- **Avoid high-cardinality partition columns** (e.g., partitioning by `customer_id` with millions of values) — leads to an unmanageable number of tiny partitions/files.
- Combine with **clustering/sorting** within partitions on secondary frequently-filtered columns for further pruning without exploding partition count.

**Follow-ups:**
- What happens if you partition on a high-cardinality column?
- How do you choose between daily and hourly partitions?

**Difficulty:** Medium
