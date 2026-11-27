# Dataflow — Use Cases, Implementation & Code

*(See the earlier Dataflow/Beam Q&A bank for concept explanations — this doc focuses on end-to-end use cases.)*

---

## Use Case 1: Streaming ETL — Pub/Sub → transform → BigQuery

**Scenario**: Clickstream events arrive continuously on a Pub/Sub topic and need to land in BigQuery within seconds for near-real-time dashboards.

```python
import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions
import json

class ParseEvent(beam.DoFn):
    def process(self, element):
        try:
            record = json.loads(element.decode("utf-8"))
            record["amount"] = float(record.get("amount", 0))
            yield record
        except Exception as e:
            yield beam.pvalue.TaggedOutput("dead_letter", (element, str(e)))

def run():
    options = PipelineOptions(
        streaming=True,
        project="my-project",
        region="us-central1",
        temp_location="gs://my-bucket/tmp",
        runner="DataflowRunner",
    )
    with beam.Pipeline(options=options) as p:
        parsed = (
            p
            | "ReadPubSub" >> beam.io.ReadFromPubSub(topic="projects/my-project/topics/clickstream")
            | "Parse" >> beam.ParDo(ParseEvent()).with_outputs("dead_letter", main="main")
        )
        (parsed.main
            | "WriteBQ" >> beam.io.WriteToBigQuery(
                "my_project:analytics.clickstream_events",
                schema="user_id:STRING,event_type:STRING,amount:FLOAT64,event_ts:TIMESTAMP",
                write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND,
                create_disposition=beam.io.BigQueryDisposition.CREATE_IF_NEEDED))
        (parsed.dead_letter
            | "WriteDeadLetter" >> beam.io.WriteToText("gs://my-bucket/dead-letter/events"))

if __name__ == "__main__":
    run()
```

**Deploy**:
```bash
python streaming_pipeline.py \
  --runner=DataflowRunner \
  --project=my-project \
  --region=us-central1 \
  --temp_location=gs://my-bucket/tmp \
  --streaming
```

---

## Use Case 2: Batch ETL — GCS files → cleaned/joined → BigQuery

**Scenario**: Nightly CSV exports from an operational system need cleaning, deduping, and enrichment before loading.

```python
import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions

options = PipelineOptions(
    runner="DataflowRunner", project="my-project", region="us-central1",
    temp_location="gs://my-bucket/tmp",
)

def clean_row(row):
    fields = row.split(",")
    return {"order_id": fields[0], "customer_id": fields[1], "amount": float(fields[2])}

with beam.Pipeline(options=options) as p:
    orders = (
        p
        | "ReadCSV" >> beam.io.ReadFromText("gs://my-bucket/raw/orders-*.csv", skip_header_lines=1)
        | "Clean" >> beam.Map(clean_row)
        | "DedupeByKey" >> beam.Map(lambda r: (r["order_id"], r))
        | "GroupDupes" >> beam.GroupByKey()
        | "TakeFirst" >> beam.Map(lambda kv: kv[1][0])
    )
    orders | "WriteBQ" >> beam.io.WriteToBigQuery(
        "my_project:sales.orders_clean",
        write_disposition=beam.io.BigQueryDisposition.WRITE_TRUNCATE)
```

---

## Use Case 3: Windowed aggregation for real-time monitoring

**Scenario**: Count failed login attempts per user in 5-minute windows to feed a fraud-detection alert.

```python
(events
 | "Window" >> beam.WindowInto(beam.window.FixedWindows(5 * 60))
 | "KeyByUser" >> beam.Map(lambda e: (e["user_id"], 1))
 | "CountPerUser" >> beam.CombinePerKey(sum)
 | "FilterSuspicious" >> beam.Filter(lambda kv: kv[1] >= 5)
 | "FormatAlert" >> beam.Map(lambda kv: {"user_id": kv[0], "failed_attempts": kv[1]})
 | "WriteAlerts" >> beam.io.WriteToBigQuery("my_project:security.login_alerts", ...))
```

---

## Use Case 4: Reusable, parameterized deployment with a Flex Template

**Scenario**: Let other teams (or Airflow/Composer) launch the same pipeline with different input/output paths, without needing the Python dev environment.

```bash
# 1. Build the container image for the pipeline
gcloud builds submit --tag gcr.io/my-project/orders-pipeline:latest .

# 2. Build the Flex Template spec
gcloud dataflow flex-template build gs://my-bucket/templates/orders-pipeline.json \
  --image gcr.io/my-project/orders-pipeline:latest \
  --sdk-language PYTHON \
  --metadata-file metadata.json

# 3. Anyone (or Composer, via DataflowStartFlexTemplateOperator) can now launch it:
gcloud dataflow flex-template run "orders-etl-$(date +%Y%m%d)" \
  --template-file-gcs-location gs://my-bucket/templates/orders-pipeline.json \
  --region us-central1 \
  --parameters input=gs://my-bucket/raw/orders-2024-01-15.csv,output_table=my_project:sales.orders
```

Triggering from Composer/Airflow:
```python
from airflow.providers.google.cloud.operators.dataflow import DataflowStartFlexTemplateOperator

run_pipeline = DataflowStartFlexTemplateOperator(
    task_id="run_orders_pipeline",
    project_id="my-project",
    location="us-central1",
    body={
        "launchParameter": {
            "jobName": "orders-etl-{{ ds_nodash }}",
            "containerSpecGcsPath": "gs://my-bucket/templates/orders-pipeline.json",
            "parameters": {"input": "gs://my-bucket/raw/orders-{{ ds }}.csv",
                            "output_table": "my_project:sales.orders"},
        }
    },
)
```

---

## Best practices
- Enable **Streaming Engine** for streaming jobs and **Dataflow Shuffle** for batch jobs (default in recent SDKs) to keep workers lean and improve autoscaling.
- Always route malformed records to a dead-letter output instead of crashing the pipeline.
- Set `allowed_lateness` and a sensible trigger strategy deliberately — don't rely on defaults for correctness-sensitive streaming jobs.
- Use Flex Templates for anything triggered by an external system/scheduler.
- Monitor **system lag** (streaming) and **watermark delay** in the Dataflow UI — the earliest sign of a pipeline falling behind.
