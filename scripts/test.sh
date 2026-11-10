#!/usr/bin/env zsh
# Dry-run: a stub `claude` goes first on PATH, so nothing real starts.
# The stub saves a session file like claude does, in a temp CLAUDE_CONFIG_DIR,
# and exits 3 so we can check cld passes the exit code through.
emulate -L zsh
tmp=$(mktemp -d); trap 'rm -rf $tmp' EXIT
export CLAUDE_CONFIG_DIR=$tmp/config
proj=$CLAUDE_CONFIG_DIR/projects/${${PWD:A}//[^a-zA-Z0-9]/-}
mkdir -p $tmp/bin $proj
cat > $tmp/bin/claude <<EOF
#!/bin/zsh
while (( \$# )); do
  case \$1 in
    --session-id) touch $proj/\$2.jsonl ;;
    -c)           touch $proj/11111111-2222-3333-4444-555555555555.jsonl ;;
  esac
  shift
done
exit 3
EOF
chmod +x $tmp/bin/claude
path=($tmp/bin $path)
source "${0:A:h}/../cld.zsh"

fail=0
check() {  # check <name> <condition result>
  if (( $2 )); then print "  ok    $1"; else print "  FAIL  $1"; fail=1; fi
}

for words in "sonnet 200k" "opus max 600k" "big" "haiku -- -c" "-- mcp list" "-- -p hi"; do
  print "\$ cld $words"
  out=$(cld ${=words} 2>&1 < /dev/null); rc=$?
  print -r -- "$out" | sed 's/^/    /'
  check "exit code passed through" $(( rc == 3 ))
  json=${out%%$'\n'↩*}
  if [[ $words != "-- mcp list" && $words != "-- -p hi" ]]; then
    check "report is valid JSON with a command" $(( $(print -r -- "$json" | jq -e '.command | startswith("claude ")' >/dev/null && echo 1 || echo 0) ))
    check "resume line printed" $(( ${#${(M)out:#*↩ resume: cld *-- --resume *}} ))
  else
    check "no session ID or resume line" $(( ! ${#${(M)out:#*(session-id|↩)*}} ))
  fi
done
print -r -- "$(cld big 2>&1 </dev/null)" | grep -q '"autoCompactWindow": 500000'
check "big sets autoCompactWindow 500000" $(( ! $? ))
out=$(cld haiku -- -c 2>&1 </dev/null)
[[ $out == *"↩ resume: cld haiku -- --resume 11111111-2222-3333-4444-555555555555"* ]]
check "-c run finds the session ID after exit" $(( ! $? ))

# Extra model IDs from ~/.zshrc are added to the defaults, without duplicates.
CLD_EXTRA_MODEL_IDS=(claude-opus-9-9 claude-opus-5-5)
out=$(cld big 2>&1 </dev/null)
check "extra model ID gets autocompact" $(( ${#${(M)out:#*claude-opus-9-9*}} ))
check "no duplicate model IDs" $(( $(print -r -- "$out" | grep -c '"claude-opus-5-5"') == 1 ))
unset CLD_EXTRA_MODEL_IDS

# `cld update`: a clone of a fake origin pulls a new commit and loads it.
g() { git -c user.name=t -c user.email=t@t "$@" >/dev/null 2>&1 }
g init $tmp/origin; cp ${0:A:h}/../cld.zsh $tmp/origin/
g -C $tmp/origin add . && g -C $tmp/origin commit -m one
g clone $tmp/origin $tmp/inst
source $tmp/inst/cld.zsh
print '# two' >> $tmp/origin/cld.zsh && g -C $tmp/origin commit -am "second change"
out=$(cld update 2>&1 </dev/null); print -r -- "$out" | sed "s/^/    /"
check "cld update pulls and lists changes" $(( ${#${(M)out:#*cld updated*second change*}} ))
out=$(cld update 2>&1 </dev/null); print -r -- "$out" | sed "s/^/    /"
check "second cld update says up to date" $(( ${#${(M)out:#*up to date*}} ))

# An open shell reloads the file on its next call once it has changed.
print 'CLD_MARKER=reloaded' >> $tmp/inst/cld.zsh; touch -t 203001010000 $tmp/inst/cld.zsh
cld big >/dev/null 2>&1 </dev/null
[[ $CLD_MARKER == reloaded ]]; check "changed file reloads on next cld call" $(( ! $? ))
exit $fail
