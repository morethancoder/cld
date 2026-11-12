# One-word lowercase targets, `help` first. See the makefile-standards skill.

.DEFAULT_GOAL := help
.PHONY: help check test

help: ## show this help
	@awk 'BEGIN {FS = ":.*?## "; printf "\n\033[1mUsage:\033[0m make \033[36m<target>\033[0m\n\n\033[1mTargets:\033[0m\n"} \
	     /^[a-z]+:.*?## / {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2} \
	     END {print ""}' $(MAKEFILE_LIST)

check: ## syntax-check cld, cld.zsh and install.sh
	@zsh -n cld && zsh -n cld.zsh && sh -n install.sh && echo "cld, cld.zsh, install.sh: ok"

test: check ## run every word against a stub claude (starts nothing real)
	@zsh scripts/test.sh
