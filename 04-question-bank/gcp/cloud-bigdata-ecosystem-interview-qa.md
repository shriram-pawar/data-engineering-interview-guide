# Cloud & Big Data Ecosystem — Interview Question Bank

*(GCP-specific services — BigQuery, Dataflow, Dataproc, Cloud Storage, Cloud Functions, Airflow/Composer, Datastream, BigLake — have their own Q&A files in this folder and use-case notes in [`02-cloud-platforms/gcp/`](../../02-cloud-platforms/gcp/). This file covers the broader/cross-cutting ecosystem: Azure equivalents, Databricks, Kafka, CI/CD, Git, Docker, and Infrastructure-as-Code.)*

> Format: Question · Answer · Follow-ups · Difficulty

---

### Q1: Map the core GCP data services to their Azure equivalents.

**Answer:**
| Purpose | GCP | Azure |
|---|---|---|
| Data warehouse | BigQuery | Synapse Analytics (dedicated SQL pool) |
| Managed Spark/Hadoop | Dataproc | HDInsight / Azure Databricks |
| Serverless stream/batch processing | Dataflow | Azure Stream Analytics / Data Factory Mapping Data Flows |
| Object storage | Cloud Storage | Blob Storage / ADLS Gen2 |
| Orchestration | Cloud Composer (Airflow) | Azure Data Factory / Managed Airflow |
| Serverless functions | Cloud Functions | Azure Functions |
| CDC | Datastream | Azure Data Factory CDC / Debezium on Azure |
| Messaging | Pub/Sub | Event Hubs / Service Bus |
Interviewers usually care less about memorizing this table and more about whether you understand the underlying *concepts* transfer across clouds.

**Follow-ups:**
- What's the Azure equivalent of BigQuery?
- How does Azure Data Factory compare with Composer?

**Difficulty:** Easy

---

### Q2: What is Databricks, and how does it relate to (and differ from) open-source Apache Spark?

**Answer:**
Databricks is a managed platform built around Spark, adding: a collaborative notebook environment, an optimized Spark runtime (faster than vanilla OSS Spark via its proprietary **Photon** execution engine and I/O optimizations), managed cluster lifecycle, **Delta Lake** (its lakehouse storage format, now open-sourced), Unity Catalog for governance, and job scheduling/orchestration built in. You still write standard PySpark/Spark SQL code — Databricks is the managed runtime and tooling layer around it, similar in spirit to how Dataproc is a managed layer around OSS Spark on GCP.

**Follow-ups:**
- What is the Photon engine?
- What does Unity Catalog provide?

**Difficulty:** Easy

---

### Q3: What is Delta Lake, and what does it add on top of plain Parquet on Databricks?

**Answer:**
A transaction-log layer (the `_delta_log` directory alongside Parquet files) providing ACID transactions, time travel (`VERSION AS OF`), schema enforcement/evolution, and efficient `MERGE`/upsert/delete operations directly on lake data — the same problem BigLake/Iceberg solve, but Delta Lake is Databricks' native format.
```python
# Time travel example
df = spark.read.format("delta").option("versionAsOf", 5).load("/mnt/lake/orders")

# Upsert
from delta.tables import DeltaTable
target = DeltaTable.forPath(spark, "/mnt/lake/customers")
target.alias("t").merge(
    updates_df.alias("s"), "t.customer_id = s.customer_id"
).whenMatchedUpdateAll().whenNotMatchedInsertAll().execute()
```

**Follow-ups:**
- How does the Delta transaction log work?
- What do OPTIMIZE and Z-ORDER do?

**Difficulty:** Medium

---

### Q4: What is Apache Kafka, and what problem does it solve that a database table can't?

**Answer:**
Kafka is a distributed, append-only, partitioned **log** for high-throughput event streaming — producers publish events to **topics**, consumers read them (independently, at their own pace, and can replay from any offset). Unlike a database table (a snapshot of current state), Kafka preserves the full **sequence of events** as they happened, decouples producers from consumers (many consumers can read the same stream independently), and is built for very high sustained throughput with low latency — the backbone for real-time pipelines feeding systems like Dataflow/Spark Structured Streaming.

**Follow-ups:**
- How does Kafka retain messages?
- How does Kafka compare with Pub/Sub?

**Difficulty:** Medium

---

### Q5: Explain Kafka's core concepts: topic, partition, offset, consumer group.

**Answer:**
- **Topic**: a named stream/category of events (e.g., `orders`).
- **Partition**: a topic is split into partitions for parallelism — each partition is an ordered, immutable log; ordering is only guaranteed *within* a partition, not across the whole topic.
- **Offset**: a message's position within its partition — consumers track offsets to know what they've already processed.
- **Consumer group**: a set of consumers that split partitions among themselves, so each partition is processed by exactly one consumer *within* that group (enabling parallel consumption), while multiple different consumer groups can each independently read the entire topic.

**Follow-ups:**
- What happens during a consumer group rebalance?
- How is ordering guaranteed?

**Difficulty:** Medium

---

### Q6: How do you decide how many partitions a Kafka topic should have?

**Answer:**
Partition count sets the ceiling on consumer parallelism (you can't have more active consumers *in one group* usefully reading a topic than it has partitions). Consider: expected throughput and how many consumers need to process in parallel, keeping per-partition throughput within a reasonable range, and that increasing partitions later is possible but can disrupt existing key-to-partition ordering guarantees (messages with the same key may land on a different partition after repartitioning) — so it's better to slightly over-provision up front than to under-provision and need a disruptive change later.

**Follow-ups:**
- Can you reduce the number of partitions later?
- How does the partition count relate to consumer parallelism?

**Difficulty:** Hard

---

### Q7: What does "exactly-once" vs "at-least-once" delivery mean in a Kafka-based pipeline?

**Answer:**
- **At-least-once**: a message will be delivered/processed at least once, but could be reprocessed after a failure/retry — the default and simplest guarantee; requires idempotent consumers to avoid duplicate side effects.
- **Exactly-once**: achieved via Kafka's transactional producer/consumer APIs (idempotent producers + transactional writes), ensuring a message is processed and its effects committed exactly once even across failures — more complex to set up correctly, and the guarantee typically only holds end-to-end if the downstream sink also participates transactionally (e.g., writing offsets and output atomically).

**Follow-ups:**
- How do idempotent producers and transactions enable exactly-once?
- What's the cost of exactly-once?

**Difficulty:** Hard

---

### Q8: What is CI/CD, and how does it apply specifically to data pipelines (not just application code)?

**Answer:**
**Continuous Integration**: automatically testing/validating code changes (unit tests, SQL linting, schema validation) on every commit/PR. **Continuous Deployment**: automatically promoting validated changes to production. For data pipelines specifically: this means testing transformation logic against sample/synthetic data, validating DAG/pipeline syntax (e.g., Airflow DAGs importing cleanly, no cyclic dependencies) before deployment, and deploying artifacts (DAG files to a Composer GCS bucket, Dataflow Flex Template images, dbt models) through an automated pipeline rather than manual copy/paste to production.

**Follow-ups:**
- How do you test data pipelines in CI?
- How do you promote code from dev to prod?

**Difficulty:** Medium

---

### Q9: What's a typical CI/CD pipeline for deploying an Airflow DAG?

**Answer:**
1. Developer pushes a DAG change to a feature branch, opens a PR.
2. CI runs: DAG import/syntax check (`python -c "import dag_file"` or `airflow dags list-import-errors`), linting, unit tests for any custom operators/Python functions.
3. On merge to main, CD deploys: syncs the DAG file(s) to the Composer environment's GCS `dags/` bucket (or via `gcloud composer environments storage dags import`).
4. Optionally, a staging Composer environment validates the DAG runs correctly before promoting to production.

**Follow-ups:**
- How do you validate DAGs before deploying?
- How do you sync DAGs to the Composer bucket?

**Difficulty:** Medium

---

### Q10: What's the difference between `git merge` and `git rebase`, and when would you use each?

**Answer:**
`git merge` creates a new "merge commit" combining two branches' histories, preserving exactly how development actually happened (including all intermediate commits) — non-destructive, but can create a messier history. `git rebase` replays your branch's commits on top of the target branch, producing a linear history as if you'd started from the latest code — cleaner history, but rewrites commit hashes (never rebase commits that have already been pushed/shared, since it breaks history for anyone else who has them).

**Follow-ups:**
- Why shouldn't you rebase shared branches?
- What's a squash merge?

**Difficulty:** Easy

---

### Q11: What is Docker, and why is containerization useful for data engineering workloads?

**Answer:**
Docker packages an application plus its exact runtime dependencies (libraries, system packages, environment) into a portable, isolated **container** that runs identically regardless of the underlying host. For data engineering: ensures a pipeline's dependencies (specific Python/Spark versions, native libraries) are reproducible across dev/staging/prod, avoids "works on my machine" issues, and is the packaging mechanism for things like Dataflow Flex Templates, `KubernetesPodOperator` tasks in Airflow, and Cloud Run/Functions gen2 deployments.

**Follow-ups:**
- How do you keep Docker images small?
- How does Docker help with dependency conflicts?

**Difficulty:** Easy

---

### Q12: What's the difference between a Docker image and a Docker container?

**Answer:**
An **image** is the immutable, built package (layers of filesystem + metadata) — like a class definition or a snapshot. A **container** is a running (or stopped) *instance* of an image — like an object instantiated from that class — with its own writable layer and runtime state on top of the image's read-only layers.

**Follow-ups:**
- What's a Dockerfile layer?
- Can multiple containers run from one image?

**Difficulty:** Easy

---

### Q13: What is Infrastructure-as-Code (IaC), and what problem does it solve compared to manually clicking through a cloud console?

**Answer:**
IaC means defining cloud infrastructure (clusters, buckets, IAM roles, networking) as version-controlled configuration files (Terraform, CloudFormation) rather than manual console/CLI actions. Benefits: **reproducibility** (spin up identical environments for dev/staging/prod), **auditability** (changes go through code review and version history, not untracked manual clicks), **disaster recovery** (rebuild infrastructure from code if something is destroyed), and enables the same CI/CD discipline applied to code to also apply to infrastructure changes.

**Follow-ups:**
- What's Terraform state, and where should it live?
- What's configuration drift?

**Difficulty:** Easy

---

### Q14: Give a simple example of defining GCP infrastructure with Terraform (e.g., a BigQuery dataset and a GCS bucket).

**Answer:**
```hcl
resource "google_storage_bucket" "raw_data" {
  name     = "my-company-datalake-raw"
  location = "US-CENTRAL1"
  lifecycle_rule {
    condition { age = 90 }
    action    { type = "SetStorageClass", storage_class = "COLDLINE" }
  }
}

resource "google_bigquery_dataset" "sales" {
  dataset_id = "sales"
  location   = "US-CENTRAL1"
}

resource "google_bigquery_table" "orders" {
  dataset_id = google_bigquery_dataset.sales.dataset_id
  table_id   = "orders"
  time_partitioning {
    type  = "DAY"
    field = "order_date"
  }
  schema = file("schemas/orders.json")
}
```
```bash
terraform init
terraform plan   # preview changes
terraform apply  # create/update infrastructure
```

**Follow-ups:**
- How do you manage multiple environments in Terraform?
- What are Terraform modules?

**Difficulty:** Medium

---

### Q15: What's the difference between Terraform's `plan` and `apply`, and why does that two-step process matter?

**Answer:**
`terraform plan` computes and shows what changes *would* be made (resources to create/modify/destroy) by comparing desired configuration against the current state, without actually making any changes. `terraform apply` executes those changes. Separating the two lets you (or a reviewer, in CI/CD) inspect exactly what will happen — especially catching accidental destructive changes (like a resource being destroyed and recreated due to an immutable field change) — before anything is actually touched in the real environment.

**Follow-ups:**
- What's a state lock?
- How do you review a plan in CI?

**Difficulty:** Easy

---

### Q16: How would you securely manage secrets (DB passwords, API keys) used by a pipeline running in the cloud?

**Answer:**
Never hardcode secrets in code or plain config files committed to Git. Use a managed secrets service (Google **Secret Manager**, Azure Key Vault, AWS Secrets Manager) and grant the pipeline's runtime service account least-privilege access to fetch only the specific secrets it needs, ideally injected at runtime (env var/mounted file) rather than baked into a container image.

**Follow-ups:**
- How do you rotate secrets?
- How do you avoid secrets ending up in logs?

**Difficulty:** Medium

---

### Q17: What is a service account, and why shouldn't pipelines run using a personal user's credentials?

**Answer:**
A service account is a non-human identity used by applications/services to authenticate to cloud APIs, with its own IAM permissions. Pipelines should use dedicated service accounts (scoped to least-privilege) instead of a personal user's credentials because: personal credentials shouldn't be embedded in automated systems (security risk if leaked, and access breaks if that person leaves/loses access), service accounts can be scoped precisely to what a specific pipeline needs, and audit logs clearly attribute actions to the pipeline/service rather than conflating them with a human's manual actions.

**Follow-ups:**
- What's Workload Identity?
- Why avoid service account key files?

**Difficulty:** Easy

---

### Q18: What's the difference between horizontal and vertical scaling, and which does a distributed system like Spark/Kafka primarily rely on?

**Answer:**
**Vertical scaling**: making a single machine bigger (more CPU/RAM). **Horizontal scaling**: adding more machines that work together. Distributed systems like Spark and Kafka are designed around horizontal scaling — work is partitioned across many nodes, so you scale out (add more executors/brokers) rather than up, which is also generally cheaper and avoids a hard ceiling (there's always a bigger cluster, but a single machine has physical limits).

**Follow-ups:**
- What are the limits of vertical scaling?
- What new challenges does horizontal scaling introduce?

**Difficulty:** Easy
