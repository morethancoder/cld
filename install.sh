#!/bin/sh
# Install or update cld: clone it and link the `cld` command into a folder on your PATH.
# Safe to run again.
#   curl -fsSL https://raw.githubusercontent.com/morethancoder/cld/main/install.sh | sh
# Options (env vars): CLD_INSTALL_DIR (default ~/cld, or the clone this script is run from),
#                     CLD_BIN_DIR (default ~/.local/bin), CLD_REPO (git URL to clone).
# Never prompts, so it works piped from curl.
set -eu

repo=${CLD_REPO:-https://github.com/morethancoder/cld.git}
bin=${CLD_BIN_DIR:-$HOME/.local/bin}
zshrc=${ZDOTDIR:-$HOME}/.zshrc

say()  { printf '%s\n' "$*"; }
warn() { printf 'cld: %s\n' "$*" >&2; }

# Run from inside a clone (sh ~/somewhere/cld/install.sh): install that clone.
here=$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)
if [ -n "${CLD_INSTALL_DIR:-}" ]; then dir=$CLD_INSTALL_DIR
elif [ -n "$here" ] && [ -f "$here/cld" ] && [ -d "$here/.git" ]; then dir=$here
else dir=$HOME/cld
fi

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

# The command: a link, so `cld update` (a git pull in the clone) is all an update needs.
mkdir -p "$bin"
if [ -e "$bin/cld" ] && [ ! -L "$bin/cld" ]; then
  warn "$bin/cld exists and is not a link made by this installer. Move it, or pick another place: CLD_BIN_DIR=~/bin"
  exit 1
fi
ln -sf "$dir/cld" "$bin/cld"
say "linked $bin/cld"

# Older versions were loaded from ~/.zshrc. Remove that line and its comment, nothing else.
if [ -f "$zshrc" ] && grep -q 'source .*cld\.zsh' "$zshrc"; then
  tmp=$(mktemp)
  awk '
    /^# cld: one-off Claude presets \(cld help\)$/ { held = $0; have = 1; next }
    /source .*\/cld\.zsh/                           { have = 0; next }
    { if (have) { print held; have = 0 } print }
    END { if (have) print held }
  ' "$zshrc" > "$tmp"
  cat "$tmp" > "$zshrc"   # write through, so a linked .zshrc stays a link
  rm -f "$tmp"
  say "removed the old cld line from $zshrc (cld is a command now)"
fi

# Make sure the folder is on PATH: add it to the startup file of your shell if it is not.
case ":$PATH:" in
  *":$bin:"*) ;;
  *)
    case "${SHELL##*/}" in
      zsh)  rc=$zshrc ;;
      bash) rc=$HOME/.bashrc ;;
      *)    rc="" ;;
    esac
    if [ -z "$rc" ]; then
      warn "$bin is not on your PATH. Add it in your shell's startup file: export PATH=\"$bin:\$PATH\""
    elif [ -f "$rc" ] && grep -qF "export PATH=\"$bin:\$PATH\"" "$rc"; then
      say "$rc already adds $bin to PATH (open a new terminal)"
    else
      printf '\n# cld: the folder its command is linked into\nexport PATH="%s:$PATH"\n' "$bin" >> "$rc"
      say "added $bin to PATH in $rc (open a new terminal)"
    fi ;;
esac

command -v zsh >/dev/null 2>&1 || warn "zsh is not installed; cld is written in zsh (see the README for your system)"
command -v claude >/dev/null 2>&1 || warn "claude is not installed yet: https://code.claude.com/docs/en/setup"
command -v jq >/dev/null 2>&1 || say "tip: install jq for the pretty JSON run report"

say ""
say "Done. Try: cld help"
