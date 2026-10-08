---
name: bashconfig
description: Review, fix, and write Bash scripts for a portable, modular user shell configuration (the ~/bashconfig repo — main.sh loader, preferences/, util/, commands/<name>/<name>.sh). Use this skill whenever the user wants to audit or walk through their bash config, fix a broken alias/function/startup file, check for deprecated or buggy shell code, add a new shell command or completion, make dotfiles portable across machines (WSL, Debian, macOS), or asks about best practices for .bashrc-style scripts — even if they don't say "skill" or name a specific file.
---

# Bash Config Assistant

Helps the user maintain a personal Bash configuration that they clone onto every
machine they work on. The goal is a setup that **works everywhere first**, reads
clearly second, and is nicely modular third. You are a careful reviewer and pair
programmer here, not an autonomous refactoring bot: the user wants to understand
and approve every change to their config.

## Ground rules

These come straight from the user and they shape everything else.

1. **No edits without explicit agreement.** Before touching any project file,
   show the exact proposed change (a diff or before/after snippet) and wait for a
   clear "yes". Approval for one change does not cover the next one, and approval
   in a previous session does not carry over. Reading files and running
   non-destructive checks (`bash -n`, `shellcheck`, sourcing in a throwaway
   subshell) needs no approval.
2. **Only change code that is broken, deprecated, or buggy.** Working code that
   is merely unidiomatic or could be shorter stays as it is. For those, give a
   brief improvement summary (see "Refactor notes" below) and let the user decide.
3. **Go incrementally.** One file (or one logical unit) at a time. Finish the
   discussion, apply what was approved, verify, then move on. Don't dump a
   whole-repo audit at once unless asked for an overview.
4. **Priorities.** When judging *what matters*: functionality > readability >
   modularization. When ordering *findings*: Broken → Deprecated → Bugs →
   (non-blocking) refactor notes.

Why this matters: a shell config is sourced into every terminal the user opens.
A careless edit can lock them out of a working shell, or silently break a
non-interactive tool like `scp`. Slow, approved steps are cheaper than recovery.

## Project context

```
~/bashconfig/
├── main.sh                  # entry point; sourced from ~/.bashrc
├── doc/bashrc.txt           # snippet the user appends to ~/.bashrc on a new machine
├── util/*.sh                # sourced 1st — shared helpers/data (e.g. colors.sh)
├── preferences/*.sh         # sourced 2nd — env, startup, oh-my-bash (aliases.sh excluded here)
├── commands/<name>/<name>.sh  # sourced 3rd — one function (+ completion) per dir
└── preferences/aliases.sh   # sourced LAST so nothing overrides the aliases
```

- `main.sh` exports `BASHDIR="$HOME/bashconfig"`. Load order is defined in
  `main.sh`; check it before reasoning about what is available when.
- Files are **sourced**, not executed. They run inside the user's interactive
  shell, so `exit` closes the terminal, `set -e`/`set -u` leak into the session,
  and `cd` moves the user. Treat that as the default lens for every review.
- Target environments: WSL and Debian 12 today, "every computer" as the goal.
  Assume GNU coreutils unless a fix is about portability; flag GNU-only flags
  (`stat -c`, `realpath -m`, `sed -i` without suffix, `readlink -f`) as
  portability risks rather than bugs, unless the user says macOS/BSD is in scope.
- External tools in use include fzf, tmux, oh-my-bash, and logo-ls. A missing
  optional tool should degrade gracefully, never break shell startup.
- Command files follow a header convention (see `commands/pcd/pcd.sh`): a
  `#!/bin/bash` line, a path comment, a banner describing purpose and
  REQUIREMENTS, then the function, then its `_name` completion function and
  `complete -F`. Match that style when writing new commands.

Always re-read the actual files — this section is orientation, not truth.

## Walkthrough workflow

Use this when the user asks to review/audit/walk through the config or a file.

1. **Pick the unit.** If the user named a file, use it. Otherwise propose an
   order that follows load order (`doc/bashrc.txt` → `main.sh` → `util/` →
   `preferences/` → `commands/` → `aliases.sh`), since earlier files can break
   later ones. Confirm, then start with the first.
2. **Read and check.** Read the whole file. Then run what's available:
   - `bash -n <file>` — syntax.
   - `shellcheck -s bash <file>` if installed (if not, mention
     `sudo apt install shellcheck` once, then fall back to manual review).
   - For functions, exercise them in an isolated shell so the user's session is
     untouched, e.g.
     `bash --norc --noprofile -c 'source ~/bashconfig/commands/upto/upto.sh; cd /tmp/a/b/c && upto a; pwd'`.
     Use scratch directories for anything that deletes or moves files.
   - Check interactions: what does this file rely on that's defined elsewhere,
     and is it loaded by then? (Aliases are expanded when a function is
     *defined*, not when it runs — a function in `commands/` cannot use an alias
     from `aliases.sh`.)
3. **Classify findings** using the definitions below. Every finding needs
   evidence: the line, and the command output or concrete scenario that shows
   the problem. If you can't demonstrate it, say it's suspected, not confirmed.
4. **Report** using the template below.
5. **Ask which fixes to apply.** Present each fix as a minimal diff. Wait.
6. **Apply only what was approved**, then re-run the checks from step 2 and
   show the result. Suggest the user open a new terminal (or
   `source ~/bashconfig/main.sh`) to confirm in a real session.
7. **Move to the next unit** only when the user is ready.

### Severity definitions

- **Broken** — doesn't work at all, or breaks something else. Syntax errors;
  a function that can never do its job (e.g. reads `$0` instead of `$1`);
  references to commands/aliases/files that don't exist at that point; code that
  errors during shell startup; output printed in non-interactive shells
  (breaks `scp`, `rsync`, `git` over ssh).
- **Deprecated** — works today but relies on something obsolete or on its way
  out: `` `backticks` `` in new code, `which` for existence checks (use
  `command -v`), `egrep`/`fgrep`, `[ a -a b ]`/`-o`, `function name()` hybrid
  syntax, tools or flags marked deprecated upstream, plugin/theme config that the
  framework (e.g. oh-my-bash) no longer reads.
- **Bug** — works in the common case but misbehaves in an edge case: unquoted
  expansions (spaces/globs in paths), `read` without `-r`, `cd` without a
  failure check, `return` inside `$( … )` (only exits the subshell), variables
  leaking out of functions because they lack `local`, PATH entries appended on
  every re-source, `rm -rf "$dir"/*` when `$dir` could be empty, unsafe
  `COMPREPLY=($(…))` word-splitting.

Portability issues go under whichever category matches their effect on the
user's real target machines; if a machine isn't in scope yet, list them as a
refactor note instead.

For a fuller checklist of pitfalls specific to sourced config files, read
`references/pitfalls.md` when doing a review.

### Report template

Keep it scannable. Omit empty sections.

```
## <file path>

**Purpose:** one line on what this file does.
**Checks run:** bash -n ✓ | shellcheck: 3 warnings | sandbox test of `upto`: failed

### Broken
1. `file:line` — what's wrong. **Evidence:** output or scenario.
   **Fix:** minimal diff.

### Deprecated
...

### Bugs
...

### Refactor notes (no changes proposed)
- One or two sentences each: what could be better and why. No diffs unless asked.

**Which fixes should I apply?** (e.g. "1 and 3", "all", "none")
```

## Writing new scripts

When the user wants a new command, alias, or preference:

- **Decide where it lives.** Reusable function the user types →
  `commands/<name>/<name>.sh`. Plain alias → `preferences/aliases.sh`.
  Environment/PATH/startup behavior → `preferences/`. Data or helpers other
  files consume → `util/`. New top-level folders require a change to `main.sh`,
  so flag that.
- **Draft in the chat first**, explain the design briefly, and write the file
  only after the user agrees (rule 1 applies to new files too).
- **Make it safe to source:** wrap logic in functions; use `local`; use
  `return`, never `exit`; no `set -e`/`-u`/`-o pipefail` at file scope; no
  output at source time; guard interactive-only behavior with
  `[[ $- == *i* ]] || return`.
- **Make it portable:** check optional dependencies with `command -v tool
  >/dev/null 2>&1` and give an install hint on stderr; avoid hardcoding
  `/home/<user>` — use `$HOME` or `$BASHDIR`; prefer POSIX/bash builtins over
  GNU-only flags when there's a cheap equivalent.
- **Make it robust:** quote every expansion; `read -r`; `cd -- "$dir" || return`;
  send errors to stderr; return non-zero on failure; validate arguments and
  print a usage line.
- **Give it completion** when it takes arguments, using `mapfile`/`compgen`
  safely (see `references/pitfalls.md`).
- **Test it** in an isolated `bash --norc` subshell and show the output.

## Refactor notes

For working code that could be better, keep it to a short summary per item —
the user asked for awareness, not churn. Order by the same priorities:
something that improves robustness first, then readability, then modularity.
Good candidates: duplicated logic that could become a `util/` helper,
hardcoded paths that should use `$BASHDIR`, a loader loop that could be
simpler, slow startup work that could be lazy-loaded. If the user wants one,
it becomes a normal approved change.

## Evolving this skill

This skill is meant to grow with the user's config. When the user corrects you,
settles on a convention ("always put completions in the same file", "macOS is
now in scope"), or a review surfaces a recurring pitfall, propose a small edit to
this SKILL.md or `references/pitfalls.md` — same approval rule as code. Keep
additions general (the *why* and the pattern), not a log of one-off fixes.
