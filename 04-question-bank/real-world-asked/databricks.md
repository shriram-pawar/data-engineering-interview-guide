# Real-World Asked: Databricks

Databricks, Delta Lake and Unity Catalog questions reported from real interviews.

See [README.md](README.md) for the layout and contributor rules. Fields are left blank when unknown.

## Deloitte

### Q1: Roughly 25 GB arrives every day. How big should the Databricks cluster be, and how do you decide?

**Answer:**
Start from the workload, not the data size alone:
- **25 GB a day is small for Spark.** A batch job can usually run on a **job cluster** with a few workers (e.g. 2–4 workers of 4–8 cores and 16–32 GB each), finishing in minutes.
- **Estimate partitions:** about 128–256 MB per partition gives roughly 100–200 tasks. With 16–32 total cores, that's a few waves of tasks.
- **Transformations matter more than input size:** wide joins with large dimensions, or many aggregations, need more memory per core (memory-optimized nodes). Simple parse-and-write needs general-purpose nodes.
- **Use autoscaling** (min 2, max 6–8) and **Photon** for SQL-heavy work; consider **serverless jobs** to avoid sizing altogether.
- **Validate with a test run:** check the Spark UI for spill, GC time and idle cores, then shrink or grow. Right-size on observed metrics, and set cost guardrails with cluster policies.

**Follow-ups:**
- How would the sizing change for a streaming job with the same daily volume?
- When would you choose memory-optimized over compute-optimized nodes?

**Difficulty:** Medium


**Role:** Azure Data Engineer

**Round:** Round 1 – Technical

**Asked:** 

---

### Q2: What does Delta Lake add on top of Parquet, and why choose Delta tables?

**Also asked at:** Wipro

**Answer:**
Delta Lake is an open table format: **Parquet data files plus a transaction log** (`_delta_log/`) that records every change as an atomic commit. That log adds:
- **ACID transactions:** readers never see half-written data; concurrent writers are handled with optimistic concurrency.
- **Updates, deletes and `MERGE`** on data lake tables (upserts, SCD2, GDPR deletes).
- **Schema enforcement and evolution:** bad writes are rejected; columns can be added deliberately (`mergeSchema`).
- **Time travel:** query or restore earlier versions.
- **Performance:** file statistics for data skipping, `OPTIMIZE`, Z-ordering or liquid clustering, and deletion vectors.
- **Unified batch and streaming:** a Delta table can be a streaming source and sink.

Plain Parquet folders have none of this. Partial writes, small files and "update a row" all have to be handled by hand. That's why Delta was introduced, and why the lakehouse (medallion) pattern is built on it.

**Follow-ups:**
- What's inside the `_delta_log` folder?
- How does Delta handle two jobs writing to the same table at once?

**Difficulty:** Easy


**Role:** Azure Data Engineer

**Round:** Round 2 – Technical + Managerial

**Asked:** 

---

### Q3: How do Delta Lake time travel and table history work?

**Answer:**
Every commit creates a new **table version** in the transaction log, so you can inspect and query the past:

```sql
DESCRIBE HISTORY sales.orders;                              -- version, timestamp, operation, user, metrics

SELECT * FROM sales.orders VERSION AS OF 42;
SELECT * FROM sales.orders TIMESTAMP AS OF '2024-06-01 08:00';

RESTORE TABLE sales.orders TO VERSION AS OF 42;            -- roll back a bad load
```

Uses: auditing, reproducing a report as of a date, debugging a bad write, and rolling back. Limits: history depends on retention. `VACUUM` deletes data files older than the retention period (7 days by default), after which those versions can't be read, and log retention (`delta.logRetentionDuration`, 30 days by default) controls how far back history goes.

**Follow-ups:**
- Why can time travel fail after a `VACUUM`?
- How would you compare row counts between two versions?

**Difficulty:** Easy


**Role:** Azure Data Engineer

**Round:** Round 2 – Technical + Managerial

**Asked:** 

---

### Q4: How do you implement CDC with Delta Lake and Databricks?

**Answer:**
Two directions:
1. **Applying incoming changes to a Delta table** (from Debezium, ADF, or files with an operation flag):
   - Land the changes in a bronze table, deduplicate to the latest change per key (ordered by sequence or timestamp), then `MERGE` into silver:
   ```sql
   MERGE INTO silver.customers t
   USING latest_changes s ON t.customer_id = s.customer_id
   WHEN MATCHED AND s.op = 'D' THEN DELETE
   WHEN MATCHED THEN UPDATE SET *
   WHEN NOT MATCHED AND s.op != 'D' THEN INSERT *;
   ```
   - Or use **Lakeflow Declarative Pipelines (DLT) `AUTO CDC` / `APPLY CHANGES INTO`**, which handles ordering, deletes and SCD Type 1 or 2 for you.
2. **Reading changes from a Delta table** downstream: enable **Change Data Feed** (`delta.enableChangeDataFeed = true`) and read `table_changes('silver.customers', <version>)`, or stream with `readChangeFeed`, to get inserts, updates (pre- and post-image) and deletes since a version.

**Follow-ups:**
- How do you handle out-of-order change events?
- What does Change Data Feed store, and what does it cost?

**Difficulty:** Medium


**Role:** Azure Data Engineer

**Round:** Round 2 – Technical + Managerial

**Asked:** 

---

### Q5: How do you read data from ADLS Gen2 into Databricks with PySpark?

**Answer:**
Preferred: **Unity Catalog external locations** (a storage credential backed by a managed identity), then read with `abfss://` paths or as tables. No keys appear in code:

```python
df = (spark.read.format("parquet")
           .load("abfss://raw@mydatalake.dfs.core.windows.net/sales/2024/"))

# or, once registered: spark.read.table("main.raw.sales")
```

Older options (avoid for new work): a service principal with OAuth configs set through `spark.conf.set(...)`, with the secret taken from a **Databricks secret scope backed by Key Vault** (`dbutils.secrets.get(...)`), or mounting with `dbutils.fs.mount`. Never hard-code account keys. Use **Auto Loader** (`cloudFiles`) for incremental file ingestion.

**Follow-ups:**
- Why are mounts discouraged with Unity Catalog?
- How would you ingest only new files every hour?

**Difficulty:** Easy


**Role:** Azure Data Engineer

**Round:** Round 2 – Technical + Managerial

**Asked:** 

---

### Q6: What are the benefits of Databricks Auto Loader?

**Answer:**
Auto Loader (`format("cloudFiles")`) incrementally ingests new files from cloud storage:
- **Processes only new files**, tracking what's been loaded in a checkpoint (RocksDB), so there's no manual file bookkeeping and it's exactly-once into Delta.
- **Scales to millions of files** with directory listing or **file notification** mode (Event Grid / SQS / Pub/Sub).
- **Schema inference and evolution:** stores the schema, adds new columns (`addNewColumns`), and captures unexpected data in `_rescued_data` instead of failing.
- **Batch or streaming:** run continuously, or as a scheduled job with `trigger(availableNow=True)`.

```python
(spark.readStream.format("cloudFiles")
      .option("cloudFiles.format", "json")
      .option("cloudFiles.schemaLocation", "/Volumes/main/raw/_schemas/orders")
      .load("abfss://landing@mylake.dfs.core.windows.net/orders/")
      .writeStream.option("checkpointLocation", "/Volumes/main/raw/_chk/orders")
      .trigger(availableNow=True)
      .toTable("main.bronze.orders"))
```

**Follow-ups:**
- When would you switch from directory listing to file notification mode?
- What lands in `_rescued_data`?

**Difficulty:** Easy


**Role:** Data Engineer

**Round:** L1

**Asked:** 

---

### Q7: The source had 30 records, but only 20 reached the target through Auto Loader. How would you debug it?

**Answer:**
Trace the 10 missing records stage by stage:
1. **Were the files picked up?** Check the stream's progress metrics (`numFilesOutstanding`, input rows) and the checkpoint. A file **re-uploaded with the same name** is skipped by default (`cloudFiles.allowOverwrites` is false), and files that arrive in a different path or with the wrong extension are ignored.
2. **Were records parsed?** Look in **`_rescued_data`** or the bad-records path for rows that didn't match the schema (type mismatches, malformed JSON). Check `cloudFiles.schemaHints` and evolution settings.
3. **Were they filtered or merged away?** Downstream filters, `dropDuplicates`, or a `MERGE` with no `WHEN NOT MATCHED` clause, or one matching on a non-unique key, can collapse rows.
4. **Timing:** with `availableNow` or a trigger interval, the remaining files may simply not be processed yet.
5. **Reconcile** counts per file (`_metadata.file_path`) between source and target to pin down exactly which file or records are missing.

**Follow-ups:**
- How do you get the source file name for each ingested row?
- How would you reprocess one specific file?

**Difficulty:** Hard


**Role:** Data Engineer

**Round:** L1

**Asked:** 

---

### Q8: What do OPTIMIZE and VACUUM do in Delta Lake?

**Answer:**
- **`OPTIMIZE`** compacts many small files into fewer large ones (about 1 GB), which speeds up reads. With `ZORDER BY (col)` it also co-locates related values, so data skipping works better on those columns. **Liquid clustering** (`CLUSTER BY`) is the newer replacement for partitioning plus Z-order.
- **`VACUUM`** permanently deletes data files that are **no longer referenced** by the current table version and are older than the retention period (7 days by default). That reclaims storage, but limits time travel to the retention window.

```sql
OPTIMIZE sales.orders ZORDER BY (customer_id);
VACUUM sales.orders RETAIN 168 HOURS;
```

Run both regularly (or enable predictive optimization). Never set retention below the longest-running reader or stream, or those readers can fail.

**Follow-ups:**
- Why is setting `VACUUM ... RETAIN 0 HOURS` dangerous?
- When does Z-ordering stop helping?

**Difficulty:** Easy


**Role:** Data Engineer

**Round:** L1

**Asked:** 

---

### Q9: How do you connect Databricks to Amazon S3, step by step?

**Answer:**
With **Unity Catalog** (recommended):
1. In AWS, create an **IAM role** with S3 read and write permissions on the bucket and a trust policy for the Databricks Unity Catalog master role (with an external ID).
2. In Databricks, create a **storage credential** that references the role ARN.
3. Create an **external location** for `s3://my-bucket/path/` using that credential.
4. **Grant** `READ FILES` / `WRITE FILES` (or `CREATE EXTERNAL TABLE`) on the external location to the right groups.
5. Read and write with `s3://` paths or external tables:
   ```python
   df = spark.read.parquet("s3://my-bucket/raw/orders/")
   ```

Legacy alternatives are instance profiles on clusters, or access keys from a **secret scope**. Never put keys in notebooks.

**Follow-ups:**
- What does an external location give you over a plain instance profile?
- How would you restrict one team to a single prefix in the bucket?

**Difficulty:** Medium


**Role:** Data Engineer

**Round:** L1

**Asked:** 

## HCLTech

### Q10: What's the logic behind each layer of the medallion architecture, and why does the layering matter?

**Also asked at:** Persistent Systems

**Answer:**
- **Bronze (raw):** data as it arrived (files, CDC events), append-only, with ingestion metadata (source file, load time). Purpose: **replayability and audit**.
- **Silver (cleaned and conformed):** deduplicated, typed, validated data, joined to reference data, with CDC applied. Purpose: a **reliable, reusable** enterprise view.
- **Gold (curated):** business-level aggregates, star schemas and feature tables for BI and ML. Purpose: **fast, consumer-ready** data with clear metric definitions.

Why it matters: each layer has one job, so problems are isolated (you can rebuild silver from bronze after a bug), data quality improves step by step, and different consumers use the right level. In Azure it's typically ADLS Gen2 + Delta, with Databricks or ADF moving data between layers and Unity Catalog for access.

**Follow-ups:**
- What data quality checks belong between bronze and silver?
- When would you skip a layer?

**Difficulty:** Easy


**Role:** Lead Data Engineer

**Round:** Round 2 – Technical

**Asked:** 

---

### Q11: Databricks job clusters vs all-purpose clusters: which do you use when?

**Answer:**
| | All-purpose cluster | Job cluster |
|---|---|---|
| Created by | A user (UI or API), shared | The job run, automatically |
| Lifetime | Runs until terminated (auto-termination) | Created for the run, terminated after |
| Use | Interactive notebooks, development, ad hoc analysis | Scheduled production workloads |
| Cost | Higher DBU rate, and idle time costs money | Lower DBU rate, no idle time |
| Isolation | Shared with other users and jobs | Isolated per run |

Production pipelines should use **job clusters** (or **serverless compute** for jobs). They're cheaper, isolated and reproducible, defined in the job or Databricks Asset Bundle configuration.

**Follow-ups:**
- Why shouldn't scheduled jobs run on all-purpose clusters?
- When would a cluster pool help job clusters?

**Difficulty:** Easy


**Role:** Lead Data Engineer

**Round:** Round 2 – Technical

**Asked:** 

---

### Q12: How do you handle late-arriving events and duplicates in a streaming pipeline?

**Answer:**
In Spark Structured Streaming (Databricks):
- **Late events:** use **event time** with a **watermark**, which tells Spark how late data may arrive (`withWatermark("event_ts", "30 minutes")`). Aggregations update windows until the watermark passes, then finalize them and drop state. Events later than that are dropped from the aggregation, so if they matter, also land raw events in bronze and reconcile with a periodic batch job.
- **Duplicates:** deduplicate on a unique event ID **within the watermark**, so state stays bounded:
  ```python
  deduped = (events.withWatermark("event_ts", "30 minutes")
                   .dropDuplicatesWithinWatermark(["event_id"]))      # Spark 3.5+; else dropDuplicates(["event_id", "event_ts"])
  ```
- **Sink idempotency:** write with `MERGE` in `foreachBatch` on the event ID, so retried micro-batches don't duplicate rows. Delta sinks with checkpoints give exactly-once for appends.

**Follow-ups:**
- What happens to state if you don't set a watermark?
- How do you choose the watermark delay?

**Difficulty:** Hard


**Role:** Lead Data Engineer

**Round:** Round 2 – Technical

**Asked:** 

## JPMorgan

### Q13: How do you upsert each day's transactions into a Delta table so the history stays consistent?

**Answer:**
Use a `MERGE` (upsert) keyed on the business key, after deduplicating the daily batch:

```python
from delta.tables import DeltaTable
from pyspark.sql import functions as F, Window

latest = (daily.withColumn("rn", F.row_number().over(
              Window.partitionBy("txn_id").orderBy(F.col("updated_at").desc())))
               .filter("rn = 1").drop("rn"))

(DeltaTable.forName(spark, "finance.transactions").alias("t")
   .merge(latest.alias("s"), "t.txn_id = s.txn_id")
   .whenMatchedUpdateAll(condition="s.updated_at > t.updated_at")
   .whenNotMatchedInsertAll()
   .execute())
```

- **Deduplicate the source first**, or `MERGE` fails when several source rows match one target row.
- The `updated_at` condition makes reruns and **out-of-order files** safe (idempotent).
- Add a **partition or date filter** in the merge condition (e.g. `t.txn_date >= current_date() - 7`) so Delta only rewrites the affected files.
- Enforce the schema, and validate counts before and after.

**Follow-ups:**
- Why does `MERGE` fail when the source has duplicate keys?
- How do you keep a `MERGE` from rewriting the whole table?

**Difficulty:** Medium


**Role:** Senior / Lead Data Engineer

**Round:** Technical Round 2

**Asked:** 

---

### Q14: Tell us about the cluster configuration and the design of the main tables in your last project.

**Answer:**
Answer with your real numbers, structured like this:
- **Compute:** job clusters (or serverless) for scheduled pipelines, plus a small all-purpose cluster for development. Node types, worker counts and autoscaling range, the Databricks Runtime version, and Photon on or off. Cluster policies to cap cost.
- **Why:** data volume per run, peak versus average load, SLA.
- **Main tables:** Delta tables in Unity Catalog (catalog.schema per layer). Partitioning only on low-cardinality date columns for big tables, or **liquid clustering** on frequent filter and join keys. `OPTIMIZE` / auto-compaction, a `VACUUM` schedule, and retention settings. Table properties such as Change Data Feed where downstream CDC was needed.
- **Result:** e.g. runtime, cost per run, or what you'd change.

Example: "A 4–8 worker autoscaling job cluster on Photon for the nightly load; fact tables liquid-clustered on `customer_id` and `txn_date`, with predictive optimization, which brought the run from 70 to 35 minutes."

**Follow-ups:**
- Why not partition a Delta table by `customer_id`?
- How did you control cluster cost?

**Difficulty:** Medium


**Role:** Senior / Lead Data Engineer

**Round:** Managerial

**Asked:** 

## Persistent Systems

### Q15: A new field starts appearing in incoming JSON files. How do you evolve the data lake schema?

**Also asked at:** JPMorgan

**Answer:**
Decide which changes are **allowed automatically** and which must stop the pipeline:
- **Additive changes** (a new optional column): let them through.
  - Auto Loader: `cloudFiles.schemaEvolutionMode = "addNewColumns"` (the stream restarts once with the new schema), and unexpected fields go to `_rescued_data`.
  - Batch Delta writes: `.option("mergeSchema", "true")`, or `spark.databricks.delta.schema.autoMerge.enabled` for `MERGE`.
- **Breaking changes** (type change, rename, drop): fail or quarantine, alert, and handle through a planned migration (new column, backfill, then switch consumers).
- **Keep bronze raw** (or keep `_rescued_data`) so nothing is lost, and enforce the expected schema in silver.
- **Communicate:** document the schema contract and notify downstream users when gold changes.

Example: a `discount_code` field starts appearing; bronze picks it up automatically, silver adds it as a nullable column, and gold reports aren't affected until someone chooses to use it.

**Follow-ups:**
- What's the risk of turning on auto-merge everywhere?
- How would you handle a column changing from integer to string?

**Difficulty:** Medium


**Role:** Data Engineer

**Round:** Round 2 – Technical

**Asked:** 

---

### Q16: What is SCD Type 2, and how would you build it with Spark and Delta Lake?

**Answer:**
SCD Type 2 keeps **full history**: when a tracked attribute changes, close the current row (`end_date`, `is_current = false`) and insert a new current row. (The SQL version, including the single-`MERGE` trick, is in [real-world-asked/sql.md](sql.md).)

In Spark with Delta Lake:

```python
from delta.tables import DeltaTable
from pyspark.sql import functions as F

dim = DeltaTable.forName(spark, "gold.dim_customer")
current = dim.toDF().filter("is_current")

changed = (updates.alias("s").join(current.alias("t"), "customer_id")
                  .filter("s.address <> t.address")
                  .select("s.*"))

# Rows to insert = changed rows (new versions) + brand-new customers; staged with a NULL merge key
staged = (changed.withColumn("merge_key", F.lit(None).cast("int"))
                 .unionByName(updates.withColumn("merge_key", F.col("customer_id"))))

(dim.alias("t").merge(staged.alias("s"), "t.customer_id = s.merge_key AND t.is_current")
    .whenMatchedUpdate(condition="t.address <> s.address",
                       set={"is_current": "false", "end_date": "current_date()"})
    .whenNotMatchedInsert(values={"customer_id": "s.customer_id", "address": "s.address",
                                  "start_date": "current_date()", "end_date": "null", "is_current": "true"})
    .execute())
```

Simpler options: **Lakeflow Declarative Pipelines `AUTO CDC ... STORED AS SCD TYPE 2`**, which manages history columns and out-of-order changes automatically.

**Follow-ups:**
- How do you handle two changes for the same customer in one batch?
- Why do SCD2 dimensions need a surrogate key?

**Difficulty:** Hard


**Role:** Data Engineer

**Round:** Round 2 – Technical

**Asked:** 

## Wipro

### Q17: What is Unity Catalog in Databricks, and how have you used it for governance and access control?

**Answer:**
Unity Catalog is Databricks' **central governance layer** across workspaces:
- **Three-level namespace:** `catalog.schema.table`, plus views, volumes (files), functions and models, all managed in a **metastore** per region.
- **Access control** with SQL `GRANT`s to groups (from Entra ID / SCIM): `GRANT SELECT ON SCHEMA main.sales TO \`analysts\``.
- **Fine-grained security:** row filters and column masks.
- **Storage governance:** storage credentials and external locations replace mounts and keys.
- **Lineage** (table and column level), **audit logs** and **system tables** for usage and cost.
- Sharing through **Delta Sharing**.

Example of use: catalogs per environment (`dev`, `prod`), schemas per layer (bronze, silver, gold), analysts granted only on gold, PII columns masked for everyone except one group, and lineage used to find every dashboard affected by a source change.

**Follow-ups:**
- How do row filters and column masks work?
- How would you migrate from a Hive metastore to Unity Catalog?

**Difficulty:** Medium


**Role:** Azure Data Engineer (5+ years)

**Round:** Round 1 – Technical

**Asked:** 
