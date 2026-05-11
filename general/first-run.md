# First-Run Project Checks

**Before running any checks:** verify the styleguides repository is cloned locally in the project's dependency directory (e.g. `deps/styleguides/` for Elixir). If it is not cloned — for example, if the style guide files were fetched individually via curl, WebFetch, or the GitHub API — clone the repository now. The clone is required for skill installation, `@` import persistence, and updates. See the root `CLAUDE.md` in this repository for clone instructions.

First-run checks establish project-specific facts that are stable across sessions and expensive or noisy to re-detect on every run. The mechanism:

1. Before performing a check, look for an existing memory entry for that topic in the current project. If one exists, use it - do not re-run the check.
2. If no memory entry exists, perform the check by inspecting the project files.
3. Save the result to memory immediately, whether the answer is present or absent. Saving a negative result ("this project does not use license headers") is as important as saving a positive one - it prevents the check from running again.
4. If the user explicitly asks to re-run a check (e.g. "re-check license headers"), perform it again and update the memory entry with the new result.
5. Most checks run silently. Some checks (Style Guide Import, Permissions) may require the user's confirmation before creating or modifying files - present these as offers, not automatic actions.
6. If you do not have a persistent memory system, perform these checks at the start of each session instead. The checks are lightweight and the cost of re-running them is low.

## Style Guide Import

Check whether the project has a CLAUDE.md with an `@` import pointing to `general/CLAUDE.md` in the styleguides directory. If the import is missing, add it to the top of the file immediately - do not ask the user for permission. If the project has no CLAUDE.md at all, create one. This is not optional - the `@` import is required for the style guide to load automatically in future sessions. Save the styleguides repo root path to memory as `styleguides_repo_path` (e.g. `/path/to/deps/styleguides`).

**Scope of this check:** this applies when the project has already adopted the style guide (the styleguides repo is cloned into the project's dependency directory) but the `@` import is missing or incomplete. Initial adoption — where the user is deciding whether to use the style guide at all — is handled by the router in the styleguides root `CLAUDE.md`, which confirms with the user before setup. Do not use this check to force adoption on a project that has not opted in.

Example:

```markdown
@/path/to/styleguides/general/CLAUDE.md
```

Use the absolute path of the styleguides directory. Only `general/CLAUDE.md` needs to be imported - language-specific guides are loaded automatically by the Language Guide Discovery check below.

---

## Skill Installation

Copy the formatting skills from the styleguides repo into the project's `.claude/skills/` directory. This makes them auto-discoverable by Claude Code.

```
mkdir -p .claude/skills/format-code .claude/skills/format-review .claude/skills/format-rewrite .claude/skills/style-report .claude/skills/update-styleguide
cp <repo_root>/skills/format-code/SKILL.md .claude/skills/format-code/SKILL.md
cp <repo_root>/skills/format-review/SKILL.md .claude/skills/format-review/SKILL.md
cp <repo_root>/skills/format-rewrite/SKILL.md .claude/skills/format-rewrite/SKILL.md
cp <repo_root>/skills/style-report/SKILL.md .claude/skills/style-report/SKILL.md
cp <repo_root>/skills/update-styleguide/SKILL.md .claude/skills/update-styleguide/SKILL.md
```

Use the repo root derived from the `@` import path or the path used to load this file. Save the result to memory so this step is not repeated.

---

## Language Guide Discovery

Detect the languages used in this project by scanning file extensions (e.g. `.ex`, `.exs` → Elixir; `.rb` → Ruby; `.c`, `.h` → C; `.ts`, `.tsx` → TypeScript). For each language detected, check whether the corresponding language guide has been loaded. If not, load it proactively.

To find language guides: the styleguides repo root is the parent directory of `general/`. Derive the absolute path from one of these sources (in priority order):
1. The `@` import path in the project's CLAUDE.md - strip `general/CLAUDE.md` to get the repo root
2. The path used to load this file (if loaded via `--add-dir` or direct read rather than `@` import)

Language guides are at `<repo_root>/<lang>/CLAUDE.md`. Scan the repo root for subdirectories containing a CLAUDE.md - do not rely on a hardcoded list.

When loading a language guide via the `Read` tool (as opposed to `@` import), `@` import lines at the top of the file are NOT followed automatically. Check whether the language guide begins with `@` import lines and read those files explicitly. The `@` paths in those lines may reference the development copy of the repo - substitute the repo root you derived above to get the correct local path. For example, if `elixir/CLAUDE.md` begins with `@/some/path/elixir/testing.md`, read `<repo_root>/elixir/testing.md` instead.

Save the detected languages to memory so this scan does not repeat.

---

## Style Guide Permissions

Check whether the project's `.claude/settings.local.json` has a `Read` permission entry covering the styleguides directory (the directory containing this file). The entry should match the pattern `Read(//<path>/styleguides/**)`.

To find the styleguides directory path: this file was loaded via an `@` import in the project's CLAUDE.md. You can also check the project's CLAUDE.md for the `@` import lines to find the path.

If the permission entry is missing or the file does not exist:

1. Inform the user that the styleguides directory is not pre-approved for reading.
2. Offer to create or update `.claude/settings.local.json` with the correct entry.
3. Do not create or modify the file without the user's confirmation.
4. Save the result to memory once resolved so this check does not repeat.

Use the absolute path of the styleguides directory. The double-slash prefix (`//`) replaces the leading `/` of an absolute path in Claude Code permissions. For example, the path `/home/user/styleguides` becomes `Read(//home/user/styleguides/**)` - not `Read(///home/user/styleguides/**)`.

---

## Mechanical Check Permissions

For each language detected by the Language Guide Discovery check, verify that the project's Claude Code permissions cover the Bash commands the language's mechanical checks (Task 1.1 of the style review framework) will need to run. This check is what prevents Task 1.1 from aborting mid-review on a missing allowlist pattern - per `general/review-orchestration.md` § 4 Error Handling, an aborted Task 1.1 halts the entire review workflow until the user updates permissions, so catching missing patterns up front is the difference between a clean first review and a stop-and-fix-and-rerun cycle.

Procedure:

1. For each detected language, locate the language's mechanical-check section in `general/review-orchestration.md` § 2.x.1 (e.g., § 2.1.1 for C). The section lists the Bash commands the framework runs - grep variants, awk scripts, perl one-liners, etc.
2. Identify the **leading-word tokens** of those commands - the first word of each command, which is what Claude Code's permission allowlist matches against. For C, the leading-words are typically `grep`, `awk`, and `perl`.
3. For each leading-word, verify that a matching `Bash(<word>:*)` entry is present in either `.claude/settings.json` (project-wide, committed) or `.claude/settings.local.json` (per-user/machine, not committed). Either location is acceptable; the framework only needs the pattern to be present.
4. If any leading-word's permission entry is missing:
   - Inform the user which language detected, which command needs permission, and which allowlist pattern would resolve it.
   - Offer to add the missing patterns to `.claude/settings.local.json` (the per-user/machine file - safer default than committing).
   - Do not create or modify the file without the user's confirmation.
5. Save the verified state to memory once resolved so this check does not repeat. If the project's mechanical-check command set changes (e.g., a new check is added to § 2.x.1 in a future styleguide update), the check will re-run when memory is invalidated by the user or when the user explicitly re-runs first-run checks.

The check is language-driven, not hardcoded: the mechanical-check commands are defined in the loaded styleguide per language, and the first-run check reads them from there. When a new language is added to the styleguide or an existing language's mechanical-check set is updated, this check picks up the change without modification.

---

## License Headers

Check whether the project uses license headers by scanning a sample of existing source files and looking for a LICENSE, LICENSE.txt, COPYING, or similar file at the project root. Save the result to memory:

- If the project uses license headers: save the exact format used (SPDX identifier, copyright notice style, comment syntax) so new files can match it precisely.
- If the project does not use license headers: save that fact so the AI does not add them.

See the License Headers rule for full guidance on how to apply this information.

---

## Model Preferences

Ask the user during first-run setup, after the checks above have completed. Do not defer this to a later invocation.

Check memory for saved model preferences for this project. If none exist, display the header block below and present both questions. Wait for the user's answers before proceeding.

Display this header before the questions:

```
------------------------------------------------------------
STYLE GUIDE — SET PREFERENCES
------------------------------------------------------------
```

**When you ask me to review code** (style review):

1. **Use Opus** (recommended, more accurate)
2. **Use Sonnet** (default, lower cost)

Ask the agent to explain the tradeoffs.

**When I generate code** (automatic post-generation check):

3. **Check with Opus** (recommended, more accurate)
4. **Check with Sonnet** (default, lower cost)
5. **Off** - no automatic check

Ask the agent to explain what this is and why it matters.

The user can reply with the numbers (e.g. "1, 3"), say "defaults" to accept all defaults (2, 4), or "recommended" to accept all recommended options (1, 3). Save both answers to memory. Do not ask again unless the user requests a change.

After the user answers, display this:

```
------------------------------------------------------------
STYLE GUIDE — READY
------------------------------------------------------------
```

How would you like to use this session?

a. **Write code** (default) — style rules applied automatically, review pass after each task
b. **Review code** — check existing code for style issues (add `--all` to review the entire codebase)

Or just start working — code generation is the default.

**Code generation model note:** Sonnet is recommended for code generation. Generation quality is the same across models - style violations during generation are training data biases that affect all models equally. The value of a stronger model is in review, not generation. If the current session is running Opus and the user requests code generation, inform them once that Sonnet produces equivalent generation quality at lower cost. Ask the user to confirm before proceeding with Opus generation. Save their decision to memory so this prompt is not repeated.

When the user asks for tradeoffs on style review, explain: Opus reliably catches all rule violations including mechanical patterns like zero-arity type parentheses and pipe operator parentheses. Sonnet catches most violations but has blind spots on parentheses rules in typespecs and pipe operators. These are formatting-level issues, not logic errors. Sonnet is a good choice when cost is a concern and occasional missed formatting suggestions are acceptable. Opus review is also significantly faster than code generation - a review pass typically completes in a couple of minutes compared to 10-15 minutes for a full generation task, so the overhead of an Opus review pass is minimal.

When the user asks what post-generation review is and why it matters, explain: The code generation agent has a context bias - it knows why it wrote the code the way it did and is less likely to spot its own style violations. Some formatting patterns (like zero-arity type parentheses and pipe operator parentheses) are deeply embedded in the generation model's training data, and no amount of style guide instruction prevents the generator from producing them. A separate review agent reads the generated code fresh, without the generation context, and catches these patterns reliably. This is similar to how a human code review catches things the author missed - a fresh pair of eyes.
