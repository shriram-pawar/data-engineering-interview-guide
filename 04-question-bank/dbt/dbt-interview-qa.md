# dbt — Interview Question Bank

> Format: Question · Answer · Follow-ups · Difficulty

---

### Q1: What is dbt, and where does it fit in a data platform?

**Answer:**
dbt (data build tool) handles the **T in ELT**: data is first loaded into the warehouse (BigQuery, Snowflake…), then dbt transforms it there using **SQL `SELECT` statements plus Jinja templating**. dbt compiles each model to SQL and runs it in the warehouse; it doesn't move data itself.

What it adds over plain SQL scripts: dependency management (`ref`), tests, documentation and lineage, environments, reusable macros, and software-engineering practices (Git, code review, CI).

**Follow-ups:**
- How is dbt different from a traditional ETL tool such as Informatica?
- What does dbt *not* do (extraction, scheduling)?

**Difficulty:** Easy

---

### Q2: What are models, sources and `ref()`, and how does dbt build its DAG?

**Answer:**
- A **model** is a `.sql` file in `models/` containing one `SELECT`. dbt materializes it as a view or table named after the file.
- A **source** declares raw tables loaded by other tools (in a `sources.yml`), referenced as `{{ source('raw', 'orders') }}`. Sources can have freshness checks.
- **`{{ ref('stg_orders') }}`** references another model. dbt resolves it to the right schema for the environment and records the dependency.

From all the `ref` and `source` calls, dbt builds a **DAG** and runs models in dependency order (`dbt run`, `dbt build`). The same graph powers lineage docs and node selection (`dbt run --select stg_orders+`).

**Follow-ups:**
- Why should you never hard-code table names instead of using `ref`?
- What does `dbt source freshness` check?

**Difficulty:** Easy

---

### Q3: What materializations does dbt support?

**Answer:**
| Materialization | What it builds | Use for |
|---|---|---|
| `view` (default) | A view | Light staging models, always-fresh logic |
| `table` | A table, rebuilt every run | Heavier models queried often |
| `incremental` | A table updated with only new or changed rows | Large fact tables |
| `ephemeral` | Nothing; inlined as a CTE into dependent models | Small reusable logic |
| `materialized_view` | A warehouse materialized view | Auto-refreshing aggregates |

Set per model with `{{ config(materialized='table') }}` or per folder in `dbt_project.yml`. Snapshots and seeds are separate resource types.

**Follow-ups:**
- What are the downsides of ephemeral models?
- When would a view become too slow for downstream models?

**Difficulty:** Easy

---

### Q4: How do incremental models work?

**Answer:**
The first run builds the full table. Later runs only process new or changed rows, filtered inside `is_incremental()`:

```sql
{{ config(materialized='incremental', unique_key='order_id',
          partition_by={'field': 'order_date', 'data_type': 'date'}) }}

SELECT order_id, customer_id, order_date, amount, updated_at
FROM {{ source('raw', 'orders') }}
{% if is_incremental() %}
WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
{% endif %}
```

- With a **`unique_key`**, BigQuery uses the `merge` strategy (upsert). `insert_overwrite` replaces whole partitions instead, which is cheaper for partitioned tables.
- **Late-arriving data:** add a lookback window (e.g. the last 3 days) rather than a strict `>`.
- Run `dbt run --full-refresh` to rebuild after a logic change.

**Follow-ups:**
- When would you choose `insert_overwrite` over `merge` in BigQuery?
- How do you handle schema changes (`on_schema_change`)?

**Difficulty:** Medium

---

### Q5: How do you test data in dbt?

**Answer:**
- **Generic data tests** in YAML: `unique`, `not_null`, `accepted_values`, `relationships`, plus packages such as `dbt-utils` and `dbt-expectations`.
- **Singular tests:** a `.sql` file in `tests/` that returns failing rows (the test passes when zero rows come back).
- **Unit tests** (dbt 1.8+): mock input rows and assert a model's output, to test logic rather than data.
- **Source freshness** checks for late loads.

```yaml
models:
  - name: fct_orders
    columns:
      - name: order_id
        data_tests: [unique, not_null]
      - name: status
        data_tests:
          - accepted_values:
              values: ['placed', 'shipped', 'returned']
```

Use `severity: warn` for non-blocking checks; `dbt build` runs models and tests in DAG order and stops downstream models when a test fails.

**Follow-ups:**
- What's the difference between data tests and unit tests?
- How would you store failing rows for investigation (`store_failures`)?

**Difficulty:** Medium

---

### Q6: What are seeds?

**Answer:**
Seeds are small CSV files in the `seeds/` folder that `dbt seed` loads into the warehouse as tables, referenced with `ref('country_codes')`. They're good for **small, static reference data** that changes rarely and benefits from version control: country codes, mapping tables, test fixtures.

They're not for large or frequently changing data, which should be loaded by a proper ingestion pipeline.

**Follow-ups:**
- How do you set column types for a seed?
- Why shouldn't seeds contain sensitive data?

**Difficulty:** Easy

---

### Q7: What are snapshots?

**Answer:**
Snapshots implement **SCD Type 2** on a mutable source table. On each `dbt snapshot` run, dbt compares the current rows with the snapshot table, closes changed rows and inserts new versions, maintaining `dbt_valid_from` and `dbt_valid_to`.

Two strategies:
- **`timestamp`:** uses an `updated_at` column to detect changes (preferred when it's reliable).
- **`check`:** compares a list of columns (`check_cols`) when there's no reliable timestamp.

Run snapshots frequently enough to catch every intermediate change you care about, because changes between runs are missed.

**Follow-ups:**
- How would you query a customer's attributes as of a past date from a snapshot?
- What happens to deleted source rows (`invalidate_hard_deletes` / `hard_deletes`)?

**Difficulty:** Medium

---

### Q8: What are macros and Jinja in dbt?

**Answer:**
dbt models are **Jinja templates**, so you can use variables, loops and conditions in SQL. **Macros** are reusable Jinja functions in the `macros/` folder:

```sql
-- macros/cents_to_dollars.sql
{% macro cents_to_dollars(col, scale=2) %}
    ROUND({{ col }} / 100, {{ scale }})
{% endmacro %}

-- models/fct_payments.sql
SELECT payment_id, {{ cents_to_dollars('amount_cents') }} AS amount
FROM {{ ref('stg_payments') }}
```

Uses include repeated expressions, generating columns from a list, environment-specific logic (`target.name`) and custom generic tests. Packages such as `dbt-utils` are collections of macros.

**Follow-ups:**
- How would you override `generate_schema_name` to control schema naming per environment?
- When does heavy Jinja hurt readability?

**Difficulty:** Medium

---

### Q9: What are pre-hooks and post-hooks?

**Answer:**
Hooks run SQL around dbt operations:
- **`pre_hook` / `post_hook`** (model config): run before or after a specific model is built, e.g. grant access, add a table label, or delete a partition.
- **`on-run-start` / `on-run-end`** (in `dbt_project.yml`): run at the start or end of a whole `dbt run`, e.g. create an audit table or log run results.

```sql
{{ config(post_hook="GRANT `roles/bigquery.dataViewer` ON TABLE {{ this }} TO 'group:analysts@example.com'") }}
```

Prefer built-in configs where they exist (e.g. `grants`) over hand-written hooks.

**Follow-ups:**
- What could go wrong if a post-hook fails?
- How would you log every model's run time into an audit table?

**Difficulty:** Medium

---

### Q10: Describe a dbt project's structure, and the difference between `profiles.yml` and `dbt_project.yml`.

**Answer:**
```
my_dbt_project/
├── dbt_project.yml     # project config: name, paths, default materializations per folder
├── models/
│   ├── staging/        # 1:1 cleaned copies of sources (views)
│   ├── intermediate/   # joins and business logic
│   └── marts/          # facts and dimensions for consumers (tables)
├── seeds/              # small reference CSVs
├── snapshots/          # SCD2 snapshots
├── tests/              # singular tests
├── macros/             # reusable Jinja
└── analyses/           # ad-hoc SQL, compiled but not run
```

- **`dbt_project.yml`** is **project-specific** and lives in the repo: project name, folder paths, model configs (materialization and schema per folder), variables.
- **`profiles.yml`** is **environment-specific** and holds connection details per **target** (dev, prod): warehouse type, GCP project, dataset, authentication method. It usually lives outside the repo (`~/.dbt/`) or uses environment variables, so credentials aren't committed.

**Follow-ups:**
- How do developers get their own dev datasets without overwriting each other?
- Where would you keep a service-account credential in CI?

**Difficulty:** Easy

---

### Q11: How do you deploy dbt to production?

**Answer:**
1. **Git workflow:** feature branch → pull request → review.
2. **CI on the pull request:** run `dbt build` against a temporary CI schema. With **slim CI**, build only changed models and their children: `dbt build --select state:modified+ --defer --state prod-artifacts/`.
3. **Merge to main** → deploy: production runs use the `prod` target.
4. **Orchestration:** dbt Cloud jobs, or Cloud Composer / Airflow (e.g. `BashOperator` or Cosmos running `dbt build`), scheduled after ingestion finishes.
5. **Monitoring:** test failures, run results (`run_results.json`), source freshness, and alerts.

**Follow-ups:**
- What does `--defer` do, and why does it make CI faster?
- How would you roll back a bad model deployment?

**Difficulty:** Medium

---

### Q12: How do you handle sensitive data in dbt models?

**Answer:**
- **Credentials:** never in code. Use `{{ env_var('DBT_...') }}` in `profiles.yml`, with secrets from Secret Manager or the CI secret store.
- **Minimize:** don't carry PII past staging unless needed; hash or tokenize identifiers in staging (`TO_HEX(SHA256(email))`).
- **Restrict access:** separate datasets for sensitive marts, the `grants` config, and BigQuery **policy tags** for column-level security and masking (apply through `meta` / `persist_docs` or post-hooks).
- **Document** PII columns in YAML (`meta: {pii: true}`), so they're visible in lineage and audits.
- Keep **seeds and tests free of real PII.**

**Follow-ups:**
- How would you let analysts join on email without exposing it?
- How would you find every model that uses a PII column?

**Difficulty:** Medium

---

### Q13: How do you optimize dbt models on BigQuery?

**Answer:**
- Use **incremental** models for large facts, with `insert_overwrite` on partitioned tables where possible.
- Configure **`partition_by`** and **`cluster_by`** on big tables, and filter on them downstream.
- Choose materializations deliberately: views for light staging, tables for models queried often; avoid deep chains of heavy views.
- Select only the needed columns; avoid `SELECT *` in marts.
- Push filters early (in staging) and pre-aggregate where it helps.
- Check cost and runtime per model from `run_results.json` and BigQuery `INFORMATION_SCHEMA.JOBS` (use query labels or comments to attribute them).
- Use **slim CI** and node selection so you don't rebuild everything on every change.

**Follow-ups:**
- How would you find the slowest models in a project?
- When is a full refresh unavoidable?

**Difficulty:** Medium
