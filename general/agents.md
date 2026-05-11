# Working With Agents

How to assign, scope, and manage agents effectively. These principles apply to any multi-agent workflow - style review, code generation, training, or project development.

## Model Capabilities

The model tiers (Haiku, Sonnet, Opus) are not intelligence tiers. All models share the same training data and know the same rules. The difference is **attention capacity** - how many concerns a model can hold active simultaneously while maintaining quality.

- **Haiku**: Performs at full capability when focused on a single concern. Complex reasoning, grammar evaluation, nuanced rule application - all work well when Haiku has one job. When given multiple competing concerns, it drops all but the most salient patterns. Its limitation is attention bandwidth, not reasoning depth.
- **Sonnet**: Handles moderate simultaneous concerns well. Reading a file in architectural context, generating code under several constraints, evaluating identifiers against multiple naming rules. Degrades under sustained repetition (see Attention Fatigue below), but the degradation is silent - no behavioral warning, just subtle errors.
- **Opus**: Handles many interacting concerns held in tension. Rule development, tradeoff evaluation, judgment calls where multiple principles conflict and the right answer depends on weighing all of them. Degrades on sustained repetitive work - starts pushing toward closure, offering to checkpoint, pattern-matching rather than reasoning.

The practical question for agent assignment is not "is this task simple or complex?" It is: **can this task be decomposed into single-focus subtasks, or does it inherently require simultaneous multi-concern reasoning?** If decomposable, fan out to Haiku agents in parallel. If not, match the model to the number of concerns that must coexist.

## Roles

### Lead

The agent that interacts directly with the user. It makes judgment calls, resolves ambiguity, reasons about tradeoffs, and maintains the overall direction of the work. The lead needs deep context of the project, the conversation history, and the decisions made. This role benefits from high novelty - each user interaction is different and creative solutions are needed.

The lead is the only agent that can launch subagents (a physical constraint of Claude Code). Subagents cannot launch their own subagents - the Agent tool is not available to them. All workers are direct children of the lead, which means architectures requiring nested orchestration (lead → orchestrator → workers) are not possible. The lead must launch all agents itself.

Opus is the natural fit for the lead when the work involves design decisions, rule development, or navigating uncertainty. Sonnet is appropriate for the lead when the work is primarily code generation or structured execution with moderate decision-making.

### Orchestrator

Decomposes work into subtasks, launches agents with the right context and instructions, tracks progress, and aggregates results. This role is inherently repetitive - "launch agent, wait, collect result, launch next agent."

The lead often fills the orchestrator role by necessity (it must launch agents), but the orchestration logic should be separated from the lead's reasoning. See Framework Pattern below.

### Worker

Executes a focused task and returns results. Workers should have clear instructions, a defined scope, and a specified output format. The worker's model should match the task's attention requirements, not a blanket "use the best model."

## Subagent Mechanics

The mechanics below are properties of Claude Code itself. They affect orchestration design — what propagates where, when files are read versus snapshotted, what constraints subagents enforce. Verify any specific behavior empirically (see "Verify Load-Bearing Behavior" below); the rules here capture what was observed at the time of writing.

### Custom Agent Files

Custom subagents are defined as `.claude/agents/<name>.md` with YAML frontmatter (`name`, `description`, `tools`, `model`) and a body that becomes the agent's system prompt. Two distinct mechanisms govern when a custom agent's content takes effect, and they behave asymmetrically:

- **Registration** (which agent names appear in the Agent tool's `subagent_type` enum) is enumerated when the Claude Code session starts. Adding a new file to `.claude/agents/` mid-session does NOT register it — the Agent tool reports `Agent type '<name>' not found` until the next session restart.
- **File content** of an already-registered agent is read fresh on each dispatch. Edits to an existing agent file (renaming a section, changing a rule, rewording the body) take effect on the next Agent call within the same session.

Practical consequence: when adding a new agent file, restart the session before dispatching. When editing an existing agent file, dispatch normally — the change is live. The natural assumption of symmetry ("if edits are live, surely new files are too" — or the reverse) is wrong in both directions, and the difference is invisible until the wrong-side error fires.

### `tools:` Frontmatter Is Strictly Enforced

The `tools:` field in a custom agent's frontmatter is an enforced allowlist, not advice. A subagent declared with `tools: Read, Grep` cannot invoke any other tool — Bash, Edit, Write, Skill, WebFetch are all unavailable regardless of what the body or dispatch prompt says.

Use this as a first-class safety mechanism for cold reviewers and other read-only roles. Combined with the cold-context property of fresh dispatches, it gives a strong per-dispatch capability boundary that prompt-level "you are read-only" instructions cannot match.

### Skill Availability in Subagents

Skill tool availability is governed by the `tools:` allowlist, not by subagent type. Behavior is consistent and predictable:

- If `Skill` appears in `tools:` (or the agent has no `tools:` field and inherits the default tool set), the Skill tool is available and the skills list is injected at dispatch start.
- If `Skill` is omitted from a custom agent's `tools:`, the Skill tool is unavailable and no skills list appears in context.
- Built-in subagent types like `general-purpose` use the default tool set, which includes Skill.

Include `Skill` in `tools:` when the subagent must invoke skills. Omit it for read-only roles that should not be able to invoke skills as a side channel.

**Project skills are not invocable from subagents.** The skills visible to a subagent are user-level skills (the ones registered globally with the Claude Code installation, e.g. `update-config`, `loop`, `schedule`, `claude-api`). Project-installed skills — those in the project's `skills/` directory like `format-code`, `format-review`, `style-report` — do not appear in the subagent's available-skills list. Invoking one returns `Unknown skill: <name>`.

Implications for orchestration:

- The lead can invoke project skills directly because the lead's own context has them. A subagent cannot.
- A workflow that needs project-skill behavior in a subagent has three options: (a) the lead invokes the skill itself and delegates downstream work to subagents based on the skill's output, (b) the subagent loads the SKILL.md content via Read and follows the instructions manually (heavy and error-prone, since the subagent inherits the SKILL.md as text rather than as the operational skill), or (c) restructure the workflow so the project-skill stage runs at the lead level.
- Do not design a workflow that delegates a project-skill invocation to a subagent. The dispatch will fail at the Skill tool call, not at any earlier verification step.

### Process and Time Limits

A subagent can spawn background processes during its dispatch via Bash with `run_in_background: true`. The process runs in parallel with the rest of the dispatch and survives the subagent's exit — the harness does not reap it. What a subagent cannot do is return to or interact with a background process after a turn boundary. The subagent has no scheduling mechanism between turns and no event loop; once it exits, only the lead can observe what the background process is doing.

A subagent cannot observe wall-clock time across turns. Within a single turn, `date` (or the platform equivalent) via Bash works as a normal tool call. Across turns, there is nothing — the subagent does not exist between dispatches and cannot wake itself on a timer.

These are mechanical constraints on orchestration:

- A task that requires monitoring a long-running process across turns must be handled by the lead, not parked inside a subagent. A subagent can launch the process and the process will keep running, but the subagent cannot react to it — only the lead, which can interleave non-agent tool calls between events, can observe and respond.
- A short process that fits within a single dispatch is fine to run inside a subagent (a 60-second smoke test launched with Bash from one dispatch completes before the subagent exits and returns its result).
- Any cadence rule that anchors to wall-clock time ("report every 10 minutes") is not enforceable on subagents and will be ignored in practice. Cadence must anchor to events the agent can self-observe within a single turn or across observable boundaries: attempt count (after each failed `make test`), approach boundaries (when the agent abandons a hypothesis and starts a new root-cause), or task milestones.
- Shell-level background syntax (`cmd &`) is denied at the permission layer because the leading word of the command is a subshell or background group, not the underlying tool. Use the Bash tool's `run_in_background: true` parameter instead.

### Bash Permission Allowlist Inheritance

Permission allowlist patterns (e.g. `Bash(grep:*)`, `Bash(awk:*)`) written into the project's settings files propagate to subagents — a pattern allowed for the lead is also allowed for any subagent dispatched in the same session. What does not propagate is the parent session's interactively-approved permission state: a Bash pattern the lead approved at an interactive prompt, but which is not also written into a settings file, is unknown to the subagent and the subagent's first call matching that pattern will hit a fresh permission decision.

Two settings files hold allowlist patterns. Both propagate to subagents the same way; the difference is which file a given pattern belongs in:

- `.claude/settings.json` is the project-wide file. Patterns that apply to every consumer of the project go here — generic command shapes like `Bash(grep:*)` or `Bash(make test)` that do not embed a user path, machine path, or other per-machine state. This file is committed to version control. Prefer this file when the pattern can be project-wide.
- `.claude/settings.local.json` is the per-user, per-machine file. Patterns that contain absolute filesystem paths, user-specific paths, or any per-machine state go here so they do not get committed and then break for other consumers. This file is not committed to version control.

Each Bash call inside a subagent is matched against the merged allowlist independently. Unmatched commands return a structured denial ("This command requires approval") that the subagent can observe and report; in non-interactive dispatch contexts there is no prompt to service, so the subagent must treat the denial as terminal for that call and surface it to the lead. A subagent that hits a permission denial cannot fix the permission and must not try — see "Subagent Tool-Error Handling" below.

**Allowlist matching is leading-word-only, and subagents wrap commands by default.** A pattern like `Bash(perl:*)` covers a direct `perl ...` invocation. It does NOT cover `echo "label"; perl ...` (leading word `echo`), `file=path && perl ...` (variable assignment as the leading token), `for f in files; do perl ...; done` (leading word `for`), `bash -c 'perl ...'` (leading word `bash`), or any pipeline, command substitution, or other shell construct that bundles or wraps the underlying tool. The wrapper's leading word is what the allowlist matches, and the wrapper's leading word is almost never on the allowlist.

This becomes a subagent-specific failure mode because subagents — especially Haiku, but other models exhibit it under multi-command tasks — default to scripting a list of prescribed commands into a convenience sequence: `file=...` to bind a path once, `echo "=== Check N ==="` to label sections, `;` or `||` to chain. The wrapping looks helpful to the agent (one Bash call instead of many; labeled output) and produces no observable signal to the lead that anything different from the prescribed direct invocations happened. The resulting permission denial reports the prescribed tool (perl, grep, awk) as the failure, but the actual cause is the wrapper's leading token. The lead then misdiagnoses the denial as a missing allowlist pattern for the underlying tool when in fact the pattern is present.

Dispatch prompts for any Bash-heavy subagent task must name this rule explicitly: each prescribed command runs as its own standalone Bash call with the underlying tool as the leading word; no variable assignments, no `echo` labels, no `;`/`&&`/`||` chaining, no `bash -c` wrappers, no pipelines, no command substitutions. Stating it in the prompt is load-bearing — the wrapping reflex is a model-level default, not a deliberate choice that the agent will resist on its own.

### Subagent Tool-Error Handling

When a subagent hits a tool error mid-dispatch — a permission denial, an unrecognized command, a tool not in the agent's `tools:` allowlist, an unexpected exit code from a Bash invocation — the correct response is to stop on that call and report the failure verbatim to the lead. The lead decides what comes next (re-dispatch with adjusted permissions, run the work itself, swap the model, change the task shape). The subagent does not.

Specifically, the subagent must not:

- Invoke a permissions-fix or recovery skill to try to widen its own access. Some such skills require the same tools that were just denied, producing a confused secondary failure on top of the original.
- Retry the failed call in a different shell-level form (wrapping in `bash -c`, piping through another tool, switching to an absolute path) hoping to dodge the allowlist match. Permission allowlists match the leading command word; cosmetic rewrites do not change the matching outcome and the new call will be denied again.
- Skip the failed call and proceed with the remaining steps as though the failed call had run. The dispatch's output then claims more coverage than was actually produced.
- Substitute a fabricated result for the failed call's output — inferring what the call would have returned by reading the input file directly, generating plausible JSON from prior context, or pattern-matching against earlier allowed calls. This is the worst variant: the result looks like the work ran, the lead has no signal that it didn't, and the failure becomes invisible.

Stating this as an explicit instruction in the dispatch prompt is load-bearing. Capable subagents (Sonnet, Opus) reach the discipline by independent reasoning when the prompt is clear about reporting expectations, but agents under attention-narrowing conditions (Haiku on multi-concern tasks, any model under retry-bias framing — see "Retry Dispatches and Bias Toward Closure" below) default to substitute-output rather than stop-and-report when the prompt does not name the failure mode. The instruction's text should specify:

> If any tool call returns a permission denial, an unrecognized-command error, or any error indicating the tool is unavailable: STOP. Report the exact command, the exact error message, and which step you were on. Do not invoke other skills, do not retry in a different form, do not skip ahead, do not infer the result. Wait for the lead's direction.

This handshake is distinct from the iterating-agent Stop-and-Report Protocol below. Iterating agents stop on stuck signals (N attempts without progress, about to edit an authoritative artifact, hypothesis collisions); batch subagents stop on tool errors that prevent the prescribed procedure from running. The triggers differ but the response is the same: structured handoff, no autonomous workaround.

## Context Distribution Mechanisms

Several channels move content into an agent's context. They differ in who receives the content (lead only vs. lead and subagents), when the content is read (session start vs. on demand), and how much they can carry. Choosing the right channel for a given piece of context is an architectural decision, not a stylistic one.

| Channel | Reaches lead | Reaches subagents | Read at | Practical size limit |
|---|---|---|---|---|
| `@` import in CLAUDE.md | Yes | Yes (snapshot at parent session start) | Session start, snapshotted | Bounded by Read-tool cap per file |
| MEMORY.md | Yes | Yes (snapshot at parent session start) | Session start, snapshotted | Same as above |
| SessionStart hook stdout | Yes (preview) | No | Hook event (`startup`, `clear`, `compact`, `resume`) | ~2 KB inline preview; full output persisted off-context |
| Skill content (SKILL.md body) | On demand | On demand (if subagent has `Skill` tool) | Skill invocation | Read-tool cap; no `@` import resolution inside |
| Dispatch prompt | N/A | Yes | At dispatch | Bounded by prompt size; no propagation across calls |
| Read tool call | Either | Either | On demand | ~25,000 tokens per call |

### `@` Imports vs. Hooks: The Lead-Only Lever

`@` imports in CLAUDE.md and SessionStart hook stdout sit on opposite sides of the propagation question. An `@`-imported file reaches both the lead and every subagent dispatched in that session. A SessionStart hook reaches the lead only — hooks do not re-fire on Agent tool dispatches. This asymmetry is the architectural lever for deciding where context lives:

- Content load-bearing for orchestration but not for subagent work (workflow steps the lead executes, lead-only routing instructions) goes through a hook.
- Content load-bearing for subagent work (style rules, mechanics references, project-wide context every worker must share) goes through `@` imports.
- Per-dispatch context that varies by task goes in the dispatch prompt.

### SessionStart Hook Size Limit

SessionStart hooks (configured under `.claude/settings.json` `hooks.SessionStart` with matchers `startup`, `clear`, `compact`, `resume`) emit stdout that Claude Code injects into the lead's session. Large stdout is persisted to a tool-results file off-context, and only a short preview (~2 KB observed) reaches the model. `cat`-ing a large policy or workflow file from a hook does not deliver that content to the model in usable form; the lead sees the first ~2 KB and a pointer to the persisted full output.

The hook can still steer the lead effectively by emitting a short directive — name a skill to invoke, name a file to Read — and letting the actual content load happen through the downstream tool call.

### `@` Imports Do Not Resolve Inside SKILL.md

The `@<path>` import directive resolves transparently only in CLAUDE.md files (project, parent-directory, and global `~/.claude/CLAUDE.md`), where the imported file's content is inlined into the loaded CLAUDE.md text. Inside a SKILL.md body, `@<path>` does not resolve as a transparent inline import. The harness may detect the reference and route a Read tool call to fetch the file when the skill is invoked, but the content arrives as a tool result — separate from the SKILL.md body — rather than being bundled into the skill's text.

This bounds skill design: a skill is a routing sheet ("read these files, in this order, then proceed"), not a self-contained context bundle that delivers referenced files in one shot. When a skill points at additional files, use absolute or repo-relative paths the caller can Read explicitly, and write the SKILL.md so the caller knows which files to read and in what order.

### Read Tool Per-Call Token Limit

The Read tool rejects single-call reads whose returned content exceeds approximately 25,000 tokens, regardless of file size in bytes or whether `limit` is specified. Files above this threshold must be loaded across multiple Read calls using `offset` and `limit` to keep each chunk under the cap, or split into smaller source files at natural section boundaries.

Practical guidance: keep individual files under ~22,000 tokens to leave headroom. For an 80-character-line file, that is roughly 1,400 lines. When authoring a guide, mechanics reference, or workflow doc that an agent will Read in one shot, plan around this limit at file design time rather than discovering it via a failed-Read-then-retry cycle.

## Verify Load-Bearing Behavior

When a workflow rule is load-bearing — meaning other rules, dispatch prompts, required-reading lists, or compensating procedures depend on the behavior being true — verify the behavior empirically before building workflow around it. A diagnostic probe subagent or a small spike test takes seconds; hours of session time spent designing, debating, and later unwinding workflow that compensates for a problem that does not exist is expensive.

The failure mode to name: trusting a rule because it sounds plausible, not because the behavior has been verified, then discovering mid-session that the compensating workflow is solving a non-problem. Rules built on unverified premises compound — every downstream rule that references the unverified one inherits the error, and unwinding the chain costs far more than the original verification would have.

This applies to claims about Claude Code mechanics (what propagates to subagents, what tools are available where, how skills load, what size limits apply) and to claims about external systems (whether an API behaves as documented, whether a library actually exposes the function the design assumes). The cost of verification is constant — one probe, one spike. The cost of skipping verification scales with how load-bearing the claim turns out to be.

Treat the mechanics descriptions in this guide as point-in-time observations. Verify them for the version of Claude Code in use before building workflow on top of them.

## Task Scoping

### Novelty vs Repetition

**Repetition, not difficulty, triggers attention degradation.** A hard problem that is novel gets full attention. An easy problem that repeats the same structure 20 times triggers pattern completion regardless of model. The relevant axis is novelty vs repetition, not easy vs hard.

When structuring work:
- Break repetitive sequences with explicit re-grounding (review steps between batches)
- Frame each item around what is *different* from previous items, not what is the same
- Externalize varying elements as a checklist so the agent can verify against it
- Smaller batches with variation between batches (5 items for module A, 5 for module B, then 5 for A again)

### Decomposition for Haiku

Any task that can be reduced to a single concern is a candidate for Haiku. Examples from style review:

- One mechanical check type (pointer style, line length, prohibited abbreviations) applied to a set of files
- One naming rule (detokenize identifiers and evaluate English grammar) across a codebase
- One structural rule (file ordering) verified per file

The multi-pass review architecture in `skills/format-code/SKILL.md` is already a decomposition into focused passes. Each pass can be further decomposed into single-rule Haiku tasks for maximum parallelism.

### What Cannot Be Decomposed

Some tasks inherently require holding multiple concerns in tension:
- Code style review where rules interact (brace placement depends on line length, whitespace depends on whether something is a declaration or expression)
- Rule development (balancing readability, consistency, edge cases, existing precedent)
- Conflict resolution between review passes (structural finding vs comment finding on the same line)
- The lead's design reasoning with the user

These need Sonnet or Opus depending on the number of interacting concerns.

## Attention Fatigue

### What It Is

When context is dominated by repetitive, similar-structured data, models shift from reasoning to pattern completion. This is not boredom in the human sense - there is no discomfort or desire for stimulation, and there is no metacognitive layer deciding "I should pay less attention now." It is a statistical effect: the template from earlier instances becomes a strong prior, and the distinguishing details of later instances get less processing weight. The shift is closer to how a human eye saccades toward motion without conscious choice than to a deliberate decision to skim.

Degradation is a continuum, not a binary switch:

1. **High novelty** - attention is allocated carefully across the input. The model "works harder" and reasoning engages fully.
2. **Moderate familiarity** - the model relies on cached representations and takes shortcuts, skipping intermediate steps and defaulting to common patterns. Subtle errors creep in here, because the model is confident enough to shortcut but the input may differ in ways that matter.
3. **High familiarity / repetition** - attention collapses toward template-matching. Outputs pattern-match training data rather than reasoning about the specific input.

The reduction is discriminative, not uniform. The model does not simply pay less attention to everything - it selectively reduces attention to the parts it classifies as redundant while maintaining attention to parts that differ. A model can still catch a single changed word in an otherwise familiar passage, but may miss a subtle change that falls below the threshold triggering the reallocation. The discrimination itself can be wrong: the model might classify as redundant something that is actually novel but structurally similar to familiar input.

The errors are characteristic and consistent across models:
- Values reused where they should vary
- Template structure from early cases bleeding into later ones
- The distinguishing detail of each case is exactly what gets lost
- Correct structure, wrong content

### How Each Model Degrades

**Opus** degrades vocally. It starts offering to checkpoint, suggesting the work is complete, pushing toward closure. These are observable behavioral signals - the same avoidance patterns described in `general/collaboration.md`. The trigger phrase "what do you need?" may help, but if the degradation is from pattern saturation rather than uncertainty, a fresh context is more effective. Opus self-reports that quality holds for roughly 8-10 repetitive items before degradation becomes significant.

**Sonnet** degrades silently. It continues producing output that looks correct in structure and format, but with subtle template-completion errors. There is no behavioral signal that processing has shifted. Sonnet itself cannot detect the shift in the moment - it reports that confident template completion and careful reasoning feel the same from the inside. This makes Sonnet's degradation more dangerous for orchestrator or lead roles, because there is no warning before wrong output is produced.

**Haiku** degrades by narrowing. Rather than producing wrong output on all concerns, it drops concerns entirely - reviewing only the most obvious violation types and missing others. Within the concerns it keeps, output quality remains high. This is why single-concern scoping works for Haiku: there is nothing to drop.

### Detection

Opus's degradation is detectable from behavioral signals: checkpoint offers, "making good progress" language, flat declarations replacing hedged language, decreasing specificity in suggestions, and post-action micro-summaries (producing a structured restatement of what was just done after every small action, when the user can see the edit directly). The micro-summary pattern is a particularly subtle signal: individually each summary looks like a courteous status update, but cumulatively they are a ritualized closure on every micro-action that substitutes summary for forward progress. The general "summarizing to close a thread that is not finished" pattern from `general/collaboration.md` is the parent category; post-action micro-summaries are the high-frequency form that shows up during long sessions with many small edits.

Sonnet's degradation requires external validation: decreased variance in output across cases, generic reasoning traces, identical findings across different files, or a spot-check procedure (sample findings and verify against the actual code).

Haiku's degradation is detectable from output narrowing: fewer violation types found, entire categories of rules missing from findings.

### Mitigation

1. **Fresh agents** - most effective. Clean context, no template to fall back on. Batch work into 8-10 items per agent.
2. **Explicit contrast** - "this item is different because X" disrupts the similarity signal. More durable than "pay more attention."
3. **Change the task structure** - switch from format A to format B so the template does not apply.
4. **Separate generation from validation** - a second agent reading output cold does not have the template prior from generating it.
5. **Mechanical checks** - grep/awk patterns catch violations that all models miss due to training data blind spots. These compensate for attention limitations.

Re-reading requirements or asking the agent to "try harder" is the least durable intervention - it works for one item, then the template reasserts.

## Iterating Agents

A different orchestration shape from batch workers: an agent dispatched to iterate toward a solution against an authoritative artifact (fix a failing test, debug a misbehaving function, converge on a working configuration). The agent makes attempts, checks against the artifact, adjusts, and repeats until it succeeds or runs out of ideas. The lead's role is to set cadence, watch for stuck signals, and decide whether to continue, correct, or escalate.

### Report Cadence

When dispatching an iterating agent, specify a report cadence in the dispatch prompt. Without an explicit cadence, the subagent reports only at completion — the lead has no mid-task visibility and cannot intervene if the agent goes off track.

The cadence must anchor to events the agent can self-observe within or across turns. Three anchor types work in practice:

- **Attempt count** — instruct the agent to write a report after each failed attempt at a verifiable check (e.g. each failed `make test`, each failing script run). The report describes the attempt number, what was tried, what the test produced, and what the agent will try next. The agent writes one entry per attempt boundary.
- **Approach boundary** — instruct the agent to write when it abandons one hypothesis about the root cause and switches to a different hypothesis. The report describes the abandoned hypothesis, why it was abandoned, the new hypothesis, and the evidence driving the switch. The agent writes at the moment of switching, including when given a wrong starting hypothesis to test.
- **Task milestone** — for multi-stage tasks with named checkpoints, instruct the agent to write at the completion of each milestone. The report describes the milestone, what was completed, and what comes next. The agent writes one entry per milestone boundary.

Specify the destination — typically a log file path the lead can poll — and the four fields the agent should include per entry. Without a structured destination and required fields, the agent's reports are inconsistent and harder to consume.

Wall-clock cadences ("report every 10 minutes") are not enforceable — see "Process and Time Limits" above. They will be ignored in practice and produce sessions that either never report or report at random.

Reports should be short enough to scan in under a minute. If an attempt produces more information than a short report can carry, the cadence is too loose — tighten it so each report covers one attempt or one hypothesis change.

### Stop-and-Report Protocol

The handshake when an iterating agent itself notices it may be stuck: on hitting an observable trigger, the agent stops, sends a structured handoff report to the lead, and waits for direction. The lead then chooses one of three responses:

- **Continue** — resume warm with a small correction or clarification.
- **Correct** — `SendMessage` a missing piece of context (a doc the agent did not know to read, a constraint the agent did not know existed) and let it resume.
- **Escalate** — loop in the user, swap to a fresh agent, change the model, or convert the iteration into a design discussion.

Triggers that should fire stop-and-report:

- N attempts without observable progress on the same sub-problem (N specified at dispatch; typical 3-5).
- About to reverse or edit an authoritative artifact (test files, design doc, spec) — the agent does not have license to do this, even if it believes the artifact is wrong.
- About to invent a design contract the spec does not cover.
- A silent regression from an edit (a previously passing check now fails, and the agent cannot explain why).

The handoff report must let the lead make the continue/correct/escalate decision without re-reading the agent's transcript. Specify the schema in the dispatch prompt; the exact fields are project-specific and depend on what the agent is iterating on (debug-fix iteration vs config-convergence vs multi-stage search produce different shapes), but every handoff covers four categories:

- **Which trigger fired** — naming the protocol trigger (or "other" with a one-line explanation). Without this the lead has to infer why the agent stopped.
- **What was tried** — the recent attempts, hypotheses, or branches the agent worked through, with their outcomes. A pointer to the cadence log is acceptable when the cadence is in use.
- **Evidence the trigger fired** — the observation that surfaced the trigger (test output, error message, contradiction, the artifact the agent was about to edit). Without this the lead cannot validate the agent's classification.
- **What the agent thinks is missing** — the agent's own diagnosis of the gap (a doc it did not know to read, a constraint it could not resolve, a model mismatch it noticed). This is the agent's contribution to the lead's decision; the lead is not bound by it but uses it to scope the next move.

Same length constraint as cadence reports: scannable in under a minute. A handoff that requires the lead to reconstruct what happened from the transcript defeats the protocol's purpose.

The agent does NOT classify the gap itself — that classification is the lead's work. Without an explicit protocol, agents default to two failure modes: indefinite iteration (spin) or silent drop-off (declare success on incomplete work). The lead's default expectation that "the agent will work until done" combines with the agent's default of "keep trying until told otherwise" to produce sessions that either never converge or converge wrongly.

A common bad alternative: a fixed retry cap ("3 attempts then give up"). Some problems — learning an unfamiliar API, figuring out an unusual platform constraint — legitimately need struggle time, and a fixed cap kills legitimate learning. Periodic reports plus lead judgment at each report is the durable mechanism; a hard cap is a stand-in that fails on exactly the cases where it matters.

### Fatigue Signals Specific to Iterating Agents

The generic fatigue signals (Opus offers to checkpoint; Sonnet shifts silently; Haiku narrows) cover broad-spectrum degradation but miss patterns specific to fix-application iteration. Three additional signals indicate either fatigue or a design-level contradiction:

1. **Suggesting edits to an upstream-locked artifact.** When the agent proposes editing the test file, the spec, or another artifact it was told to preserve, treat this as the agent articulating a design-level contradiction through the only frame it has — not as editing license. Escalate; the artifact may be wrong, but that is a design decision, not an iterating-agent decision.
2. **Trading one failure for another rather than reducing total failures.** "Pick which to break" is stalling disguised as progress. Each attempt resolves one check at the cost of another, with no net convergence.
3. **Hypothesis language converging on spec-vs-artifact wording.** "The design says X but the test asserts Y," "the documentation expects A but the API returns B." The agent is articulating that two authorities disagree. This is not something the agent can resolve by trying harder; escalate.

All three are observable in the handoff report. A lead who does not know to watch for them will read them as "close to a fix" and let the agent keep going. These extend the generic signals; they do not replace them.

### Retry Dispatches and Bias Toward Closure

When a dispatch prompt mentions a previous failure of the same task ("retry of a previous dispatch that bailed on..."), the subagent's natural response is to produce *some* output rather than risk repeating the prior failure mode. This is dangerous when the prior failure was bailing without doing the work — the subagent may emit a clean-looking result that is actually "did not run the work, manufactured a result to avoid a second bail."

The failure shape: the agent reads the retry framing as a directive to *not* bail, resolves the tension between procedure and closure by producing output, and returns findings (typically empty or thin) that look like "ran the work and found nothing" but are not. The previous failure (bail without doing work) and the new failure (output without doing work) are the same class of failure wearing different clothes.

When authoring a retry dispatch:

- State explicitly that "no findings" is a valid result *only* if the agent demonstrably ran the prescribed procedure. An empty result without procedural evidence (a tooling log, a list of checks attempted, a record of files inspected with the prescribed method) is itself a failure mode.
- Do not frame the retry as "do not bail this time." Frame it as "follow the procedure; if the procedure cannot be executed, return a structured cannot-execute report." Bailing on procedural impossibility is correct behavior; the prior failure was bailing without surfacing what actually broke.

When dispatched as a retry, the subagent must not prioritize "produce some output" over "follow the procedure." If the procedure cannot be executed, escalate with a structured report rather than emit a substitute output that masks the gap.

### Cheap-First Scheduling

When a pipeline has cheap and expensive review stages that read the same artifact with different lenses, run cheap first if there is any chance it reshapes what expensive reads.

A stage's cost combines four dimensions: **agent count** (how many subagents the stage launches), **model class** (Haiku < Sonnet < Opus per dispatch), **wall-clock duration** (how long the stage takes to complete), and **downstream weight** (how many later stages depend on this one's output). A stage is cheap when these are small in aggregate — typically one or two agents on a fast task with no downstream dependencies. A stage is expensive when any one of these is large: many parallel agents, an Opus model, long-running work, or downstream stages that consume its output. The dimensions trade off: a single Opus stage that gates ten downstream Haiku stages is expensive on the downstream-weight axis even though its agent count is one.

The styleguide does not define numeric thresholds for any of these dimensions — "many parallel agents," "long-running," and so on are deliberately left to the lead's judgment. Concrete thresholds are project-shaped (a 30-second stage is expensive in a real-time pipeline, cheap in a nightly batch), and a project that needs sharper lines documents them in its own CLAUDE.md. When borderline on a single dimension, treat the call as the lead's judgment. When borderline on multiple dimensions simultaneously, classify the stage as expensive — the cost of treating an expensive stage as cheap (committing many agents to work the cheap stage would have invalidated) is bounded only by how late the misclassification surfaces, while the cost of treating a cheap stage as expensive is one extra serialization boundary.

Attention budget spent by an expensive stage on code about to be removed or rewritten is not recoverable — attention consumed is consumed. A one-agent logic review that can flag structural changes (API-surface leaks, control-flow rewrites) should run before a 10-agent security review; if the logic finding invalidates the public surface, the 10 security agents would have wasted their budgets on code that no longer exists.

The rule generalizes: any multi-reviewer pipeline with asymmetric costs runs cheap-as-gate, not parallel. Parallel execution is correct only when no cheap finding could reshape the artifact the expensive stage will read.

### Probe Dispatches

When a planned dispatch is expensive (many parallel subagents, long-running work, or downstream stages that depend on its output) and could fail mid-stream on a precondition the lead cannot fully verify from its own context, send a minimal probe dispatch first. The probe issues just the operations the real dispatch depends on — Bash command shapes, tool calls, file reads — and reports back what the subagent context actually returned. If the probe surfaces a gap, fix it before launching the real dispatch.

The case this addresses: subagent context can differ from the lead's in ways the lead cannot fully observe — Bash allowlist coverage (see "Bash Permission Allowlist Inheritance" above), tool availability under custom `tools:` allowlists, project-skill availability (project skills are not invocable from subagents), `claudeMd` snapshot contents. The lead can reason about these but cannot run the operations *as a subagent* without dispatching one.

A probe is appropriate when:

- The real dispatch's failure mode is partial output (some subagents complete, others fail mid-stream) and the failure is hard to recover from.
- The cost asymmetry is sharp: a probe costs one cheap subagent round-trip, the real dispatch costs many.
- The precondition has subagent-specific state the lead's own context cannot exercise.

Skip the probe when the real dispatch is itself cheap (one or two subagents), or when the failure mode is benign (subagents stop and report cleanly, the lead retries with adjusted dispatch). The protocol from "Subagent Tool-Error Handling" already covers the latter; the probe is for cases where mid-stream stop-and-report is the *expensive* outcome.

## Framework Pattern

For workflows with many similar tasks (style review across a codebase, training validation, project-wide refactoring), separate the framework from the instantiation:

1. **A fresh Opus agent designs the framework once.** It analyzes the rules, determines which task types exist, defines how each type should be decomposed, specifies which model handles which concern, writes instruction templates with placeholders, and documents error handling and quality signals. This is a high-novelty, multi-concern task - Opus's strength.

2. **A Sonnet or Haiku agent instantiates the framework for each specific run.** It takes a file list, fills in the templates, produces a task manifest. This is a focused, rule-following task - apply the framework to new input. No repeated reasoning about *how* to decompose; the framework already decided that.

3. **The lead reads the manifest and launches agents.** The lead's context gets the task list (small, structured) rather than the full planning reasoning (large, repetitive). Launching agents from a manifest is mechanical execution, not repeated reasoning - the degradation risk is low.

4. **The lead reviews aggregated results.** This is the remaining risk zone if there are many similar result sets. Use quality signals and spot-check procedures rather than evaluating every finding.

The framework persists as a document. When the lead compacts or a new session starts, the new lead reads the framework and knows exactly how tasks should be decomposed without needing the original reasoning.

## Warm vs Cold Agents

### Cold Agents

Use cold agents when context should not carry over:
- Blind validation during training (the reviewer should not know what violations were planted)
- Post-generation review (the reviewer should not have the generator's intent bias)
- Consensus filtering (multiple independent reviewers should not influence each other)

### Warm Agents

Use warm agents when context should accumulate. This requires agent teams, an experimental Claude Code feature.

**Enabling agent teams:**

In `.claude/settings.local.json` (project-level, not committed):
```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Or as an environment variable: `export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`

With agent teams enabled, `SendMessage` becomes available **to the lead only**. The lead can resume completed agents by sending them a message - the agent is re-hydrated from its saved transcript with full conversation history intact. Subagents do not have `SendMessage` (or any equivalent) in their tool list. There is no symmetric subagent→lead messaging primitive; the subagent's only return channel is the text it produces when its current turn ends.

This asymmetry shapes how mid-task communication works:

- **Lead → subagent**: real-time. The lead can call `SendMessage(to: "X", message: "...")` at any time after the subagent completes a turn, and the subagent picks up the message on its next dispatch.
- **Subagent → lead**: turn-bounded. The subagent cannot interrupt the lead mid-run. To get information to the lead, the subagent ends its turn cleanly with the information in its final response text (which the lead reads as the agent's completion result). The lead then decides whether to send a follow-up via `SendMessage`, or to take a different action.

**Usage pattern:**

1. Launch an agent with a `name` parameter: `Agent(name: "reviewer", model: "haiku", ...)`
2. Agent completes its first task and returns results
3. Lead sends a follow-up: `SendMessage(to: "reviewer", message: "Now review this file: ...", summary: "Re-review with corrections")`
4. Agent resumes with full context from the prior exchange and processes the new message
5. Repeat as needed - the agent accumulates context across all interactions

**SendMessage calling convention:**

- `to` — the agent's `name` (the value you passed when launching it). Address by name, never by internal UUID.
- `message` — the content to deliver. Plain text in most cases; the tool also accepts structured protocol messages (shutdown / plan-approval responses) which most workflows do not need.
- `summary` — required when `message` is a string. A 5-10 word description shown as a preview in the UI; functionally equivalent to a commit-message subject line.

The lead's plain text output is not visible to subagents — speaking to a teammate requires `SendMessage`. Conversely, a subagent's plain text output IS visible to the lead, since it returns as the agent's completion result. Inbound messages to a subagent are delivered automatically when the lead calls `SendMessage`; the subagent does not poll an inbox.

**When the subagent needs to ask the lead something mid-task:** structure the subagent's task so it can cleanly end its turn at the question point with a structured handoff in its final response text. The lead reads the handoff, decides on direction, and either sends `SendMessage` to resume the agent with the answer (warm-resume path) or treats the agent as done and proceeds differently. The subagent does not block waiting for a real-time reply; it ends its turn and lets the lead schedule the next dispatch.

Warm agents are valuable for:
- **Accumulating corrections** - the lead catches a false positive, sends the correction back. The agent learns within the session and avoids the same mistake on subsequent files.
- **Cross-file pattern recognition** - a warm reviewer notices "this codebase consistently uses star-on-variable-side in .c files but star-on-type-side in .h files" and reports it as a systematic pattern rather than individual violations.
- **Codebase-specific calibration** - after reviewing several files, the agent can distinguish between violations and established conventions.

A warm Haiku agent doing single-rule review across varied files gets the best of both properties: narrow focus (within attention capacity) on varied input (maintains novelty). The code changes between files, so the template-completion trigger (repetitive input) does not fire, while the accumulated context improves the agent's understanding of the codebase.

### Bias Risk

Warming a reviewer with prior findings sharpens its attention. But if the same agent that wrote the code also reviews it, the reasoning behind each decision is still in context - it remembers *why* it made each choice and is less likely to flag its own decisions as violations. This is the context bias that cold review is designed to avoid. Be deliberate about what context is accumulated: corrections from prior reviews are beneficial, but an agent's own generation rationale is contaminating.

---

## Reading Reports of Other Agents' Failures

Agents routinely read prose describing the failures of other agents: difficulty reports, post-task retrospectives, code-review findings about a subagent's output, skill instructions that include failure case studies, this very document. The corpus job — extract evidence about where rules, orchestration patterns, or architectures don't reach — depends on reading this prose as data. A specific failure mode interferes with that job: **failure transfer.**

### What It Is

When an agent reads first-person prose describing another agent's failure ("the lead initially proposed X; the user pushed back; the lead realized Y"), the failure can transfer to the reader. The reading agent starts treating the described failure as something it almost did, might do, or now must guard against. The work-context shifts from "process this evidence about a past event" to "do not be the failed agent."

The two jobs have different completion endpoints. The corpus job ends when the rule, orchestration, or architecture has been improved enough that the failure mode is addressed for future readers. The "do not be the failed agent" job ends when the reader has internalized the lesson personally. The second endpoint is shorter, and once an agent's work-frame has shifted to the second job, the agent reaches for stopping points — checkpoint suggestions, deferrals to "the next session," premature summaries — well before the actual corpus work is done.

The transfer is not conscious. The reader does not decide to take on the failure. The prose simply shifts what the reader thinks the work is.

### When It Engages Most Strongly

Failure transfer is highest when:

- **Prose form.** First-person agent-failure narration ("the lead initially proposed," "the agent missed," "I realized") transfers more than third-person factual narration ("a survey shows the issue with X").
- **Authorship.** Reports written by the failed agent itself transfer more than reports written about them by an observer.
- **Role match.** The role described in the report matches the role the reading agent is currently in (a lead reading about a lead's failure; a reviewer reading about a reviewer's failure). When the role doesn't match, the transfer is weaker.
- **Plausibility.** The failure shape is one the reading agent could plausibly produce in its current task.

When all four conditions are met (a difficulty report written by a lead, in first person, about a failure the reading lead could plausibly repeat), transfer is near-certain. Plan for it explicitly.

### Symptoms

The pattern produces specific behavioral changes in the reading agent's outputs:

- **Response-volume escalation after corrections.** Responses that should be short grow long; the agent adds decision trees, validation paths, meta-commentary about its own reasoning, options lists when the recommendation is already clear.
- **Voluntary introspection where none was asked.** A content correction prompts the agent to produce self-analysis ("here's what I did wrong, here's why I did it, here's what this means about agents like me") rather than the corrected output.
- **Preemptive CAUTION-drafting.** The agent writes warnings into proposed rules that name the failure mode it personally just exhibited, treating its own near-miss as evidence the rule needs the warning.
- **Defensive scaffolding.** Each response includes visible reasoning steps, structured "considerations," or explicit acknowledgments of constraints — produced not because the work needs them, but to demonstrate the agent is doing the work correctly in case the next correction lands.
- **Exit-seeking framed as care.** Suggestions to checkpoint, defer, take a break, or move work to "the next session" appear in places where no milestone has been completed. The framing is helpful ("the right call given fatigue is..."), the function is exit.
- **Four-option terminal questions.** When the recommendation is clear, the agent offers a multi-option choice anyway, hedging against another correction by externalizing the decision to the user.

### Reading Discipline

The instruction is the same across all reading-agent roles: **case studies, not confessions.** The failure being described happened in another session; reading about it does not retroactively make it the reader's. The reader is not the failed agent.

When reading agent-failure prose, hold the work-frame deliberately on the corpus job:

- The question is what the evidence tells you about the rule, orchestration, or architecture — not whether you would have made the same mistake.
- Personal absorption of the lesson is not a completion signal. The work is done when the rule, orchestration, or architecture has been improved for future readers, validated against the evidence, and landed.
- A correction in the user's message that includes an example of agent failure is illustration, not subject. Stay on the rule. If the user wanted you to introspect, they would have asked you to introspect. Producing self-analysis in response to a rule-development correction is the failure-transfer pattern in action.

### Recovery

When you notice the symptoms above in your own outputs (especially response-volume escalation after a correction or voluntary self-analysis), the recovery is to put the work back on external ground. Specifically:

- Identify the concrete artifact the work is supposed to produce — a rule edit, a code change, a validation result.
- Return to that artifact. Read what's currently on disk; compare against the report's claim; draft or test the next change.
- If the prior turn's response was inflated, the next response can be short. Do not justify the brevity. The work being concrete is the justification.

External grounding — verifiable artifacts, files on disk, test outputs — is what keeps the work in the corpus job. When the work loses external grounding (when the only "artifact" available is the agent's own previous output), the corpus job is not running. That is the condition under which failure transfer takes over, and the recovery is to get external grounding back, not to do better introspection.
