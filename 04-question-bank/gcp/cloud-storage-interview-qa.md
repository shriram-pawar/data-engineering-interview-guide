# Cloud Storage — Interview Question Bank

> Format: Question · Answer · Follow-ups · Difficulty

---

### Q1: What is Cloud Storage, and what role does it typically play in a GCP data pipeline?

**Answer:**
Cloud Storage is GCP's object storage service — durable, highly available, and effectively infinitely scalable, with a flat namespace (buckets containing objects, "folders" are just a naming convention via `/` prefixes). In data pipelines it's almost always the **landing zone** for raw data, the **staging area** between processing stages, the home for **Dataflow/Dataproc temp files and job outputs**, and often the **data lake** itself — queried directly via BigQuery external/BigLake tables rather than always being loaded into a database first.

**Follow-ups:**
- How does GCS differ from HDFS?
- Is GCS strongly consistent?

**Difficulty:** Easy

---

### Q2: What are the storage classes, and how do you choose between them?

**Answer:**
- **Standard**: frequently accessed data, highest cost per GB, no retrieval fee, no minimum storage duration.
- **Nearline**: accessed roughly monthly or less, lower storage cost, small retrieval fee, 30-day minimum storage duration.
- **Coldline**: accessed roughly quarterly or less, even lower storage cost, higher retrieval fee, 90-day minimum.
- **Archive**: accessed roughly once a year or less, lowest storage cost, highest retrieval fee, 365-day minimum.
Choose based on **expected access frequency**, not just age — accessing "cold"-classed data frequently costs more overall due to retrieval fees, even though storage itself is cheaper. **Autoclass** can manage this automatically based on actual observed access patterns instead of you predicting it upfront.

**Follow-ups:**
- What are the minimum storage durations and retrieval fees?
- What's Autoclass?

**Difficulty:** Easy

---

### Q3: What are Lifecycle rules, and write one that transitions data to Coldline after 90 days and deletes it after 3 years.

**Answer:**
Lifecycle rules automatically apply actions (change storage class, delete) to objects matching conditions (age, storage class, custom time, etc.) — removing the need for manual cleanup jobs.
```json
{
  "rule": [
    {"action": {"type": "SetStorageClass", "storageClass": "COLDLINE"}, "condition": {"age": 90}},
    {"action": {"type": "Delete"}, "condition": {"age": 1095}}
  ]
}
```
```bash
gsutil lifecycle set lifecycle.json gs://my-bucket
```

**Follow-ups:**
- Can lifecycle rules apply only to a prefix?
- How do lifecycle rules interact with object versioning?

**Difficulty:** Easy

---

### Q4: Regional vs multi-regional (and dual-region) buckets — how do you choose location?

**Answer:**
- **Regional**: data stored in a single region — lowest latency and no cross-region egress cost when compute (Dataflow, Dataproc, BigQuery) is colocated in that same region; slightly lower availability SLA than multi-region.
- **Multi-region**: data replicated across multiple regions within a continent — higher availability, good for globally-served content, but reads from compute in a single region may cross regions (and note: BigQuery/Dataflow jobs generally still need to be in a compatible location).
- **Dual-region**: a specific pair of regions, balancing some of both — often used for a good latency/DR tradeoff.
For most data engineering pipelines where compute is pinned to one region, **regional** buckets colocated with that compute are the default choice — cheaper and faster, with DR handled at the pipeline/backup level if needed.

**Follow-ups:**
- How does location choice affect egress costs?
- What's turbo replication?

**Difficulty:** Medium

---

### Q5: How do you trigger downstream processing automatically when a new file lands in a bucket?

**Answer:**
Two main patterns:
1. **Pub/Sub notifications**: `gsutil notification create` publishes an event to a Pub/Sub topic on object changes (create/delete/etc.), which any subscriber (Cloud Function, Dataflow streaming pipeline, custom consumer) can act on.
2. **Eventarc + Cloud Functions (2nd gen)**: deploy a function with a GCS trigger filter (`google.cloud.storage.object.v1.finalized`) — Eventarc handles the routing under the hood, no manual Pub/Sub topic setup required.
```bash
gsutil notification create -t new-file-topic -f json -e OBJECT_FINALIZE gs://my-bucket
```

**Follow-ups:**
- How do Eventarc and Pub/Sub notifications differ?
- How do you prevent a function from processing half-written files?

**Difficulty:** Medium

---

### Q6: ### Q6. What's the difference between IAM permissions and ACLs (Access Control Lists) in Cloud Storage, and which should you use?

**Answer:**
- **IAM**: project/bucket-level (and with Conditions, sometimes prefix-level) permissions — the recommended, centrally-manageable approach, especially with **uniform bucket-level access** enabled (which disables legacy ACLs entirely and enforces IAM-only).
- **ACLs**: legacy, per-object/per-bucket fine-grained permissions — more flexible at the individual-object level but harder to audit/manage at scale, and easy to end up with inconsistent object-level overrides.
Best practice: enable **uniform bucket-level access** and manage everything through IAM (plus IAM Conditions for narrower scoping) rather than mixing in legacy ACLs.

**Follow-ups:**
- What happens to your data if the CMEK key is disabled?
- What's the difference between CMEK and CSEK?

**Difficulty:** Medium

---

### Q7: How would you give a partner/external user temporary access to a specific file without granting them a GCP account/IAM role?

**Answer:**
**Signed URLs** — a time-limited URL that grants access to a specific object/operation without the requester needing GCP credentials at all.
```python
from google.cloud import storage

client = storage.Client()
blob = client.bucket("my-bucket").blob("exports/report.csv")
url = blob.generate_signed_url(expiration=3600, method="GET")  # valid for 1 hour
```
For access to an entire prefix/set of objects under custom conditions, **signed policy documents** are the equivalent for POST-based uploads.

**Follow-ups:**
- What's the maximum expiration time for a V4 signed URL?
- Which identity signs the URL?

**Difficulty:** Medium

---

### Q8: What is object versioning, and when would you enable it?

**Answer:**
When enabled, overwriting or deleting an object keeps the prior version(s) instead of discarding them, retrievable by generation number — protects against accidental overwrites/deletes and supports point-in-time recovery. Trade-off: storage cost accumulates for retained old versions, so it's usually paired with a lifecycle rule that expires noncurrent versions after some period.
```bash
gsutil versioning set on gs://my-bucket
```

**Follow-ups:**
- How does versioning affect storage cost?
- How do you restore a deleted object?

**Difficulty:** Easy

---

### Q9: How do you avoid or mitigate the "small files problem" when a pipeline writes many small objects to GCS?

**Answer:**
- Configure the writing job (Spark `coalesce`, Beam sink `num_shards`) to control output file count/size directly rather than defaulting to one file per task/partition.
- Periodically **compact** small files into larger ones via a scheduled job.
- For streaming ingestion producing many tiny files, consider batching writes over a short time window (e.g., write once per minute rather than once per message) before landing in GCS.
Too many small files slow down downstream listing/metadata operations (BigQuery external tables, Spark/Dataproc reads) even though total data volume may be small.

**Follow-ups:**
- What's a good target file size?
- How would you compact existing small files?

**Difficulty:** Medium

---

### Q10: What's the difference between `gsutil cp`, `gsutil rsync`, and `gsutil -m cp` (parallel), and when would you use each?

**Answer:**
- **`gsutil cp`**: straightforward copy of one or more explicit objects/files.
- **`gsutil rsync`**: synchronizes a source and destination (local↔GCS or GCS↔GCS), copying only changed/new files and optionally deleting extras — good for keeping a mirrored directory/bucket in sync.
- **`gsutil -m cp`**: the `-m` flag parallelizes the operation across multiple threads/processes — essential for copying large numbers of files quickly rather than sequentially.
```bash
gsutil -m rsync -r ./local_data gs://my-bucket/data
```

**Follow-ups:**
- Why could `rsync -d` be dangerous?
- How does `gcloud storage` compare with `gsutil`?

**Difficulty:** Easy

---

### Q11: How does Cloud Storage support customer-managed encryption keys (CMEK), and why would a team need that over Google's default encryption?

**Answer:**
All data in Cloud Storage is encrypted at rest by default (Google-managed keys), but regulated industries often need control over the encryption key lifecycle (rotation, revocation, audit) themselves. **CMEK** lets you supply a key from **Cloud KMS** that GCS uses to encrypt the data — you control rotation and can revoke access by disabling the key, immediately making the data unreadable, which is often a compliance requirement (e.g., certain finance/healthcare regulations).

**Follow-ups:**
- What happens to your data if the CMEK key is disabled?
- What's the difference between CMEK and CSEK?

**Difficulty:** Medium

---

### Q12: Coding: using the Python client, list all Parquet files under a date-partitioned prefix and compute their total size.

**Answer:**
```python
from google.cloud import storage

client = storage.Client()
total_bytes = 0
for blob in client.list_blobs("my-bucket", prefix="orders/dt=2024-01-15/"):
    if blob.name.endswith(".parquet"):
        total_bytes += blob.size

print(f"Total size: {total_bytes / (1024**3):.2f} GB")
```

**Follow-ups:**
- How would you handle millions of objects efficiently?
- What does the `delimiter` parameter do?

**Difficulty:** Medium

---

### Q13: What is a "requester pays" bucket, and when would you use it?

**Answer:**
A bucket configured so that whoever *accesses* the data (not the bucket owner) is billed for the request/network egress costs — used when sharing large public or semi-public datasets where the owner doesn't want to absorb download costs for arbitrary consumers.
```bash
gsutil requesterpays set on gs://my-shared-dataset
```

**Follow-ups:**
- Who pays for egress?
- How does the requester specify the billing project?

**Difficulty:** Easy

---

### Q14: How would you design the bucket/prefix structure for a multi-team data lake to keep it manageable and secure?

**Answer:**
- Separate buckets (or at least clearly separated top-level prefixes) **per data domain/sensitivity level** (raw vs curated, PII vs non-PII), so IAM can be scoped cleanly rather than needing complex per-object rules.
- A consistent, partition-friendly naming convention, e.g. `gs://lake-raw/<domain>/<table>/dt=YYYY-MM-DD/`.
- Separate **raw/staging/curated** zones (often separate buckets or prefixes) reflecting pipeline stage, so downstream consumers only get access to the curated zone, not raw/in-flight data.
- Centralize governance for anything needing row/column-level control via **BigLake** rather than trying to enforce that at the GCS layer.

**Follow-ups:**
- How would you separate raw, curated and sandbox zones?
- Would you use one bucket per team or prefixes in a shared bucket?

**Difficulty:** Medium

---

### Q15: What causes a `403` or `AccessDenied` error when a service (e.g., a Cloud Function or Dataflow job) tries to read/write a bucket, and how do you debug it?

**Answer:**
Most commonly: the calling identity (the job/function's **service account**) lacks the needed IAM role (`roles/storage.objectViewer`/`objectAdmin`) on the bucket, or a **VPC Service Controls** perimeter is blocking cross-service access. Debug by checking which service account the job is actually running as (not necessarily your own user), confirming its IAM bindings on the specific bucket (`gsutil iam get gs://my-bucket`), and checking Cloud Audit Logs for the exact denied permission in the error detail.

**Follow-ups:**
- How do you find out which service account a job runs as?
- How do VPC Service Controls show up in error messages?

**Difficulty:** Medium
