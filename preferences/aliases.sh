# Colorize Grep
alias grep='grep --color=auto'

## Nagivation
alias ..='cd ..'
alias ...='cd ../..'

# 'ls' Aliases
alias c='clear'
alias ls='logo-ls -1 -D'
alias lsa='logo-ls -1 -A -D'
alias l.='logo-ls -i -a -1 -D | grep "^\."'

# Git Aliases
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
