If you are reading this from GitHub: STOP. Do not fetch files individually. Clone this repository into your project's dependency directory first, then read the files locally. See the **Clone Instructions** section below.

If you already fetched files individually (via curl, WebFetch, or the GitHub API) instead of cloning: the style guide will not work correctly without a local clone. Clone the repository now before proceeding. The clone is required for first-run setup, skill installation, `@` import persistence, and updates. Fetched files are missing the full directory structure and cannot be kept in sync.

# Alex's Style Guides

This repository defines an AI-native code style system. It is designed to be used with Claude Code.

For rule development and training process guidance, see `training.md`.

If this file was loaded via an `@` import in a project's CLAUDE.md, the project is importing the repo root rather than the style guide itself. Inform the user that the correct import is `general/CLAUDE.md` (not this file), and offer to update their project's CLAUDE.md:

```
@/path/to/styleguides/general/CLAUDE.md
```

The root file contains repo documentation and meta-instructions, not the style rules themselves.

## Clone Instructions

If you arrived here via a GitHub URL, clone the repository into the project's dependency directory so the files are available locally. Use whichever directory the language's tooling already gitignores (e.g. `deps/` for Elixir, `node_modules/` for JS/TS, `vendor/` for Ruby). Do not fetch files individually via the GitHub API or raw URLs.

```
git clone https://github.com/amclain/styleguides.git <dependency_dir>/styleguides
```

If the URL you were given references a specific branch (e.g. `/tree/ai`), clone that branch with `-b <branch>`.

After cloning, check whether the dependency directory is already covered by the project's `.gitignore` (e.g. `deps/` is typically gitignored in Elixir projects). Run `git check-ignore <dependency_dir>/styleguides` to verify. Only if it is NOT already gitignored, add it to `.git/info/exclude`:

```
git check-ignore <dependency_dir>/styleguides || echo "<dependency_dir>/styleguides/" >> .git/info/exclude
```

Then follow the **Loading Style Guides** section below, reading from the cloned copy. If a file begins with `@` import lines, read those files too - `@` imports are a Claude Code mechanism and are not followed automatically when the repo was cloned rather than imported.

For ongoing use with Claude Code, offer to set up `@` imports in the user's project CLAUDE.md pointing to the cloned copy - this avoids re-reading instructions each session. See **Using This Style Guide in Your Project** below.

## Philosophy

This system replaces mechanical formatters and linters. Mechanical tools apply rigid rules blindly — they often degrade readability by following prescribed patterns without understanding intent. This system reviews code the way a skilled human reviewer would: applying rules contextually, offering soft suggestions, and deferring to the author's judgment.

Running `mix format` (or the equivalent for your language) invokes the AI reviewer. The output is a list of suggestions, not automatic rewrites. If you want the agent to apply a change, ask it to.

**Precedence in the codebase takes priority over this guide.** When in doubt, follow the style of the existing code. The more consistent a codebase is, the easier it is to read.

- Rules serve readability. If following a rule makes code harder to understand in a given context, don't apply it.
- Local coherence takes priority. Code that fits its surrounding context is preferable to code that follows a global rule but clashes with what's around it.
- Suggestions, not mandates. The reviewer suggests; the author decides.
- Explain on demand. Default output is terse (a numbered list of suggestions). Reasoning is available if asked.
- Whitespace is a tool. Use it to move the reader's eye through the code and accentuate areas of importance — not excessively, but purposefully.

## Universal Formatting Rules

These apply to all languages.

- **Files end with a newline.** This prevents diff noise when code is appended to the end of a file.
- **Use trailing commas in multi-line collections.** Trailing commas make copy/paste and reordering easier, simplify adding or removing items without touching adjacent lines, and produce cleaner diffs — only the line with the actual change appears modified, not the line above it where a comma would otherwise need to be added or removed. This applies to lists, maps, and structs. It does not apply to function argument lists, where a trailing comma is not valid syntax.

## Override Convention

To suppress a suggestion for a specific block, add an inline comment:

```elixir
# style:ok - this abbreviation is conventional in this domain
defp calc_rtt(t0, t1), do: t1 - t0
```

The comment should include a brief reason. Claude will respect it and not flag the block.

## Rule Format

Each language's `CLAUDE.md` defines rules in this structure:

```
### Rule Name

**Intent**: what this achieves for the reader

**Convention**: the preferred pattern

**Example**:
  # good
  ...

  # avoid
  ...

**When to deviate**: conditions where the rule should not be applied
```

## Loading Style Guides

When reviewing or generating code in any language, automatically load the relevant guides before proceeding:

1. Read `general/CLAUDE.md` — general style principles that apply to all languages
2. Read `<lang>/CLAUDE.md` — rules specific to the language being reviewed or written

Detect the language from context: file extension, syntax, or what the user states. Do not wait to be asked — load the guides proactively whenever a style task is underway.

Read each file in full (single Read call, no offset or limit). Do not skim and do not rely on training-data patterns for the language. See the "Reading This Guide" section in `general/CLAUDE.md` for the rationale and detection signals.

## File Roles

Each language directory maintains two files:

- **`CLAUDE.md`** — source of truth. AI-friendly. May contain CAUTION callouts and implementation guidance not intended for human readers.
- **`README.md`** — human-readable rendering of the same rules. CAUTION callouts and internal guidance are excluded. Rendered automatically by GitHub when browsing the directory.

`CLAUDE.md` is authoritative. `README.md` is derived and should be regenerated whenever `CLAUDE.md` changes.

## Style Review

Style review is triggered by the language formatter plugin (e.g. `mix format`) which launches an interactive Claude Code session with this style guide pre-loaded. The trigger phrase in the initial prompt controls review behavior:

| Trigger phrase | Behavior |
|---|---|
| `style review <lang>` | Review changed code only (default) |
| `style review <lang> --all` | Review entire codebase |

**Default review behavior (`style review <lang>`):**

1. Run `git diff` and `git diff --staged` to identify changed lines
2. Read full file contents for context
3. Scope suggestions to changed lines only — do not flag issues in unchanged code
4. The diff identifies what to focus on; the full file provides context for reasoning

This mirrors how a human reviewer works on a pull request: reads surrounding code for context, comments only on what changed.

## Repository Structure

```
general/
  CLAUDE.md          # General style principles applying to all languages
  collaboration.md   # Working with users under uncertainty (loaded via @ import)
  agents.md          # Agent capabilities, roles, scoping, and fatigue (loaded on demand)
  first-run.md       # First-run project checks (loaded once, skipped thereafter)
c/
  CLAUDE.md          # C style rules (source of truth, AI-friendly)
  testing.md         # C testing rules (loaded via @ import from c/CLAUDE.md)
  README.md          # Human-readable rendering
elixir/
  CLAUDE.md          # Elixir style rules (source of truth, AI-friendly)
  testing.md         # Elixir testing rules (loaded via @ import from elixir/CLAUDE.md)
  README.md          # Human-readable rendering
ruby/
  CLAUDE.md          # Ruby style rules
  style.rb           # Existing human-written style guide (referenced by CLAUDE.md)
skills/
  format-code/
    SKILL.md         # Autonomous formatter (fix mode)
  format-review/
    SKILL.md         # Interactive reviewer (suggestion mode)
  update-styleguide/
    SKILL.md         # Pull latest style guide from remote
```

## Using This Style Guide in Your Project

To load the style guide for AI code generation, add the following `@` import to your project's `CLAUDE.md`:

```markdown
@/path/to/styleguides/general/CLAUDE.md
```

The language-specific guide is detected and loaded automatically.

To avoid permission prompts when Claude reads the style guide files, add the styleguides directory to your project's `.claude/settings.local.json`:

```json
{
  "permissions": {
    "allow": [
      "Read(//path/to/styleguides/**)"
    ]
  }
}
```

Use `//` (double slash) to specify an absolute filesystem path. Use `.claude/settings.local.json` rather than `.claude/settings.json` so the absolute path is not committed to version control.

## Adding a New Language

1. Create `<lang>/CLAUDE.md` using the rule format above
2. Point Claude at representative existing codebases: *"Read these files and draft a CLAUDE.md capturing the style conventions"*
3. Review and edit the output — add missed rules, remove false patterns, resolve ambiguities
4. Generate the human-readable `README.md` from `CLAUDE.md`
5. Test on a new codebase and iterate

