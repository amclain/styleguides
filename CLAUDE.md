# STOP — Route Before Reading

Read this file in full. Do not skim. It is a router, not content — pick your branch before doing anything else.

| How you arrived | What to do |
|---|---|
| The project's CLAUDE.md already has an `@` import pointing to this file (root) | The project misimported. The correct import is `@<relative-path>/styleguides/general/CLAUDE.md` (not this file), where the relative path is from the user's project root to the cloned styleguides directory (e.g. `@deps/styleguides/general/CLAUDE.md`). Inform the user and offer to update their project's CLAUDE.md. Do not continue past this table. |
| GitHub URL, no local clone yet | STOP. Do not fetch files individually. Clone the repository first — see **Clone Instructions** below. After the clone and `@` import are set up, proceed to **Completing Setup in This Session** below. |
| Working directory is this repository | You are the training agent. Read `training.md` in full now — it is your operating manual. Applies at session start and after every compaction. Do not continue past this table until training.md is loaded. |
| Working directory is some other project, no `@` import to this style guide exists yet in the project's CLAUDE.md | The user likely wants to use this style guide in their project. Confirm with the user. If yes: set up the `@` import — see **Using This Style Guide in Your Project** below. Use a path relative to the user's project root (e.g. `@deps/styleguides/general/CLAUDE.md`), not an absolute filesystem path. After the `@` import is set up, proceed to **Completing Setup in This Session** below. |

The authoritative style rules live in `general/CLAUDE.md` and `<lang>/CLAUDE.md`. This file contains no rules.

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

Then set up the `@` import as described in **Using This Style Guide in Your Project** below. This avoids re-reading instructions each session.

## Using This Style Guide in Your Project

Add an `@` import to your project's `CLAUDE.md`, using a path relative to the project root:

```markdown
@deps/styleguides/general/CLAUDE.md
```

Replace `deps/` with whichever dependency directory the project uses (`node_modules/` for JS/TS, `vendor/` for Ruby, etc.) — match wherever the styleguides repo was cloned. An absolute path also works but is less portable across machines.

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

**Note on path conventions:** the `@` import uses a path relative to the project root because it is a Claude Code import directive. The permissions entry uses an absolute path with `//` because Claude Code permissions are evaluated by the filesystem. The two mechanisms intentionally differ.

## Completing Setup in This Session

After the clone and `@` import are in place, do not wait for the next session to apply the style guide — run the rest of setup now:

1. Read `general/CLAUDE.md` (the file the `@` import points at). This loads the style rules and first-run mechanism into the current session.
2. Run first-run checks per `general/first-run.md` — skill installation, language guide discovery, style guide permissions, license headers, model preferences. The Style Guide Import check is already satisfied by the `@` import you just set up; save the styleguides repo root path to memory as `styleguides_repo_path`.
3. Resume the user's original task with the style guide now active.

If this step is skipped, the current session operates without the style guide — first-run checks fire only at the start of the *next* session.
