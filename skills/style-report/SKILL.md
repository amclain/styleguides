---
name: style-report
description: File a difficulty report when the style guide has a gap, produces the wrong result, or a rule is consistently missed while writing or reviewing code style. Use when the user says "file a style report", "report a style issue", or "/style-report". Also invoke proactively when you notice a style guide gap during code style review or code generation work.
---

# Style Report

File a difficulty report capturing evidence about a gap, error, or strengthening signal in the style guide. Reports are the primary feedback mechanism from project use back to rule development - they travel from the project environment to a separate training environment where the style guide is updated.

## What the Style Guide Governs

The style guide governs **how source code is written and reviewed for style** — naming, formatting, comments and docstrings, structural conventions, idiom selection, and the language-specific equivalents of those concerns. A style report captures failures of that: a code style decision the guide got wrong, a gap in the style rules, a style rule an agent missed when writing or reviewing source code.

The styleguides repo contains files beyond the rule text itself — `general/review-orchestration.md` describes the standalone style-review framework, `general/review-pipeline.md` covers multi-stage pipeline composition, `general/agents.md` describes agent capabilities, `skills/` contains workflow instructions. **Findings about those files are not style reports.** A finding that the style-review framework dispatches the wrong tasks, that agent orchestration in your project's dev-phase pipeline went sideways, that a skill's instructions were ambiguous, or that multi-stage review composition needs different doctrine — none of those are style reports, even though the file you were reading lives in the styleguides repo.

The gate question to apply before filing a report: **what source code, under review or generation, produced this finding?** If you can quote the source code in question and the style decision the guide got wrong about it, the finding is in scope. If the "code" is your own dispatch plan, your own task decomposition, or your own orchestration choices, the finding is out of scope for a style report. The styleguides repo currently has no separate intake channel for orchestration or workflow findings; capture them in your project's own notes if useful, but do not file them as style reports.

## When to File a Report

File a report when you encounter any of the following **while writing or reviewing source code style**:

- **Gap** - a code style situation the guide says nothing about
- **Error** - a code style situation where following the guide produces the wrong result on actual source code
- **Tooling gap** - a mechanical check on source code that misses a style pattern it should catch
- **Capability finding** - a model-specific behavior that affects style rule application to source code (e.g. one model catches a style pattern reliably, another does not)
- **Strengthening signal** - a style rule the guide already covers but you or another agent missed or misapplied when writing or reviewing source code. This is a signal the rule text is not strong enough.
- **Local resolution** - the project hit a style gap or error and arrived at a rule text that produces the right behavior locally on source code. The hardened rule text is one piece of evidence the report captures alongside the original failure evidence.

## Reports Are Evidence-Only

Reports are filed at the moment a failure occurs, by the agent that hit the failure. That agent is, by definition, in a state where its judgment about its own thought process, the causal sequence of the conversation, and the right rule wording is unreliable. **Anything that requires reliable cognition from the reporting agent is contamination, not corpus**, and the training agent has no way to detect contamination from inside the report.

A reporting agent can reliably produce **evidence**: verbatim quotes from its own output, verbatim quotes from the user's correction, file and section pointers, and direct quotations of guide text that was being applied. A reporting agent **cannot reliably produce**: a description of what it was thinking, a causal narrative ("I did X because Y"), a prescription of what the rule should say, a generalization of the failure ("agents tend to..."), a common-thread synthesis across multiple findings, or a self-assessment of whether the issue was resolved.

The format below is built on this distinction. Capture evidence verbatim; do not interpret it. The training agent does the interpretive work in its own session, against a fresh context, with the validation discipline that role requires. Evidence-only reports are sometimes shorter than the agent feels they should be — that is the correct shape, not an incomplete report.

If you cannot cite specific evidence for a finding (no draft text to quote, no user correction to quote, no specific guide section to point at), that absence is itself a signal worth surfacing. Note the finding briefly with what evidence is and isn't available; the training agent can decide whether to pursue it. A finding that cannot cite primary evidence is more often a fatigue artifact than a real gap, and the training agent treats it accordingly — but does not discard it on that basis alone.

## What a Report Contains

### Report header

- **styleguide-commit** - the commit hash of the style guide at the time of the finding. Obtain with `git -C <styleguides_repo> rev-parse HEAD` where `<styleguides_repo>` is the cloned styleguides directory (derive its path from the `@` import in the project's CLAUDE.md, or from `deps/styleguides/`). This lets the training agent check whether the finding was already addressed in commits after that point.
- **date** - the date the report was generated (YYYY-MM-DD).

### Each finding — required fields

- **file** - which guide file is affected (e.g. `c/CLAUDE.md`, `general/collaboration.md`).
- **section** - which section within that file, or `(no existing section)` for gaps.
- **guide-text** - direct quote of the relevant guide text the agent was applying or attempting to apply. For gaps, write `(no existing rule)`. Do not paraphrase; copy the prose verbatim from the file. If the relevant text spans multiple paragraphs, quote the smallest contiguous span that captures the rule the failure relates to.
- **agent-output** - direct quote of what the agent produced (the draft, the test name, the code, the review verdict — whatever the failed output was). Verbatim. If the output was lengthy, quote the specific portion the failure was about; do not summarize.
- **user-correction** - direct quote of the user's correction, if the failure surfaced through a user correction. Verbatim. If the correction came in pieces across multiple turns, quote each turn's relevant portion. If the failure surfaced without a user correction (e.g. the agent caught its own output during review), write `(self-detected)` and capture in `agent-context` what the agent saw that flagged it.
- **agent-context** - role and model of the agent that hit the failure (e.g. `Sonnet code-generator`, `Opus formatter`, `Haiku single-rule reviewer`). One short line; this is metadata, not narrative.

### Each finding — optional fields

- **project-rule-text** - if the project iterated to a hardened rule wording and stored it locally, include the verbatim text here AND a pointer to the file it lives in. Do not summarize the iteration path that produced it; quote only the final text. The training agent can adopt this text directly (subject to upstream validation). Omit this field if no hardened text exists.
- **comparative-data** - if the failure was tested against multiple models and the results differed (e.g. Sonnet missed, Opus caught), capture the results as a table or short list. Verbatim outputs from each model where possible. This is evidence, not interpretation.

### What NOT to include

- Operating system or platform information (not relevant to style rules).
- Timestamps (the file name carries the date).
- Cost estimates or severity ratings (the training agent evaluates priority).
- The agent's description of its own thought process during the failure ("I was treating this as X when I realized Y"). This is reconstructed narrative, not evidence.
- Generalizations beyond the immediate finding ("agents tend to...", "this is a common pattern of..."). The training agent identifies patterns across reports; a single report does not generalize.
- Cross-finding "common threads." If a session produces multiple findings, list them as independent findings. The training agent identifies real connections during ingestion. If the project agent has trouble citing distinct evidence per finding, that is a signal worth letting the training agent see, not a problem to paper over with a synthesis.
- Proposed solutions, mechanisms, conventions, or rule wordings — whether under a labeled field or as inline prose ("the rule should be...", "the project adopted...", "every X must..."). The reporting agent is not the authority on the guide; the training agent decides what the rule says. Project-side resolutions belong in `project-rule-text` (verbatim hardened text only, no narrative about how it was arrived at) — not in additional prose.
- A reporting agent's reconstruction of "what happened" as connected narrative — iteration paths, sequence of attempts, why one wording worked and another didn't. The required fields above capture the same information as evidence (verbatim quotes of what was on the page and what was said) without the reconstruction step, which fatigued agents tend to smooth, dramatize, or selectively recall.

## Report Format

```markdown
# Difficulty Report
- styleguide-commit: <hash>
- date: <YYYY-MM-DD>

## Short title describing the finding
- file: path/to/guide/file.md
- section: ### Section Name
- guide-text: |
    (verbatim quote of the guide text being applied, or "(no existing rule)" for gaps)
- agent-output: |
    (verbatim quote of the agent's output that revealed the failure)
- user-correction: |
    (verbatim quote of the user's correction, or "(self-detected)")
- agent-context: <role> <model> (e.g. "Sonnet code-generator")
- project-rule-text: |
    (optional — verbatim hardened rule text, if any)
    Source: path/to/project/file.md, section/heading
- comparative-data: |
    (optional — verbatim results from multiple models, if tested)
```

Multiple findings go in a single report file. Each finding is a separate `##` section. Findings are listed independently — do not introduce a synthesis paragraph or cross-finding analysis.

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
