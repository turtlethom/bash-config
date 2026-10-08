#!/usr/bin/env bash
# ~/bashconfig/install.sh
# Hooks bashconfig into ~/.bashrc on a new machine. Safe to run more than once:
# if ~/.bashrc already loads main.sh, nothing is changed.
#
# Usage: bash ~/bashconfig/install.sh

set -euo pipefail

bashdir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
bashrc="$HOME/.bashrc"

if [[ -f "$bashrc" ]] && grep -qF 'bashconfig/main.sh' "$bashrc"; then
  echo "~/.bashrc already loads bashconfig. Nothing to do."
  exit 0
fi

if [[ -f "$bashrc" ]]; then
  backup="$bashrc.bak.$(date +%Y%m%d-%H%M%S)"
  cp -- "$bashrc" "$backup"
  echo "Backed up ~/.bashrc to $backup"
fi

cat >> "$bashrc" <<EOF

# >>> bashconfig >>>
# Set Terminal Path To ~
cd ~

if [ -f "$bashdir/main.sh" ]; then
  source "$bashdir/main.sh"
fi
# <<< bashconfig <<<
EOF

if [[ ! -f "$bashdir/local.sh" ]]; then
  echo "Tip: cp \"$bashdir/local.sh.example\" \"$bashdir/local.sh\" for machine-specific settings."
fi
echo "Done. Open a new terminal or run: source ~/.bashrc"
