# Go Back To Target Directory
upto()
{
    if [ -z "$1" ]; then
        return
    fi
    local upto=$1
    cd "${PWD/\/$upto\/*//$upto}"
}

## Autocompletion Config
_upto()
{
    local cur=${COMP_WORDS[COMP_CWORD]}
    local d=${PWD//\//\ }
    COMPREPLY=( $( compgen -W "$d" -- "$cur" ) )
}
complete -F _upto upto

# Clear All Saved Tmux Sessions

tmuxc()
{
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

pcd() {
  local shortcuts_file="$HOME/bashconfig/.shortcuts.txt"
  declare -A paths

  if [[ ! -f "$shortcuts_file" ]]; then
    echo "Shortcuts file not found at $shortcuts_file"
    return 1
  fi

  # Load entries from the file into the associative array
  while IFS='=' read -r label path; do
    [[ -n "$label" && -n "$path" ]] && paths["$label"]="${path/#\~/$HOME}"
  done < "$shortcuts_file"

  # Interactive selection
  local selected_key=$(for key in "${!paths[@]}"; do echo "$key"; done | fzf --reverse --header="Select a destination" --bind='tab:down,shift-tab:up')

  if [[ -n "$selected_key" ]]; then
    cd "${paths[$selected_key]}" || echo "Failed to change directory."
  else
    echo "No selection made."
  fi
}
