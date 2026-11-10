#!/usr/bin/env zsh
# Dry-run: a stub `claude` goes first on PATH, so cld only prints what it would run.
stub=$(mktemp -d); trap 'rm -rf $stub' EXIT
print '#!/bin/sh\nexit 0' > $stub/claude; chmod +x $stub/claude
path=($stub $path)
source "${0:A:h}/../cld.zsh"
for words in "sonnet 200k" "opus max 600k" "big" "haiku -- -c"; do
  print -n "cld $words  "
  cld ${=words} 2>&1 < /dev/null
done
