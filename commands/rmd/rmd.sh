rmd() {
  # Check argument exists
  if [ $# -eq 0 ]; then
    echo "Usage: rmd <directory>" >&2
    return 1
  fi

  # Verify directory exists
  if [ ! -d "$1" ]; then
    echo "Error: '$1' is not a directory" >&2
    return 1
  fi

  # Get absolute path SAFELY (without realpath)
  local target
  target=$(
    cd -- "$1" >/dev/null 2>&1 && pwd -P || {
      echo "Error: Could not resolve path for '$1'" >&2
      return 1
    }
  )

  # STRICT HOME DIRECTORY CHECK
  if [[ "$target" != "$HOME"/* ]]; then
    echo "SECURITY ERROR: Can only delete directories inside $HOME" >&2
    return 1
  fi

  # Extra protection against $HOME itself
  if [[ "$target" == "$HOME" ]]; then
    echo "EMERGENCY STOP: Refusing to delete entire home directory!" >&2
    return 1
  fi

  # Confirmation
  read -p "Delete '$target' and ALL contents? [y/N] " confirm
  if [[ "$confirm" =~ ^[yY]$ ]]; then
    echo "Deleting..."
    rm -rf -- "$target" && echo "Done." || echo "Failed (check permissions?)" >&2
  else
    echo "Aborted."
  fi
}
