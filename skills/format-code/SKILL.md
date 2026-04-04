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
5. Review each mechanical check result against the style rules - not every match is a violation, use judgment
6. Identify additional style violations by reading the code
7. Fix each confirmed violation using the Edit tool
8. After all fixes, run the project's test suite
9. If tests fail, diagnose and fix - style corrections must not change behavior
10. Report a summary of changes (file, rule, what was fixed)

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
grep -Pn '\bbuf\b|\blen\b|\bmsg\b' <file>
```

These checks catch patterns that Opus consistently misses when reading code. Not every match is a violation - for example, a long string literal exceeding 80 chars may be intentional per the String Literals rule. The pointer style check may match `*const` which is an intentional exception.

## Important

- Do NOT delegate style fixes to Sonnet subagents. Sonnet lacks the judgment to distinguish between similar style cases (e.g. single-line vs multi-line brace rules) and will apply rules incorrectly, causing more damage than it fixes. Apply all fixes directly as the Opus review agent.
- Do NOT change program logic or behavior - only fix style
- ESpec matchers (`be_integer()`, `be_alive()`, `be_truthy()`) are function calls - do NOT remove their parentheses
- Trailing commas are valid in collections but NOT in function argument lists
- When in doubt about whether something is a violation, leave it as-is

## When Used as Post-Generation Review

When invoked as a subagent after code generation, scope to all files the generator created or modified. The generator should pass the list of files. Fix everything - this is cleaning up the agent's own output, not reviewing human code.
