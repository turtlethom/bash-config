# ~/bashconfig/interactive/tools.sh
# Shell integration (cd wrappers, Tab completion) for optional tools.
# Each block is skipped when the tool isn't installed. Loaded after
# oh_my_bash.sh because fcd's completion needs bash-completion.
#
# Not here: webi. `webi --init bash` re-appends its own line to ~/.bashrc
# whenever ~/.bashrc doesn't contain it, so webi keeps that line itself and
# install.sh leaves it alone.

# fcd: fuzzy cd wrapper + its completion (the wrapper calls ~/.local/bin/fcd)
if [ -x "$HOME/.local/bin/fcd" ] && [ -f "$HOME/.local/share/fcd/fcd.sh" ]; then
  source "$HOME/.local/share/fcd/fcd.sh"
  if [ -f "$HOME/.local/share/fcd/fcd.bash" ]; then
    source "$HOME/.local/share/fcd/fcd.bash"
  fi
fi
