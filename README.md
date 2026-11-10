# cld

Short for `claude`, with words for one-off settings. Nothing is written to settings.json.

    cld help              list the words
    cld sonnet 200k       Sonnet, 200k autocompact
    cld opus max 600k     combine any of them
    cld big -- -c         after --, args go straight to claude

## Install

One line, on any system below once zsh and git are there:

    curl -fsSL https://raw.githubusercontent.com/morethancoder/cld/main/install.sh | sh

It clones cld into `~/cld` and adds one line to `~/.zshrc`. Safe to run again (it updates).
Open a new terminal afterwards. Other folder: `CLD_INSTALL_DIR=~/tools/cld` before `sh`.

**Requirements**

- [Claude Code](https://code.claude.com/docs/en/setup) (the `claude` command)
- zsh (cld is a zsh function and does not run in bash or fish)
- `git`
- optional: `jq` for the JSON run report, `uuidgen` for exact session IDs.
  Without them cld still works: it prints a one-line command and finds the session ID after exit.

### macOS

zsh, `jq` (macOS 15+) and `uuidgen` are already there. Just run the installer:

    curl -fsSL https://raw.githubusercontent.com/morethancoder/cld/main/install.sh | sh

On older macOS, add `jq` with `brew install jq`.

### Linux

Install zsh and jq (`uuidgen` comes with `util-linux`, present on most systems):

    sudo apt install zsh jq uuid-runtime   # Debian / Ubuntu
    sudo dnf install zsh jq util-linux     # Fedora
    sudo pacman -S zsh jq util-linux       # Arch

If zsh is not your shell yet, make it the default (then log out and back in):

    chsh -s "$(command -v zsh)"

Then run the installer:

    curl -fsSL https://raw.githubusercontent.com/morethancoder/cld/main/install.sh | sh

### Windows

Use WSL (Windows Subsystem for Linux). PowerShell and cmd are not supported.

    wsl --install          # in PowerShell, once; restart when asked

Then open the Ubuntu terminal, install Claude Code inside WSL, and follow the Linux steps above.

### Manual install

If you'd rather not pipe a script into `sh` (read [install.sh](install.sh) first, it's short):

    git clone https://github.com/morethancoder/cld ~/cld
    echo 'source ~/cld/cld.zsh' >> ~/.zshrc

### Check it works

    cld help

### Update

    cld update

It pulls the latest version and shows what changed. Other open terminals pick it up on their
next `cld` call, no reload needed.

### A model cld doesn't know yet

`autocompact` words apply to the models listed in `cld.zsh`, which `cld update` keeps current.
If a new model ships before that, add it in `~/.zshrc` (not in `cld.zsh`, so updates never conflict):

    CLD_EXTRA_MODEL_IDS=(claude-opus-6-0)

### Uninstall

Delete the cld line from `~/.zshrc`, then `rm -rf ~/cld`.

## What it prints

Before claude starts, `cld` prints the run as pretty JSON (via `jq`): model, effort,
autocompact, passthrough args, session ID, the `--settings` value laid out, and the exact
`command` (shell-quoted, copy-pasteable). Bare `cld` prints nothing.

When the session ends (`/exit`, Ctrl+D or Ctrl+C) it prints how to get back, with the same words:

    ↩ resume: cld sonnet high -- --resume 3f2a…

New sessions get their ID from `cld` (`--session-id`); `-c`/`--resume` runs are looked up
in `~/.claude/projects/<folder>/` after exit. `-p` runs and subcommands (`cld -- mcp list`)
print no resume line.

## Development

    make test     run sample calls against a stub `claude`; checks the JSON, resume line,
                  exit code, extra model IDs, `cld update`, reload of open shells
                  and install.sh

When a new model version ships, add its full ID to `CLD_MODEL_IDS` in `cld.zsh` and push:
users get it with `cld update`.
