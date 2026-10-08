# ~/bashconfig/functions/tmuxc.sh
# tmuxc: delete every tmux session saved by tmux-resurrect (asks first).
# Tip: tmux-continuum re-saves every 15 min while tmux runs; for a clean
# slate run `tmux kill-server` first.
# REQUIREMENTS: tmux-resurrect (installed via tmux-config + tpm)

tmuxc() {
  # Same lookup tmux-resurrect uses: ~/.tmux/resurrect if it exists,
  # otherwise $XDG_DATA_HOME/tmux/resurrect.
  local dir="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
  if [[ -d "$HOME/.tmux/resurrect" ]]; then
    dir="$HOME/.tmux/resurrect"
  fi

  if [[ ! -d "$dir" ]]; then
    echo "tmuxc: '$dir' does not exist. Nothing to clear." >&2
    return 1
  fi
  if [[ -z "$(find "$dir" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    echo "Directory '$dir' is empty. Nothing to delete."
    return 0
  fi

  local count reply=""
  count="$(find "$dir" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
  read -r -p "Delete $count saved item(s) in '$dir'? [y/N] " reply || true
  if [[ "$reply" != [yY] ]]; then
    echo "Aborted. Nothing deleted."
    return 1
  fi

  find "$dir" -mindepth 1 -delete
  echo "All tmux sessions cleared from $dir."
}
