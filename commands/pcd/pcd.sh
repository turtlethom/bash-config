#!/bin/bash
# ~/bashconfig/commands/pcd/pcd.sh
# REQUIRES: fzf (for interactive selection)
# Security-hardened directory navigator with shortcuts.

pcd() {
  local shortcuts_file="${1:-$HOME/bashconfig/commands/pcd/shortcuts.txt}"
  declare -A paths
  declare -a labels_in_order
  local selected_key
  # --- Check if fzf is installed ---
  if ! command -v fzf &> /dev/null; then
    echo "Error: 'fzf' is required but not installed." >&2
    echo "Install it with:" >&2
    echo "  sudo apt install fzf  # Debian/Ubuntu" >&2
    echo "  brew install fzf      # macOS" >&2
    echo "Or see: https://github.com/junegunn/fzf#installation" >&2
    return 1
  fi

  # --- SECURITY CHECKS ---
  # 1. Validate shortcuts file exists and is owned by the user.
  if [[ ! -f "$shortcuts_file" ]]; then
    echo "Error: Shortcuts file not found at '$shortcuts_file'" >&2
    return 1
  fi

  # Paranoid mode: Verify file ownership (optional)
  if [[ "$(stat -c %U "$shortcuts_file" 2>/dev/null)" != "$USER" ]]; then
    echo "Error: '$shortcuts_file' is not owned by you!" >&2
    return 1
  fi

  # --- PARSE SHORTCUTS FILE ---
  while IFS='=' read -r label path; do
    # Skip empty/malformed lines
    if [[ -z "$label" || -z "$path" ]]; then
      continue
    fi

    # 2. Require absolute paths (must start with '/')
    if [[ "$path" != /* ]]; then
      echo "Error: Path '$path' must be absolute (start with '/')" >&2
      continue
    fi

    # 3. Resolve path safely (prepend $HOME, resolve symlinks)
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

    # Store valid paths and maintain order for prefixing
    paths["$label"]="$resolved_path"
    labels_in_order+=("$label")
  done < "$shortcuts_file"

  # --- INTERACTIVE SELECTION ---
  if [[ ${#paths[@]} -eq 0 ]]; then
    echo "Error: No valid directories found in '$shortcuts_file'" >&2
    return 1
  fi

  # Generate prefixed labels for display
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

  selected_key=$(
    printf "%s\n" "${prefixed_labels[@]}" | fzf \
      --reverse \
      --height 40% \
      --bind 'ctrl-j:down,ctrl-k:up' \
      --header="Select directory (Ctrl-J/K: Navigate, Enter: Confirm)"
  )

  # --- CHANGE DIRECTORY ---
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

# --- AUTOCOMPLETION FUNCTION ---
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
