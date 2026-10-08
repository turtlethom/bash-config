# Pitfalls in sourced Bash config files

A checklist for reviews. Each item says what to look for, why it matters in a
config that is *sourced into an interactive shell*, and the usual fix.

## Contents
1. Sourcing & load order
2. Interactive vs non-interactive shells
3. Functions
4. Quoting & word splitting
5. Filesystem safety
6. Environment & PATH
7. Completion
8. External tools & frameworks
9. Portability (GNU vs BSD/macOS)
10. Startup performance

---

## 1. Sourcing & load order

- **`exit` in a sourced file** closes the user's terminal. Use `return`.
- **`set -e`, `set -u`, `set -o pipefail` at file scope** change the user's live
  shell; one failing command later can kill the session. Keep them out of
  sourced files (they are fine inside a standalone executable script).
- **Aliases expand at parse time.** A function body is parsed when the file is
  sourced, so it only sees aliases defined *before* it. In this repo
  `aliases.sh` loads last, so functions in `commands/` cannot use those aliases.
  Call the real command instead (e.g. `logo-ls`, or `ls -A`).
- **Using something before it's loaded:** a `util/` helper calling a
  `commands/` function at source time fails. Calls inside function bodies are
  fine, since they resolve at run time.
- **Double-sourcing:** sourcing a framework twice, or code that isn't
  idempotent (appends to arrays/PATH), misbehaves when the user runs
  `source ~/.bashrc` again.

## 2. Interactive vs non-interactive shells

- **Output at source time** (echo, banners, `tmux` auto-attach) in a
  non-interactive shell breaks `scp`, `rsync`, and `git` over ssh. Guard with
  `[[ $- == *i* ]] || return` at the top of the file (in a sourced file,
  `return` stops just that file).
- `[ -n "$PS1" ]` works as an interactive test but `[[ $- == *i* ]]` is the
  more direct, conventional check.
- Auto-launching tmux: also skip when already in tmux (`$TMUX`), when tmux
  isn't installed, and consider skipping in editor terminals (`$TERM_PROGRAM`,
  `$VSCODE_*`) so they don't nest or hijack.

## 3. Functions

- **Positional params:** inside a function, arguments are `$1…$n`; `$0` is the
  shell/script name. Reading `$0` as an argument is a Broken finding.
- **Missing `local`:** variables leak into the user's session and can clobber
  their own variables. `declare` inside a function *is* local; plain
  assignment is not.
- **`return` inside `$( … )`** only exits the subshell. The function keeps
  going with an empty value. Check the substitution's exit status instead:
  `target=$(cd -- "$1" && pwd -P) || { echo "…" >&2; return 1; }`.
- **`cd` without a check:** `cd "$dir" || return 1`. Matters more before
  destructive commands.
- **`((i++))` returns status 1 when `i` was 0.** Harmless normally, fatal under
  `set -e`. `((i += 1))` or `i=$((i + 1))` avoids it.
- **Errors to stdout:** send diagnostics to `>&2` so callers capturing stdout
  don't get them, and return non-zero.
- **Naming collisions:** a function named like an existing command (`ls`,
  `cd`) shadows it everywhere; check with `type -a name`.

## 4. Quoting & word splitting

- Quote every expansion: `"$var"`, `"${arr[@]}"`, `"$(cmd)"`. Unquoted paths
  break on spaces and expand globs.
- `read -r` (without `-r`, backslashes are eaten). Use `IFS= read -r line` when
  leading/trailing whitespace matters.
- `read -p` is bash-only, which is fine here, but pair it with `-r`.
- In `[[ ]]`, the right side of `==`/`!=` is a pattern unless quoted. Quote it
  when you mean a literal string.
- `printf '%s\n'` over `echo` for arbitrary data (echo mangles `-n`, `-e`,
  backslashes).

## 5. Filesystem safety

- `rm -rf "$dir"/*` with an empty or unset `$dir` becomes `rm -rf /*`. Guard with
  `${dir:?}` or an explicit non-empty check, and prefer resolving to an absolute
  path and checking it's under `$HOME` (as `rmd` does).
- Use `--` before user-supplied paths (`rm -rf -- "$target"`, `cd -- "$1"`) so
  names starting with `-` aren't read as options.
- "Is this directory empty?" — don't parse `ls` output. Use
  `compgen -G "$dir/*" >/dev/null` or
  `[[ -n $(find "$dir" -mindepth 1 -maxdepth 1 -print -quit) ]]`.
- Confirmation prompts for destructive commands should default to No.

## 6. Environment & PATH

- **PATH appended on every source** grows forever. Add idempotently:
  ```bash
  path_add() { case ":$PATH:" in *":$1:"*) ;; *) PATH="$PATH:$1" ;; esac; }
  ```
  and only if the directory exists (`[[ -d $1 ]]`), so missing tools on a new
  machine don't add dead entries.
- Hardcoded user paths (`/home/alice/...`) break on other machines — use `$HOME`
  or `$BASHDIR`. Version numbers in comments (e.g. "Go 1.22.2") go stale.
- `cd ~` in `.bashrc` changes directory for every new shell, including ones an
  editor or tmux opens in a project folder. Usually unwanted.
- Unquoted variables in the `.bashrc` snippet (`source $BASH_CONFIG`) break if
  `$HOME` has a space; quote them.

## 7. Completion

- `COMPREPLY=($(compgen -W "$words" -- "$cur"))` word-splits and globs the
  output (shellcheck SC2207). Safer:
  ```bash
  mapfile -t COMPREPLY < <(compgen -W "$words" -- "$cur")
  ```
- Completion functions should be cheap — they run on every Tab.
- If the completion reads a file, use the same path variable as the command
  (e.g. one shared `PCD_SHORTCUTS` default) so they can't drift apart.

## 8. External tools & frameworks

- Check optional tools with `command -v tool >/dev/null 2>&1` (not `which`),
  and degrade gracefully: skip the alias/feature, or print an install hint on
  stderr only when the user actually runs the command.
- Aliases that replace core commands (`alias ls='logo-ls …'`) break on any
  machine without that tool. Define them conditionally.
- **oh-my-bash:** configuration variables (`OSH_THEME`, `plugins`, `aliases`,
  `completions`) must be set *before* `source "$OSH/oh-my-bash.sh"`, and it
  should be sourced exactly once. Check upstream for renamed/removed settings
  when flagging deprecations.
- `/etc/bash_completion` is often already sourced by the system `bashrc` or by
  the framework; sourcing it again slows startup.

## 9. Portability (GNU vs BSD/macOS)

Flag these when a target machine might not have GNU coreutils:

| GNU (Linux/WSL)        | BSD/macOS equivalent / portable option     |
|------------------------|--------------------------------------------|
| `stat -c %U file`      | `stat -f %Su file`; or `[[ -O file ]]`     |
| `realpath -m`          | no `-m`; use `cd -- dir && pwd -P`         |
| `readlink -f`          | `cd -P` + `pwd -P`, or `realpath` (newer macOS) |
| `sed -i 's/…/'`        | `sed -i '' 's/…/'`; or write to temp + mv  |
| `date -d`              | `date -j -f`                               |

Also: macOS ships bash 3.2, which lacks associative arrays (`declare -A`),
`mapfile`, and `${var,,}`. If macOS is in scope, either require a newer bash
(Homebrew) or avoid those features.

## 10. Startup performance

- Every command at source time runs for every new terminal. Measure with
  `time bash -i -c exit`.
- Avoid spawning subprocesses at source time when a builtin works.
- Heavy frameworks and many plugins/completions are the usual cost — trim or
  lazy-load (define a stub function that sources the real thing on first use).
