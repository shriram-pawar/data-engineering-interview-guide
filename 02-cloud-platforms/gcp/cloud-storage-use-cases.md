# Cloud Storage — Use Cases, Implementation & Code

## What it is
Object storage — the foundation most GCP data pipelines are built on top of: the landing zone for raw data, the staging area between processing stages, the home for Dataflow/Dataproc temp files and templates, and often the data lake itself (queried directly via BigQuery external/BigLake tables).

---

## Use Case 1: Data lake landing zone with lifecycle management

**Scenario**: Raw data lands continuously; you want cheap long-term retention without manual cleanup, and want older data to automatically move to cheaper storage classes.

```bash
gsutil mb -l us-central1 -c STANDARD gs://my-company-datalake-raw
```

```json
// lifecycle.json — move to cheaper tiers over time, delete after 3 years
{
  "rule": [
    {
      "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
      "condition": {"age": 30}
    },
    {
      "action": {"type": "SetStorageClass", "storageClass": "COLDLINE"},
      "condition": {"age": 90}
    },
    {
      "action": {"type": "Delete"},
      "condition": {"age": 1095}
    }
  ]
}
```
```bash
gsutil lifecycle set lifecycle.json gs://my-company-datalake-raw
```

**Organize with a clear prefix convention** for partition-pruning-friendly reads downstream:
```
gs://my-company-datalake-raw/orders/dt=2024-01-15/part-0001.parquet
gs://my-company-datalake-raw/orders/dt=2024-01-15/part-0002.parquet
```

---

## Use Case 2: Event-driven pipeline trigger (file arrival → processing)

**Scenario**: As soon as a file lands, kick off downstream processing (paired with Cloud Functions or Eventarc → Dataflow/Composer).

```bash
# Configure a Pub/Sub notification on bucket writes
gsutil notification create -t new-file-topic -f json -e OBJECT_FINALIZE gs://my-company-datalake-raw
```
This publishes a message to Pub/Sub whenever a new object is finalized, which a Cloud Function or Eventarc trigger (see the Cloud Functions guide) can consume to start processing — no polling needed.

---

## Use Case 3: Staging + programmatic access from pipeline code

```python
from google.cloud import storage

client = storage.Client()

# Upload
bucket = client.bucket("my-company-datalake-raw")
blob = bucket.blob("orders/dt=2024-01-15/part-0001.parquet")
blob.upload_from_filename("local_orders.parquet")

# Download
blob.download_to_filename("local_copy.parquet")

# List objects under a prefix (e.g., all files for one day)
for blob in client.list_blobs("my-company-datalake-raw", prefix="orders/dt=2024-01-15/"):
    print(blob.name, blob.size)

# Generate a signed URL for temporary, credential-free access (e.g., for a downstream partner)
url = blob.generate_signed_url(expiration=3600, method="GET")
```

---

## Use Case 4: Access control for a multi-team data lake

```bash
# Grant a specific service account read-only access to just the "orders" prefix
# (fine-grained prefix-level control typically needs IAM Conditions or separate buckets per domain)
gsutil iam ch serviceAccount:etl-reader@my-project.iam.gserviceaccount.com:objectViewer \
  gs://my-company-datalake-raw

# Uniform bucket-level access (recommended over legacy ACLs)
gsutil uniformbucketlevelaccess set on gs://my-company-datalake-raw
```
For genuinely fine-grained per-object/row/column security over lake data, use **BigLake** (see the BigLake guide) rather than trying to slice GCS IAM at a sub-bucket level.

---

## Best practices
- Use a consistent, hierarchical, partition-friendly naming convention (`domain/table/dt=YYYY-MM-DD/`).
- Set lifecycle rules from day one — don't let raw/staging data accumulate indefinitely at Standard-class prices.
- Prefer **regional** buckets colocated with your compute (Dataflow/Dataproc/BigQuery) to avoid cross-region egress costs and latency.
- Use **Autoclass** as an alternative to manual lifecycle rules when access patterns are unpredictable — GCS automatically moves objects between classes based on actual access.
- Avoid extremely large numbers of small files (same "small files problem" as HDFS/Spark) — compact where possible.
