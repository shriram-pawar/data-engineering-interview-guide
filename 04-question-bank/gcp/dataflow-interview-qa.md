# GCP Dataflow (Apache Beam) — Interview Question Bank

> Format: Question · Answer · Follow-ups · Difficulty

---

### Q1: What is Dataflow, and how does it relate to Apache Beam?

**Answer:**
**Apache Beam** is an open-source, unified programming model/SDK (Java, Python, Go) for defining both **batch and streaming** data processing pipelines, independent of the execution engine. **Dataflow** is Google Cloud's fully-managed **runner** that executes Beam pipelines — handling provisioning, autoscaling, and operating the underlying workers. You could run the same Beam pipeline code on Dataflow, Spark, or Flink by just swapping the runner.

**Follow-ups:**
- What other runners does Beam support?
- What does Dataflow manage for you that a self-managed Flink cluster wouldn't?

**Difficulty:** Easy

---

### Q2: Explain the core Beam concepts: `Pipeline`, `PCollection`, `PTransform`.

**Answer:**
- **`Pipeline`**: the overall graph/job definition.
- **`PCollection`**: an immutable, distributed collection of data flowing through the pipeline — can represent bounded (batch) or unbounded (streaming) data.
- **`PTransform`**: an operation applied to a `PCollection` to produce another `PCollection` (e.g., `ParDo`, `GroupByKey`, `Combine`, `Map`, `Filter`).
```python
import apache_beam as beam

with beam.Pipeline() as pipeline:
    (pipeline
     | "Read" >> beam.io.ReadFromText("gs://bucket/input.csv")
     | "Parse" >> beam.Map(parse_line)
     | "Filter" >> beam.Filter(lambda x: x["amount"] > 0)
     | "Write" >> beam.io.WriteToText("gs://bucket/output"))
```

**Follow-ups:**
- Is a PCollection mutable?
- What's a composite transform?

**Difficulty:** Easy

---

### Q3: What's the difference between `ParDo` and `Map`/`Filter`?

**Answer:**
`Map` and `Filter` are simple, common-case wrappers built on top of `ParDo`. `ParDo` (via a `DoFn`) is the general-purpose "do arbitrary processing per element" transform — it can emit zero, one, or many output elements per input, access side inputs, and maintain per-element state, which `Map`/`Filter` (1-in-1-out or 1-in-0/1-out) can't.
```python
class SplitWords(beam.DoFn):
    def process(self, element):
        for word in element.split():
            yield word

words = lines | beam.ParDo(SplitWords())
```

**Follow-ups:**
- When would `ParDo` emit zero or several outputs per element?
- What are DoFn lifecycle methods like `setup` and `start_bundle` used for?

**Difficulty:** Easy

---

### Q4: Explain `GroupByKey` vs `CombinePerKey`.

**Answer:**
Both operate on `PCollection`s of key-value pairs. `GroupByKey` collects **all** values for each key into an iterable — you get every raw value, which can be memory-heavy for hot keys. `CombinePerKey` applies an associative/commutative combining function (sum, count, custom `CombineFn`) incrementally, including partial combining *before* the shuffle — much more efficient for aggregations since it doesn't need to materialize every value.
```python
totals = pairs | beam.CombinePerKey(sum)          # efficient
grouped = pairs | beam.GroupByKey()                # needed if you need all raw values
```

**Follow-ups:**
- Why is `CombinePerKey` more efficient?
- Which combiners must be associative and commutative?

**Difficulty:** Medium

---

### Q5: What are windows, and what types does Beam support?

**Answer:**
Windows divide an unbounded (or bounded) `PCollection` into finite chunks based on event time, so aggregations (like `GroupByKey`/`Combine`) can be applied to streaming data.
- **Fixed windows**: fixed-size, non-overlapping (e.g., every 5 minutes).
- **Sliding windows**: fixed-size, overlapping, emitted at a shorter interval than the window size (e.g., 10-minute window every 5 minutes).
- **Session windows**: dynamically sized per key, based on gaps of inactivity (e.g., group events with no more than 30 min between them).
- **Global window**: the default — the entire `PCollection` is one window (typical for batch).
```python
windowed = events | beam.WindowInto(beam.window.FixedWindows(60))  # 60-second windows
```

**Follow-ups:**
- When would you use session windows?
- How do sliding windows affect cost?

**Difficulty:** Medium

---

### Q6: What is a watermark, and why does it matter for streaming pipelines?

**Answer:**
The watermark is Beam's estimate of "event time up to which we believe all data has arrived" for a given source — it's how the system decides when a window is likely complete enough to fire results, even though data can still arrive late. Watermarks let Beam balance **completeness vs latency**: waiting longer captures more late data but delays results.

**Follow-ups:**
- What happens to data that arrives behind the watermark?
- How does Dataflow estimate the watermark for Pub/Sub?

**Difficulty:** Hard

---

### Q7: Explain triggers and how they interact with windows.

**Answer:**
Triggers control **when** a window emits its (possibly still-incomplete) results, independent of when the window itself ends. By default, a window fires once when the watermark passes the end of the window. You can configure triggers to fire early (e.g., every N elements or on a processing-time interval, for low-latency partial results) and/or fire again on late data (`AfterWatermark.pastEndOfWindow().withLateFirings(...)`), combined with an **accumulation mode** (discarding vs accumulating previous firings).

**Follow-ups:**
- What's the difference between accumulating and discarding modes?
- How would you get early speculative results every minute?

**Difficulty:** Hard

---

### Q8: How does Beam handle late-arriving data?

**Answer:**
You configure `allowed_lateness` on a window, which keeps the window's state around after the watermark passes, so any data arriving within that lateness bound is still incorporated (and triggers can be configured to re-fire on late data with `withLateFirings`). Data arriving after `allowed_lateness` expires is dropped. This is a deliberate trade-off (correctness vs resource usage) you configure based on how late your sources are known to run.

**Follow-ups:**
- What does `allowed_lateness` do?
- How do you capture data that arrives too late for later reconciliation?

**Difficulty:** Hard

---

### Q9: What are side inputs, and give a use case?

**Answer:**
A side input lets a `ParDo`/`DoFn` access an *additional* `PCollection` (typically small, broadcast to all workers) while processing the main `PCollection` — analogous to a broadcast join in Spark.
```python
lookup = beam.pvalue.AsDict(country_codes)  # small PCollection as a side input

def enrich(element, lookup):
    element["country_name"] = lookup.get(element["country_code"], "Unknown")
    return element

enriched = main_pcoll | beam.Map(enrich, lookup=lookup)
```
Common use case: enriching streaming events with a reference/dimension table that's too large to hardcode but small enough to broadcast.

**Follow-ups:**
- What's the size limit on side inputs?
- How would you refresh a slowly changing side input in a streaming job?

**Difficulty:** Medium

---

### Q10: Batch vs streaming in Dataflow — how do you choose, and can the same code do both?

**Answer:**
Beam's model is unified: the same pipeline code can run in batch (bounded source, e.g., GCS files) or streaming (unbounded source, e.g., Pub/Sub) mode, with windowing/triggers determining behavior either way. In practice you choose based on latency requirements: batch for periodic/scheduled bulk processing, streaming when you need near-real-time results as events arrive (e.g., fraud detection, live dashboards).

**Follow-ups:**
- What changes in the code when switching from bounded to unbounded sources?
- Why might a streaming job cost more than hourly batch?

**Difficulty:** Medium

---

### Q11: What are Dataflow templates, and why use them (classic vs Flex templates)?

**Answer:**
Templates package a pipeline so it can be triggered/run **without** needing the original development environment — just parameters (e.g., input path, output table) at launch time, via the console, `gcloud`, REST API, or from Airflow/Composer.
- **Classic templates**: staged at pipeline-construction time; parameters are limited to runtime value providers, less flexible.
- **Flex templates**: package the pipeline as a Docker container, allow full control over pipeline construction at launch time (including dynamic logic based on parameters), and are the generally recommended modern approach.
Google also provides many ready-made templates (e.g., "Pub/Sub to BigQuery", "GCS Text to BigQuery") for common patterns.

**Follow-ups:**
- How are runtime parameters passed to Flex templates?
- How would you launch a template from Airflow?

**Difficulty:** Medium

---

### Q12: How does Dataflow autoscaling work?

**Answer:**
Dataflow can automatically adjust the number of worker instances during a job based on throughput and backlog (for streaming) or based on estimated remaining work (for batch), within a configured min/max worker range (`--maxNumWorkers`, `--numWorkers`). Streaming Engine and Dataflow Prime further improve autoscaling responsiveness and let scaling decisions happen more granularly than whole-worker increments (e.g., via decoupled compute/state).

**Follow-ups:**
- Why might autoscaling not scale up?
- How do you cap the maximum number of workers?

**Difficulty:** Medium

---

### Q13: What is Dataflow Shuffle / Streaming Engine, and why do they matter?

**Answer:**
Normally, shuffle (data redistribution between stages, like `GroupByKey`) happens on the worker VMs themselves, consuming their CPU/disk/network and tying shuffle capacity to worker count.
- **Dataflow Shuffle** (batch) and **Streaming Engine** (streaming) move this shuffle/state-management work off the worker VMs into a separate, dedicated Google-managed service. This improves autoscaling (workers can scale for compute only), reduces worker resource contention, and generally improves performance/reliability for shuffle-heavy jobs. Recommended to enable for most production jobs.

**Follow-ups:**
- Where does state live with Streaming Engine?
- How does service-based shuffle affect worker sizing?

**Difficulty:** Hard

---

### Q14: How would you handle malformed/bad records in a Dataflow pipeline without failing the whole job?

**Answer:**
Use a "dead-letter" pattern with `ParDo`'s multiple-output capability (tagged outputs) — route bad records to a separate output for logging/reprocessing instead of raising an exception that kills the pipeline.
```python
class ParseFn(beam.DoFn):
    def process(self, element):
        try:
            yield beam.pvalue.TaggedOutput("good", parse(element))
        except Exception as e:
            yield beam.pvalue.TaggedOutput("bad", (element, str(e)))

results = raw | beam.ParDo(ParseFn()).with_outputs("good", "bad")
results.good | beam.io.WriteToBigQuery(...)
results.bad | beam.io.WriteToText("gs://bucket/dead-letter/")
```

**Follow-ups:**
- How do you implement a dead-letter output with tagged outputs?
- Where would you store the bad records, and how would you replay them?

**Difficulty:** Medium

---

### Q15: What does "exactly-once" processing mean in Dataflow, and what are its guarantees/limits?

**Answer:**
Dataflow guarantees exactly-once processing of records **within the pipeline itself** (no duplicate processing due to internal retries), and exactly-once delivery to supported sinks like BigQuery. However, if your `DoFn` has **external side effects** (e.g., calling a third-party API, writing to a system Beam doesn't manage transactionally), those side effects can still happen more than once during retries — you need to design such side effects to be idempotent yourself.

**Follow-ups:**
- Does exactly-once extend to external sinks?
- How do idempotent writes help when the sink isn't transactional?

**Difficulty:** Hard

---

### Q16: Dataflow vs Dataproc vs Cloud Composer — when would you use each?

**Answer:**
- **Dataflow**: serverless, autoscaled batch/streaming data processing (Beam pipelines) — best when you don't want to manage cluster infrastructure and want unified batch+streaming code.
- **Dataproc**: managed Spark/Hadoop/Hive/Flink **clusters** — best when you have existing Spark/Hadoop code/expertise, need fine-grained cluster control, or need the broader Hadoop ecosystem (HDFS, Hive, etc.).
- **Cloud Composer**: managed **Airflow** — orchestrates and schedules workflows (which might themselves trigger Dataflow jobs, Dataproc jobs, BigQuery queries, etc.); it's not a processing engine itself.
They're complementary, not competitors — a common pattern is Composer orchestrating a DAG that triggers a Dataflow job to process data and then load it into BigQuery.

**Follow-ups:**
- When would you run Spark on Dataproc instead of Beam on Dataflow?
- Why isn't Composer a processing engine?

**Difficulty:** Medium

---

### Q17: How do you monitor a running Dataflow job?

**Answer:**
The **Dataflow Monitoring UI** in the console shows the execution graph, per-stage throughput, autoscaling history, watermark/system lag (crucial for streaming jobs to spot processing delays), and worker resource utilization. It integrates with **Cloud Monitoring** (metrics, custom alerting policies, e.g., alert if system lag exceeds a threshold) and **Cloud Logging** (`Logging` calls / stack traces from your `DoFn`s).

**Follow-ups:**
- Which metrics show a streaming job is falling behind?
- How do you find a stuck or slow step?

**Difficulty:** Easy

---

### Q18: What's the difference between `Combine.globally()` and `Combine.perKey()`?

**Answer:**
`CombinePerKey` aggregates values **per key** (like a `GROUP BY` + aggregate), producing one output per key. `Combine.globally()` aggregates **across the entire `PCollection`**, producing a single output value (e.g., a single grand-total count/sum for the whole dataset, or per-window if windowed).

**Follow-ups:**
- What does `Combine.globally` return on empty input?
- How would you compute per-key averages?

**Difficulty:** Easy

---

### Q19: How would you write a Beam pipeline that reads from Pub/Sub, aggregates per 1-minute window, and writes to BigQuery?

**Answer:**
```python
import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions

options = PipelineOptions(streaming=True)

with beam.Pipeline(options=options) as p:
    (p
     | "ReadPubSub" >> beam.io.ReadFromPubSub(topic="projects/my-proj/topics/events")
     | "ParseJSON" >> beam.Map(parse_json)
     | "AddTimestamps" >> beam.Map(lambda x: beam.window.TimestampedValue(x, x["event_ts"]))
     | "Window" >> beam.WindowInto(beam.window.FixedWindows(60))
     | "KeyByType" >> beam.Map(lambda x: (x["event_type"], 1))
     | "CountPerWindow" >> beam.CombinePerKey(sum)
     | "FormatForBQ" >> beam.Map(lambda kv: {"event_type": kv[0], "count": kv[1]})
     | "WriteBQ" >> beam.io.WriteToBigQuery(
           "my_dataset.event_counts",
           write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND))
```

**Follow-ups:**
- How would you handle duplicate Pub/Sub messages?
- Which BigQuery write method would you pick for streaming (Storage Write API vs streaming inserts)?

**Difficulty:** Hard

---

### Q20: What levers do you have to control Dataflow job cost?

**Answer:**
- Right-size `--maxNumWorkers` / machine type — don't over-provision beyond what autoscaling actually needs.
- Use **Flexible Resource Scheduling (FlexRS)** for non-urgent batch jobs, which trades a delayed start (up to 6h) for significantly cheaper (preemptible-backed) compute.
- Enable Dataflow Shuffle/Streaming Engine so workers aren't oversized just to handle shuffle I/O.
- Avoid unnecessarily wide fan-out/shuffle steps; combine/filter early to shrink data volume before expensive stages.
- For streaming, tune windowing/triggers so you're not processing more often than actually needed downstream.
- Stop/drain streaming jobs that are no longer needed rather than leaving them running.

**Follow-ups:**
- How do FlexRS and Spot VMs reduce batch cost?
- How does choosing the right machine type affect cost?

**Difficulty:** Medium
