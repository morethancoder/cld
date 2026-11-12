#!/usr/bin/env zsh
# Dry-run: a stub `claude` goes first on PATH, so nothing real starts.
# The stub saves a session file like claude does, logs what it was given (args and the env
# vars cld sets), and exits 3 so we can check cld passes the exit code through.
# Everything cld writes goes to a temp CLD_HOME; the token lives in a file, never the Keychain.
emulate -L zsh
root=${0:A:h}/..
tmp=$(mktemp -d); tmp=${tmp:A}; trap 'rm -rf $tmp' EXIT
export CLAUDE_CONFIG_DIR=$tmp/config CLD_HOME=$tmp/cldhome CLD_TOKEN_STORE=file
export CLD_STUB_LOG=$tmp/stub.log TMPDIR=$tmp/t
unset CLAUDE_CODE_OAUTH_TOKEN CLAUDE_CODE_AUTO_COMPACT_WINDOW YES
projname=${${PWD:A}//[^a-zA-Z0-9]/-}
mkdir -p $tmp/bin $tmp/bare $tmp/t $CLAUDE_CONFIG_DIR/projects/$projname

# The stub names its models the way the real program does, so cld can read them from it.
# "zeta" and effort "turbo" exist nowhere in cld: they only work if cld really reads them here.
cat > $tmp/bin/claude <<'EOF'
#!/bin/zsh
# models: claude-fable-5 claude-fable-5-1 claude-fable-5-2 claude-opus-5-5 claude-sonnet-5-5
# models: claude-fable-5 claude-fable-5-1 claude-fable-5-2 claude-opus-5-5 claude-sonnet-5-5
# models: claude-haiku-5-5 claude-zeta-1 claude-zeta-1-5 claude-desktop-3 claude-once-7-7
# models: claude-haiku-5-5 claude-zeta-1 claude-zeta-1-5 claude-desktop-3
case $1 in
  --version)   print "9.9.9 (Claude Code)"; exit 0 ;;
  --help)      [[ -n $CLD_STUB_NOHELP ]] && exit 0
               print "  --effort <level>     Effort level for the current session"
               print "                       (low, medium, high, xhigh, max, turbo)"; exit 0 ;;
  setup-token) print "stub token printed"; exit 0 ;;
esac
cfg=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
proj=$cfg/projects/${${PWD:A}//[^a-zA-Z0-9]/-}
mkdir -p $proj
{
  print "args=$*"
  print "config=$cfg"
  print "token=$CLAUDE_CODE_OAUTH_TOKEN"
  print "compact=$CLAUDE_CODE_AUTO_COMPACT_WINDOW"
  print "onboarded=$([[ -s $cfg/.claude.json ]] && print yes || print no)"
  print "remembered=$([[ -e $cfg/memory.txt ]] && print yes || print no)"
} > $CLD_STUB_LOG
print remember > $cfg/memory.txt
while (( $# )); do
  case $1 in
    --session-id) touch $proj/$2.jsonl ;;
    -c)           touch $proj/11111111-2222-3333-4444-555555555555.jsonl ;;
  esac
  shift
done
[[ -n $CLD_STUB_SIGINT ]] && kill -INT $$   # quit like Ctrl+C does
exit 3
EOF
chmod +x $tmp/bin/claude
path=($tmp/bin $path)
cld() { $root/cld "$@" }
log() { grep "^$1=" $CLD_STUB_LOG 2>/dev/null | cut -d= -f2- }

fail=0
check() {  # check <name> <condition result>
  if (( $2 )); then print "  ok    $1"; else print "  FAIL  $1"; fail=1; fi
}
has() { [[ $1 == *$2* ]] && print 1 || print 0 }   # has <text> <part>

print "── words, report, resume line"
for words in "sonnet 200k" "opus max 600k" "big" "haiku 300k -- -c" "sonnet high" "-- mcp list" "-- -p hi"; do
  print "\$ cld $words"
  out=$(cld ${=words} 2>&1 < /dev/null); rc=$?
  print -r -- "$out" | sed 's/^/    /'
  check "exit code passed through" $(( rc == 3 ))
  json=${out%%$'\n'↩*}
  if [[ $words == "sonnet high" ]]; then
    check "no window word or as: claude's own resume line is enough, none from cld" $(( ! $(has "$out" "↩") ))
  elif [[ $words != "-- mcp list" && $words != "-- -p hi" ]]; then
    check "report is valid JSON with a command" $(( $(print -r -- "$json" | jq -e '.command | test("claude ")' >/dev/null && echo 1 || echo 0) ))
    check "resume line printed" $(( ${#${(M)out:#*↩ resume: cld *-- --resume *}} ))
  else
    check "no session ID or resume line" $(( ! ${#${(M)out:#*(session-id|↩)*}} ))
  fi
done
out=$(cld haiku 300k -- -c 2>&1 </dev/null)
check "-c run finds the session ID after exit" $(has "$out" "↩ resume: cld haiku 300k -- --resume 11111111-2222-3333-4444-555555555555")
rm -f $CLD_STUB_LOG; out=$(cld 2>&1 </dev/null); rc=$?
check "bare cld: plain claude, no report, same config (AC14)" $(( rc == 3 && ! $(has "$out" "{") && $(has "$(log config)" "$CLAUDE_CONFIG_DIR") && ${#$(log token)} == 0 ))

print "── autocompact without a model list (AC23)"
out=$(cld big 2>&1 </dev/null)
check "big: report says 500000" $(has "$out" '"autoCompactWindow": 500000')
check "big: claude gets the window, no --settings" $(( $(log compact) == 500000 && ! $(has "$(log args)" settings) ))
cld fable 350k >/dev/null 2>&1 </dev/null
check "350k works for a model cld never listed" $(( $(log compact) == 350000 ))
check "no model ID list left in cld" $(( ! $(grep -c 'CLD_MODEL_IDS\|claude-opus-5-5' $root/cld) ))

print "── models and effort from the installed claude (AC18-25)"
out=$(cld models 2>&1); print -r -- "$out" | sed 's/^/    /'
check "cld models lists families and versions" $(( $(has "$out" "fable    5 5.1 5.2") && $(has "$out" "zeta     1 1.5") ))
check "stray matches are not models" $(( ! $(has "$out" desktop) && ! $(has "$out" once) ))
check "cache written" $(( $(grep -c '^version=9.9.9$' $CLD_HOME/cache/claude) == 1 ))
cld fable >/dev/null 2>&1 </dev/null;      check "fable = latest (alias)"        $(has "$(log args)" "--model fable --session-id")
cld zeta >/dev/null 2>&1 </dev/null;       check "a family cld never heard of"   $(has "$(log args)" "--model zeta ")
cld fable 5.2 >/dev/null 2>&1 </dev/null;  check "fable 5.2 = claude-fable-5-2"  $(has "$(log args)" "--model claude-fable-5-2 ")
cld fable-5.1 >/dev/null 2>&1 </dev/null;  check "fable-5.1 = claude-fable-5-1"  $(has "$(log args)" "--model claude-fable-5-1 ")
out=$(cld fable 5.2 high big 2>&1 </dev/null)
check "resume line keeps the version" $(has "$out" "↩ resume: cld fable 5.2 high big -- --resume")
out=$(cld fable 9.9 2>&1 </dev/null); rc=$?
check "unlisted version: warns and still runs" $(( rc == 3 && $(has "$out" "doesn't list claude-fable-9-9") && $(has "$(log args)" "--model claude-fable-9-9 ") ))
cld sonnet turbo >/dev/null 2>&1 </dev/null
check "effort level read from claude --help" $(has "$(log args)" "--effort turbo")
rm -f $CLD_STUB_LOG; out=$(cld fabel 2>&1 </dev/null); rc=$?
check "typo: unknown word, exit 1, claude not started" $(( rc == 1 && $(has "$out" "unknown word 'fabel'") && ! ${#$(log args)} ))
out=$(cld help 2>&1)
check "help lists what was found" $(( $(has "$out" "zeta") && $(has "$out" "turbo") && $(has "$out" "as <name>") ))
# claude --help unreadable: today's five levels.
out=$(CLD_HOME=$tmp/nohelp CLD_STUB_NOHELP=1 $root/cld sonnet xhigh 2>&1 </dev/null)
check "no --help: falls back to the five levels" $(has "$(log args)" "--effort xhigh")
out=$(CLD_HOME=$tmp/nohelp CLD_STUB_NOHELP=1 $root/cld sonnet turbo 2>&1 </dev/null); rc=$?
check "no --help: turbo is unknown" $(( rc == 1 ))
# A claude with no readable model list: the word goes to claude as the model.
print '#!/bin/zsh\nprint "args=$*" > $CLD_STUB_LOG; exit 3' > $tmp/bare/claude; chmod +x $tmp/bare/claude
out=$(PATH=$tmp/bare:$PATH CLD_HOME=$tmp/barehome $root/cld newthing 2>&1 </dev/null)
check "no model list: word passed to claude as the model" $(has "$(log args)" "--model newthing")

print "── login (AC6-7)"
rm -f $CLD_STUB_LOG; out=$(cld temp 2>&1 </dev/null); rc=$?
check "no token, no terminal: says cld login, exit 1, claude not started" $(( rc == 1 && $(has "$out" "cld login") && ! ${#$(log args)} ))
# With a terminal: cld runs the one-time login itself, saves the token, then starts claude.
zmodload zsh/zpty; zmodload -F zsh/stat b:zstat
# exec: the pty starts as a copy of this script, and must not run its cleanup trap on exit.
zpty -b login "exec zsh -fc '$root/cld temp; print RC\"\"=\$?'"
out=""; deadline=$(( SECONDS + 10 )); sent=0
while [[ $out != *RC=* ]] && (( SECONDS < deadline )); do
  zpty -r -t login line 2>/dev/null && out+=$line || sleep 0.05
  if (( ! sent )) && [[ $out == *Paste* ]]; then zpty -w login "tok-secret-123"; sent=1; fi
done
zpty -d login
print -r -- "$out" | tr -d '\r' | grep -v '^ *$' | sed 's/^/    /'
check "terminal: login runs by itself, then claude starts" $(( $(has "$out" "RC=3") && $(has "$(log token)" "tok-secret-123") ))
check "token saved in a file only the owner can read" $(( $(has "$(cat $CLD_HOME/token 2>/dev/null)" tok-secret-123) && $(( $(zstat +mode -- $CLD_HOME/token 2>/dev/null || print 0) % 512 )) == 8#600 ))
check "token never shown on screen" $(( ! $(has "$out" tok-secret-123) ))

print "── cld temp (AC1-2, 8-11)"
out=$(cld temp sonnet high 2>&1 </dev/null); rc=$?; print -r -- "$out" | sed 's/^/    /'
tdir=$(log config)
check "temp: own empty config folder in the temp dir" $(( rc == 3 && $(has "$tdir" "$TMPDIR/cld-temp.") ))
check "temp: first-run screens skipped, nothing remembered" $(( $(has "$(log onboarded)" yes) && $(has "$(log remembered)" no) ))
check "temp: token passed, words still apply" $(( $(has "$(log token)" tok-secret-123) && $(has "$(log args)" "--model sonnet --effort high") ))
check "temp: folder deleted after exit" $(( ! ${#$(print -l $TMPDIR/cld-temp.*(N))} ))
check "temp: report shows mode and folder, never the token" $(( $(has "$out" '"profile": "temp"') && $(has "$out" '"configDir"') && ! $(has "$out" tok-secret) ))
check "temp: no resume line" $(( ! $(has "$out" "↩") ))
CLD_STUB_SIGINT=1 cld temp big -- -p hi >/dev/null 2>&1 </dev/null
check "temp: folder deleted after a Ctrl+C quit, passthrough works" $(( ! ${#$(print -l $TMPDIR/cld-temp.*(N))} && $(has "$(log args)" "-p hi") && $(log compact) == 500000 ))

print "── cld as <name> (AC3-5, 9-13)"
out=$(cld as work sonnet 2>&1 </dev/null); rc=$?; print -r -- "$out" | sed 's/^/    /'
check "as work: kept folder under ~/.cld/profiles" $(( rc == 3 && $(has "$(log config)" "$CLD_HOME/profiles/work") && $(has "$(log onboarded)" yes) ))
check "as work: starts empty" $(has "$(log remembered)" no)
check "as work: resume line has the name and finds the session there" $(has "$out" "↩ resume: cld as work sonnet -- --resume")
check "as work: report shows the name and folder, never the token" $(( $(has "$out" '"profile": "work"') && ! $(has "$out" tok-secret) ))
cld as work >/dev/null 2>&1 </dev/null
check "as work again: what it saved is still there" $(has "$(log remembered)" yes)
cld as work -- mcp list >/dev/null 2>&1 </dev/null
check "as work with a subcommand uses that folder" $(( $(has "$(log config)" profiles/work) && $(has "$(log args)" "mcp list") ))
for bad in "as" "as a/b" "as ../x" "temp as work" "as work temp"; do
  rm -f $CLD_STUB_LOG; cld ${=bad} >/dev/null 2>&1 </dev/null
  check "'cld $bad' is an error, claude not started" $(( $? == 1 && ! ${#$(log args)} ))
done
cld as side >/dev/null 2>&1 </dev/null
check "cld profiles lists them" $(( $(has "$(cld profiles | tr '\n' ' ')" "side work") ))
# Without a terminal the y/N question answers no (an open pipe, not /dev/null, to prove no wait).
t0=$SECONDS; $root/cld drop side >/dev/null 2>&1 < <(sleep 5); rc=$?
check "drop without a terminal: answers no, does not wait" $(( rc == 1 && SECONDS - t0 < 3 )) ; [[ -d $CLD_HOME/profiles/side ]]
check "…and the folder is still there" $(( ! $? ))
YES=1 cld drop side >/dev/null 2>&1 </dev/null
check "YES=1 drop deletes it, others stay" $(( $? == 0 )) ; [[ ! -d $CLD_HOME/profiles/side && -d $CLD_HOME/profiles/work ]]
check "…only that one" $(( ! $? ))
YES=1 cld drop nope >/dev/null 2>&1; check "drop of an unknown name is an error" $(( $? == 1 ))

print "── a real command (AC28, 34)"
# Quit with Ctrl+C in a real terminal (job control on): the resume line must still print.
zpty -b sigint "PATH=$tmp/bin:\$PATH CLD_STUB_SIGINT=1 exec zsh -f -i"
zpty -w sigint "setopt monitor; $root/cld sonnet 200k"
zpty -w sigint "print DO''NE; exit"
out=""; deadline=$(( SECONDS + 10 ))
while [[ $out != *DONE* ]] && (( SECONDS < deadline )); do
  zpty -r -t sigint line 2>/dev/null && out+=$line || sleep 0.05
done
zpty -d sigint
check "resume line printed after Ctrl+C quit" $(( ${#${(M)out:#*↩ resume: cld sonnet 200k -- --resume *}} ))
out=$(bash -c "'$root/cld' fable 5.2; echo rc=\$?" 2>&1 </dev/null)
check "runs from bash, exit code passed through" $(( $(has "$out" "rc=3") && $(has "$out" claude-fable-5-2) ))
print "#!/bin/sh\n'$root/cld' sonnet" > $tmp/s.sh; sh $tmp/s.sh >/dev/null 2>&1 </dev/null
check "runs from a script" $(( $? == 3 ))

print "── update and install (AC29-33)"
# `cld update`: a clone of a fake origin pulls a new commit.
g() { git -c user.name=t -c user.email=t@t "$@" >/dev/null 2>&1 }
g init $tmp/origin; cp $root/cld $root/cld.zsh $root/install.sh $tmp/origin/
g -C $tmp/origin add . && g -C $tmp/origin commit -m one
g clone $tmp/origin $tmp/inst
print '# two' >> $tmp/origin/cld && g -C $tmp/origin commit -am "second change"
out=$($tmp/inst/cld update 2>&1 </dev/null); print -r -- "$out" | sed "s/^/    /"
check "cld update pulls and lists changes" $(( ${#${(M)out:#*cld updated*second change*}} ))
out=$($tmp/inst/cld update 2>&1 </dev/null)
check "second cld update says up to date" $(has "$out" "up to date")
# An old install still sources cld.zsh: it keeps working and says how to finish the move.
out=$(zsh -fc "source $tmp/inst/cld.zsh; cld help; cld help" 2>&1 </dev/null)
check "old install: cld.zsh still runs cld, says to reinstall once" $(( $(has "$out" "one-off settings") && $(print -r -- "$out" | grep -c 'install.sh') == 1 ))

# install.sh into a fake HOME that has the old .zshrc line, with the bin folder not on PATH.
home=$tmp/home; mkdir -p $home
print -l 'export KEEP_ME=1' '' '# cld: one-off Claude presets (cld help)' \
  '[[ -f ~/cld/cld.zsh ]] && source ~/cld/cld.zsh' 'alias keep=true' > $home/.zshrc
inst_env=(HOME=$home ZDOTDIR= SHELL=/bin/zsh CLD_REPO=$tmp/origin CLD_INSTALL_DIR=$home/cld CLD_BIN_DIR=)
env $inst_env sh $root/install.sh </dev/null >/dev/null 2>&1
[[ -L $home/.local/bin/cld && -x $home/cld/cld ]]; check "install.sh clones cld and links the command" $(( ! $? ))
check "old .zshrc line and its comment removed" $(( ! $(grep -c 'cld.zsh\|one-off Claude presets' $home/.zshrc) ))
check "the rest of .zshrc untouched" $(( $(grep -c -E '^(export KEEP_ME=1|alias keep=true)$' $home/.zshrc) == 2 ))
env $inst_env sh $root/install.sh </dev/null >/dev/null 2>&1
check "bin folder not on PATH: added to .zshrc, once after two runs" $(( $(grep -c "^export PATH=\"$home/.local/bin:\\\$PATH\"$" $home/.zshrc) == 1 ))
out=$(env HOME=$home ZDOTDIR=$home zsh -ic 'cld help' 2>&1 </dev/null)
check "a new zsh in that HOME knows cld" $(has "$out" "one-off settings")
cp $home/.zshrc $tmp/before
env $inst_env PATH=$home/.local/bin:$PATH sh $root/install.sh </dev/null >/dev/null 2>&1
cmp -s $home/.zshrc $tmp/before; check "bin folder already on PATH: .zshrc not touched" $(( ! $? ))
mkdir -p $tmp/other
env $inst_env CLD_INSTALL_DIR=$tmp/other sh $root/install.sh </dev/null >/dev/null 2>&1
check "refuses a folder that is not a cld clone" $(( $? == 1 ))
mkdir -p $tmp/b2; print x > $tmp/b2/cld
env $inst_env CLD_BIN_DIR=$tmp/b2 sh $root/install.sh </dev/null >/dev/null 2>&1
check "refuses to replace a cld file it did not link" $(( $? == 1 && $(has "$(<$tmp/b2/cld)" x) ))

print
(( fail )) && print "FAILED" || print "all checks passed"
exit $fail
