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

With agent teams enabled, `SendMessage` becomes available. The lead can resume completed agents by sending them a message - the agent is re-hydrated from its saved transcript with full conversation history intact.

**Usage pattern:**

1. Launch an agent with a `name` parameter: `Agent(name: "reviewer", model: "haiku", ...)`
2. Agent completes its first task and returns results
3. Lead sends a follow-up: `SendMessage(to: "reviewer", message: "Now review this file: ...")`
4. Agent resumes with full context from the prior exchange and processes the new message
5. Repeat as needed - the agent accumulates context across all interactions

Warm agents are valuable for:
- **Accumulating corrections** - the lead catches a false positive, sends the correction back. The agent learns within the session and avoids the same mistake on subsequent files.
- **Cross-file pattern recognition** - a warm reviewer notices "this codebase consistently uses star-on-variable-side in .c files but star-on-type-side in .h files" and reports it as a systematic pattern rather than individual violations.
- **Codebase-specific calibration** - after reviewing several files, the agent can distinguish between violations and established conventions.

A warm Haiku agent doing single-rule review across varied files gets the best of both properties: narrow focus (within attention capacity) on varied input (maintains novelty). The code changes between files, so the template-completion trigger (repetitive input) does not fire, while the accumulated context improves the agent's understanding of the codebase.

### Bias Risk

Warming a reviewer with prior findings sharpens its attention. But if the same agent that wrote the code also reviews it, the reasoning behind each decision is still in context - it remembers *why* it made each choice and is less likely to flag its own decisions as violations. This is the context bias that cold review is designed to avoid. Be deliberate about what context is accumulated: corrections from prior reviews are beneficial, but an agent's own generation rationale is contaminating.
