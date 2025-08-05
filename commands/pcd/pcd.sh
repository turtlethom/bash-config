#!/bin/bash
# ~/bashconfig/commands/pcd/pcd.sh

#############################################################################
#<< ***** --- ( PCD ) --- ***** >># 
# ->* Command that utilizes fzf for quickly going to bookmarked directories
# ->* Security-hardened fzf directory navigator with shortcuts & autocomplete.
# ***** --- REQUIREMENTS --- ***** #
# ->* fzf (for interactive selection)
# ->* shortcuts.txt declaration
#############################################################################

pcd() {
  # Location of shortcut file
  local shortcuts_file="${1:-$HOME/bashconfig/commands/pcd/shortcuts.txt}"
  # Associative array (key:value)
  declare -A paths
  # Indexed array
  declare -a labels_in_order
  # Name for user selected key representing shortcut
  local selected_key

  # --- VERIFY FZF INSTALLATION --- >>#
  if ! command -v fzf &> /dev/null; then
    echo "Error: 'fzf' is required but not installed." >&2
    echo "Install it with:" >&2
    echo "  sudo apt install fzf  # Debian/Ubuntu" >&2
    echo "  brew install fzf      # macOS" >&2
    echo "Or see: https://github.com/junegunn/fzf#installation" >&2
    return 1
  fi

  #<< --- SECURITY CHECKS --- >>#
  # 1. Validate shortcuts file exists and is owned by the user.
  if [[ ! -f "$shortcuts_file" ]]; then
    echo "Error: Shortcuts file not found at '$shortcuts_file'" >&2
    return 1
  fi

  #<< --- IDENTITY CHECK --- >>#
  # Paranoid mode: Verify file ownership
  if [[ "$(stat -c %U "$shortcuts_file" 2>/dev/null)" != "$USER" ]]; then
    echo "Error: '$shortcuts_file' is not owned by you!" >&2
    return 1
  fi

  #<< --- PARSE SHORTCUTS FILE --- >>#
  # Parse label and respective path ('SOME_LABEL=/some/directory/')
  while IFS='=' read -r label path; do
    # 1. Skip improper/empty lines
    if [[ -z "$label" || -z "$path" ]]; then
      continue
    fi

    # 2. Require absolute paths (must start with '/')
    if [[ "$path" != /* ]]; then
      echo "Error: Path '$path' must be absolute (start with '/')" >&2
      continue
    fi

    # 3. Resolve path safely (prepend $HOME, resolve symlinks with 'realpath')
    local resolved_path
    resolved_path="$(realpath -mP "$HOME$path" 2>/dev/null)"

    # 4. Verify path is within $HOME
    if [[ -z "$resolved_path" || "$resolved_path" != "$HOME"/* ]]; then
      echo "Error: Path '$path' resolves outside $HOME or is invalid" >&2
      continue
    fi

    # 5. Check if directory exists
    if [[ ! -d "$resolved_path" ]]; then
      echo "Warning: Directory '$resolved_path' for '$label' does not exist" >&2
      continue
    fi

    #<< --- PASS ALL CHECKS --- >>#
    #   >>> Store valid paths and maintain order for prefixing
    paths["$label"]="$resolved_path"
    labels_in_order+=("$label")
  done < "$shortcuts_file"

  #<< --- INTERACTIVE SELECTION --- >>#
  # If no paths exist, inform and exit
  if [[ ${#paths[@]} -eq 0 ]]; then
    echo "Error: No valid directories found in '$shortcuts_file'" >&2
    return 1
  fi

  # Generate prefixed labels for fzf option display
  local -a prefixed_labels
  local prefix_index=0
  for label in "${labels_in_order[@]}"; do
    # Calculate prefix (a, b, c, ..., z, aa, ab, etc.)
    local prefix
    prefix=$(printf "\\$(printf '%03o' $((97 + prefix_index % 26)))")
    if (( prefix_index >= 26 )); then
      prefix=$(printf "\\$(printf '%03o' $((97 + (prefix_index / 26 - 1) % 26)))")$prefix
    fi
    prefixed_labels+=("$prefix) $label")
    ((prefix_index++))
  done

  #<< --- GRAB USER'S SELECTION INTO FZF SEARCH --- >>#
  selected_key=$(
    printf "%s\n" "${prefixed_labels[@]}" | fzf \
      --reverse \
      --height 40% \
      --bind 'ctrl-j:down,ctrl-k:up' \
      --header="Select directory (Ctrl-J/K: Navigate, Enter: Confirm)"
  )

  #<< --- CHANGE DIRECTORY --- >>#
  if [[ -n "$selected_key" ]]; then
    # Extract the original label by removing the prefix
    local original_label="${selected_key#*) }"
    cd "${paths[$original_label]}" || {
      echo "Error: Failed to change directory to '${paths[$original_label]}'" >&2
      return 1
    }
    echo "Changed to: ${paths[$original_label]}"
  fi
}

#<< --- AUTOCOMPLETION FUNCTION --- >>#
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
