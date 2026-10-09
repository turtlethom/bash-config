#!/usr/bin/env bash
# ~/bashconfig/claude/statusline.sh
# Claude Code status line in the style of the oh-my-bash "powerline" prompt
# (interactive/oh_my_bash.sh): user | git branch | cwd, then the model and
# usage: how much of the 5-hour and weekly plan limits is left, and how full
# the conversation's context window is.
# Claude Code runs it with session JSON on stdin and shows the first line.
# Hooked up in ~/.claude/settings.json:
#   "statusLine": {"type": "command",
#                  "command": "bash \"$HOME/bashconfig/claude/statusline.sh\""}
# REQUIREMENTS: jq (session JSON), git (branch segment). Needs a Nerd Font.

input="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
  printf 'statusline: jq not installed (sudo apt install jq)\n'
  exit 0
fi

# One jq call; fields joined with \x1f, which (unlike a tab) `read` doesn't
# merge when a field is empty. Missing or null fields come out empty:
# rate_limits only exists for Pro/Max plans, after the session's first reply.
IFS=$'\x1f' read -r dir model ctx_used h5_left h5_reset week_left week_reset < <(
  jq -r 'def left: if . == null then "" else 100 - . | if . < 0 then 0 else floor end end;
         [ .workspace.current_dir // .cwd // "",
           .model.display_name // "",
           (.context_window.used_percentage | if . == null then "" else floor end),
           (.rate_limits.five_hour.used_percentage | left),
           .rate_limits.five_hour.resets_at // "",
           (.rate_limits.seven_day.used_percentage | left),
           .rate_limits.seven_day.resets_at // "" ]
         | map(tostring) | join("\u001f")' <<<"$input")
[[ -n "$dir" ]] || dir="$PWD"

# Colors from oh-my-bash's themes/powerline/powerline.theme.sh (256-color).
user_bg=32 cwd_bg=240 model_bg=236
git_clean=25 git_untracked=88 git_unstaged=92 git_staged=30
# Usage segments (not in the prompt): green, yellow at <=50% left, red at <=20%.
usage_ok=28 usage_low=136 usage_critical=124 ctx_bg=238
sep=$'\ue0b0'     # powerline right-pointing separator
thin_sep=$'\ue0b1' # between two segments of the same color
git_char=$'\ue0a0'  # branch icon

out="" prev_bg=""

# segment <text> <bg color>: draws the separator from the previous segment.
# Text keeps the terminal's default color, like the prompt.
segment() {
  if [[ "$prev_bg" == "$2" ]]; then
    out+=$'\e[48;5;'"$2"'m'"$thin_sep"$'\e[0m'
  elif [[ -n "$prev_bg" ]]; then
    out+=$'\e[38;5;'"${prev_bg}"$';48;5;'"$2"'m'"$sep"$'\e[0m'
  fi
  out+=$'\e[48;5;'"$2"'m '"$1"$' \e[0m'
  prev_bg="$2"
}

# user (user@host over ssh, like the prompt)
if [[ -n "${SSH_CLIENT-}" ]]; then
  segment "${USER}@${HOSTNAME}" "$user_bg"
else
  segment "$USER" "$user_bg"
fi

# git: same text and color as oh-my-bash's git_prompt_vars
# (lib/omb-prompt-base.sh): branch, → upstream, ↑ahead ↓behind, {stashes},
# S:/U:/?: file counts. Its checks run staged, unstaged, untracked and the
# last match sets the color, so untracked > unstaged > staged > clean.
if command -v git >/dev/null 2>&1 &&
   status="$(git -C "$dir" --no-optional-locks status --porcelain=v1 -b 2>/dev/null)"; then
  header="${status%%$'\n'*}"
  staged=0 unstaged=0 untracked=0
  while IFS= read -r line; do
    case "$line" in
      '##'*|'') continue ;;
      '??'*) untracked=$((untracked + 1)); continue ;;
    esac
    [[ "${line:1:1}" != ' ' ]] && unstaged=$((unstaged + 1))
    [[ "${line:0:1}" != ' ' ]] && staged=$((staged + 1))
  done <<<"$status"

  if text="$(git -C "$dir" symbolic-ref -q --short HEAD)"; then
    text="${text//[^[:print:]]/-}"
    if [[ "$header" == "## $text..."* ]]; then
      upstream="${header#"## $text..."}"
      upstream="${upstream%% \[*}"
      remote="${upstream%%/*}" remote_branch="${upstream#*/}"
      info=""
      if (( $(git -C "$dir" remote | wc -l) >= 2 )); then
        info="$remote"
        [[ "$remote_branch" != "$text" ]] && info+="/$remote_branch"
      elif [[ "$remote_branch" != "$text" ]]; then
        info="$remote_branch"
      fi
      if [[ -n "$info" ]]; then
        if [[ "$header" == *'[gone]' ]]; then text+=" ⇢ $info"; else text+=" → $info"; fi
      fi
    fi
  elif ref="$(git -C "$dir" describe --tags --exact-match 2>/dev/null)"; then
    text="tag:$ref"
  else
    ref="$(git -C "$dir" describe --contains --all HEAD 2>/dev/null)" ||
      ref="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)"
    text="detached:${ref#remotes/}"
  fi

  [[ "$header" =~ ahead\ ([0-9]+) ]] && text+=" ↑${BASH_REMATCH[1]}"
  [[ "$header" =~ behind\ ([0-9]+) ]] && text+=" ↓${BASH_REMATCH[1]}"
  stashes="$(git -C "$dir" stash list 2>/dev/null | wc -l)"
  (( stashes > 0 )) && text+=" {$stashes}"

  color=$git_clean
  (( staged > 0 )) && { text+=" S:$staged"; color=$git_staged; }
  (( unstaged > 0 )) && { text+=" U:$unstaged"; color=$git_unstaged; }
  (( untracked > 0 )) && { text+=" ?:$untracked"; color=$git_untracked; }
  segment "$git_char $text" "$color"
fi

# cwd with $HOME shown as ~
case "$dir" in
  "$HOME") dir="~" ;;
  "$HOME"/*) dir="~/${dir#"$HOME"/}" ;;
esac
segment "$dir" "$cwd_bg"

[[ -n "$model" ]] && segment "$model" "$model_bg"

# usage_segment <label> <percent left> <resets_at epoch>
# Reset shows the time when it's within a day, otherwise the weekday.
usage_segment() {
  local text="$1: $2% left" color=$usage_ok now when
  (( $2 <= 50 )) && color=$usage_low
  (( $2 <= 20 )) && color=$usage_critical
  if [[ -n "$3" ]]; then
    printf -v now '%(%s)T' -1
    if (( $3 - now < 86400 )); then
      printf -v when '%(%l:%M%p)T' "$3"
      when="${when# }" when="${when,,}"
    else
      printf -v when '%(%a)T' "$3"
    fi
    text+=" (resets $when)"
  fi
  segment "$text" "$color"
}

[[ -n "$h5_left" ]] && usage_segment "5h" "$h5_left" "$h5_reset"
[[ -n "$week_left" ]] && usage_segment "week" "$week_left" "$week_reset"
[[ -n "$ctx_used" ]] && segment "ctx $ctx_used%" "$ctx_bg"

# close the last segment
out+=$'\e[38;5;'"${prev_bg}"'m'"$sep"$'\e[0m'
printf '%s\n' "$out"
