# Cloud Functions — Use Cases, Implementation & Code

## What it is
A serverless, event-driven compute service — you write a single function that reacts to a trigger (HTTP request, Pub/Sub message, GCS event, Firestore change, etc.) and GCP handles provisioning, scaling to zero, and scaling out. In data engineering, it's most often the lightweight "glue" that reacts to events rather than the place heavy processing happens.

---

## Use Case 1: File-arrival trigger that kicks off a Dataflow/Dataproc job

**Scenario**: The moment a file lands in GCS, validate it and launch downstream processing — no polling/scheduling needed.

```python
# main.py (2nd gen Cloud Function, Python, GCS trigger via Eventarc/CloudEvents)
import functions_framework
from google.cloud import dataflow_v1beta3

@functions_framework.cloud_event
def on_file_arrival(cloud_event):
    data = cloud_event.data
    bucket = data["bucket"]
    name = data["name"]

    if not name.endswith(".csv"):
        print(f"Ignoring non-csv file: {name}")
        return

    print(f"New file detected: gs://{bucket}/{name} — launching Dataflow job")
    client = dataflow_v1beta3.TemplatesServiceClient()
    request = dataflow_v1beta3.LaunchFlexTemplateRequest(
        project_id="my-project",
        location="us-central1",
        launch_parameter=dataflow_v1beta3.LaunchFlexTemplateParameter(
            job_name=f"orders-etl-{name.replace('/', '-')}",
            container_spec_gcs_path="gs://my-bucket/templates/orders-pipeline.json",
            parameters={"input": f"gs://{bucket}/{name}", "output_table": "my_project:sales.orders"},
        ),
    )
    client.launch_flex_template(request=request)
```

```txt
# requirements.txt
functions-framework==3.*
google-cloud-dataflow-client==0.8.*
```

**Deploy**:
```bash
gcloud functions deploy on-file-arrival \
  --gen2 \
  --runtime=python312 \
  --region=us-central1 \
  --source=. \
  --entry-point=on_file_arrival \
  --trigger-event-filters="type=google.cloud.storage.object.v1.finalized" \
  --trigger-event-filters="bucket=my-company-datalake-raw" \
  --memory=256MB \
  --timeout=60s
```

---

## Use Case 2: Pub/Sub-triggered micro-transform straight into BigQuery

**Scenario**: Small, simple streaming records (e.g., IoT sensor pings) that don't need Dataflow's full windowing/scaling machinery — just parse and insert.

```python
import base64, json
import functions_framework
from google.cloud import bigquery

bq_client = bigquery.Client()
TABLE = "my_project.iot.sensor_readings"

@functions_framework.cloud_event
def process_sensor_event(cloud_event):
    payload = base64.b64decode(cloud_event.data["message"]["data"])
    record = json.loads(payload)

    row = {
        "device_id": record["device_id"],
        "temperature": float(record["temperature"]),
        "reading_ts": record["timestamp"],
    }
    errors = bq_client.insert_rows_json(TABLE, [row])
    if errors:
        print(f"BigQuery insert errors: {errors}")
        raise RuntimeError(errors)
```
```bash
gcloud functions deploy process-sensor-event \
  --gen2 --runtime=python312 --region=us-central1 \
  --source=. --entry-point=process_sensor_event \
  --trigger-topic=sensor-readings
```
> For high-volume streaming (thousands of events/sec, need for windowing/aggregation/exactly-once guarantees), use **Dataflow** instead — Cloud Functions is best for simple, low/moderate-volume, stateless event handling.

---

## Use Case 3: HTTP-triggered on-demand API for pipeline utilities

**Scenario**: A lightweight internal API other services (or Composer, via a simple HTTP call) can hit to check pipeline status or trigger a manual reprocess.

```python
import functions_framework
from flask import jsonify

@functions_framework.http
def reprocess_date(request):
    body = request.get_json(silent=True) or {}
    target_date = body.get("date")
    if not target_date:
        return jsonify({"error": "date is required"}), 400

    # ... trigger reprocessing logic (e.g., launch a Dataflow job / Dataproc batch) ...
    return jsonify({"status": "triggered", "date": target_date}), 200
```
```bash
gcloud functions deploy reprocess-date \
  --gen2 --runtime=python312 --region=us-central1 \
  --source=. --entry-point=reprocess_date \
  --trigger-http --allow-unauthenticated=false
```

---

## Use Case 4: Scheduled lightweight housekeeping (paired with Cloud Scheduler)

**Scenario**: Nightly cleanup of expired staging files — too small a task to justify a full Composer DAG.

```python
import functions_framework
from google.cloud import storage
from datetime import datetime, timedelta, timezone

@functions_framework.cloud_event
def cleanup_staging(cloud_event):
    client = storage.Client()
    cutoff = datetime.now(timezone.utc) - timedelta(days=7)
    for blob in client.list_blobs("my-bucket", prefix="staging/"):
        if blob.time_created < cutoff:
            blob.delete()
            print(f"Deleted expired: {blob.name}")
```
```bash
gcloud scheduler jobs create pubsub cleanup-staging-daily \
  --schedule="0 2 * * *" \
  --topic=cleanup-trigger \
  --message-body="run"
```
(Function is deployed with `--trigger-topic=cleanup-trigger`, same pattern as Use Case 2.)

---

## Best practices
- Keep functions **stateless and idempotent** — they can be retried/invoked more than once for the same event.
- Use Cloud Functions for **glue and light transforms**, not heavy/long-running processing (there are timeout and memory ceilings) — hand off real processing to Dataflow/Dataproc.
- Set a **dead-letter topic** on Pub/Sub-triggered functions so repeatedly-failing messages don't retry forever.
- Grant the function's service account the **minimum IAM roles** needed (e.g., `roles/bigquery.dataEditor` on a specific dataset, not project-wide).
- Prefer **2nd generation** Cloud Functions (built on Cloud Run) for better concurrency, longer timeouts, and Eventarc's broader event source support.
