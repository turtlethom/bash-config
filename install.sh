#!/usr/bin/env bash
# ~/bashconfig/install.sh
# One command to set up bashconfig on a new machine. Safe to re-run at any
# time as a health check:
#   1. Checks dependencies and offers to install anything missing
#   2. Checks the tmux config (tmux-config repo) and tpm
#   3. Checks fcd (own repo), reports optional tools and the font requirement
#   4. Generates the bashconfig block in ~/.bashrc and cleans up lines the
#      repo now handles (shows a diff, asks first, keeps a backup). Last, so
#      it also cleans lines that installers above just appended.
# Nothing is changed or installed without a y/N prompt; the default is No.
#
# Usage: bash ~/bashconfig/install.sh

set -euo pipefail

bashdir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
bashrc="$HOME/.bashrc"

# ask "Question?" -> succeeds only on y/Y. No input (stdin closed) means No.
ask() {
  local reply=""
  read -r -p "$1 [y/N] " reply || true
  [[ "$reply" == [yY] ]]
}

have() { command -v "$1" >/dev/null 2>&1; }

# run <command...> -> runs it, but a failure (or Ctrl-C in apt) doesn't abort
run() {
  "$@" || echo "  -> failed or cancelled: $*" >&2
}

# Check tools with the same PATH your shell gets (Go, ~/.local/bin, ...).
# SDKMAN's init isn't safe under `set -eu`, so relax it while loading env.sh.
set +eu
source "$bashdir/env.sh"
set -eu

#----------------------------------------------------------------------------
# 1. Required tools (the config works without them, but not as intended)
#----------------------------------------------------------------------------
echo
echo "== Required tools"

if have apt-get; then
  pm="apt"
elif have brew; then
  pm="brew"
else
  pm=""
fi

missing=()

# need <command> <apt package> <brew package>
need() {
  if have "$1"; then
    echo "  [ok]      $1"
    return
  fi
  echo "  [missing] $1"
  case "$pm" in
    apt)  missing+=("$2") ;;
    brew) missing+=("$3") ;;
    *)    echo "            install '$1' with your package manager" ;;
  esac
}

need git     git     git
need tmux    tmux    tmux
need python3 python3 python
need jq      jq      jq

# bash-completion is a file, not a command (Tab completion for git, fcd, ...)
if [[ "$pm" == apt ]]; then
  if [[ -f /usr/share/bash-completion/bash_completion ]]; then
    echo "  [ok]      bash-completion"
  else
    echo "  [missing] bash-completion"
    missing+=(bash-completion)
  fi
fi

if (( ${#missing[@]} > 0 )); then
  if [[ "$pm" == apt ]]; then
    install_cmd=(sudo apt install "${missing[@]}")
  else
    install_cmd=(brew install "${missing[@]}")
  fi
  echo "  To install: ${install_cmd[*]}"
  if ask "  Run it now?"; then
    run "${install_cmd[@]}"
  fi
fi

# logo-ls: not packaged in apt, so point to the release download
if have logo-ls; then
  echo "  [ok]      logo-ls"
else
  echo "  [missing] logo-ls (the ls/lsa/l. aliases use it)"
  echo "            Download the .deb for your CPU from"
  echo "            https://github.com/Yash-Handa/logo-ls/releases"
  echo "            then: sudo apt install ./logo-ls_*.deb"
fi

# oh-my-bash: clone it. Its official installer would replace ~/.bashrc.
omb_dir="$HOME/.oh-my-bash"
if [[ -f "$omb_dir/oh-my-bash.sh" ]]; then
  echo "  [ok]      oh-my-bash"
elif [[ -e "$omb_dir" ]]; then
  echo "  [broken]  $omb_dir exists but has no oh-my-bash.sh; move it aside and re-run"
else
  echo "  [missing] oh-my-bash"
  omb_cmd=(git clone --depth=1 https://github.com/ohmybash/oh-my-bash.git "$omb_dir")
  echo "  To install: ${omb_cmd[*]}"
  if ! have git; then
    echo "            (install git first, then re-run this script)"
  elif ask "  Run it now?"; then
    run "${omb_cmd[@]}"
  fi
fi

#----------------------------------------------------------------------------
# 2. tmux config (separate repo) and its plugin manager
#----------------------------------------------------------------------------
echo
echo "== tmux config"

tmux_repo="https://github.com/turtlethom/tmux-config.git"
tmux_dir="$HOME/.tmux-config"          # location its README uses
tpm_dir="$HOME/.tmux/plugins/tpm"

if [[ -f "$HOME/.tmux.conf" && -d "$HOME/.tmux.d" ]]; then
  echo "  [ok]      ~/.tmux.conf and ~/.tmux.d"
else
  echo "  [missing] ~/.tmux.conf / ~/.tmux.d (from $tmux_repo)"
  if [[ ! -d "$tmux_dir" ]]; then
    clone_cmd=(git clone "$tmux_repo" "$tmux_dir")
    echo "  To clone: ${clone_cmd[*]}"
    if ! have git; then
      echo "            (install git first, then re-run this script)"
    elif ask "  Run it now?"; then
      run "${clone_cmd[@]}"
    fi
  fi
  if [[ -f "$tmux_dir/install.sh" ]]; then
    echo "  To install: (cd $tmux_dir && bash install.sh)"
    if ask "  Run it now?"; then
      run bash -c 'cd -- "$1" && bash install.sh' _ "$tmux_dir"
    fi
  fi
fi

if [[ -d "$tpm_dir" ]]; then
  echo "  [ok]      tpm (tmux plugin manager)"
else
  echo "  [missing] tpm (tmux plugin manager)"
  tpm_cmd=(git clone --depth=1 https://github.com/tmux-plugins/tpm "$tpm_dir")
  echo "  To install: ${tpm_cmd[*]}"
  if ! have git; then
    echo "            (install git first, then re-run this script)"
  elif ask "  Run it now?"; then
    run "${tpm_cmd[@]}"
    echo "  Then inside tmux press PREFIX + I to install the plugins."
  fi
fi

#----------------------------------------------------------------------------
# 3. fcd, optional tools, font (each tool is skipped by the config when absent)
#----------------------------------------------------------------------------
echo
echo "== Optional tools"

# optional <name> <file that proves it's installed> <where to get it>
optional() {
  if [[ -e "$2" ]] || have "$1"; then
    echo "  [ok]      $1"
  else
    echo "  [--]      $1  ($3)"
  fi
}

optional go    /usr/local/go/bin/go               "https://go.dev/doc/install"
optional cargo "$HOME/.cargo/bin/cargo"           "https://rustup.rs"
optional sdk   "$HOME/.sdkman/bin/sdkman-init.sh" "https://sdkman.io/install"
optional webi  "$HOME/.local/bin/webi"            "https://webinstall.dev"
echo "  Note: the rustup and SDKMAN installers append their own line to"
echo "  ~/.bashrc. env.sh already loads both; the ~/.bashrc step removes it."

# fcd: own repo, same path on every machine. Its scripts/install.sh builds
# with Go, installs to ~/.local and appends lines to ~/.bashrc (cleaned up by
# the ~/.bashrc step below).
fcd_repo="https://github.com/turtlethom/fcd.git"
fcd_dir="$HOME/Desktop/workspace/TURTLETHOM/linux_tools/fcd"

if [[ -x "$HOME/.local/bin/fcd" ]]; then
  echo "  [ok]      fcd"
else
  echo "  [--]      fcd  ($fcd_repo; needs Go)"
  if [[ ! -d "$fcd_dir/.git" ]]; then
    clone_cmd=(git clone "$fcd_repo" "$fcd_dir")
    echo "  To clone: ${clone_cmd[*]}"
    if ! have git; then
      echo "            (install git first, then re-run this script)"
    elif ask "  Run it now?"; then
      run "${clone_cmd[@]}"
    fi
  fi
  if [[ -f "$fcd_dir/scripts/install.sh" ]]; then
    if ! have go; then
      echo "            (install Go first: https://go.dev/doc/install, then re-run)"
    else
      # Run from the repo root: its `go build` needs to start inside the module.
      echo "  To install: (cd $fcd_dir && bash scripts/install.sh)"
      if ask "  Run it now?"; then
        run bash -c 'cd -- "$1" && bash scripts/install.sh' _ "$fcd_dir"
      fi
    fi
  fi
fi

echo
echo "== Terminal font"
echo "  The powerline prompt and logo-ls icons need a Nerd Font selected in"
echo "  your terminal app (on WSL: Windows Terminal > Settings > Profile >"
echo "  Appearance > Font face). Get one at https://www.nerdfonts.com"
echo "  Without it, the prompt and ls show empty boxes instead of icons."


#----------------------------------------------------------------------------
# 4. ~/.bashrc is generated from this repo (last; see header)
#----------------------------------------------------------------------------
# ~/.bashrc should hold only the managed block below. Each run:
#   a. rewrites the block between the markers (or adds it at the end)
#   b. finds lines the repo now handles (old hook, PATH, tool inits) and
#      removes them, along with the comment lines directly above them
#   c. lists every other line, so it can be moved into env.sh or local.sh
# Lines that come from the system default (/etc/skel/.bashrc) are kept quietly.

begin_marker="# >>> bashconfig >>>"
end_marker="# <<< bashconfig <<<"

# Write $HOME literally when the repo is under it, so the block is
# identical on every machine.
if [[ "$bashdir" == "$HOME"/* ]]; then
  main_ref="\$HOME/${bashdir#"$HOME"/}/main.sh"
else
  main_ref="$bashdir/main.sh"
fi

managed_block() {
  cat <<EOF
$begin_marker (managed by install.sh; edits inside are overwritten)
# Set Terminal Path To ~
cd ~

if [ -f "$main_ref" ]; then
  source "$main_ref"
fi
$end_marker
EOF
}

# Lines the repo now handles. Each pattern matches only a single-purpose line,
# so e.g. a PATH line that also adds some other directory is left alone.
re_hook='bashconfig/main\.sh|BASH_CONFIG|^# COPY THIS INTO BASHRC|^# Set Terminal Path To ~$|^cd ~$'
re_localbin='^(export )?PATH="?(\$PATH:)?(\$HOME|~)/\.local/bin/?(:\$PATH)?"?$'
re_gobin='^(export )?PATH="?(\$PATH:)?(\$HOME/go|/usr/local/go)/bin/?(:\$PATH)?"?$'
re_envman='envman/load\.sh'
re_sdkman='SDKMAN_DIR=|sdkman-init\.sh'
re_cargo='\.cargo/env'
re_fcd='/share/fcd/fcd\.(sh|bash)'

# Lines another tool owns and re-adds itself: kept, not reported for review.
# webi: `webi --init bash` re-appends its line whenever ~/.bashrc lacks it.
re_webi='webi --init'

# covered_by <trimmed line> -> prints what now handles it, or nothing
covered_by() {
  if   [[ "$1" =~ $re_hook ]];     then echo "the bashconfig block"
  elif [[ "$1" =~ $re_localbin ]]; then echo "env.sh (~/.local/bin)"
  elif [[ "$1" =~ $re_gobin ]];    then echo "env.sh (Go)"
  elif [[ "$1" =~ $re_envman ]];   then echo "env.sh (envman)"
  elif [[ "$1" =~ $re_sdkman ]];   then echo "env.sh (SDKMAN)"
  elif [[ "$1" =~ $re_cargo ]];    then echo "env.sh (Rust)"
  elif [[ "$1" =~ $re_fcd ]];      then echo "interactive/tools.sh (fcd)"
  fi
}

from_skel() {
  [[ -f /etc/skel/.bashrc ]] && grep -qxF -- "$1" /etc/skel/.bashrc
}

out=()              # lines of the new file (outside the block)
removed=()          # report: lines the repo now covers
unknown=()          # report: lines to move into the repo by hand
pending=()          # comment lines; their fate depends on the next line
pending_report=()
skel_count=0
owned=()            # lines another tool manages (webi); placed after the block
owned_count=0
block_at=-1         # index in out[] where the block goes (-1 = at the end)
in_block=0
in_legacy_if=0
n=0

flush_pending() {   # keep the waiting comments
  if (( ${#pending[@]} > 0 )); then
    out+=("${pending[@]}")
  fi
  pending=(); pending_report=()
}

current=""
if [[ -f "$bashrc" ]]; then
  current="$(cat -- "$bashrc")"
fi

while IFS= read -r line || [[ -n "$line" ]]; do
  n=$((n + 1))
  t="${line#"${line%%[![:space:]]*}"}"     # trim leading whitespace
  t="${t%"${t##*[![:space:]]}"}"           # trim trailing whitespace

  # a. the existing managed block is replaced as a whole
  if (( in_block )); then
    [[ "$t" == "$end_marker"* ]] && in_block=0
    continue
  fi
  if [[ "$t" == "$begin_marker"* ]]; then
    flush_pending
    block_at=${#out[@]}
    in_block=1
    continue
  fi

  # body of the old `if [ -f $BASH_CONFIG ]; then ... fi` hook
  if (( in_legacy_if )); then
    removed+=("$n: $line")
    [[ "$t" == fi ]] && in_legacy_if=0
    continue
  fi

  if [[ -z "$t" ]]; then
    flush_pending
    out+=("")
    continue
  fi

  by="$(covered_by "$t")"

  if [[ "$t" == \#* && -z "$by" ]]; then
    pending+=("$line")
    pending_report+=("$n: $line")
    continue
  fi

  # b. covered: drop it and the comments directly above it
  if [[ -n "$by" ]]; then
    if (( ${#pending_report[@]} > 0 )); then
      removed+=("${pending_report[@]}")
    fi
    pending=(); pending_report=()
    removed+=("$n: $line   -> $by")
    if [[ "$t" == if\ * && "$t" != *fi ]]; then
      in_legacy_if=1
    fi
    continue
  fi

  # Lines another tool owns: moved to just after the block (with the comments
  # directly above them), since they may need the PATH that main.sh sets up.
  if [[ "$t" =~ $re_webi ]]; then
    if (( ${#pending[@]} > 0 )); then
      owned+=("${pending[@]}")
    fi
    pending=(); pending_report=()
    owned+=("$line")
    owned_count=$((owned_count + 1))
    continue
  fi

  # c. anything else stays
  flush_pending
  out+=("$line")
  if from_skel "$line"; then
    skel_count=$((skel_count + 1))
  else
    unknown+=("$n: $line")
  fi
done <<< "$current"
flush_pending

(( block_at < 0 )) && block_at=${#out[@]}

# The block, followed by the lines other tools own.
block_and_owned() {
  echo
  managed_block
  if (( ${#owned[@]} > 0 )); then
    echo
    printf '%s\n' "${owned[@]}"
  fi
  echo
}

# Assemble: kept lines with the block in place; squeeze runs of blank lines
# and drop leading/trailing ones.
new_bashrc="$(mktemp)"
trap 'rm -f "$new_bashrc"' EXIT
{
  for (( i = 0; i < ${#out[@]}; i++ )); do
    if (( i == block_at )); then block_and_owned; fi
    printf '%s\n' "${out[i]}"
  done
  if (( block_at >= ${#out[@]} )); then block_and_owned; fi
} | awk 'NF { if (seen && blank) print ""; print; seen = 1; blank = 0; next } { blank = 1 }' > "$new_bashrc"

echo
echo "== ~/.bashrc"
if [[ -f "$bashrc" ]] && cmp -s "$bashrc" "$new_bashrc"; then
  echo "  [ok]      up to date"
else
  if (( ${#removed[@]} > 0 )); then
    echo "  These lines are now handled by the repo and will be removed:"
    printf '    %s\n' "${removed[@]}"
  fi
  echo "  Proposed change:"
  if [[ -f "$bashrc" ]]; then
    diff -u -L "~/.bashrc (now)" -L "~/.bashrc (new)" "$bashrc" "$new_bashrc" | sed 's/^/    /' || true
  else
    sed 's/^/    + /' "$new_bashrc"
  fi
  if ask "  Apply it?"; then
    if [[ -f "$bashrc" ]]; then
      backup="$bashrc.bak.$(date +%Y%m%d-%H%M%S)"
      cp -- "$bashrc" "$backup"
      echo "  backed up to $backup"
    fi
    cat -- "$new_bashrc" > "$bashrc"   # cat keeps permissions and symlinks
    echo "  [ok]      ~/.bashrc updated"
  else
    echo "  [skipped] ~/.bashrc left unchanged"
  fi
fi

if (( skel_count > 0 )); then
  echo "  [ok]      $skel_count line(s) from the system default ~/.bashrc kept"
fi
if (( owned_count > 0 )); then
  echo "  [ok]      webi's line kept (webi manages it and re-adds it if removed)"
fi
if (( ${#unknown[@]} > 0 )); then
  echo "  [review]  Lines the repo doesn't know about. Move each into env.sh"
  echo "            (every machine) or local.sh (this machine), then re-run:"
  printf '              %s\n' "${unknown[@]}"
fi

#----------------------------------------------------------------------------
echo
if [[ ! -f "$bashdir/local.sh" ]]; then
  echo "Tip: cp \"$bashdir/local.sh.example\" \"$bashdir/local.sh\" for machine-specific settings."
fi
echo "Done. Open a new terminal or run: source ~/.bashrc"
