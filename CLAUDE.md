# CLAUDE.md

Project rules for working in this repo.

## Repo

- Public interview prep guide for data engineers, focused on **GCP** and **Azure Databricks**.
- GitHub: `shriram-pawar/data-engineering-interview-guide`, under the personal account (not an organization).
- **All rights reserved; no license.** Don't add a LICENSE file or any license text. The copyright notice is at the end of `README.md`.

| Folder | Contents |
|---|---|
| `01-theory/` | Concept notes |
| `02-cloud-platforms/` | `gcp/`, `azure-databricks/` |
| `03-code/` | `sql/`, `python/`, `pyspark/`, `airflow-dags/`, `projects/` |
| `04-question-bank/` | Questions by topic (format below) |
| `05-system-design/` | `case-studies/`, `templates/` |
| `06-cheat-sheets/` | One-page references |
| `assets/images/` | Shared images |

## Git workflow

- **Never push to `main`.** Always work on a `feature/<topic>` or `fix/<topic>` branch created from `main`, then open a PR.
- `main` is protected: it requires a PR, 1 approval and Code Owner review.

## Original content only

- Never copy paid course material (e.g. GrowDataSkills), LeetCode, DataLemur, or any other copyrighted content.
- To cover a concept from such a source, rewrite it with new wording, schemas and data. Don't reuse problem titles, table designs, sample rows or solution write-ups.
- If source material looks copied, flag it to the user before importing it.

## Pre-commit scan (every commit)

Before every commit, scan the staged files for:

- passwords, secrets, API keys, tokens and private keys
- real GCP project IDs, bucket names, service accounts, Azure subscription or tenant IDs, Databricks workspace URLs
- client or company names
- personal details (names, emails, phone numbers)

Show the user what you found. Placeholders like `my-project`, `gs://my-bucket` and `example.com` / `.test` addresses are fine.

## Question bank format

Every question in `04-question-bank/` uses this format:

```markdown
### Q<n>: <question>

**Answer:**
<answer, with code if relevant>

**Follow-ups:**
- <follow-up>
- <follow-up>

**Difficulty:** Easy | Medium | Hard
```

- Separate questions with `---`.
- For SQL, **add a BigQuery version** wherever BigQuery syntax differs (dates, intervals, `QUALIFY`, `UNNEST`, `PIVOT`, etc.).
- SQL practice problems use the fictional FreshCart schema in `03-code/sql/practice-schema.sql`.

## System design case studies

Each case study goes in `05-system-design/case-studies/<project-name>/`:

```
<project-name>/
├── diagrams/                 # editable .drawio or .excalidraw files + PNG exports
├── README.md                 # overview, business problem, summary
├── legacy-architecture.md
├── target-architecture.md
├── migration-design.md       # approach, stack mapping table (replaced / kept / retired), validation, cutover
└── lessons-learned.md        # challenges, trade-offs, interview talking points
```

- Every editable diagram must have a PNG export next to it, so it renders on GitHub.
- **Case studies based on real work must be anonymized:** no client names, and use generic data and numbers.

## Collaboration

- People request access through the **"Collaboration request" issue form**.
- The form must **not** have an email field, because issues are public.
