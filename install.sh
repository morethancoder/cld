#!/bin/sh
# Install or update cld: clone it and load it from ~/.zshrc. Safe to run again.
#   curl -fsSL https://raw.githubusercontent.com/morethancoder/cld/main/install.sh | sh
# Options (env vars): CLD_INSTALL_DIR (default ~/cld), CLD_REPO (git URL to clone).
# Never prompts, so it works piped from curl.
set -eu

repo=${CLD_REPO:-https://github.com/morethancoder/cld.git}
dir=${CLD_INSTALL_DIR:-$HOME/cld}
zshrc=${ZDOTDIR:-$HOME}/.zshrc

say()  { printf '%s\n' "$*"; }
warn() { printf 'cld: %s\n' "$*" >&2; }

command -v git >/dev/null 2>&1 || { warn "git is needed: install it, then run this again"; exit 1; }

if [ -d "$dir/.git" ]; then
  say "cld is already in $dir, updating"
  GIT_TERMINAL_PROMPT=0 git -C "$dir" pull --ff-only -q </dev/null \
    || { warn "update failed. Local edits? Check: git -C $dir status"; exit 1; }
elif [ -e "$dir" ]; then
  warn "$dir exists and is not a cld clone. Move it, or pick another place: CLD_INSTALL_DIR=~/somewhere"
  exit 1
else
  GIT_TERMINAL_PROMPT=0 git clone -q "$repo" "$dir" </dev/null
  say "cld cloned into $dir"
fi

line="[[ -f \"$dir/cld.zsh\" ]] && source \"$dir/cld.zsh\""
if [ -f "$zshrc" ] && grep -qF "$dir/cld.zsh" "$zshrc"; then
  say "$zshrc already loads cld"
else
  printf '\n# cld: one-off Claude presets (cld help)\n%s\n' "$line" >> "$zshrc"
  say "added cld to $zshrc"
fi

command -v zsh >/dev/null 2>&1 || warn "zsh is not installed; cld runs in zsh only (see the README for your system)"
command -v claude >/dev/null 2>&1 || warn "claude is not installed yet: https://code.claude.com/docs/en/setup"
command -v jq >/dev/null 2>&1 || say "tip: install jq for the pretty JSON run report"

say ""
say "Done. Open a new terminal (or run: source $zshrc), then try: cld help"
