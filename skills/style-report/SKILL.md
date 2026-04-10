---
name: style-report
description: File a difficulty report when the style guide has a gap, produces the wrong result, or a rule is consistently missed. Use when the user says "file a style report", "report a style issue", or "/style-report". Also invoke proactively when you notice a style guide gap during review or code generation work.
---

# Style Report

File a difficulty report describing a gap, error, or strengthening signal in the style guide. Reports are the primary feedback mechanism from project use back to rule development - they travel from the project environment to a separate training environment where the style guide is updated.

## When to File a Report

File a report when you encounter any of:

- **Gap** - a situation the style guide says nothing about
- **Error** - a situation where following the guide produces the wrong result
- **Tooling gap** - a mechanical check that misses a pattern it should catch
- **Capability finding** - a model-specific behavior that affects rule application (e.g. one model catches a pattern reliably, another does not)
- **Strengthening signal** - a rule the guide already covers but you or another agent missed or misapplied. This is a signal the rule text is not strong enough.

Report verbosely. The training agent can prune a finding that turns out to be noise, but cannot infer information that was not reported. When in doubt, include the finding.

## What a Report Contains

### Report header

- **styleguide-commit** - the commit hash of the style guide at the time of the finding. Obtain with `git -C <styleguides_repo> rev-parse HEAD` where `<styleguides_repo>` is the cloned styleguides directory (derive its path from the `@` import in the project's CLAUDE.md, or from `deps/styleguides/`). This lets the training agent check whether the finding was already addressed in commits after that point.
- **date** - the date the report was generated (YYYY-MM-DD).

### Each finding

- **file** - which guide file is affected (e.g. `c/CLAUDE.md`, `general/collaboration.md`)
- **section** - which section within that file, or `(no existing section)` for gaps
- **says** - what the guide currently says (direct quote or paraphrase), or `nothing` for gaps
- **should-say** - what the guide should say, written as a concrete rule statement
- **evidence** - what happened that revealed the finding. Include the model and role of the agent involved (e.g. "Sonnet generator", "Opus formatter", "Haiku single-rule reviewer"). If multiple models were tested, include comparative results.
- **resolved** - `yes` if you worked around the issue, `no` if it blocked progress

### What NOT to include

- Operating system or platform information (not relevant to style rules)
- Timestamps (the file name carries the date)
- Cost estimates or severity ratings (the training agent evaluates priority)

## Report Format

```markdown
# Difficulty Report
- styleguide-commit: <hash>
- date: <YYYY-MM-DD>

## Short title describing the finding
- file: path/to/guide/file.md
- section: ### Section Name
- says: what the guide currently says
- should-say: what the guide should say
- evidence: what happened, which model/role, comparative results if available
- resolved: yes/no

Additional context, examples, or test data if needed.
```

Multiple findings go in a single report file. Each finding is a separate `##` section.

## Report Location

Write reports to `.claude/reports/style/` in the project directory, named `style_report_<YYYY-MM-DD-HHMMSS>.md`. The filename includes `style_report` so that when the report is transferred to another machine for training, the report type is preserved independent of its directory context. Create the directory if it does not exist.

A project can override the report location by specifying a path in its CLAUDE.md:

```markdown
## Style Guide Reports
Difficulty reports are written to: path/to/reports/
```

If an override is present, use it. Otherwise default to `.claude/reports/style/`.

## Reports Are Transient

Each report is a self-contained artifact that will be transferred to a separate training environment and deleted from the project afterward. This has specific implications for how to handle the reports directory:

- Do not look for a "latest" report to append to.
- Do not assume a prior report is still present.
- If the reports directory is empty, that is the normal state - prior findings have already been ingested.

**Default behavior:** create a new report file for each batch of findings. Do not merge new findings into an existing report file on your own initiative, even if one happens to be present - you cannot reliably know whether that file has already been read by the training agent.

**User override:** if the user explicitly asks to append to the last report (e.g. "add this to the report I just filed"), append to it. The user has context about whether the prior report is still present and whether the new finding belongs with it. The default rule exists to prevent guessing about state that cannot be verified; an explicit user instruction removes that uncertainty.

**If the referenced report is missing:** when asked to append to a specific report and the file does not exist at the expected path, create a new report instead. Do not search the filesystem for it in other locations. A missing report means it has already been transferred and deleted - that is the expected state, not an error. Searching elsewhere risks writing to stale copies in backups or old clones.

## After Writing the Report

Tell the user where you wrote the report and briefly what it contains. Do not attempt to "ingest" or "apply" the report yourself - report ingestion is a training-agent task that happens in a separate environment. Your job is to capture the finding and stop.
