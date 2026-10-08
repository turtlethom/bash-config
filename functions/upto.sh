# ~/bashconfig/functions/upto.sh
# upto <dir>: jump up to the nearest parent directory named <dir>.
#   ~/a/b/c/d $ upto b    ->  ~/a/b
# Tab completes the names of the current directory's parents.

upto() {
  if [[ $# -ne 1 || -z "$1" ]]; then
    echo "Usage: upto <parent-directory-name>" >&2
    return 1
  fi
  # Cut $PWD after the LAST "/<dir>/" so the nearest parent wins.
  # Quoting "$1" keeps *, ? and [ in folder names literal.
  case "$PWD" in
    */"$1"/*) cd -- "${PWD%/"$1"/*}/$1" ;;
    *)
      echo "upto: no parent directory named '$1' in $PWD" >&2
      return 1
      ;;
  esac
}

# Tab completion: the parent folder names (not the current folder itself)
_upto() {
  local cur="${COMP_WORDS[COMP_CWORD]}" part
  local -a parts
  COMPREPLY=()
  IFS=/ read -r -a parts <<< "${PWD%/*}"
  for part in "${parts[@]}"; do
    if [[ -n "$part" && "$part" == "$cur"* ]]; then
      COMPREPLY+=("$part")
    fi
  done
}
complete -o filenames -F _upto upto
