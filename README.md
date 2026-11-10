# cld

Short for `claude`, with words for one-off settings. Nothing is written to settings.json.

    cld help              list the words
    cld sonnet 200k       Sonnet, 200k autocompact
    cld opus max 600k     combine any of them
    cld big -- -c         after --, args go straight to claude

Loaded from `~/.zshrc`: `source ~/Projects/CLI/cld/cld.zsh`.
`make test` prints the commands a few sample calls would run, without starting claude.

When a new model version ships, add its full ID to `CLD_MODEL_IDS` in `cld.zsh`.
