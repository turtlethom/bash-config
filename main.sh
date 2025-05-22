# ~/bashconfig/main.sh

# Set the base directory
export BASHDIR="$HOME/bashconfig"

# 1. Source utility functions
if [ -d "$BASHDIR/util" ]; then
    for util_file in "$BASHDIR"/util/*.sh; do
        if [ -f "$util_file" ]; then
            source "$util_file"
        fi
    done
fi

# 2. Source other preferences (except aliases.sh)
if [ -d "$BASHDIR/preferences" ]; then
    for pref_file in "$BASHDIR"/preferences/*.sh; do
        if [ -f "$pref_file" ] && [ "$pref_file" != "$BASHDIR/preferences/aliases.sh" ]; then
            source "$pref_file"
        fi
    done
fi

# 3. Source commands
if [ -d "$BASHDIR/commands" ]; then
    for cmd_dir in "$BASHDIR"/commands/*; do
        if [ -d "$cmd_dir" ]; then
            for cmd_file in "$cmd_dir"/*.sh; do
                if [ -f "$cmd_file" ]; then
                    source "$cmd_file"
                fi
            done
        fi
    done
fi

# 4. Load aliases LAST to prevent overrides
if [ -f "$BASHDIR/preferences/aliases.sh" ]; then
    source "$BASHDIR/preferences/aliases.sh"
fi
