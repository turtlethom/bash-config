# ~/bashconfig/interactive/tmux.sh
# Auto-attach every new terminal to the tmux session 'main'.
# Skipped when tmux isn't installed, when already inside tmux, and in editor
# terminals (VS Code, Neovim's :terminal), which manage their own panes.
# REQUIREMENTS: tmux; config + plugins from github.com/turtlethom/tmux-config
# (install.sh checks both).
if command -v tmux >/dev/null 2>&1 && [ -n "$PS1" ] && [ -z "$TMUX" ] \
  && [ "${TERM_PROGRAM-}" != vscode ] && [ -z "${NVIM-}" ]; then
  # Adapted from https://unix.stackexchange.com/a/176885/347104
  # Create session 'main' or attach to 'main' if already exists.
  tmux new-session -A -s main
fi
