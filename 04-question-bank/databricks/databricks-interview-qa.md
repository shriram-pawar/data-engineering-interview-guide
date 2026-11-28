# Databricks — Interview Question Bank

> Format: Question · Answer · Follow-ups · Difficulty

---

### Q1: How do you process JSON, CSV and Parquet files with Azure Databricks and PySpark?

**Answer:**
```python
schema = "order_id STRING, order_ts TIMESTAMP, amount DECIMAL(10,2), customer STRUCT<id: STRING, city: STRING>"

csv_df = (spark.read.option("header", True).option("mode", "PERMISSIVE")
               .option("badRecordsPath", "/Volumes/main/raw/_bad/csv")
               .schema("order_id STRING, order_ts TIMESTAMP, amount DECIMAL(10,2)")
               .csv("abfss://landing@mylake.dfs.core.windows.net/orders_csv/"))

json_df = (spark.read.option("multiLine", True).schema(schema)
                .json("abfss://landing@mylake.dfs.core.windows.net/orders_json/")
                .select("order_id", "order_ts", "amount", "customer.id", "customer.city"))

parquet_df = spark.read.parquet("abfss://landing@mylake.dfs.core.windows.net/orders_parquet/")  # schema stored in the files

csv_df.write.mode("append").saveAsTable("main.bronze.orders")
```

Differences that matter: **CSV** needs header, delimiter, quoting and explicit types; **JSON** is often nested (flatten structs, explode arrays; `multiLine` for pretty-printed files); **Parquet** is columnar, typed and fast, so prefer it (or Delta) after ingestion. For continuous arrival, use **Auto Loader** (`cloudFiles.format`) instead of plain reads.

**Follow-ups:**
- Why avoid `inferSchema` for production CSV reads?
- How do you capture malformed rows instead of failing the job?

**Difficulty:** Easy

---

### Q2: How do you handle data partitioning and small-file compaction in Azure Databricks?

**Answer:**
- **Partition carefully:** only on low-cardinality columns that queries filter on (usually a date), and only for large tables (about 1 TB or more, partitions of about 1 GB). Over-partitioning creates many small files and slows everything down.
- **Prefer liquid clustering** (`CLUSTER BY (customer_id, order_date)`) for new Delta tables: it adapts to query patterns without a rigid directory layout and replaces partitioning plus Z-order.
- **Compaction:** `OPTIMIZE` merges small files into about 1 GB files; enable **optimized writes** and **auto compaction** (`delta.autoOptimize.*`) or **predictive optimization**, so it happens automatically.
- **Control output files:** avoid writing thousands of tiny files from streaming micro-batches (bigger trigger intervals, `maxFilesPerTrigger`), and `repartition` sensibly before writes.
- **Clean up** with `VACUUM` after compaction.

**Follow-ups:**
- Why is partitioning by `customer_id` usually a bad idea?
- How does liquid clustering differ from Z-ordering?

**Difficulty:** Medium

---

### Q3: What is Azure Databricks, and what are its main building blocks?

**Answer:**
Azure Databricks is a first-party Azure service running the **Databricks Data Intelligence Platform**, built on **Apache Spark** (with PySpark, Spark SQL, Scala and R) and Delta Lake:
- **Workspace:** the environment holding notebooks, files, jobs, dashboards and Git folders.
- **Compute:** all-purpose clusters (interactive), job clusters, **serverless** compute, and **SQL warehouses** for BI.
- **Notebooks and Git folders** for collaborative development; **Databricks Asset Bundles** for deploying code and jobs.
- **Lakeflow** (Jobs/Workflows, Declarative Pipelines, Connect) for orchestration, pipelines and ingestion.
- **Unity Catalog** for governance; **Delta Lake** as the storage format; ML and AI tooling (MLflow, model serving).

It integrates with Entra ID, ADLS Gen2, Key Vault, ADF, Event Hubs and Power BI.

**Follow-ups:**
- What's the difference between a cluster and a SQL warehouse?
- Why use Git folders instead of editing notebooks directly in the workspace?

**Difficulty:** Easy

---

### Q4: What is the Delta Lake transaction log, and how does it provide ACID guarantees?

**Answer:**
The transaction log is the `_delta_log/` folder: an ordered series of **JSON commit files** (`000…0010.json`), each listing the actions of one transaction (add or remove data files, metadata or schema changes, protocol), plus periodic **Parquet checkpoints** that summarize the state for fast reads.

How it gives ACID:
- **Atomicity:** a commit is a single file write. Readers see either all the files of a transaction or none.
- **Consistency and isolation:** writers use **optimistic concurrency**. They read the latest version, write data files, then try to commit version N+1; if another writer committed first, Delta checks for conflicts and retries or fails.
- **Durability:** commits are stored in cloud storage.
- **Snapshot reads:** a reader replays the log up to a version, which also enables time travel.

Data files are never modified in place; updates write new files and mark old ones as removed (until `VACUUM`).

**Follow-ups:**
- What happens when two jobs try to commit at the same time?
- Why are checkpoint files needed?

**Difficulty:** Medium

---

### Q5: What is Databricks Lakeflow?

**Answer:**
Lakeflow is Databricks' unified **data engineering** product family:
- **Lakeflow Connect:** managed **ingestion connectors** for databases (e.g. SQL Server with CDC) and SaaS apps (Salesforce, Workday, ServiceNow…), landing data in Unity Catalog tables with little code.
- **Lakeflow Declarative Pipelines** (formerly Delta Live Tables): you declare tables and transformations (SQL or Python); the platform handles dependencies, incremental processing, **data quality expectations**, CDC (`AUTO CDC`) and infrastructure.
- **Lakeflow Jobs** (formerly Workflows): orchestration of notebooks, scripts, pipelines, SQL and dbt tasks with dependencies, triggers, retries and notifications.

Together they cover ingestion → transformation → orchestration inside the platform.

**Follow-ups:**
- What do expectations in Declarative Pipelines do?
- When would you still use ADF instead of Lakeflow Connect?

**Difficulty:** Medium

---

### Q6: What are Databricks Workflows (Lakeflow Jobs), and how do you use them?

**Answer:**
Lakeflow Jobs (formerly Databricks Workflows) is the built-in **orchestrator**:
- A **job** is a DAG of **tasks**: notebooks, Python scripts or wheels, SQL, dbt, Declarative Pipelines, JARs, or other jobs, with dependencies (`depends_on`, run-if conditions), branching (`If/else`), loops (`For each`), and **job parameters**.
- **Triggers:** schedules (cron), file arrival, table updates, continuous mode, or the API.
- **Compute:** job clusters per task or shared, or serverless.
- **Operations:** retries, timeouts, **repair runs** (rerun only failed tasks), notifications, run history, and system tables for monitoring.
- Defined as code with **Databricks Asset Bundles** for CI/CD.

Use it when the work is mostly inside Databricks; use ADF or Airflow when orchestrating many external systems.

**Follow-ups:**
- What is a repair run?
- How would you trigger a job when new files arrive?

**Difficulty:** Medium

---

### Q7: What is Databricks Photon, and when does it help?

**Answer:**
Photon is Databricks' **native vectorized query engine**, written in C++, that runs Spark SQL and DataFrame operations instead of the JVM-based engine, with no code changes:
- Processes data in **columnar batches** using SIMD CPU instructions.
- Big speedups for SQL-heavy workloads: scans, joins, aggregations, Delta `MERGE`, `UPDATE` and `DELETE`, and writes to Delta and Parquet.
- Operators it doesn't support fall back to the regular engine automatically.

It's enabled on SQL warehouses and serverless by default, and optional on clusters (a higher DBU rate, often lower total cost because jobs finish faster). It helps less with Python UDF-heavy or RDD-based code.

**Follow-ups:**
- Which workloads benefit least from Photon?
- How would you decide whether Photon is worth its higher DBU rate?

**Difficulty:** Easy
