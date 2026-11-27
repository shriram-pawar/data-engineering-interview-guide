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

## Real-world asked questions

`04-question-bank/real-world-asked/` holds questions people were **actually asked** in interviews (see its `README.md`).

- **One file per skill** (`sql.md`, `gcp.md`, …), created only when it has questions; add a new skill file if none fits. Never create empty files.
- **One `## <Company>` section per company**, or `## Unspecified company`.
- Each question adds three fields to the standard format: `**Role:**`, `**Round:**` and `**Asked:**` (month and year). Leave them blank when unknown.
- **Contributor rules:** only questions the contributor was asked themselves; no copied posts, blogs or course content; nothing under NDA; no interviewer or candidate names; no client names, internal project names, real project IDs or datasets.
- **When importing notes from others**, sort each question into one of three groups:
  - **A.** Clearly copied from websites or posts: rewrite in original wording, skip duplicates, and put it in the regular topic folders (not `real-world-asked/`).
  - **B.** Looks genuinely asked (personal wording, specific scenario, company or round mentioned): put it in `real-world-asked/`.
  - **C.** Not sure: don't import; list it for the user to check with the source.
- Don't commit source documents or screenshots. Add an image to `assets/images/` only if it's original, has no personal details or logos, and isn't copied from a website; otherwise recreate diagrams as Mermaid.

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
- The form must **not** have an email field, because issues are public. GitHub username is required; full name and LinkedIn URL are optional and labelled as public.
- Blank issues are disabled (`.github/ISSUE_TEMPLATE/config.yml`).
- Contributors grant Shriram Pawar the rights to their submissions (see "Rights to Contributions" in `CONTRIBUTING.md`).
