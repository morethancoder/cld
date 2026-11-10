# cld: short for claude, with words for one-off settings. Nothing is saved to settings.json.
# A bare `cld` just runs claude. `cld help` lists the words.

# Full model IDs that get the autocompact size (settings are stored per ID).
# Add the new ID here when a new model version comes out.
CLD_MODEL_IDS=(claude-opus-5-5 claude-sonnet-5-5 claude-haiku-5-5)

cld() {
  local model="" effort="" compact=""
  local -a args
  while (( $# )); do
    case "$1" in
      opus|sonnet|haiku)            model=$1 ;;   # aliases: claude picks the latest version
      low|medium|high|xhigh|max)    effort=$1 ;;
      big)                          compact=500000 ;;
      huge)                         compact=800000 ;;
      <->k)                         compact=$(( ${1%k} * 1000 )) ;;
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
EOF
        return ;;
      --)  shift; args+=("$@"); break ;;
      -*)  args+=("$1") ;;
      *)   print -u2 "cld: unknown word '$1' (try: cld help)"; return 1 ;;
    esac
    shift
  done

  local -a flags
  [[ -n $model  ]] && flags+=(--model "$model")
  [[ -n $effort ]] && flags+=(--effort "$effort")
  if [[ -n $compact ]]; then
    local m json="" sep=""
    for m in $CLD_MODEL_IDS; do
      json+="$sep\"$m\":{\"autoCompactWindow\":$compact}"; sep=","
    done
    flags+=(--settings "{\"modelSettings\":{$json}}")
  fi

  (( ${#flags} + ${#args} )) && print -u2 "→ claude ${flags[*]} ${args[*]}"
  command claude "${flags[@]}" "${args[@]}"
}
