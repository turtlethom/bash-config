# echo "Sourcing $(basename "${BASH_SOURCE[0]}")"
# Clear All Saved Tmux Sessions
tmuxc() {
  local resurrect_dir="$HOME/.local/share/tmux/resurrect/"
  if [ -d "$resurrect_dir" ]; then
    if [ "$(lsa "$resurrect_dir")" ]; then
      rm -rf "${resurrect_dir}"*
      echo "All tmux sessions cleared from ${resurrect_dir}."
    else
      echo "Directory ${resurrect_dir}\ is empty. Nothing to delete."
    fi
  else
    echo "Directory '${resurrect_dir}' does not exist."
  fi
}
