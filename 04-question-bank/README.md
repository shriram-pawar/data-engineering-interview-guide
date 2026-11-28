# 04 · Question Bank

Interview questions organized by topic.

| Folder | Topics |
|---|---|
| `sql/` | SQL queries and concepts |
| `python-pyspark/` | Python and PySpark coding/concepts |
| `gcp/` | Google Cloud data services |
| `databricks/` | Databricks, Delta Lake, Spark on Databricks |
| `azure/` | Azure Data Factory, Synapse/Azure SQL, Event Hubs, monitoring and governance, DevOps and DR, architecture scenarios |
| `data-warehousing/` | Modeling, warehousing, and architecture |
| `scenario-based/` | Real-world troubleshooting and design scenarios |
| `behavioral/` | STAR-format behavioral questions |
| `dbt/` | dbt models, tests, snapshots, incremental loads, deployment |
| `devops/` | Git, Terraform and CI/CD for data platforms |
| [`real-world-asked/`](real-world-asked/) | Questions people were **actually asked** in interviews, by skill and company ([rules](real-world-asked/README.md)) |

## Question Format

Every question file **must** use this format (multiple questions per file are fine, separated by `---`):

```markdown
### Q: <question text>

**Answer:**
<clear, concise answer; include code if relevant>

**Follow-ups:**
- <follow-up question 1>
- <follow-up question 2>

**Difficulty:** Easy | Medium | Hard
```

For SQL questions, add a `**BigQuery version:**` block after the answer wherever BigQuery syntax differs (dates and intervals, `QUALIFY`, `UNNEST`, `PIVOT`, percentiles, query parameters, DML patterns).

See [`_template.md`](_template.md) for a starter file.
