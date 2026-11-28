# Real-World Asked: Scenario-Based & Project

Scenario, design and project-discussion questions reported from real interviews.

See [README.md](README.md) for the layout and contributor rules. Fields are left blank when unknown.

## Deloitte

### Q1: How would you deal with problems when much larger volumes of data than usual arrive from upstream systems?

**Answer:**
- **Detect early:** volume monitoring (row and byte counts versus the usual range), with alerts on anomalies, before downstream jobs choke.
- **Decide if it's valid:** a real spike (seasonality, a backfill) or a duplication bug upstream (the same files resent)? Check counts per key and file names, and talk to the source team.
- **Absorb valid spikes:** autoscaling compute (Databricks autoscale, serverless, Dataflow), more partitions and parallelism, and processing in chunks (by date or file) instead of one giant batch.
- **Protect the platform:** backpressure or rate limits for streaming (`maxFilesPerTrigger`, `maxBytesPerTrigger`), queueing, separate compute so other jobs aren't starved.
- **Keep correctness:** idempotent loads and deduplication so resends don't double-count; reconcile totals after processing.
- **Follow up:** capacity planning and agreements on backfill notice with source teams.

**Follow-ups:**
- How would you handle the upstream team resending a full month of files by mistake?
- What limits would you set on a streaming job to survive a spike?

**Difficulty:** Medium


**Role:** Data Engineer

**Round:** L1

**Asked:** 

---

### Q2: How do you handle data type changes in the source data?

**Answer:**
- **Detect:** validate incoming types against the expected schema (contract) before loading; in Spark, use an explicit schema plus `badRecordsPath` or `_rescued_data`; in ADF, enable fault tolerance and log incompatible rows.
- **Classify the change:**
  - *Widening* (INT → BIGINT, FLOAT → DOUBLE): usually safe. Evolve the target type (Delta supports some widening with type widening; BigQuery allows some relaxations).
  - *Narrowing or incompatible* (STRING → INT, a date format change): risky. Don't silently cast and lose data.
- **Handle safely:** land raw data unchanged in bronze; in silver, cast with `try_cast` / `SAFE_CAST`, route failures to a quarantine table, and alert.
- **Migrate deliberately:** add a new column with the new type, backfill from raw, and switch consumers through views.
- **Prevent:** schema contracts and change notices with source owners.

**Follow-ups:**
- Why is a silent cast dangerous?
- How would you backfill after changing a column type?

**Difficulty:** Medium


**Role:** Data Engineer

**Round:** L1

**Asked:** 

## HCLTech

### Q3: In your project, how were large files ingested, and how was schema evolution handled?

**Answer:**
Describe your actual setup; a typical strong answer:
- **Ingestion:** files land in ADLS or Cloud Storage; **Auto Loader** (or ADF copy into the raw zone) picks up new files incrementally; large files are split or kept in splittable formats (Parquet, or compressed CSV split by the source); parallelism comes from many files rather than one huge one.
- **Performance:** explicit schemas (no inference pass), sensible partition sizes, writing Delta with file compaction (`OPTIMIZE`).
- **Schema evolution:** Auto Loader `addNewColumns` with `_rescued_data` for unexpected fields; `mergeSchema` for additive changes into silver; breaking changes quarantined and alerted.
- **Reliability:** checkpoints for exactly-once, file-level audit (file name, row count, load time) and reconciliation against source counts.

Mention real numbers (file sizes, count per day, runtime).

**Follow-ups:**
- How did you handle a single very large non-splittable file?
- What was the last schema change you handled, and how?

**Difficulty:** Medium


**Role:** Lead Data Engineer

**Round:** Round 2 – Technical

**Asked:** 

---

### Q4: In your last Azure project, how were failures, retries and alerts handled?

**Answer:**
- **Retries:** activity-level retry (count and interval) in ADF for transient errors, Databricks job task retries, and code-level retries with backoff for API calls. Fatal errors (bad data, auth) aren't retried.
- **Idempotency:** every load writes to a partition or uses `MERGE` on keys, and watermarks update only after success, so a rerun is safe.
- **Failure paths:** ADF "on failure" branches log the error to an audit table and call a notification (Logic App or Web activity → Teams or email).
- **Alerting and monitoring:** ADF and Databricks diagnostics sent to **Log Analytics**, **Azure Monitor alerts** on failed runs or long durations with **action groups**, plus a run-status dashboard.
- **Recovery:** a runbook with rerun-from-failure steps; in metadata-driven pipelines, failed tables are retried independently.

**Follow-ups:**
- Which errors should never be retried automatically?
- How did you make sure watermarks weren't advanced on failure?

**Difficulty:** Medium


**Role:** Lead Data Engineer

**Round:** Round 2 – Technical

**Asked:** 

## JPMorgan

### Q5: How do you handle NULL records in a pipeline?

**Answer:**
Decide **per column** what NULL means, then handle it explicitly:
- **Profile first:** count NULLs per column and per source to tell normal gaps from broken feeds.
- **Required fields** (keys, dates): reject or quarantine the row with a reason (`NOT NULL` checks, dbt or expectations tests), and alert when the rate jumps.
- **Optional fields:** keep NULL (don't invent data), or apply a documented default (`COALESCE(country, 'Unknown')`, a `-1` "unknown" dimension member for foreign keys).
- **Watch the SQL semantics:** `NULL = NULL` isn't true (use `IS NULL` / `IS NOT DISTINCT FROM`), `NOT IN` with NULLs returns nothing, aggregates ignore NULLs, and joins drop NULL keys.
- **In Spark:** `df.na.drop(subset=[...])`, `df.na.fill({...})`, `F.coalesce`, and **null-safe joins** with `<=>` / `eqNullSafe`.

**Follow-ups:**
- Why might NULL join keys silently drop rows?
- When is it wrong to fill NULLs with a default?

**Difficulty:** Easy


**Role:** Senior / Lead Data Engineer

**Round:** Technical Round 1

**Asked:** 

---

### Q6: How would you load only new and changed data instead of reloading everything each run?

**Answer:**
Common approaches:
- **Watermark-based**: track the max `updated_at`/`id` processed so far; each run pulls only rows newer than that watermark.
- **CDC (Change Data Capture)**: use a tool (Datastream, Debezium) that reads the source database's transaction log directly, capturing every insert/update/delete as it happens — most accurate, doesn't rely on an `updated_at` column being reliably maintained by the source application.
- **Partition-based reprocessing**: for sources where late updates are common but bounded (e.g., "data can be corrected up to 3 days late"), reprocess a rolling window of recent partitions each run rather than tracking exact watermarks.

**Follow-ups:**
- What are the pitfalls of using an `updated_at` watermark?
- How does CDC compare with watermark-based incremental loads?

**Difficulty:** Medium


**Role:** Senior / Lead Data Engineer

**Round:** Technical Round 1

**Asked:** 

---

### Q7: A daily job dies partway through. How do you make reruns safe, duplicate-free and alerted?

**Answer:**
**Design for idempotency** so "just rerun it" is always safe:
- **Process in units** (a day or a partition) and **write with overwrite-or-merge semantics:** `INSERT OVERWRITE` / `replaceWhere` for that partition, or `MERGE` on a business key, never blind appends.
- **Stage then publish:** write to a staging table and swap or `MERGE` into the target in one atomic step at the end (Delta and BigQuery transactions are atomic per statement).
- **Checkpoint progress:** a control table records which steps or tables finished; on rerun, skip completed steps or redo them idempotently. Watermarks update **only after** a successful publish.
- **Deduplicate inputs** by key (in case the source resent data).
- **Alerting:** failure callbacks or alerts (Airflow `on_failure_callback`, ADF / Azure Monitor action groups) to Slack, Teams, email or PagerDuty, with the run ID and failing step; also SLA-miss alerts.
- **Verify after the rerun:** row counts and totals reconciled against the source.

**Follow-ups:**
- What's the difference between partition overwrite and `MERGE` for idempotency?
- How do you rerun only the failed tables in a 200-table pipeline?

**Difficulty:** Medium


**Role:** Senior / Lead Data Engineer

**Round:** Technical Round 2

**Asked:** 

## Persistent Systems

### Q8: How would you make PDFs and images that land in your pipeline searchable and queryable?

**Answer:**
1. **Land the binaries** in object storage (ADLS or Cloud Storage) with metadata: source, upload time, hash for deduplication.
2. **Extract content:**
   - **Text and structure** from PDFs: Azure AI Document Intelligence / Google Document AI, or open-source tools; OCR for scanned documents.
   - **Images:** OCR, labels and captions from vision services or models.
   - Databricks has `ai_parse_document`; BigQuery can call Document AI and Vision through **object tables** and remote models.
3. **Store structured results** in tables: one row per document or page with extracted fields, text, entities, and a pointer to the original file (Delta, BigQuery).
4. **Make it queryable:** SQL over the extracted fields; **full-text search** (Azure AI Search, BigQuery `SEARCH`); and for semantic questions, **chunk the text and create embeddings** in a vector index (RAG).
5. **Pipeline concerns:** event-driven processing (storage events → function or job), retries and a dead-letter path for files that fail extraction, PII detection and access control, and cost (OCR is per page).

**Follow-ups:**
- How would you handle scanned PDFs versus digital ones?
- How would you keep the extracted data in sync when a file is replaced?

**Difficulty:** Hard


**Role:** Data Engineer

**Round:** Round 2 – Technical

**Asked:** 

---

### Q9: A pipeline spans AWS and Azure. How do you give it secure, low-cost access to data in both?

**Answer:**
- **Minimize data movement:** process data where it lives (compute in each cloud), and move only curated or aggregated results; **egress fees** are often the biggest cost.
- **Open formats and sharing:** Parquet, Delta or Iceberg, with **Delta Sharing** or Iceberg REST catalogs so the other cloud reads without copying; or a single platform spanning both (e.g. Databricks with Unity Catalog in each cloud).
- **Identity and access:** federated identity (Entra ID ↔ AWS IAM Identity Center), **short-lived credentials** (role assumption, workload identity federation) instead of long-lived keys, least privilege per dataset.
- **Network security:** private connectivity (VPN or interconnect, private endpoints), encryption in transit and at rest with customer-managed keys where required.
- **Governance:** a central catalog and lineage, consistent classification and PII masking in both clouds, audit logs from both sides in one SIEM.
- **Cost control:** schedule transfers in bulk, compress, cache shared datasets, and tag resources for cost visibility per cloud.

**Follow-ups:**
- How would you avoid storing AWS access keys in Azure?
- When is copying data between clouds still the right choice?

**Difficulty:** Hard


**Role:** Data Engineer

**Round:** Round 2 – Technical

**Asked:** 

## TEKsystems

### Q10: Walk through the architecture of a recent data pipeline, from source to target. What challenges did you face?

**Also asked at:** Deloitte, Wipro

**Answer:**
Structure the walkthrough left to right, then cover challenges:
1. **Sources:** systems, formats, volume and frequency (e.g. "OLTP databases via CDC plus daily partner files; about 200 GB a day").
2. **Ingestion:** how data lands (Datastream or Pub/Sub for CDC, files to Cloud Storage), and the raw layer for replay.
3. **Processing:** Dataflow or Dataproc/Spark or BigQuery SQL; validation, deduplication, transformations; staging → curated layers.
4. **Storage and serving:** BigQuery datasets per layer, partitioning and clustering, and who consumes the data (BI dashboards, ML, APIs).
5. **Orchestration and operations:** Composer DAGs, retries, monitoring, alerting, CI/CD.

**Challenges** (pick 2 real ones, with how you solved them): late or duplicate CDC events (idempotent `MERGE` on key plus sequence), schema changes (validation and quarantine), performance at growth (partitioning, clustering, incremental loads), meeting an SLA. Draw the diagram on a whiteboard if you can.

**Follow-ups:**
- What would break first if the volume grew 10 times?
- Why did you choose that processing engine?

**Difficulty:** Medium


**Role:** GCP Data Engineer

**Round:** Technical evaluation

**Asked:** 
