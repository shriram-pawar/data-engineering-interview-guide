# Dataproc — Interview Question Bank

> Format: Question · Answer · Follow-ups · Difficulty

---

### Q1: What is Dataproc, and how does it compare to running self-managed Hadoop/Spark on Compute Engine?

**Answer:**
Dataproc is a managed service for running Hadoop, Spark, Hive, Flink, and Presto clusters on GCP. Google handles cluster provisioning, image management, and integration with other GCP services (GCS, BigQuery, IAM, Stackdriver), and clusters start in about 90 seconds. Compared to hand-rolling clusters on raw Compute Engine VMs, you skip the work of installing/configuring the whole Hadoop ecosystem, patching, and building your own autoscaling/monitoring — at the cost of some flexibility versus a fully custom setup.

**Follow-ups:**
- What do you lose by not managing the cluster yourself?
- How fast does a Dataproc cluster start?

**Difficulty:** Easy

---

### Q2: Dataproc vs Dataflow — when would you choose one over the other?

**Answer:**
- **Dataproc**: choose when you have existing Spark/Hadoop/Hive code and expertise, need the broader Hadoop ecosystem (HDFS, Hive metastore, Presto), or want fine-grained cluster control.
- **Dataflow**: choose for a unified batch+streaming programming model (Apache Beam) with fully serverless, no-cluster-management execution, especially for new pipelines with no existing Spark investment.
They can coexist — e.g., legacy Spark ETL on Dataproc feeding data that a new streaming pipeline on Dataflow later consumes.

**Follow-ups:**
- Which would you pick for an existing Spark codebase?
- Which would you pick for a streaming job with complex windowing?

**Difficulty:** Medium

---

### Q3: What's the difference between a standard long-running cluster, an ephemeral cluster, and Dataproc Serverless?

**Answer:**
- **Long-running cluster**: stays up continuously, used for interactive work or many jobs sharing infrastructure — you pay for it whether or not it's actively processing.
- **Ephemeral cluster**: created just before a job (or set of jobs) runs, then deleted afterward — pay only for actual usage, common pattern via **Workflow Templates**.
- **Dataproc Serverless (Batches)**: no cluster to create/manage at all — submit a Spark batch job and Google provisions/releases the resources automatically. Best for sporadic or bursty Spark workloads where cluster sizing/management isn't worth the overhead.

**Follow-ups:**
- What are the limitations of Dataproc Serverless?
- How does billing differ between them?

**Difficulty:** Medium

---

### Q4: How do you submit a Spark job to Dataproc, and what are the main ways to do it?

**Answer:**
```bash
gcloud dataproc jobs submit pyspark gs://my-bucket/jobs/etl.py \
  --cluster=my-cluster \
  --region=us-central1 \
  -- --input=gs://my-bucket/raw --output=gs://my-bucket/clean
```
Other options: the Dataproc console UI, the REST API/client libraries (for programmatic submission, e.g. from a custom orchestrator), or via **Airflow/Composer** using `DataprocSubmitJobOperator`. For scheduled recurring jobs paired with cluster lifecycle, use **Workflow Templates** instead of manually creating/submitting/deleting.

**Follow-ups:**
- How do you pass job arguments and Python dependencies?
- How would you submit from Airflow?

**Difficulty:** Easy

---

### Q5: Explain primary vs secondary workers, and why you'd use preemptible/spot secondary workers.

**Answer:**
- **Primary workers**: standard VMs that hold HDFS data (if used) and run tasks reliably.
- **Secondary workers**: additional compute-only workers (they don't store HDFS data) used to scale out processing capacity cheaply — commonly configured as **preemptible/spot VMs**, which cost significantly less but can be reclaimed by GCP at any time.
Because secondary/preemptible workers don't hold persistent data, losing one mid-job just means Spark/YARN retries the lost tasks elsewhere — a good fit for fault-tolerant, cost-sensitive batch processing, but risky for jobs that can't tolerate task retries well (e.g., very long-running single tasks).

**Follow-ups:**
- Why shouldn't preemptible workers hold HDFS data?
- What happens to a job when Spot workers are reclaimed?

**Difficulty:** Medium

---

### Q6: How does autoscaling work in Dataproc, and what should you watch out for?

**Answer:**
An **autoscaling policy** defines min/max worker counts (for both primary and secondary worker groups) and scale-up/down factors based on YARN pending memory. Attach the policy at cluster creation:
```bash
gcloud dataproc clusters create my-cluster \
  --autoscaling-policy=my-policy --region=us-central1
```
Watch out for: **graceful decommissioning timeout** (workers finishing in-flight tasks before removal — too short can kill running work), scaling **too aggressively** on bursty-but-short workloads (causing thrashing), and autoscaling **not** helping if the bottleneck is actually driver-side or a single long-running task rather than parallel task backlog.

**Follow-ups:**
- Why is graceful decommissioning important?
- Why doesn't autoscaling work well with HDFS-heavy jobs?

**Difficulty:** Medium

---

### Q7: What is a Workflow Template, and why use it for scheduled Spark jobs instead of a bare cluster + job submission script?

**Answer:**
A Workflow Template bundles cluster creation (or reuse of an existing cluster), one or more job submissions (with dependency ordering between them), and cluster teardown into a single, atomic, reusable definition — so "create cluster → run job A → run job B → delete cluster" is one operation instead of several separately-orchestrated steps you'd otherwise have to sequence and error-handle yourself (e.g., making sure the cluster gets deleted even if the job fails).
```bash
gcloud dataproc workflow-templates instantiate my-template --region=us-central1
```

**Follow-ups:**
- What's a managed versus a cluster-selector workflow template?
- How do you parameterize a workflow template?

**Difficulty:** Medium

---

### Q8: How would you connect a Dataproc Spark job to BigQuery, both for reading and writing?

**Answer:**
```python
# Read
df = spark.read.format("bigquery").option("table", "project.dataset.table").load()

# Write
df.write.format("bigquery") \
  .option("table", "project.dataset.output_table") \
  .option("temporaryGcsBucket", "my-temp-bucket") \
  .mode("overwrite").save()
```
Uses the **Spark-BigQuery connector**, pre-installed on Dataproc images (or addable via `--jars`/`spark.jars.packages`). Under the hood, writes typically stage data in GCS temporarily before loading into BigQuery.

**Follow-ups:**
- How does the Spark BigQuery connector read data (Storage Read API)?
- What's the difference between direct and indirect write?

**Difficulty:** Medium

---

### Q9: What's the role of the Dataproc **Component Gateway**, and why prefer it over SSH for accessing web UIs (Jupyter, YARN, Spark History Server)?

**Answer:**
Component Gateway provides secure, authenticated, IAM-controlled HTTPS access to cluster web UIs (YARN ResourceManager, Spark History Server, Jupyter, etc.) without needing to SSH in, open firewall ports to the cluster's internal network, or manage per-node access. It's the recommended way to give data scientists/engineers UI access without widening network exposure.
```bash
gcloud dataproc clusters create my-cluster --enable-component-gateway ...
```

**Follow-ups:**
- Which UIs can you reach through it?
- How is access controlled?

**Difficulty:** Easy

---

### Q10: Where should data live for jobs running on Dataproc — HDFS on the cluster, or Cloud Storage — and why?

**Answer:**
**Cloud Storage**, in almost all cases, because it decouples data lifetime from cluster lifetime — you can delete an ephemeral cluster without losing data, multiple clusters/jobs can share the same data without duplicating it, and GCS has better durability/availability guarantees than a cluster's local HDFS. Dataproc's GCS connector makes `gs://` paths work as a drop-in replacement for `hdfs://` in Spark/Hadoop jobs. HDFS is still occasionally used for very hot, short-lived intermediate/shuffle data within a single job, but rarely as the primary/durable data store anymore.

**Follow-ups:**
- When would HDFS still make sense?
- How does storing data in GCS make ephemeral clusters possible?

**Difficulty:** Easy

---

### Q11: How do you troubleshoot a failed or slow Spark job on Dataproc?

**Answer:**
- Check job **driver output** (`gcloud dataproc jobs wait <job-id>` or console) for the actual stack trace/error.
- Use the **Spark History Server** (via Component Gateway) to inspect stage-level timing, shuffle read/write, and skewed tasks after the job finishes.
- Check **YARN ResourceManager UI** for container failures, memory pressure, or resource starvation (jobs stuck pending due to insufficient cluster capacity).
- Common failure causes: executor OOM (adjust `spark.executor.memory`/`spark.executor.memoryOverhead`), data skew, too many/few partitions, or a dependency/jar version mismatch on the cluster image.

**Follow-ups:**
- Where do you find driver and executor logs?
- Which Spark UI tabs help diagnose a slow stage?

**Difficulty:** Medium

---

### Q12: What are initialization actions, and give a use case.

**Answer:**
Initialization actions are scripts that run on every node during cluster creation, used to install additional software, configure the environment, or set up dependencies not included in the base Dataproc image (e.g., installing a Python package system-wide, configuring a custom logging agent, or pulling down a proprietary JAR).
```bash
gcloud dataproc clusters create my-cluster \
  --initialization-actions=gs://my-bucket/init-scripts/install-deps.sh \
  --region=us-central1
```

**Follow-ups:**
- What happens if an initialization action fails?
- When would you use a custom image instead?

**Difficulty:** Easy

---

### Q13: How would you migrate an existing on-prem Hive metastore/warehouse to Dataproc?

**Answer:**
Typically: point Dataproc's Hive to a managed external metastore (e.g., **Dataproc Metastore**, a fully-managed Hive Metastore service) so metadata persists independently of any single cluster's lifecycle, migrate underlying data into Cloud Storage (replacing HDFS paths with `gs://`), and update table location metadata accordingly. Using a shared, persistent metastore also lets multiple ephemeral clusters share the same table definitions instead of each cluster needing its own metastore database.

**Follow-ups:**
- What's Dataproc Metastore?
- How would you validate data after migration?

**Difficulty:** Hard

---

### Q14: What's the difference between cluster-level and job-level Spark configuration overrides?

**Answer:**
Cluster-level properties (`--properties spark:spark.executor.memory=8g` at cluster creation) apply as defaults for every job on that cluster. Job-level properties (`--properties spark.executor.memory=16g` on `gcloud dataproc jobs submit`) override the default for that specific job run only — useful when most jobs share a cluster but one particular job needs more memory/different tuning.

**Follow-ups:**
- Which takes precedence?
- Give an example of a property you'd set per job.

**Difficulty:** Medium

---

### Q15: Coding/scenario: You have a nightly PySpark job reading 500GB of Parquet from GCS, joining against a 2GB dimension table, then writing partitioned output back to GCS. How would you size and configure the cluster/job for good performance and cost?

**Answer:**
- Use an **ephemeral cluster via Workflow Template**, sized for the 500GB scan (e.g., start with primary workers sized for reasonable parallelism, add preemptible secondary workers for cheap scale-out on the shuffle-heavy stages).
- **Broadcast** the small 2GB dimension table explicitly (`broadcast(dim_df)`) to avoid a shuffle join against the large fact table.
- Repartition before writing (`coalesce`/`repartition`) to avoid the small-files problem in the output.
- Enable **Dataproc autoscaling** with a reasonable secondary-worker max, so the cluster scales for the shuffle-heavy join stage but doesn't sit oversized for the whole job.
- Confirm with the **Spark History Server** after a run whether time is dominated by the join/shuffle or the scan, and tune accordingly (increase executor memory for a skewed join, or partition pruning on the read for the scan).

**Follow-ups:**
- How would you choose between a broadcast join and a sort-merge join here?
- How would you size the cluster and control the number of output files?

**Difficulty:** Hard
