DB := example
IPYTHON := no

# set environment variable WAREHOUSE_IPYTHON_SHELL=1 if IPython
# needed in development environment
ifeq ($(WAREHOUSE_IPYTHON_SHELL), 1)
    IPYTHON = yes
endif

# Optimization: if the user explicitly passes tests via `T`,
# disable xdist (since the overhead of spawning workers is typically
# higher than running a small handful of specific tests).
# Only do this when the user doesn't set any explicit `TESTARGS` to avoid
# confusion.
COVERAGE := yes
ifneq ($(T),)
		COVERAGE = no
		ifeq ($(TESTARGS),)
				TESTARGS = -n 0
		endif
endif

# PEP 669 introduced sys.monitoring, a lighter-weight way to monitor
# the execution. While this introduces significant speed-up during test
# execution, coverage does not yet support dynamic contexts when enabled.
# This variable can be set to other tracers (ctrace, pytrace, sysmon).
# https://nedbatchelder.com/blog/202312/coveragepy_with_sysmonitoring.html
# TODO: Flip to `sysmon` when we're on Python 3.14
COVERAGE_CORE ?= ctrace

default:
	@echo "Call a specific subcommand:"
	@echo
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null\
	| awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}'\
	| sort\
	| egrep -v -e '^[^[:alnum:]]' -e '^$@$$'
	@echo
	@exit 1

.state/docker-build-base: Dockerfile requirements/main.txt requirements/deploy.txt requirements/lint.txt requirements/tests.txt requirements/dev.txt
	# Build our base container for this project.
	docker compose build --build-arg IPYTHON=$(IPYTHON) --force-rm base

	# Mark the state so we don't rebuild this needlessly.
	mkdir -p .state
	touch .state/docker-build-base

.state/docker-build-static: Dockerfile package.json package-lock.json babel.config.js
	# Build our static container for this project.
	docker compose build --force-rm static

	# Mark the state so we don't rebuild this needlessly.
	mkdir -p .state
	touch .state/docker-build-static

.state/docker-build-docs: Dockerfile requirements/docs-dev.txt requirements/docs-blog.txt requirements/docs-user.txt
	# Build the worker container for this project
	docker compose build --build-arg  USER_ID=$(shell id -u)  --build-arg GROUP_ID=$(shell id -g) --force-rm dev-docs

	# Mark the state so we don't rebuild this needlessly.
	mkdir -p .state
	touch .state/docker-build-docs

.state/docker-build: .state/docker-build-base .state/docker-build-static .state/docker-build-docs
	# Build the worker container for this project
	docker compose build --force-rm worker

	# Mark the state so we don't rebuild this needlessly.
	mkdir -p .state
	touch .state/docker-build

build:
	@$(MAKE) .state/docker-build

	docker system prune -f --filter "label=com.docker.compose.project=warehouse"

serve: .state/docker-build
	$(MAKE) .state/db-populated
	$(MAKE) .state/search-indexed
	docker compose up --remove-orphans

debug: .state/docker-build-base
	docker compose run --rm --service-ports web

tests: .state/docker-build-base
	docker compose run --rm --env COVERAGE=$(COVERAGE) --env COVERAGE_CORE=$(COVERAGE_CORE) tests bin/tests --postgresql-host db $(T) $(TESTARGS)

static_tests: .state/docker-build-static
	docker compose run --rm static bin/static_tests $(T) $(TESTARGS)

static_pipeline: .state/docker-build-static
	docker compose run --rm static bin/static_pipeline $(T) $(TESTARGS)

reformat: .state/docker-build-base
	docker compose run --rm base bin/reformat

lint: .state/docker-build-base .state/docker-build-static
	docker compose run --rm base bin/lint
	docker compose run --rm static bin/static_lint
