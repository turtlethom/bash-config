# ~/bashconfig/env.sh
# PATH and exported variables. Loaded by every shell that reads ~/.bashrc
# (interactive terminals and `ssh host cmd`; not `bash script.sh` or cron),
# so nothing here may print output or depend on a terminal.
# Every tool is optional: each block is skipped when it isn't installed.

# Add a directory to the end of PATH once, and only if it exists.
path_append() {
  local dir="${1%/}"
  [[ -d "$dir" ]] || return 0
  case ":$PATH:" in
    *":$dir:"*) ;;
    *) PATH="${PATH:+$PATH:}$dir" ;;
  esac
}

# Put a directory first so its commands win; moves it up if already present.
path_prepend() {
  local dir="${1%/}"
  [[ -d "$dir" ]] || return 0
  local rest=":$PATH:"
  while [[ "$rest" == *":$dir:"* ]]; do
    rest="${rest//:"$dir":/:}"
  done
  rest="${rest#:}"; rest="${rest%:}"
  PATH="$dir${rest:+:$rest}"
}

# envman (webi's PATH/env manager). First, because its PATH.env prepends
# entries without checking; path_append below then sees them and skips.
if [ -s "$HOME/.config/envman/load.sh" ]; then
  source "$HOME/.config/envman/load.sh"
fi

# Go toolchain (official tarball install) and `go install` binaries
path_append /usr/local/go/bin
path_append "$HOME/go/bin"

# Rust toolchain (rustup)
if [ -f "$HOME/.cargo/env" ]; then
  source "$HOME/.cargo/env"
fi

# SDKMAN (its docs say to initialise it after other PATH changes)
if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
  export SDKMAN_DIR="$HOME/.sdkman"
  source "$SDKMAN_DIR/bin/sdkman-init.sh"
fi

# User-installed commands (pipx, webi, fcd). Truly last, so they come first
# in PATH and the order stays the same when this file is re-sourced.
path_prepend "$HOME/.local/bin"

export PATH
