# BigQuery — Interview Question Bank

> Format: Question · Answer · Follow-ups · Difficulty

---

### Q1: What is BigQuery, and how is its architecture different from a traditional data warehouse?

**Answer:**
BigQuery is a serverless, fully-managed data warehouse that separates **storage** (columnar, distributed, automatically managed) from **compute** (a massive multi-tenant fleet that executes queries via the Dremel engine, dynamically allocating "slots" to your query). You never provision servers or storage size — you just load data and query it, and BigQuery scales compute out across thousands of workers for a single query if needed. Traditional warehouses (on-prem or fixed-cluster cloud DBs) tightly couple storage and compute, so scaling either means resizing the whole cluster.

**Follow-ups:**
- What are Dremel, Colossus and Jupiter?
- Why does columnar storage reduce cost?

**Difficulty:** Easy

---

### Q2: On-demand vs flat-rate (capacity) pricing — how do you choose?

**Answer:**
- **On-demand**: pay per byte of data scanned by each query (first 1 TB/month free). Good for unpredictable, spiky, or low-volume workloads.
- **Flat-rate / capacity (slots via reservations, now "editions")**: pay for a fixed or autoscaling pool of query-processing capacity regardless of bytes scanned. Good once query volume is high and predictable enough that the flat cost is cheaper than paying per-byte, and it gives predictable, budgetable spend.
Many teams start on-demand and move specific high-volume workloads/projects to a slot reservation once cost/usage patterns are clear.

**Follow-ups:**
- What are editions and autoscaling slots?
- How would you estimate monthly on-demand cost?

**Difficulty:** Medium

---

### Q3: What's the difference between partitioning and clustering, and how do you use both together?

**Answer:**
- **Partitioning** splits a table into segments based on a column (usually a date/timestamp, or an integer range) — BigQuery can skip entire partitions that don't match a query's filter, drastically cutting bytes scanned.
- **Clustering** sorts data *within* each partition (or the whole table if unpartitioned) by up to 4 columns — BigQuery uses this to further prune blocks it needs to read for filters/joins on those columns.
```sql
CREATE TABLE sales.orders (order_id STRING, region STRING, amount NUMERIC, order_date DATE)
PARTITION BY order_date
CLUSTER BY region, order_id;
```
Use partitioning for your primary time-based filter, and clustering for the next most common filter/join columns.

**Follow-ups:**
- How many partitions can a table have?
- When is clustering better than partitioning?

**Difficulty:** Medium

---

### Q4: How do you prevent an accidental full table scan on a huge partitioned table?

**Answer:**
```sql
ALTER TABLE sales.orders
SET OPTIONS (require_partition_filter = TRUE);
```
This forces every query against the table to include a filter on the partitioning column, or BigQuery rejects the query outright — a safety net against a forgotten `WHERE` clause scanning years of data.

**Follow-ups:**
- What does `require_partition_filter` do?
- How do maximum-bytes-billed limits help?

**Difficulty:** Easy

---

### Q5: What are the different table types in BigQuery — native, external, and views (including materialized views)?

**Answer:**
- **Native tables**: data stored and managed by BigQuery itself (best performance, supports all features).
- **External tables**: query data that physically lives elsewhere (GCS, Bigtable, Drive) without loading it in — convenient, but generally slower and with some feature limitations versus native storage.
- **Views**: a saved query, re-run each time it's queried (no storage of results).
- **Materialized views**: a saved query whose results *are* precomputed/stored and incrementally refreshed — BigQuery can even transparently route a query against the base table to the materialized view if it's cheaper, without you rewriting the query.

**Follow-ups:**
- When does a materialized view refresh?
- What are the limitations of materialized views?

**Difficulty:** Medium

---

### Q6: How would you deduplicate rows in a BigQuery table?

**Answer:**
```sql
CREATE OR REPLACE TABLE sales.orders_dedup AS
SELECT * EXCEPT(rn) FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY updated_at DESC) AS rn
  FROM sales.orders
)
WHERE rn = 1;
```
`ROW_NUMBER()` over the natural key, keeping the most recent row per key, is the standard pattern.

**Follow-ups:**
- How do you dedupe with `QUALIFY ROW_NUMBER()`?
- How would you dedupe in place without recreating the table?

**Difficulty:** Medium

---

### Q7: Explain `MERGE` and why it's preferred for upserts over separate DELETE + INSERT.

**Answer:**
`MERGE` lets you insert, update, and delete in a single atomic statement based on a join condition against a source — avoiding the race condition/partial-state risk of running separate DML statements, and it's usually cheaper (single scan/plan).
```sql
MERGE sales.orders T
USING staging.orders_incoming S
ON T.order_id = S.order_id
WHEN MATCHED THEN
  UPDATE SET T.amount = S.amount, T.updated_at = S.updated_at
WHEN NOT MATCHED THEN
  INSERT (order_id, amount, updated_at) VALUES (S.order_id, S.amount, S.updated_at);
```

**Follow-ups:**
- How does `MERGE` handle multiple source rows matching one target row?
- How do you limit the `MERGE` scan to recent partitions?

**Difficulty:** Medium

---

### Q8: What are the main ways to load data into BigQuery?

**Answer:**
- **Batch load** (`bq load`, console, or `LOAD DATA` SQL) from GCS files (CSV, JSON, Avro, Parquet, ORC) — free, but not instantaneous.
- **Streaming inserts** (`insertAll`/`tabledata.insertAll`, or the newer **Storage Write API**) — near-real-time, small cost per row, good for continuous event ingestion.
- **Query-based load**: `INSERT INTO ... SELECT`, `CREATE TABLE AS SELECT`, federated/external queries.
- **EL/ELT tools & connectors**: Dataflow, Datastream (CDC), Data Transfer Service (for SaaS sources), Dataproc/Spark connector.
The modern recommendation for high-throughput streaming is the **BigQuery Storage Write API** over the legacy streaming insert API (cheaper, exactly-once support, higher throughput).

**Follow-ups:**
- Batch loads are free — so what's charged with streaming?
- When would you use the Storage Write API?

**Difficulty:** Easy

---

### Q9: What's the difference between `WITH` (CTEs) and temporary tables in BigQuery, performance-wise?

**Answer:**
A `WITH` clause (CTE) is inlined into the query plan — if you reference the same CTE multiple times, BigQuery may (depending on the optimizer) recompute it more than once rather than materializing it automatically. For a genuinely expensive intermediate result reused several times, explicitly materializing it into a **temp table** (`CREATE TEMP TABLE` in a script, or a real staging table) guarantees it's computed once and reused, which can be significantly cheaper/faster than relying on CTE reuse.

**Follow-ups:**
- Are CTEs materialized in BigQuery?
- When would you use a temp table in a multi-statement script?

**Difficulty:** Medium

---

### Q10: How do you control who can see which rows/columns in a shared table?

**Answer:**
- **Column-level security**: tag sensitive columns with **policy tags** (via Data Catalog taxonomies); only users granted `Fine-Grained Reader` on that tag can see the real values, everyone else gets them nulled.
- **Row-level security**: `CREATE ROW ACCESS POLICY` to filter which rows a principal/group can see.
- **Authorized views/datasets**: expose a view to users who don't have direct access to the underlying base table(s), so they only ever see the view's (possibly filtered/joined/aggregated) output.
```sql
CREATE ROW ACCESS POLICY us_only ON sales.orders
GRANT TO ("group:us-analysts@company.com")
FILTER USING (region = 'US');
```

**Follow-ups:**
- How do row access policies work?
- How do policy tags provide column-level security?

**Difficulty:** Medium

---

### Q11: What is BigQuery ML, and when would you use it instead of exporting data to a separate ML platform?

**Answer:**
BigQuery ML lets you train and serve models (linear/logistic regression, k-means, boosted trees, time-series forecasting, even importing TensorFlow/ONNX models) directly with SQL, against data that's already in BigQuery. Best for teams that want fast iteration without building a data-export pipeline to a separate ML platform, or for relatively standard model types where SQL-based training is "good enough." For deep learning, large-scale custom architectures, or heavy feature engineering pipelines, a dedicated ML platform (Vertex AI, etc.) is usually still the better fit — and BigQuery ML integrates with Vertex AI for that handoff.

**Follow-ups:**
- Which model types does BigQuery ML support?
- How do you evaluate and predict with `ML.EVALUATE` and `ML.PREDICT`?

**Difficulty:** Medium

---

### Q12: Explain slots, and how query performance relates to them.

**Answer:**
A **slot** is a unit of BigQuery's query-execution compute (CPU + memory). Every query is broken into stages/shards that run in parallel across as many slots as are available/allocated. Under on-demand pricing, BigQuery dynamically allocates slots up to a project-level quota; under a reservation, you have a defined (or autoscaling) pool of slots shared across the queries assigned to that reservation. A query queuing or running slowly despite low data volume can indicate slot contention — visible in `INFORMATION_SCHEMA.JOBS` or the query execution details ("slot time consumed" vs actual elapsed time).

**Follow-ups:**
- What's slot contention?
- How do reservations and assignments work?

**Difficulty:** Medium

---

### Q13: How would you debug a BigQuery query that's slow or scanning way more data than expected?

**Answer:**
- Check the query's **execution details** (stage breakdown, bytes shuffled, slot time) in the console or `bq show -j`.
- Confirm partition pruning is actually happening — a filter using a function on the partition column (e.g. `DATE(TIMESTAMP_COLUMN) = ...` instead of filtering the raw partition column) can defeat pruning.
- Look for a broadcast/shuffle-heavy join where one side is unexpectedly huge, or a `SELECT *` pulling far more columns than needed (columnar storage means you pay for columns scanned, not rows).
- Check `INFORMATION_SCHEMA.JOBS_BY_PROJECT` for historical bytes-processed/slot-time trends on that query.

**Follow-ups:**
- What do you look for in the query execution graph?
- How do you identify a skewed join stage?

**Difficulty:** Hard

---

### Q14: What's the difference between `INFORMATION_SCHEMA` and Cloud Logging/Cloud Monitoring, for observability on BigQuery usage?

**Answer:**
`INFORMATION_SCHEMA` views (`JOBS`, `TABLE_STORAGE`, `COLUMNS`, etc.) are **queryable SQL views inside BigQuery itself** — great for ad-hoc cost/usage analysis, finding expensive queries, or auditing schema. Cloud Logging/Monitoring capture BigQuery **audit logs and metrics** (job state changes, slot utilization over time, errors) for building dashboards/alerts outside of SQL, and for longer-term retention/export to a SIEM.

**Follow-ups:**
- Write a query to find the most expensive queries of the last 7 days.
- How would you attribute cost to teams using labels?

**Difficulty:** Medium

---

### Q15: How do scheduled queries differ from using Cloud Composer/Airflow to run BigQuery SQL on a schedule?

**Answer:**
**Scheduled queries** are built into BigQuery — simplest option for a single, self-contained SQL transformation that needs to run on a timer, with no dependency on other systems/tasks. **Composer/Airflow** (using `BigQueryInsertJobOperator` etc.) is the right choice once you need dependencies between multiple tasks, conditional branching, retries with custom logic, cross-system orchestration (e.g., "wait for a GCS file, then run this query, then trigger a Dataflow job"), or centralized monitoring/alerting across many workflows.

**Follow-ups:**
- When do scheduled queries become insufficient?
- How do you handle dependencies between scheduled queries?

**Difficulty:** Easy

---

### Q16: Explain `ARRAY`/`STRUCT` (nested/repeated fields) in BigQuery and why you'd model data this way instead of always normalizing into separate tables.

**Answer:**
BigQuery natively supports nested (`STRUCT`) and repeated (`ARRAY`) fields within a single row/column — e.g., an `orders` table where each row has an `items ARRAY<STRUCT<sku STRING, qty INT64>>` column, instead of a separate `order_items` table requiring a join. Because BigQuery is columnar and optimized for this, denormalizing this way often avoids expensive joins and matches how semi-structured source data (JSON from an API) naturally looks.
```sql
SELECT order_id, item.sku, item.qty
FROM sales.orders, UNNEST(items) AS item;
```

**Follow-ups:**
- How do you query an array with `UNNEST`?
- How does nesting reduce join cost?

**Difficulty:** Medium

---

### Q17: What are `EXTERNAL` tables and `BigLake` tables, and when would you use them over loading data natively?

**Answer:**
Both let you query data sitting in GCS without loading/copying it into BigQuery storage. Plain **external tables** are simplest, but don't get BigQuery's fine-grained row/column security or full performance optimizations. **BigLake tables** extend external tables with BigQuery-grade governance (policy tags, row-level security) and consistent access across engines (BigQuery, Spark), making them the better choice when the data needs to stay in the lake but still be securely, consistently governed. Use native tables when you want maximum query performance and don't need to avoid duplicating storage.

**Follow-ups:**
- What does BigLake add over plain external tables?
- Can external tables be partitioned?

**Difficulty:** Medium

---

### Q18: How do you handle schema evolution (e.g., a new column appearing in incoming data) in BigQuery?

**Answer:**
- Loads support `--autodetect` (schema inference) and `--schema_update_option=ALLOW_FIELD_ADDITION` to let new nullable columns be added automatically during a load job.
- For `MERGE`/`INSERT` pipelines, add the column explicitly via `ALTER TABLE ... ADD COLUMN` ahead of time, coordinated with the pipeline change.
- New columns should generally be added as `NULLABLE` (not `REQUIRED`) so historical rows remain valid without backfilling every existing row.

**Follow-ups:**
- Which schema changes are allowed without recreating the table?
- How does `ALLOW_FIELD_ADDITION` work on load jobs?

**Difficulty:** Medium

---

### Q19: Coding: write a query to find, for each customer, their most recent order.

**Answer:**
```sql
SELECT customer_id, order_id, order_date, amount
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rn
  FROM sales.orders
)
WHERE rn = 1;
```

**Follow-ups:**
- How would you return the top 3 most recent orders instead?
- How would you handle two orders with the same timestamp?

**Difficulty:** Easy

---

### Q20: What cost-control mechanisms would you put in place for a team of analysts writing ad-hoc queries?

**Answer:**
- Set a **`maximum_bytes_billed`** per query (fails the query instead of running an unexpectedly huge scan).
- Set **custom cost controls / quotas** at the project or user level (daily bytes-billed limits).
- Encourage partitioned/clustered tables and `require_partition_filter` so accidental full scans are structurally harder.
- Move heavy, predictable workloads to a **flat-rate/autoscaling reservation** so cost is capped and predictable rather than per-query variable.
- Regularly review `INFORMATION_SCHEMA.JOBS` for the most expensive recurring queries and optimize/materialize them.

**Follow-ups:**
- How do custom quotas per user or project work?
- How do you alert on cost spikes?

**Difficulty:** Medium
