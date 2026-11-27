# 05 · System Design

Data platform case studies (mostly migrations) and templates for design interviews.

## Structure

```
05-system-design/
├── case-studies/
│   └── <project-name>/
│       ├── diagrams/                # editable .drawio or .excalidraw files + PNG exports
│       ├── README.md                # overview, business problem, summary
│       ├── legacy-architecture.md
│       ├── target-architecture.md
│       ├── migration-design.md      # approach, stack mapping (replaced / kept / retired), validation, cutover
│       └── lessons-learned.md       # challenges, trade-offs, interview talking points
└── templates/
    ├── case-study/                  # copy this folder to start a new case study
    └── design-doc-template.md       # for greenfield "design a system" interview questions
```

## Adding a Case Study

1. Copy `templates/case-study/` to `case-studies/<project-name>/`, using a lowercase, hyphenated name.
2. Fill in each file, and add the editable diagrams with PNG exports to `diagrams/`.
3. **If it's based on real work, anonymize it:** no client or company names, and use generic data and numbers.

## Case Studies

| Case study | Summary |
|---|---|
| [sample-retail-sales-migration](case-studies/sample-retail-sales-migration/) | On-prem SQL Server/SSIS sales warehouse to Cloud Storage, Dataproc Serverless, BigQuery, Composer and Looker (sample) |
