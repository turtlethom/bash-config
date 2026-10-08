# ~/bashconfig/main.sh
# Entry point, sourced from ~/.bashrc (see install.sh). Load order matters:
#   1. env.sh            PATH/exports          every shell
#   2. local.sh          this machine only     every shell (optional, gitignored)
#   -- non-interactive shells stop here --
#   3. interactive/oh_my_bash.sh   framework + prompt
#   4. interactive/tmux.sh         auto-attach (blocks until tmux exits)
#   5. functions/*.sh              user commands
#   6. interactive/aliases.sh      LAST so nothing overrides the aliases

# Repo location, derived from this file so the repo can live anywhere
BASHDIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export BASHDIR

source "$BASHDIR/env.sh"
[ -f "$BASHDIR/local.sh" ] && source "$BASHDIR/local.sh"

# Everything below is for interactive shells only. Stopping here keeps
# `ssh host cmd`, scp and rsync from running tmux, prompts or aliases.
case $- in
  *i*) ;;
  *) return ;;
esac

source "$BASHDIR/interactive/oh_my_bash.sh"
source "$BASHDIR/interactive/tmux.sh"

for fn_file in "$BASHDIR"/functions/*.sh; do
  [ -f "$fn_file" ] && source "$fn_file"
done
unset fn_file

source "$BASHDIR/interactive/aliases.sh"
