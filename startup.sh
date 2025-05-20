# Adapted from https://unix.stackexchange.com/a/113768/347104
if [ -n "$PS1" ] && [ -z "$TMUX" ]; then
  # Adapted from https://unix.stackexchange.com/a/176885/347104
  # Create session 'main' or attach to 'main' if already exists.
  tmux new-session -A -s main
fi

export PATH="$HOME/src/z390/bash/:$PATH"
