# System Design & Production Support (for Data Engineers) — Interview Question Bank

> Format: Question · Answer · Follow-ups · Difficulty

---

### Q1: Walk through how you'd design a pipeline to ingest, process, and serve daily sales data for a company with ~50M rows/day.

**Answer:**
A structured answer usually covers: **(1) Ingestion** — where source data lands (GCS via CDC/Datastream, or file drops) and how frequently. **(2) Processing** — batch (Dataflow/Dataproc/BigQuery SQL) transforming raw → clean → aggregated layers, partitioned by date. **(3) Storage** — raw layer in GCS (cheap, replayable), curated layer in BigQuery (partitioned/clustered for query performance). **(4) Orchestration** — Composer/Airflow DAG coordinating the steps with retries and dependency management. **(5) Serving** — BI tools/dashboards querying BigQuery directly, or a materialized/pre-aggregated table for consistently fast dashboard loads. **(6) Observability** — data quality checks, SLA monitoring, alerting on failures. Interviewers are listening for whether you think in **layers** (raw/staging/curated), consider **idempotency** and **failure handling**, and can justify tradeoffs (not just name-drop tools).

**Follow-ups:**
- How would the design change at 5 billion rows a day?
- How do you handle late-arriving sales data?

**Difficulty:** Medium

---

### Q2: How would you design a pipeline that needs to support both real-time dashboards and historical batch reporting from the same source data?

**Answer:**
A common pattern is **Lambda-ish architecture** (though modern tools blur the line): a streaming path (Pub/Sub → Dataflow → BigQuery streaming insert) feeds real-time dashboards with slightly relaxed consistency/completeness guarantees, while a separate batch path reprocesses the same raw data (landed in GCS) on a schedule to produce authoritative, fully-reconciled historical tables. Alternatively, many modern warehouses (BigQuery) let you unify this: stream raw events in continuously, and run scheduled batch queries on top of the same table for reporting — avoiding maintaining two separate processing codepaths where possible (a "kappa"-style simplification).

**Follow-ups:**
- How do you reconcile streaming and batch numbers?
- What are the trade-offs of Lambda versus Kappa architecture?

**Difficulty:** Hard

---

### Q3: A daily batch pipeline that normally takes 20 minutes suddenly takes 3 hours. How do you approach diagnosing it?

**Answer:**
1. **Check the obvious first**: did input data volume spike unexpectedly? A skewed key or duplicated upstream data can silently balloon row counts.
2. **Look at the execution plan/Spark UI/Dataflow monitoring**: find which specific stage is slow — don't guess, look at actual stage-level timing and shuffle/spill metrics.
3. **Check for data skew**: one or a few keys dominating a partition, causing straggler tasks.
4. **Check for resource contention**: was the cluster/warehouse under unusually high concurrent load from other jobs at the same time?
5. **Check for a recent code/schema change**: did someone add an expensive join, remove a filter that used to prune data, or was a table's partitioning/clustering altered?
6. **Check infra-level issues**: degraded network, a scaled-down cluster, a stuck/zombie task holding resources.
Systematic elimination beats guessing — start from monitoring data, not assumptions.

**Follow-ups:**
- What do you check first?
- How do you tell whether data volume or the code changed?

**Difficulty:** Medium

---

### Q4: What's your general framework for doing root cause analysis (RCA) after a production data incident?

**Answer:**
1. **Contain first**: stop the bleeding (pause the pipeline, alert downstream consumers if bad data shipped) before fully understanding the cause.
2. **Establish a timeline**: when did the issue start, what changed right before that (deploys, upstream schema changes, data volume anomalies)?
3. **Reproduce/isolate**: narrow down to the specific stage/record pattern causing the issue, ideally with a minimal reproducible example.
4. **Identify root cause vs symptom**: e.g., "the job crashed" is a symptom; "an upstream schema change introduced a null in a required field with no validation catching it" is closer to root cause.
5. **Fix and verify**: fix the immediate issue, backfill/correct affected data if needed (see the ETL backfill question), and verify against expected results.
6. **Prevent recurrence**: add a monitoring check, data quality assertion, or process change (e.g., "upstream teams must notify us of schema changes") so the same class of issue doesn't silently recur.
7. **Document/share**: a blameless postmortem so the team learns from it.

**Follow-ups:**
- What goes into a blameless post-mortem?
- How do you prevent the same incident from happening again?

**Difficulty:** Medium

---

### Q5: How would you monitor a production data pipeline, and what would you alert on vs just log?

**Answer:**
**Alert on** (needs a human to act, ideally quickly): pipeline/task failures, SLA misses (data not ready by the time downstream consumers expect it), anomalous data volume (sudden drop/spike suggesting an upstream break), and data quality check failures on critical fields.
**Log (but don't page someone for)**: routine execution details, row counts per run (useful for trend analysis, not urgent), warnings that are expected/self-healing (e.g., a single record routed to a dead-letter queue, not the whole batch failing).
Good monitoring also distinguishes **symptom alerts** ("pipeline X failed") from **business-impact alerts** ("today's revenue dashboard has no data") — the latter is what actually matters to stakeholders and is worth a distinct, higher-urgency alert.

**Follow-ups:**
- Which signals are worth paging someone at night?
- How do you set alert thresholds?

**Difficulty:** Medium

---

### Q6: What does "SLA" mean for a data pipeline, and how would you design around one (e.g., "sales data must be available in BigQuery by 6 AM daily")?

**Answer:**
An SLA here is a commitment about **when data will be ready**, not just that a job eventually finishes. Designing around it means: understanding the full critical path (source data availability → extraction → transformation → load) and working backward from the deadline to know when each stage must start/finish; building in buffer for retries (a pipeline that *just barely* makes the SLA on a good day has no room for a hiccup); monitoring/alerting on **SLA misses specifically** (not just failures) so you know *before* a stakeholder complains that data is late; and having a clear escalation path if a critical upstream dependency is delayed.

**Follow-ups:**
- How do you detect an SLA breach before it happens?
- What do you communicate to stakeholders when you're going to miss the SLA?

**Difficulty:** Medium

---

### Q7: How would you design a pipeline to gracefully handle a downstream system (e.g., an API or database) being temporarily unavailable?

**Answer:**
- **Retries with exponential backoff** for transient failures, rather than failing immediately on the first error or hammering a struggling system with immediate retries.
- **Circuit breaker pattern**: after repeated failures, stop hammering the downstream system for a cooldown period rather than retrying indefinitely.
- **Dead-letter/buffering**: if the downstream system is down for an extended period, buffer/queue the data (e.g., in Pub/Sub, or a staging table) rather than dropping it, so it can be replayed once the system recovers.
- **Idempotent writes** so that replaying buffered/retried data after a partial failure doesn't create duplicates.

**Follow-ups:**
- How do you implement exponential backoff with jitter?
- What's a circuit breaker?

**Difficulty:** Medium

---

### Q8: What's the difference between horizontal partitioning (sharding) and vertical partitioning in system design, and how does each apply to data pipelines?

**Answer:**
- **Horizontal partitioning (sharding)**: splitting rows across multiple physical locations/nodes by some key (e.g., customer_id ranges across DB shards, or date partitions in a warehouse) — each shard holds a subset of *rows*, full schema.
- **Vertical partitioning**: splitting columns across separate storage, e.g., splitting a very wide table into a "core, frequently-queried columns" table and a "rarely-used, bulky columns" table — each partition holds a subset of *columns* for all rows.
Data pipelines mostly deal with horizontal partitioning (date-based table partitions), but vertical partitioning shows up conceptually in columnar storage itself (Parquet/BigQuery only reading needed columns is a form of this).

**Follow-ups:**
- How do you choose a shard key?
- What are hot shards?

**Difficulty:** Medium

---

### Q9: How would you approach capacity planning for a pipeline that needs to handle 10x current data volume within a year?

**Answer:**
Favor architecture choices that scale **horizontally without redesign** — e.g., partitioned/distributed storage (GCS, BigQuery) and elastic compute (Dataflow autoscaling, Dataproc autoscaling/serverless) over anything with a hard vertical ceiling. Load-test with realistic (or synthetically scaled) data volume ahead of time rather than discovering bottlenecks in production. Identify early which stage is most likely to become the bottleneck at scale (often shuffle-heavy joins/aggregations, or a downstream system like a database not designed for the new write volume) and address that specifically, rather than assuming uniform scaling everywhere.

**Follow-ups:**
- Which components would hit their limits first?
- How do you load-test a data pipeline?

**Difficulty:** Hard

---

### Q10: What are common causes of out-of-memory (OOM) errors in a Spark job, and how do you fix them?

**Answer:**
- **Data skew**: one partition/task holds far more data than others, exceeding executor memory even though the average partition is fine — fix with salting, broadcast joins, or AQE skew handling.
- **Collecting too much data to the driver** (`.collect()` on a huge DataFrame) — avoid pulling large results back to a single machine; write to storage instead, or use `.take(n)`/sampling if you just need a preview.
- **Broadcasting a table that's actually too large** — check `autoBroadcastJoinThreshold` isn't misconfigured or being forced inappropriately.
- **Too few partitions** for the data volume, so each partition/task is oversized — increase `spark.sql.shuffle.partitions` or repartition explicitly.
- **Caching too much** without unpersisting — accumulates memory pressure over a long-running job; unpersist DataFrames once no longer needed.

**Follow-ups:**
- How do you tell whether the driver or an executor ran out of memory?
- How does `spark.memory.fraction` affect this?

**Difficulty:** Hard

---

### Q11: How would you design a schema/pipeline to support "reprocessing" — recomputing historical results after a bug fix — without downtime or double-counting?

**Answer:**
Write outputs to **partitioned** storage (by date, or another natural boundary), and make each partition write an **atomic overwrite** rather than an append — so reprocessing a given day just replaces that partition's data cleanly, with no risk of duplicated rows from old + new runs coexisting. Keep raw/source data retained (not just the transformed output) so reprocessing is actually possible without re-extracting from a source system that might not have historical data available anymore. Communicate to downstream consumers when historical values have changed, since dashboards/reports referencing that period will shift.

**Follow-ups:**
- How would you use versioned tables or a blue-green swap?
- How do you avoid double-counting during reprocessing?

**Difficulty:** Hard

---

### Q12: A stakeholder reports "the dashboard numbers don't match what I expect." How do you debug this as a data engineer?

**Answer:**
1. **Clarify precisely** what's mismatched — which metric, which time period, expected vs actual value — vague reports waste time.
2. **Trace the metric backward**: dashboard → underlying BigQuery table/view → transformation logic → raw source data, checking at each layer whether numbers look right.
3. **Check for known culprits**: duplicate rows (missing dedup), a filter excluding more than intended, a join fan-out (one-to-many join inflating counts), timezone mismatches in date filtering, or a recent code/schema change around when the discrepancy started.
4. **Compare against source-of-truth** if one exists (e.g., does the operational database itself show the expected number for that period?).
5. Once found, fix root cause, backfill affected data if needed, and consider whether a data quality check could have caught this automatically going forward.

**Follow-ups:**
- How do you trace a metric back to its source?
- How do you confirm the metric definition with the stakeholder?

**Difficulty:** Medium

---

### Q13: What's the difference between "scaling reactively" (autoscaling) and "scaling proactively" (pre-provisioning), and when would you choose each for a pipeline?

**Answer:**
**Reactive/autoscaling** (Dataflow, Dataproc autoscaling): resources scale up/down based on real-time load — efficient (pay only for what's used) but has some lag responding to sudden spikes, and a burst can briefly overwhelm the system before scaling catches up. **Proactive/pre-provisioning**: sizing for known/predictable peak load ahead of time (e.g., a Dataproc cluster sized for a known nightly batch volume) — more predictable performance, but wastes resources during non-peak periods. Choose autoscaling for variable/unpredictable load where efficiency matters; proactive provisioning for latency-sensitive, predictable, time-boxed workloads where you can't tolerate scale-up lag.

**Follow-ups:**
- How do you handle predictable peaks such as month-end?
- What does over-provisioning cost?

**Difficulty:** Medium

---

### Q14: How would you design access control for a data platform serving multiple teams with different sensitivity requirements (e.g., finance data vs general analytics)?

**Answer:**
Layer it: **project/dataset-level IAM** for broad separation (finance data in its own dataset/project with restricted membership), **row-level security** for data that must be filtered by team/region within a shared table, **column-level security (policy tags)** for specific sensitive fields (PII, salary) that only specific roles should see even within an otherwise-shared table, and **authorized views** to expose a safe, filtered subset of sensitive data to a broader audience without granting direct table access. Pair with **audit logging** so access to sensitive data is traceable, and follow least-privilege by default rather than granting broad access and restricting later.

**Follow-ups:**
- How do you implement column masking for PII?
- How do you audit who accessed what?

**Difficulty:** Hard

---

### Q15: What questions would you ask before committing to a specific technology choice (e.g., "should we use Dataflow or Dataproc for this job")?

**Answer:**
- What's the actual **latency requirement** (batch is fine vs true streaming needed)?
- What's the team's **existing expertise** (Spark experience → Dataproc/Databricks might be faster to deliver than learning Beam)?
- Is there **existing code** that needs to be reused/migrated (existing Spark jobs favor Dataproc)?
- What's the expected **data volume and growth**, and does the option scale accordingly?
- What are the **operational costs** — both infrastructure cost and ongoing maintenance/ops burden?
- How well does it **integrate** with the rest of the existing stack (orchestration, monitoring, security model already in place)?
Good system design answers show you're weighing tradeoffs against real constraints, not picking a tool because it's trendy.

**Follow-ups:**
- How do you weigh team skills against technical fit?
- How do you estimate total cost of ownership?

**Difficulty:** Medium
