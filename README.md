# cld

Short for `claude`, with words for one-off settings. Nothing is written to settings.json.

    cld help                 list the words
    cld sonnet 200k          Sonnet, 200k autocompact
    cld fable 5.2 max 600k   an exact version, max effort, 600k: combine any of them
    cld temp                 a clean, throwaway Claude
    cld as work              a separate Claude that is kept
    cld big -- -c            after --, args go straight to claude
    cld sonnet -p "why?"     one answer printed in the terminal, no session

## Models and effort

cld has no list of models. It reads the model families and versions from the `claude` you have
installed, and the effort levels from `claude --help`, so a new model works the day you update
claude.

    cld fable             the latest Fable
    cld fable 5.2         exactly claude-fable-5-2 (also: cld fable-5.2)
    cld models            every family and version your claude knows

A version your claude doesn't list still runs, with a one-line warning. A word that is no
model, effort level or cld word is an error, so typos don't start a session.

Autocompact words (`big`, `huge`, `350k`) apply to whichever model runs. Claude Code accepts
100k to 1M.

## One-off answers

    cld -p "what does git rebase --onto do?"
    cld haiku low -p "summarise this" < notes.txt > summary.txt

`-p` (or `--print`) and everything after it go straight to claude, so put cld's words before
it. Only the answer is printed: no JSON report and no resume line.

## Temporary and separate Claudes

    cld temp              a Claude with an empty config folder: none of your skills, plugins,
                          memory, CLAUDE.md or settings. The folder is deleted when it ends.
    cld as work           a Claude with its own kept folder, ~/.cld/profiles/work. What you set
                          up inside it (settings, memory, sessions) is there next time.
    cld profiles          list the kept ones
    cld drop work         delete one (asks first; YES=1 skips the question)

Both combine with every other word: `cld as work sonnet high`, `cld temp big -- -p "hi"`.

A Claude with its own config folder can't use your normal login, so `temp` and `as` share one
long-lived token. The first time, cld runs the login for you (`claude setup-token`) and saves
the token: in the Keychain on macOS, in `~/.cld/token` (readable only by you) on Linux.
`cld login` renews it. The token is never printed.

## Install

One line, on any system below once zsh and git are there:

    curl -fsSL https://raw.githubusercontent.com/morethancoder/cld/main/install.sh | sh

It clones cld into `~/cld` and links the `cld` command into `~/.local/bin`. Nothing is loaded
from `~/.zshrc`; if `~/.local/bin` is not on your PATH yet, the installer adds it to your
shell's startup file. Safe to run again (it updates). Other places: `CLD_INSTALL_DIR=~/tools/cld`
and `CLD_BIN_DIR=~/bin` before `sh`.

Coming from an older version that was loaded from `~/.zshrc`? Run the installer once more: it
links the command and removes that line.

**Requirements**

- [Claude Code](https://code.claude.com/docs/en/setup) (the `claude` command)
- zsh installed (cld is written in zsh; you can call it from any shell)
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

zsh only has to be installed; it does not have to be your shell. Then run the installer:

    curl -fsSL https://raw.githubusercontent.com/morethancoder/cld/main/install.sh | sh

### Windows

Use WSL (Windows Subsystem for Linux). PowerShell and cmd are not supported.

    wsl --install          # in PowerShell, once; restart when asked

Then open the Ubuntu terminal, install Claude Code inside WSL, and follow the Linux steps above.

### Manual install

If you'd rather not pipe a script into `sh` (read [install.sh](install.sh) first, it's short):

    git clone https://github.com/morethancoder/cld ~/cld
    mkdir -p ~/.local/bin && ln -s ~/cld/cld ~/.local/bin/cld

### Check it works

    cld help

### Update

    cld update

It pulls the latest version and shows what changed. Every open terminal has it at once.

`cld: unknown word 'update'` in a terminal that was open before the move to a command? That
shell still holds the old `cld` function in memory, and `source ~/.zshrc` doesn't remove it.
Drop it, then update:

    unfunction cld; cld update

Or start a fresh shell with `exec zsh`. New terminals are not affected.

### Uninstall

    rm ~/.local/bin/cld && rm -rf ~/cld

`rm -rf ~/.cld` also removes the kept Claudes, the cache and (on Linux) the saved token.

## What it prints

Before claude starts, `cld` prints the run as pretty JSON (via `jq`): model, effort,
autocompact, `temp` or the profile name with its config folder, passthrough args, session ID,
and the exact `command` (shell-quoted, copy-pasteable; for `temp` and `as` it leaves out the
login token). Bare `cld` and `-p` runs print nothing of their own.

Claude Code prints its own resume line when a session ends. It repeats `--model` and
`--effort` but not the autocompact window (an env var, not saved with the session), and it
can't find sessions made with `cld as <name>`. So when the run used a window word (`200k`,
`big`…) or `as <name>`, `cld` adds its own line after Claude's, with the same words:

    ↩ resume: cld sonnet 200k -- --resume 3f2a…

New sessions get their ID from `cld` (`--session-id`); `-c`/`--resume` runs are looked up
in `~/.claude/projects/<folder>/` after exit (for `cld as work`, in that Claude's own folder).
Runs without a window word or `as`, `-p` runs, subcommands (`cld -- mcp list`) and `cld temp`
get no `cld` resume line.

## Development

    make test     run sample calls against a stub `claude`; checks the JSON, resume line,
                  exit code, models and effort read from claude, `temp`, `as`, login,
                  `cld update` and install.sh

`cld` is the command. `cld.zsh` only keeps installs from before the move working until the
installer is run again.
