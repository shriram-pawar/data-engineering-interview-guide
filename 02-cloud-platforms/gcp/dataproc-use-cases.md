# Dataproc — Use Cases, Implementation & Code

## What it is
A managed Hadoop/Spark/Hive/Flink/Presto service. You get real clusters (or fully serverless Spark via **Dataproc Serverless**) with fast startup (~90s), autoscaling, and per-second billing — the go-to choice when you already have Spark/Hadoop code/expertise or need the broader ecosystem, as opposed to Dataflow's Beam-only model.

---

## Use Case 1: Lift-and-shift an existing on-prem Spark/Hive workload

**Scenario**: A company migrating off an on-prem Hadoop cluster wants to run existing PySpark jobs largely unchanged.

**Create an ephemeral cluster (spun up per job, torn down after)**:
```bash
gcloud dataproc clusters create etl-cluster \
  --region=us-central1 \
  --zone=us-central1-a \
  --master-machine-type=n2-standard-4 \
  --worker-machine-type=n2-standard-4 \
  --num-workers=4 \
  --image-version=2.1-debian11 \
  --enable-component-gateway \
  --optional-components=JUPYTER
```

**Submit the existing PySpark job unchanged**:
```bash
gcloud dataproc jobs submit pyspark gs://my-bucket/jobs/transform_orders.py \
  --cluster=etl-cluster \
  --region=us-central1 \
  -- --input=gs://my-bucket/raw/orders --output=gs://my-bucket/clean/orders
```

```python
# transform_orders.py — standard PySpark, no GCP-specific rewrite needed
import sys, argparse
from pyspark.sql import SparkSession

parser = argparse.ArgumentParser()
parser.add_argument("--input"); parser.add_argument("--output")
args = parser.parse_args()

spark = SparkSession.builder.appName("transform_orders").getOrCreate()
df = spark.read.parquet(args.input)
clean = df.dropDuplicates(["order_id"]).filter("amount > 0")
clean.write.mode("overwrite").parquet(args.output)
```

**Tear down when done** (or use `--max-idle` to auto-delete):
```bash
gcloud dataproc clusters delete etl-cluster --region=us-central1
```

---

## Use Case 2: Scheduled recurring Spark jobs via Workflow Templates

**Scenario**: A nightly Spark job that needs a cluster spun up, job run, and cluster torn down as one atomic unit — ideal for triggering from Composer/cron without managing cluster lifecycle manually.

```bash
gcloud dataproc workflow-templates create nightly-orders-etl --region=us-central1

gcloud dataproc workflow-templates set-managed-cluster nightly-orders-etl \
  --region=us-central1 \
  --cluster-name=nightly-etl-cluster \
  --num-workers=4 \
  --worker-machine-type=n2-standard-4

gcloud dataproc workflow-templates add-job pyspark gs://my-bucket/jobs/nightly_etl.py \
  --workflow-template=nightly-orders-etl \
  --region=us-central1 \
  --step-id=main-job

# Trigger it (cluster is created, job runs, cluster is deleted automatically)
gcloud dataproc workflow-templates instantiate nightly-orders-etl --region=us-central1
```
From Airflow/Composer:
```python
from airflow.providers.google.cloud.operators.dataproc import DataprocInstantiateWorkflowTemplateOperator

run_etl = DataprocInstantiateWorkflowTemplateOperator(
    task_id="run_nightly_etl",
    template_id="nightly-orders-etl",
    project_id="my-project",
    region="us-central1",
)
```

---

## Use Case 3: Cost-efficient, no-cluster-management Spark with Dataproc Serverless

**Scenario**: Sporadic/bursty Spark jobs where managing cluster sizing isn't worth the effort — pay only for the job's actual runtime, no cluster to provision or delete.

```bash
gcloud dataproc batches submit pyspark gs://my-bucket/jobs/transform_orders.py \
  --region=us-central1 \
  --batch=orders-batch-$(date +%s) \
  --deps-bucket=gs://my-bucket/deps \
  -- --input=gs://my-bucket/raw/orders --output=gs://my-bucket/clean/orders
```
No cluster creation/deletion step needed at all — Dataproc provisions and releases resources automatically for the batch's lifetime.

---

## Use Case 4: Autoscaling cluster for variable, long-running workloads

```bash
gcloud dataproc autoscaling-policies import orders-autoscaling \
  --region=us-central1 \
  --source=autoscaling-policy.yaml
```
```yaml
# autoscaling-policy.yaml
workerConfig:
  minInstances: 2
  maxInstances: 10
secondaryWorkerConfig:
  minInstances: 0
  maxInstances: 20        # preemptible workers for cheap scale-out
basicAlgorithm:
  cooldownPeriod: 4m
  yarnConfig:
    scaleUpFactor: 0.5
    scaleDownFactor: 1.0
    gracefulDecommissionTimeout: 1h
```
```bash
gcloud dataproc clusters create long-running-cluster \
  --region=us-central1 \
  --autoscaling-policy=orders-autoscaling
```

---

## Best practices
- Prefer **ephemeral clusters** or **Dataproc Serverless** over long-lived clusters — pay only while jobs actually run.
- Use **Workflow Templates** for scheduled jobs so cluster lifecycle is handled atomically alongside the job.
- Store data in **Cloud Storage**, not HDFS on the cluster, so data outlives any individual cluster (standard "separate compute from storage" pattern).
- Use **secondary (preemptible/spot) workers** for cost savings on fault-tolerant batch stages.
- For interactive/notebook work, enable **Component Gateway** with Jupyter rather than SSHing into nodes.
