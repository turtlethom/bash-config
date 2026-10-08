# ~/bashconfig/interactive/tmux.sh
# Auto-attach every new terminal to the tmux session 'main'.
if [ -n "$PS1" ] && [ -z "$TMUX" ]; then
  # Adapted from https://unix.stackexchange.com/a/176885/347104
  # Create session 'main' or attach to 'main' if already exists.
  tmux new-session -A -s main
fi
