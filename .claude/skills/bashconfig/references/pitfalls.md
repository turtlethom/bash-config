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
  `interactive/aliases.sh` loads last, so functions in `functions/` cannot use
  those aliases. Call the real command instead (e.g. `logo-ls`, or `ls -A`).
- **Using something before it's loaded:** `env.sh` or `local.sh` calling a
  `functions/` function at source time fails (and non-interactive shells never
  load `functions/` at all). Calls inside function bodies are
  fine, since they resolve at run time.
- **Double-sourcing:** sourcing a framework twice, or code that isn't
  idempotent (appends to arrays/PATH), misbehaves when the user runs
  `source ~/.bashrc` again.
- **`$(cd … && pwd)` with `CDPATH` set:** if the path is relative and matches
  a `CDPATH` entry, `cd` prints the directory, which ends up in the captured
  value (it came out doubled, and the whole config failed to load). Use
  `$(CDPATH= cd -- "$dir" && pwd -P)`.

## 2. Interactive vs non-interactive shells

- **Output at source time** (echo, banners, `tmux` auto-attach) in a
  non-interactive shell breaks `scp`, `rsync`, and `git` over ssh. Guard with
  `[[ $- == *i* ]] || return` at the top of the file (in a sourced file,
  `return` stops just that file).
- `[ -n "$PS1" ]` works as an interactive test but `[[ $- == *i* ]]` is the
  more direct, conventional check.
- Auto-launching tmux: also skip when already in tmux (`$TMUX`), when tmux
  isn't installed, and in editor terminals (`$TERM_PROGRAM == vscode`,
  `$NVIM` for Neovim's `:terminal`) so they don't nest or hijack.
- **tmux panes are login shells**: `/etc/profile` and `/etc/profile.d/*` run
  before `.bashrc` there (e.g. bash-completion is already loaded), but not in
  a plain terminal tab. Code that loads something "if not loaded" must check
  for it rather than assume either case.

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
  path and checking it's under `$HOME`. `"$dir"/*` also skips hidden files, so
  an "is it empty?" check and the deletion can disagree.
  `find "$dir" -mindepth 1 -delete` covers exactly what
  `find "$dir" -mindepth 1 -maxdepth 1 -print -quit` saw, and keeps the folder.
- Use `--` before user-supplied paths (`rm -rf -- "$target"`, `cd -- "$1"`) so
  names starting with `-` aren't read as options.
- "Is this directory empty?" — don't parse `ls` output. Use
  `compgen -G "$dir/*" >/dev/null` or
  `[[ -n $(find "$dir" -mindepth 1 -maxdepth 1 -print -quit) ]]`.
- Confirmation prompts for destructive commands should default to No.

## 6. Environment & PATH

- **PATH appended on every source** grows forever. This repo's `env.sh` has
  `path_append` / `path_prepend`: they skip missing directories, strip a
  trailing slash (`/x` and `/x/` are otherwise two entries), and
  `path_prepend` *moves* an existing entry to the front (a prepend that
  skips existing entries doesn't guarantee precedence). Use them for every
  PATH change.
- **Third-party init scripts prepend without checking.** envman's `PATH.env`
  and SDKMAN add entries unconditionally. Load such scripts *before* the
  `path_append` lines that cover the same dirs (so those see them and skip),
  and put the final `path_prepend` after SDKMAN, or the PATH order flips on
  every reload. Verify by sourcing twice and comparing `$PATH`.
- Exported "already loaded" flags (envman's `ENVMAN_LOAD`) make child shells,
  such as tmux panes, skip the init and inherit the parent's PATH instead.
  Usually fine, but it makes "before" snapshots from an existing shell differ
  from a fresh terminal.
- Hardcoded user paths (`/home/alice/...`) break on other machines — use `$HOME`
  or `$BASHDIR`. Version numbers in comments (e.g. "Go 1.22.2") go stale.
- `cd ~` in `.bashrc` changes directory for every new shell, including ones an
  editor or tmux opens in a project folder. Often unwanted, but in this repo
  it's a deliberate choice (see "Decisions already made" in SKILL.md).
- Unquoted variables in the `.bashrc` snippet (`source $BASH_CONFIG`) break if
  `$HOME` has a space; quote them.

## 7. Completion

- `COMPREPLY=($(compgen -W "$words" -- "$cur"))` word-splits and globs the
  output (shellcheck SC2207). Safer:
  ```bash
  mapfile -t COMPREPLY < <(compgen -W "$words" -- "$cur")
  ```
  Even that splits a word list on spaces. When candidates can contain spaces
  (folder names), build `COMPREPLY` in a loop with a prefix test
  (`[[ $part == "$cur"* ]] && COMPREPLY+=("$part")`) and register with
  `complete -o filenames -F …` so readline escapes the inserted text.
- Completion functions should be cheap — they run on every Tab.
- If the completion reads a file, use the same path variable as the command
  (one shared default) so they can't drift apart.
- Many tool completions (cobra-generated ones like fcd's) call bash-completion
  helpers such as `_get_comp_words_by_ref` at Tab time, so bash-completion must
  be loaded before them, or Tab prints "command not found".

## 8. External tools & frameworks

- Check optional tools with `command -v tool >/dev/null 2>&1` (not `which`),
  and degrade gracefully: skip the alias/feature, or print an install hint on
  stderr only when the user actually runs the command.
- Aliases that replace core commands (`alias ls='logo-ls …'`) break on any
  machine without that tool. Define them conditionally.
- **Wrapper scripts:** when a tool's shell wrapper calls a binary (fcd's
  wrapper calls `~/.local/bin/fcd`), check for the binary, not just the
  wrapper file, or a half-removed tool leaves a command that fails with 127.
- **oh-my-bash:**
  - Configuration variables (`OSH_THEME`, `plugins`, `aliases`,
    `completions`) must be set *before* `source "$OSH/oh-my-bash.sh"`, and it
    must be sourced exactly once.
  - To check for renamed/removed settings, compare against the installed
    `~/.oh-my-bash/templates/bashrc.osh-template` rather than memory.
  - Its official installer **moves `~/.bashrc` aside and replaces it**.
    Install with `git clone --depth=1` instead.
  - It does **not** load bash-completion (the code in `lib/bourne-shell.sh` is
    marked unused). Load it yourself, once:
    `[ -z "${BASH_COMPLETION_VERSINFO-}" ] && [ -f /usr/share/bash-completion/bash_completion ]`.
    `/etc/bash_completion` is just a one-line forwarder to that file.
  - Completions resolve `<name>.completion.sh` *or* `.bash`, so a missing
    `.sh` file isn't proof that a completion is missing.
  - Plugins and core libs define many short aliases (the git plugin has 100+;
    bashmarks has `s`/`g`/`p`/`d`; core defines `d`, `..`). Before calling an
    alias "from plugin X", find its definition with `grep -rn` across
    `plugins/`, `aliases/` and `lib/`.
- **Installers that append to `~/.bashrc`:** rustup, SDKMAN, fcd, webi. Here
  `install.sh` removes the lines the repo already handles; when adding a tool,
  add its pattern there.
- **Tools that re-add their line at runtime:** `webi --init bash` greps
  `~/.bashrc` for `webi --init` on *every* call and appends its 2 lines if it
  isn't there. Calling it from the repo while `install.sh` removes the line
  means every new terminal re-adds it. Check a tool's init source for this
  before deciding to "own" its line. `webi --init` also refreshes its package
  list over the network (`curl`, no timeout) when its cache is more than 15
  minutes old, so some terminals make a network request at startup.
- **A tool line placed before the bashconfig block** can run before `env.sh`
  has put the tool on PATH (`~/.local/bin`), and fail with "command not found"
  in non-login terminals. Keep such lines after the block.
- **SDKMAN's init fails under `set -u`** (`ZSH_VERSION: unbound variable`).
  A strict-mode script that sources `env.sh` must wrap it in
  `set +eu … set -eu`.
- **tmux-resurrect's save dir:** `~/.tmux/resurrect` if that exists,
  otherwise `${XDG_DATA_HOME:-~/.local/share}/tmux/resurrect`, or the
  `@resurrect-dir` option (see the plugin's `scripts/helpers.sh`).
  tmux-continuum re-saves every 15 minutes while tmux runs.
- **Other repos' installers** may assume they run from their own directory
  (tmux-config checks for `.tmux.conf`; fcd's ran `go build` on a file path,
  which needs the module root — fixed with `go build -C "$root" -o … .`). Run
  them as `bash -c 'cd -- "$1" && bash install.sh' _ "$dir"`.

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
  `time bash -i -c exit` (with `TMUX=x` so it doesn't attach), or time one
  block with `$EPOCHREALTIME` (see `testing.md`).
- Avoid spawning subprocesses at source time when a builtin works.
  `eval "$(tool --init bash)"` is a subprocess per terminal (webi's is about
  36 ms) for output that rarely changes; caching it to a file is an option if
  startup feels slow.
- Heavy frameworks and many plugins/completions are the usual cost — trim or
  lazy-load (define a stub function that sources the real thing on first use).
