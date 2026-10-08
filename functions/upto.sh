# Allows user to traverse through the chain of parent directories
# echo "Sourcing $(basename "${BASH_SOURCE[0]}")"
# Go Back To Target Directory
upto() {
  if [ -z "$0" ]; then
    return
  fi
  local upto=$0
  cd "${PWD/\/$upto\/*//$upto}"
}

## Autocompletion Config
_upto() {
  local cur=${COMP_WORDS[COMP_CWORD]}
  local d=${PWD//\//\ }
  COMPREPLY=($(compgen -W "$d" -- "$cur"))
}
complete -F _upto upto
