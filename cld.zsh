# cld: short for claude, with words for one-off settings. Nothing is saved to settings.json.
# A bare `cld` just runs claude. `cld help` lists the words.

# Full model IDs that get the autocompact size (settings are stored per ID).
# Add the new ID here when a new model version comes out.
CLD_MODEL_IDS=(claude-opus-5-5 claude-sonnet-5-5 claude-haiku-5-5)

# claude subcommands: these start no session, so cld adds no session ID and no resume line.
CLD_SUBCOMMANDS=(agents attach auth auto-mode doctor gateway import install logs mcp plugin plugins
                 purge respawn rm setup-token stop kill ultrareview update upgrade)

zmodload zsh/datetime 2>/dev/null
zmodload -F zsh/stat b:zstat 2>/dev/null   # only zstat, so the system `stat` stays

cld() {
  local model="" effort="" compact=""
  local -a words args
  while (( $# )); do
    case "$1" in
      opus|sonnet|haiku)            model=$1; words+=$1 ;;   # aliases: claude picks the latest version
      low|medium|high|xhigh|max)    effort=$1; words+=$1 ;;
      big)                          compact=500000; words+=$1 ;;
      huge)                         compact=800000; words+=$1 ;;
      <->k)                         compact=$(( ${1%k} * 1000 )); words+=$1 ;;
      help)
        cat <<'EOF'
cld [words] [-- claude args]     one-off settings, nothing saved

  model     opus | sonnet | haiku          (always the latest version)
  effort    low | medium | high | xhigh | max
  compact   big (500k) | huge (800k) | <N>k  e.g. 350k

  cld                   plain claude
  cld big               500k autocompact
  cld sonnet high       Sonnet, high effort
  cld opus max 600k     combine any of them
  cld big -- -c         after --, args go straight to claude (here: continue last session)
  cld -c                flags starting with - also pass through

Before it starts, cld prints the run as JSON (with the exact command).
When the session ends, it prints the command to resume it.
EOF
        return ;;
      --)  shift; args+=("$@"); break ;;
      -*)  args+=("$1") ;;
      *)   print -u2 "cld: unknown word '$1' (try: cld help)"; return 1 ;;
    esac
    shift
  done

  local -a flags
  local settings=""
  [[ -n $model  ]] && flags+=(--model "$model")
  [[ -n $effort ]] && flags+=(--effort "$effort")
  if [[ -n $compact ]]; then
    local m json="" sep=""
    for m in $CLD_MODEL_IDS; do
      json+="$sep\"$m\":{\"autoCompactWindow\":$compact}"; sep=","
    done
    settings="{\"modelSettings\":{$json}}"
    flags+=(--settings "$settings")
  fi

  # Session ID. A new interactive session gets one from us, so it is exact.
  # Continue/resume runs pick their own, so we look it up after exit instead.
  # Print mode and subcommands start no session to come back to.
  local sid="" track=1 lookup=0 a
  for a in $args; do
    case $a in
      -p|--print)                                   track=0 ;;
      -c|--continue|-r|--resume|--resume=*|--session-id|--session-id=*|--fork-session) lookup=1 ;;
    esac
  done
  (( ${#args} )) && [[ -n ${CLD_SUBCOMMANDS[(r)${args[1]}]} ]] && track=0
  if (( track && ! lookup )); then
    sid=${(L)$(uuidgen 2>/dev/null)}             # no uuidgen: look it up after exit
    [[ -n $sid ]] && flags+=(--session-id "$sid")
  fi

  local -a cmd=(claude "${flags[@]}" "${args[@]}")
  if (( ${#words} + ${#args} )); then
    local line="${(j: :)${(@q-)cmd}}"
    if (( $+commands[jq] )); then
      local color=-M; [[ -t 2 ]] && color=-C
      jq -n $color \
        --arg model "$model" --arg effort "$effort" --arg compact "$compact" \
        --arg pass "${(pj:\x1f:)args}" --arg sid "$sid" --arg settings "$settings" \
        --arg command "$line" '{
          model: $model,
          effort: $effort,
          autoCompactWindow: (($compact | tonumber?) // ""),
          passthrough: (if $pass == "" then [] else ($pass | split("\u001f")) end),
          sessionId: $sid,
          settings: (($settings | fromjson?) // ""),
          command: $command
        } | with_entries(select(.value != "" and .value != []))' >&2
    else
      print -u2 "→ $line"
    fi
  fi

  local start=$EPOCHSECONDS
  command claude "${flags[@]}" "${args[@]}"
  local rc=$?

  if (( track )); then
    local projects=${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects
    local -a found
    if [[ -n $sid ]]; then
      found=($projects/*/$sid.jsonl(N))          # only if the session was saved
    else
      found=($projects/${${PWD:A}//[^a-zA-Z0-9]/-}/*.jsonl(N.om[1]))
      (( ${#found} )) && (( $(zstat +mtime -- $found[1]) >= start )) || found=()
    fi
    (( ${#found} )) && print -u2 "↩ resume: cld ${words:+${words} }-- --resume ${found[1]:t:r}"
  fi
  return $rc
}
