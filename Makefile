# One-word lowercase targets, `help` first. See the makefile-standards skill.

.DEFAULT_GOAL := help
.PHONY: help check test

help: ## show this help
	@awk 'BEGIN {FS = ":.*?## "; printf "\n\033[1mUsage:\033[0m make \033[36m<target>\033[0m\n\n\033[1mTargets:\033[0m\n"} \
	     /^[a-z]+:.*?## / {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2} \
	     END {print ""}' $(MAKEFILE_LIST)

check: ## syntax-check cld.zsh
	@zsh -n cld.zsh && echo "cld.zsh: ok"

test: check ## dry-run sample commands (prints the claude command, runs nothing)
	@zsh scripts/test.sh
