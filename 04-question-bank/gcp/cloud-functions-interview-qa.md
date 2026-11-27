# Cloud Functions — Interview Question Bank

> Format: Question · Answer · Follow-ups · Difficulty

---

### Q1: What is Cloud Functions, and where does it fit in a data engineering stack compared to Dataflow/Dataproc?

**Answer:**
Cloud Functions is a serverless, event-driven compute service — you deploy a single function, GCP handles provisioning, scaling (including to zero), and infrastructure. It's built for **lightweight, event-triggered glue logic** (react to a file landing, a Pub/Sub message, an HTTP call), not heavy data processing. Dataflow/Dataproc are for actual large-scale data transformation/computation; Cloud Functions typically **triggers** those services or handles small, low-volume transforms itself.

**Follow-ups:**
- When would you use Cloud Run instead?
- Why isn't Cloud Functions suitable for heavy ETL?

**Difficulty:** Easy

---

### Q2: What trigger types does Cloud Functions support?

**Answer:**
- **HTTP triggers**: invoked via a direct HTTP request.
- **Pub/Sub triggers**: invoked when a message is published to a topic.
- **Cloud Storage triggers**: invoked on object finalize/delete/archive/metadata-update events.
- **Eventarc triggers** (2nd gen): a broader set of event sources (Firestore, Cloud Logging, Audit Logs, and many more), using CloudEvents as a standard format.
- **Scheduled** (paired with Cloud Scheduler publishing to Pub/Sub, since there's no native "cron" trigger type).

**Follow-ups:**
- What's the difference between HTTP and event-driven functions?
- How does Eventarc expand the available triggers?

**Difficulty:** Easy

---

### Q3: What's the difference between 1st generation and 2nd generation Cloud Functions?

**Answer:**
2nd gen is built on **Cloud Run/Eventarc** under the hood, giving: longer max timeouts (up to 60 min vs 9 min for 1st gen), larger max instance sizes, concurrent request handling per instance (better utilization), and access to the wider Eventarc event catalog. Google generally recommends 2nd gen for new development.

**Follow-ups:**
- What concurrency improvements does 2nd gen bring?
- What's the maximum timeout in each generation?

**Difficulty:** Medium

---

### Q4: How would you design a Cloud Function to react to new files landing in GCS and kick off processing?

**Answer:**
```python
import functions_framework

@functions_framework.cloud_event
def on_file_arrival(cloud_event):
    data = cloud_event.data
    bucket, name = data["bucket"], data["name"]
    if not name.endswith(".csv"):
        return  # ignore irrelevant files
    # launch downstream processing (Dataflow job, Dataproc batch, etc.)
    trigger_pipeline(bucket, name)
```
```bash
gcloud functions deploy on-file-arrival \
  --gen2 --runtime=python312 --region=us-central1 \
  --entry-point=on_file_arrival \
  --trigger-event-filters="type=google.cloud.storage.object.v1.finalized" \
  --trigger-event-filters="bucket=my-bucket"
```
Key point: the function should be a thin trigger/dispatcher — it launches the actual heavy job rather than doing the transformation itself.

**Follow-ups:**
- How do you handle very large files in this design?
- What would you do if processing takes longer than the timeout?

**Difficulty:** Medium

---

### Q5: What does "idempotent" mean for a Cloud Function, and why does it matter?

**Answer:**
An idempotent function produces the same end result no matter how many times it's invoked for the same event — important because Cloud Functions (and most event-driven systems) offer **at-least-once** delivery, meaning the same event can trigger the function more than once (e.g., due to retries after a transient failure). If a function inserts a row into BigQuery without checking for duplicates, a retry could double-insert. Designing for idempotency means using upserts/`MERGE`, checking-before-inserting, or deterministic keys the destination system can dedupe on.

**Follow-ups:**
- How would you implement idempotency with a processed-files table?
- Why can events be delivered more than once?

**Difficulty:** Medium

---

### Q6: How do you handle errors and retries in event-driven Cloud Functions?

**Answer:**
- For **Pub/Sub-triggered** functions, you can enable retry on failure at the subscription level, with an exponential backoff and a **dead-letter topic** so messages that repeatedly fail don't retry forever and get parked somewhere for investigation.
- Wrap risky logic in try/except, log context-rich error messages (Cloud Logging), and decide deliberately whether to `raise` (triggering a retry) or swallow-and-log (if the error is unrecoverable and retrying won't help).
- Set a reasonable function `--timeout` so a hung external call doesn't eat retry budget indefinitely.

**Follow-ups:**
- What happens with retries enabled and a persistent failure?
- How do you avoid infinite retry loops?

**Difficulty:** Medium

---

### Q7: What are the resource/execution limits of Cloud Functions, and how do they affect what you'd build with it?

**Answer:**
Functions have caps on memory (up to a few GB, gen-2 higher), CPU, execution timeout (up to 60 min for gen 2), and request/payload size. This makes Cloud Functions unsuitable for long-running batch transforms or processing very large files/datasets in memory — those belong in Dataflow/Dataproc, with Cloud Functions limited to triggering them or handling small, quick, bounded units of work.

**Follow-ups:**
- What are the memory and timeout limits?
- How do you handle work that exceeds them?

**Difficulty:** Easy

---

### Q8: How do you secure a Cloud Function that shouldn't be publicly callable?

**Answer:**
- For **HTTP functions**: deploy with `--no-allow-unauthenticated` and require IAM-based authentication (caller needs `roles/cloudfunctions.invoker` or the Cloud Run equivalent), or front it with API Gateway/Cloud Endpoints for API-key/OAuth-based access control.
- For **event-triggered functions**: they're invoked internally by the event source, not publicly reachable by default — the security concern shifts to what IAM permissions the function's **runtime service account** has (should be least-privilege, scoped to only what it needs).

**Follow-ups:**
- How do you invoke an authenticated function from another service?
- What does ingress settings control?

**Difficulty:** Medium

---

### Q9: How would you pass configuration (e.g., target table names, thresholds) into a function without hardcoding it?

**Answer:**
Use **environment variables** set at deploy time, or reference **Secret Manager** for sensitive values (API keys, credentials) rather than embedding them in code.
```bash
gcloud functions deploy process-events \
  --gen2 --runtime=python312 --region=us-central1 \
  --entry-point=process_events \
  --trigger-topic=events \
  --set-env-vars=TARGET_TABLE=my_project.analytics.events,THRESHOLD=100 \
  --set-secrets=API_KEY=my-api-key-secret:latest
```
```python
import os
target_table = os.environ["TARGET_TABLE"]
```

**Follow-ups:**
- Environment variables or Secret Manager — when do you use each?
- How do you rotate a secret without redeploying?

**Difficulty:** Easy

---

### Q10: How does Cloud Functions scaling work, and what's a "cold start"?

**Answer:**
Cloud Functions scales automatically based on incoming request/event volume, spinning up new instances as needed (up to a configurable max) and down to zero when idle. A **cold start** is the latency incurred when a new instance has to initialize (loading the runtime, your code, and any heavy imports) before it can serve its first request — noticeable for functions with large dependencies or infrequent invocation. Mitigations: set a **minimum instance count** (`--min-instances`) to keep some warm, minimize heavy imports/initialization at global scope vs inside the handler, and keep the deployment package lean.

**Follow-ups:**
- How do you reduce cold starts (min instances)?
- How does `max_instances` protect downstream systems?

**Difficulty:** Medium

---

### Q11: Compare using a Cloud Function vs a Dataflow streaming pipeline for processing Pub/Sub messages.

**Answer:**
| | Cloud Function | Dataflow |
|---|---|---|
| Volume | Low-moderate | High-volume, sustained |
| Processing | Simple per-message logic | Windowing, joins, stateful aggregation |
| Ordering/exactly-once | Not guaranteed by default | Strong support (windowing, watermarks) |
| Ops overhead | Minimal | More (pipeline design, monitoring lag) |
| Cost model | Pay per invocation | Pay for worker time |
Rule of thumb: simple, stateless, moderate-volume message handling → Cloud Function. Anything needing aggregation across messages, exactly-once guarantees, or high sustained throughput → Dataflow.

**Follow-ups:**
- At what message volume does Dataflow become the better choice?
- How does ordering differ between the two?

**Difficulty:** Medium

---

### Q12: How would you test a Cloud Function locally before deploying it?

**Answer:**
Use the **Functions Framework** to run the function locally as an HTTP server (`functions-framework --target=my_function`), and simulate CloudEvents payloads for event-triggered functions with test fixtures/mocked `cloud_event` objects in unit tests (e.g., pytest), mocking out GCP client calls (BigQuery, Storage) so tests don't hit real infrastructure.
```bash
functions-framework --target=on_file_arrival --signature-type=cloudevent
```

**Follow-ups:**
- How do you mock a CloudEvent?
- How would you run integration tests against real GCP resources?

**Difficulty:** Easy

---

### Q13: What IAM role(s) does a Cloud Function need, and what's the principle you should follow when granting them?

**Answer:**
Every function runs as a **runtime service account** (default compute SA, or ideally a dedicated one per function). Follow **least privilege**: grant only the specific roles needed for what the function actually touches — e.g. `roles/bigquery.dataEditor` scoped to one dataset, `roles/storage.objectViewer` on one bucket — rather than broad project-level Editor/Owner roles, since a compromised or buggy function shouldn't have blast radius beyond its actual job.

**Follow-ups:**
- Why use a dedicated service account per function?
- Which role allows writing to BigQuery?

**Difficulty:** Easy

---

### Q14: Scenario: a Pub/Sub-triggered Cloud Function occasionally fails and you're seeing duplicate rows in BigQuery. How do you fix it?

**Answer:**
Two things are likely happening together: (1) Pub/Sub's at-least-once delivery means the function *will* sometimes run more than once for the same message, and (2) the insert logic isn't idempotent. Fix by either using `insertAll`'s **insertId** (deduplication window) or switching to a **`MERGE`-based upsert** keyed on a natural/dedup key (e.g., message ID or event ID) so a re-run doesn't create a second row, rather than trying to eliminate retries altogether (which isn't fully possible in a distributed at-least-once system).

**Follow-ups:**
- How do you use the Pub/Sub message ID for dedupe?
- Would `MERGE` or `insertId` work better here?

**Difficulty:** Hard
