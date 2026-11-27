# Contributing

Thanks for helping improve the Data Engineering Interview Guide!

## Requesting Access

Open a **[Collaboration request](https://github.com/shriram-pawar/data-engineering-interview-guide/issues/new?template=collaboration-request.yml)** issue. Issues are public: full name and LinkedIn URL are optional and will be visible to anyone, and you shouldn't include your email address or phone number. Your GitHub username is all that's needed for an invite.

You don't need access to contribute: you can fork the repo and open a pull request from your fork.

## Workflow

> **Direct pushes to `main` are not allowed.** All changes go through a pull request.

1. **Sync `main`**
   ```bash
   git checkout main
   git pull origin main
   ```
2. **Create a branch** using one of these naming patterns:
   - `feature/<topic>`: new content (e.g. `feature/spark-optimization-questions`)
   - `fix/<topic>`: corrections (e.g. `fix/scd-type2-typo`)
   ```bash
   git checkout -b feature/<topic>
   ```
3. **Make your changes** and commit with clear messages.
   ```bash
   git add .
   git commit -m "Add questions on Spark partitioning"
   ```
4. **Push and open a pull request** against `main`.
   ```bash
   git push -u origin feature/<topic>
   gh pr create --base main
   ```
5. **Review**: at least one approval from a code owner is required. New commits dismiss earlier approvals.

## Content Guidelines

- Put content in the right folder (see the main [README](README.md)).
- **Original content only.** Don't copy paid course material, LeetCode, DataLemur or other copyrighted content. Explain concepts in your own words, with your own schemas and data.
- Question-bank files must follow the format in [`04-question-bank/README.md`](04-question-bank/README.md): **Question, Answer, Follow-ups, Difficulty**. For SQL, add a **BigQuery version** wherever the syntax differs.
- System design case studies follow the layout in [`05-system-design/README.md`](05-system-design/README.md). Start from [`templates/case-study/`](05-system-design/templates/case-study/).
- **Anonymize anything based on real work:** no client or company names, and use generic data and numbers.
- Use lowercase, hyphen-separated file names (e.g. `window-functions.md`).
- Make sure code samples run, and say which versions you used (Python, Spark, Airflow, etc.).
- Don't commit credentials, keys, or proprietary/confidential data.

## Rights to Contributions

By submitting a contribution (a pull request, issue content or any other material), you confirm it is your own original work and you **grant Shriram Pawar the rights to your submission**, including a perpetual, worldwide, irrevocable, royalty-free right to use, copy, modify, publish and relicense it, as part of this guide or otherwise. The guide stays under the copyright notice in the [README](README.md).
