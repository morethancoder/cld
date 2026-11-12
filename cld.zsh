# cld used to be a zsh function loaded from ~/.zshrc. It is now a command (the `cld` file next
# to this one). This file only keeps an old install working until the installer is run again:
#   curl -fsSL https://raw.githubusercontent.com/morethancoder/cld/main/install.sh | sh
# That links cld into ~/.local/bin and removes the line in ~/.zshrc that loads this file.
CLD_DIR=${${(%):-%x}:A:h}

cld() {
  if [[ -z $CLD_MOVED_TOLD ]]; then
    CLD_MOVED_TOLD=1
    print -u2 "cld: cld is now a command and no longer needs ~/.zshrc. To finish the move, run:"
    print -u2 "  sh $CLD_DIR/install.sh"
  fi
  $CLD_DIR/cld "$@"
}
