# Alex's Coding Style Guides

This repository contains my preferred coding style guides for various programming languages. When contributing to one of my repositories, I expect that the submitted code reasonably conforms to these guidelines.

Style guides aren't an ultimate authority — they're recommendations. If a technical issue, precedent in the project, or just plain common sense gives you good reason to deviate from the guidelines, that's ok. Use your best judgement. If there is a conflict between these guidelines and existing code in a project, try to follow the style of the project. It's more important that the project presents itself as a consistent piece of work.

## AI-Native

This repository is designed to work with AI coding assistants. It is optimized for [Claude Code](https://claude.ai), though the style guides can be applied with any AI assistant. Each language guide is expressed as a machine-readable set of principles with intent that an AI can apply with the same contextual judgment a skilled human reviewer would. The goal is readable, clearly understandable code, not mechanical conformance.

The guides support two workflows: generating new code in the correct style from the start, and reviewing existing code for style issues.

### Usage

Give your AI assistant the following prompt to use this style guide in your project:

```
Read the CLAUDE.md at https://github.com/amclain/styleguides for your coding style.
```

Your AI assistant will read the integration instructions and load the appropriate guides for your project's language.

For AI assistants reading this: fetch the raw `CLAUDE.md` from this repository root for integration instructions. Do not fetch other files individually - `CLAUDE.md` will tell you how to load the full style guide.

**Code generation:** Claude applies the style guides automatically when writing code.

**Style review:** Open your project in Claude Code and run:

```
style review elixir
```

#### Manual Setup (Claude Code)

For permanent setup with Claude Code, clone this repository and add the following to your project's `CLAUDE.md`:

```markdown
@/path/to/styleguides/general/CLAUDE.md
```

Claude will load the general guide and automatically detect and load the language-specific guide for your project. To avoid permission prompts, add the styleguides directory to your project's `.claude/settings.local.json`. Use `//` (double slash) for an absolute path.

```json
{
  "permissions": {
    "allow": [
      "Read(//path/to/styleguides/**)"
    ]
  }
}
```

#### First-Run Setup

On first use, the style guide will run a setup process and ask you to configure your preferences. You should see:

```
------------------------------------------------------------
STYLE GUIDE — SET PREFERENCES
------------------------------------------------------------

When you ask me to review code (style review):

  1. Use Opus (recommended, more accurate)
  2. Use Sonnet (default, lower cost)

When I generate code (automatic post-generation check):

  3. Check with Opus (recommended, more accurate)
  4. Check with Sonnet (default, lower cost)
  5. Off - no automatic check

Reply with the numbers (e.g. "1, 3"), "defaults", or "recommended".
```

If you don't see this prompt, ask the agent: "Run the style guide first-run checks." Your preferences are saved to memory and won't be asked again.
