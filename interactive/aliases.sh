# Colorize Grep
alias grep='grep --color=auto'

## Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias c='clear'

# 'ls' Aliases: logo-ls adds icons + git status; plain ls is the fallback,
# so ls/lsa/l. work on every machine.
if command -v logo-ls >/dev/null 2>&1; then
  alias ls='logo-ls -1 -D'
  alias lsa='logo-ls -1 -A -D'
  alias l.='logo-ls -i -a -1 -D | grep "^\."'
else
  alias ls='ls -1 --color=auto'
  alias lsa='ls -1 -A'
  alias l.='ls -1 -d .*'
fi

# Git Aliases
alias g='git'
alias gs="git status"
alias ga="git add"
alias gc="git commit -m"
alias gp="git push"
alias gl="git log --oneline --graph"

# Safety Flags
alias mv='mv -iv' # Prompt about moving files/directories
alias cp='cp -iv' # Prompt about copying files/directories
alias df='df -h'  # Human readable disk space usage

# Python 3 Shortcut
alias py='python3'
