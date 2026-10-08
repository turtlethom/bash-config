# ~/bashconfig/env.sh
# PATH and exported variables. Loaded for EVERY shell (including `ssh host cmd`
# and scripts), so nothing here may print output or depend on a terminal.

# Add a directory to PATH once, and only if it exists on this machine.
# Safe to call on every re-source: duplicates are skipped.
path_append() {
  [[ -d "$1" ]] || return 0
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="${PATH:+$PATH:}$1" ;;
  esac
}

path_prepend() {
  [[ -d "$1" ]] || return 0
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1${PATH:+:$PATH}" ;;
  esac
}

# Go toolchain (official tarball install location)
path_append /usr/local/go/bin

export PATH
