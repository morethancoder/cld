# cld

Short for `claude`, with words for one-off settings. Nothing is written to settings.json.

    cld help              list the words
    cld sonnet 200k       Sonnet, 200k autocompact
    cld opus max 600k     combine any of them
    cld big -- -c         after --, args go straight to claude

Before claude starts, `cld` prints the run as pretty JSON (via `jq`): model, effort,
autocompact, passthrough args, session ID, the `--settings` value laid out, and the exact
`command` (shell-quoted, copy-pasteable). Bare `cld` prints nothing. Without `jq` it prints one line.

When the session ends it prints how to get back, with the same words:

    ↩ resume: cld sonnet high -- --resume 3f2a…

New sessions get their ID from `cld` (`--session-id`); `-c`/`--resume` runs are looked up
in `~/.claude/projects/<folder>/` after exit. `-p` runs and subcommands (`cld -- mcp list`)
print no resume line.

Install: clone it and source it from `~/.zshrc` (zsh only; `jq` optional, for the JSON report):

    git clone https://github.com/morethancoder/cld ~/cld
    echo 'source ~/cld/cld.zsh' >> ~/.zshrc
`make test` runs sample calls against a stub `claude` and checks the JSON, resume line and exit code.

When a new model version ships, add its full ID to `CLD_MODEL_IDS` in `cld.zsh`.
