BASH_CONFIG_DIR="${BASH_CONFIG%/*}"

# Skip for non-interactive shells
# [[ $- != *i* ]] && return

# Source Startup Config
if [ -f "$BASH_CONFIG_DIR/startup.sh" ]; then
  source "$BASH_CONFIG_DIR/startup.sh"
  # echo "Startup loaded"
fi

# Source 'Oh-My-Bash'
if [ -f "$BASH_CONFIG_DIR/oh_my_bash.sh" ]; then
  source "$BASH_CONFIG_DIR/oh_my_bash.sh"
  # echo "Sourced oh_my_bash.sh"
fi

if [ -f "$BASH_CONFIG_DIR/aliases.sh" ]; then
  source "$BASH_CONFIG_DIR/aliases.sh"
  # echo "Loading aliases from $BASH_CONFIG_DIR/aliases.sh"
fi

if [ -f "$BASH_CONFIG_DIR/commands.sh" ]; then
  source "$BASH_CONFIG_DIR/commands.sh"
  # echo "Sourced commands.sh"
fi
