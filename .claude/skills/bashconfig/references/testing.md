# Testing shell config changes safely

Recipes that work in this environment, and the traps that produced misleading
results before. Use your session's scratchpad directory for every temp file
(`mktemp -d -p "$SCRATCH"`), never `~/.cache` or the repo.

## Contents
1. Simulating shells
2. Simulating machines
3. Before/after snapshots
4. Testing install.sh
5. Destructive code
6. Traps that make a test lie

---

## 1. Simulating shells

**A fresh terminal** (clean environment, nothing inherited from your tool shell):
```bash
env -i HOME="$HOME" USER="$USER" TERM=xterm PATH=/usr/local/bin:/usr/bin:/bin TMUX=x \
  bash --norc -ic 'source ~/bashconfig/main.sh
type -t upto; alias ls' 2>&1 | grep -v 'job control\|process group'
```
- `TMUX=x` stops `tmux.sh` from auto-attaching (which would hang the test).
- `-i` is required for anything interactive-only (see traps).
- The `job control` / `process group` warnings are noise from `-i` without a
  terminal; filter them.

**A login shell, like a tmux pane** (loads `/etc/profile.d` first):
add `source /etc/profile >/dev/null 2>&1;` before sourcing `main.sh`.

**`ssh host cmd` / non-interactive**: `env -i HOME="$HOME" PATH=/usr/bin:/bin
bash -c 'source ~/bashconfig/main.sh; …'`. Capture stdout and assert it's
empty: any output there breaks scp/rsync.

**Reload idempotency**: in one shell, source `main.sh`, save `$PATH`, source it
twice more, and compare. Same string = stable; also check
`tr : '\n' <<<"$PATH" | sort | uniq -d` is empty.

**Timing**: `bash` 5 has `$EPOCHREALTIME`; measure a block with
`s=$EPOCHREALTIME; …; echo $(( (${EPOCHREALTIME/./}-${s/./})/1000 )) ms`.

## 2. Simulating machines

- **Tool missing**: drop its directory from `PATH` (e.g. `PATH=/usr/bin:/bin`
  hides `/usr/local/bin/logo-ls`), or point `HOME` at an empty scratch dir to
  hide `~/.oh-my-bash`, `~/.local/bin`, etc.
- **Editor terminals**: set `TERM_PROGRAM=vscode` or `NVIM=/tmp/x`.
- **Fake tool**: a script in a scratch dir that echoes its arguments, put first
  on `PATH` (e.g. a fake `tmux` to see what would be run).

## 3. Before/after snapshots

When moving code between files (e.g. out of `~/.bashrc`), record what a fresh
shell has before and after, then `diff`:
- `type -t` of every function the user relies on,
- `complete -p <cmd>` for their completions,
- key variables (`SDKMAN_DIR`, `ENVMAN_LOAD`, …),
- `tr : '\n' <<<"$PATH" | sort -u`.

Explain every difference before calling it a regression: some come from the
test setup (an inherited `ENVMAN_LOAD`, a `PATH` without `/usr/games`, locale
sort order).

## 4. Testing install.sh

- Build a fake new machine: `H=$(mktemp -d -p "$SCRATCH")`, copy the repo to
  `$H/bashconfig` (`command cp -r`, see traps), write a test `.bashrc`, then
  `HOME="$H" bash "$H/bashconfig/install.sh"`.
- Feed answers in prompt order with `printf 'n\ny\n' | …`; closed stdin
  (`</dev/null`) answers No everywhere. Prompts aren't printed when stdin
  isn't a terminal, so count the `ask` calls to get the order right.
- Useful `.bashrc` fixtures: the user's legacy file, `/etc/skel/.bashrc` plus
  an old-format block, custom lines (including a PATH line that adds an extra
  dir, which must be kept), no file at all.
- External repos: copy the local clone into the fake home instead of cloning
  from GitHub. For Go builds without network:
  `GOMODCACHE=$HOME/go/pkg/mod GOCACHE="$H/.gocache" GOPROXY=off GOTOOLCHAIN=local`.
- Against the real home, only run it with `</dev/null` (read-only: every
  prompt answers No). Real changes are the user's to run with `!`.

## 5. Destructive code

- Don't run functions that delete through `bash -c`: the harness's safety
  check blocks `rm` inside scripts it can't inspect, and you shouldn't
  route around it. Test deletion logic on scratch dirs, and prefer
  `find "$dir" -mindepth 1 -delete` in the code itself.
- Never use variables like `rm -rf "$U"` to clean up test dirs. Make a fresh
  `mktemp -d` per test instead.
- To show a broken condition without running the deletion, test the
  condition alone (e.g. the `[ "$(lsa …)" ]` check) and show `declare -f`
  of the function.

## 6. Traps that make a test lie

- **`PS1` is unset in non-interactive shells**, so `[ -n "$PS1" ]` guards
  silently skip. Use `bash -i` when testing interactive-only code.
- **Aliases defined on the same line aren't active**: `bash -ic 'source
  aliases.sh; ls'` runs the real `ls`, because bash parses the whole line
  first. Put a newline before the command that should use the alias.
- **`~` vs a changed `HOME`**: in `HOME=/fake bash -c '… ~/bashconfig …'`,
  `~` already points at the fake home. Use absolute repo paths.
- **Your tool shell has the user's aliases** (`ls` → logo-ls, `cp -iv`,
  `mv -iv`): use `command ls`, `command cp` in test scripts.
- **Inherited environment**: your tool shell already has `ENVMAN_LOAD`,
  SDKMAN, etc. loaded, which makes "before" snapshots differ from a real new
  terminal. Use `env -i` for both sides.
- **`type -t fcd` says `file`**, not `function`, when the wrapper isn't
  defined but the binary is on `PATH`; that can be the correct result.
