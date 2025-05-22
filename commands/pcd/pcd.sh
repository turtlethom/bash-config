#!/bin/bash
# ~/bashconfig/commands/pcd/pcd.sh
# REQUIRED - apt install fzf

# echo "[bashconfig] Loading pcd command"

pcd() {
  local shortcuts_file="${1:-$HOME/bashconfig/commands/pcd/shortcuts.txt}"
  declare -A paths
  local selected_key

  # Validate shortcuts file
  if [[ ! -f "$shortcuts_file" ]]; then
    echo "Error: Shortcuts file not found at $shortcuts_file" >&2
    return 1
  fi

  # Parse shortcuts file
  while IFS='=' read -r label path; do
    if [[ -n "$label" && -n "$path" ]]; then
      # Remove trailing slash if present
      path="${path%/}"
      
      # Add $HOME prefix to paths starting with /
      if [[ "$path" == /* ]]; then
        path="$HOME$path"
      else
        echo "Warning: Path '$path' must start with '/'" >&2
        continue
      fi
      
      # Convert to absolute path
      path="$(realpath -mP "$path" 2>/dev/null)"
      
      # Security check: Must be within $HOME
      if [[ "$path" != "$HOME"/* && "$path" != "$HOME" ]]; then
        echo "Warning: Path must be within your home directory" >&2
        continue
      fi
      
      if [[ ! -d "$path" ]]; then
        echo "Warning: Directory '$path' for '$label' does not exist" >&2
        continue
      fi
      
      paths["$label"]="$path"
    fi
  done < "$shortcuts_file"

  if [[ ${#paths[@]} -eq 0 ]]; then
    echo "Error: No valid directories found in $shortcuts_file" >&2
    return 1
  fi

  # Interactive selection
  selected_key=$(
    printf "%s\n" "${!paths[@]}" | fzf \
      --reverse \
      --height 40% \
      --bind 'ctrl-j:down,ctrl-k:up' \
      --header="Select directory (Ctrl-J/K: Navigate)"
  )

  if [[ -n "$selected_key" ]]; then
    cd "${paths[$selected_key]}" || {
      echo "Error: Failed to change directory" >&2
      return 1
    }
    echo "Changed to: ${paths[$selected_key]}"
    ls --color=auto
  fi
}

# Completion function
_pcd() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local shortcuts_file="$HOME/bashconfig/commands/pcd/shortcuts.txt"
  local labels=()

  if [[ -f "$shortcuts_file" ]]; then
    while IFS='=' read -r label _; do
      [[ -n "$label" ]] && labels+=("$label")
    done < "$shortcuts_file"
  fi

  COMPREPLY=($(compgen -W "${labels[*]}" -- "$cur"))
}

complete -F _pcd pcd
