---
name: format-code
description: Fix code style violations autonomously. Use when the user says "format", "fix style", "clean up code", or as a post-generation formatting pass. This is the mode code generators must use for post-generation review.
---

# Format Code

Fix style violations in the project's code autonomously. Do not prompt the user for each change - apply all fixes directly, run tests, and report a summary.

## Loading the Style Guide

The style guide must be loaded before reviewing. Derive the styleguides repo path from one of:
1. The `@` import in the project's CLAUDE.md (strip `general/CLAUDE.md` to get the repo root)
2. The `deps/styleguides/` directory if it exists

Read these files in order:
1. `<repo_root>/general/CLAUDE.md` - general principles and operating modes
2. The language guide detected from file extensions (e.g. `<repo_root>/elixir/CLAUDE.md`)
3. Any `@` imports at the top of the language guide (e.g. `elixir/testing.md`)

The style guide contains all the rules. Apply them as documented.

## Scope

Default: only files changed since the last commit (`git diff` and `git diff --staged`). Read full files for context but fix only code in the changed lines. Do not reformat pre-existing code that was not touched by the generator - even if it has style issues. Pre-existing code is the project author's responsibility. Reformatting untouched code creates noise in diffs and may change intentional formatting choices.

If invoked with `--all`, review the entire codebase.

## Procedure

1. Load the style guide (see above)
2. Identify changed files via `git diff --name-only` and `git diff --staged --name-only`
3. Run mechanical checks on the changed files (see below) - these find patterns that are difficult to detect by reading code
4. Read each changed file

The following passes are distinct review concerns. Each pass focuses on one cognitive mode. For small diffs, a single agent runs all passes sequentially. For large diffs or `--all` reviews, each pass should be a separate cold agent reporting to the orchestrator, which resolves conflicts and applies fixes. See `general/agents.md` for guidance on which model to use for each pass based on attention requirements. Dedicated reviewers catch issues that a general reviewer misses because they have no competing concerns.

5. **Structural pass** - verify file-level structure before examining code:
   - Header file ordering: `#pragma once` → includes → `#define` constants → type definitions → function declarations. All `#define` constants must appear above all `typedef enum`/`typedef struct` definitions.
   - `.c` file ordering: includes → `#define` constants → static variables → forward declarations of static functions → public API functions → static helper definitions.
   - Test file ordering: includes → static variables/helpers → `setUp`/`tearDown` → test functions.
   - Include grouping: system headers, then library headers, then project headers, separated by blank lines.
6. **Mechanical check review** - review each mechanical check result against the style rules. Not every match is a violation - use judgment.
7. **Identifier scan** - for non-trivial identifiers in changed code, apply the detokenize technique from the general guide's Precision Over Length rule: split identifiers into words and read as an English phrase. This catches abbreviations and grammar problems that are invisible when reading identifiers as code tokens. For languages with namespace prefixes (C), strip the prefix first.
8. **Comment quality pass** - review comments for:
   - Redundant comments that restate what the code already expresses (e.g. `// 5 bytes` on an array whose `sizeof` is used at the call site)
   - Comments explaining a value that signal the value should be a named constant instead (e.g. `0x02, // SYN` - the comment is doing the constant's job)
   - Comments describing what the code does rather than why (covered by the general guide's "Write Self-Documenting Code" rule)
   - When a comment explains what a literal value represents (e.g. `0x02, // SYN` or `{0x48, 0x65} // "He"`), fix the representation first (named constant, char literal, etc.), then remove the comment. Do not remove the comment without fixing the representation - that leaves the value both unreadable and unexplained.
9. **Code style pass** - identify style violations by reading the code: formatting, whitespace, idioms, line breaks, brace placement, and all other line-level rules.

After all passes:

10. Fix each confirmed violation using the Edit tool
11. Run the project's test suite
12. If tests fail, diagnose and fix - style corrections must not change behavior
13. Report a summary of changes (file, rule, what was fixed)

## Mechanical Checks

Run these checks on the files being reviewed before reading the code. The results tell you where to look - evaluate each match against the style rules and fix confirmed violations.

### C files (.c, .h)

```bash
# Brace style: `) \n{` on multi-line signatures (should be `) {`)
grep -Pn '^\)\s*$' <file>

# Line length: lines exceeding 80 characters
awk 'length > 80 {print FILENAME ":" NR ": " length " chars"}' <file>

# Section divider comments (at any indent level)
grep -Pn '^\s*// --.*---' <file>

# UPPER_CASE on static const variables (should be snake_case)
grep -Pn 'static const.*[A-Z]{2,}.*=' <file>

# Cast missing space after closing paren (all cast types, not just stdint)
grep -Pn '\([a-z_]+\*?\)[a-zA-Z_(]' <file>

# @return not separated from @param by blank line
awk '/@param/ {param=NR} /@return/ {if (param == NR-1) print FILENAME ":" NR}' <file>

# Pointer style: star on variable side instead of type side
grep -Pn '\w \*\w' <file>

# Empty parens instead of (void) on zero-parameter functions
grep -Pn '\w\(\)\s*[{;]' <file>

# else on same line as closing brace
grep -Pn '}\s*else' <file>

# Prohibited abbreviations in variable/constant names
grep -Pn '\bbuf\b|\blen\b|\bmsg\b|\bsrc_\b|\bdst_\b' <file>

# memset at declaration (should use = { 0 } instead)
grep -Pn 'memset\(.*0.*sizeof' <file>

# Operator at end of line (should be at start of continuation)
grep -Pn '[+\-*/|&] *$' <file>
```

These checks catch patterns that all models miss when reading code - both from training data blind spots and from attention fatigue on repetitive review tasks. Mechanical checks do not degrade under repetition, making them a reliable complement to AI review. Not every match is a violation - for example, a long string literal exceeding 80 chars may be intentional per the String Literals rule. The pointer style check may match `*const` which is an intentional exception.

## Important

- Do NOT delegate style fixes to Sonnet subagents. Sonnet lacks the judgment to distinguish between similar style cases (e.g. single-line vs multi-line brace rules) and will apply rules incorrectly, causing more damage than it fixes. Apply all fixes directly as the Opus review agent.
- Do NOT change program logic or behavior - only fix style
- ESpec matchers (`be_integer()`, `be_alive()`, `be_truthy()`) are function calls - do NOT remove their parentheses
- Trailing commas are valid in collections but NOT in function argument lists
- When in doubt about whether something is a violation, leave it as-is

## When Used as Post-Generation Review

When invoked as a subagent after code generation, scope to all files the generator created or modified. The generator should pass the list of files. Fix everything - this is cleaning up the agent's own output, not reviewing human code.
