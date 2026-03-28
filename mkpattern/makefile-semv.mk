## mkpattern/makefile-semv.mk — reusable semv integration module

SEMV ?= semv
SEMV_FLAGS ?= --auto --yes
SEMV_MIN_SUPPORT ?= 1.0.0
SEMV_COMPAT ?= major   # major | min | exact
SEMV_CACHE ?= .semv.cache

.PHONY: semv.detect semv.status semv.init \
        version version.next version.tag version.pend version.file \
        version.get.bash version.set.bash version.sync version.sync.bash

# One-time detection per make run; caches state to $(SEMV_CACHE)
semv.detect:
	@set -e; \
	if ! command -v '$(SEMV)' >/dev/null 2>&1; then \
	  echo 'SEMV_UNAVAIL=1' > '$(SEMV_CACHE)'; \
	  echo 'semv not found; semv integration disabled'; \
	  exit 0; \
	fi; \
	ver="$$( $(SEMV) --version 2>/dev/null | grep -Eo '[0-9]+(\.[0-9]+){1,3}' | head -1 )"; \
	if [ -z "$$ver" ]; then \
	  echo 'SEMV_UNAVAIL=1' > '$(SEMV_CACHE)'; \
	  echo 'semv found but version unknown; semv integration disabled'; \
	  exit 0; \
	fi; \
	req_major="$$(echo '$(SEMV_MIN_SUPPORT)' | cut -d. -f1)"; \
	have_major="$$(echo "$$ver" | cut -d. -f1)"; \
	ok=0; \
	case '$(SEMV_COMPAT)' in \
	  major) [ "$$req_major" = "$$have_major" ] && ok=1 ;; \
	  min)   smallest="$$(printf '%s\n' '$(SEMV_MIN_SUPPORT)' "$$ver" | sort -V | head -1)"; [ "$$smallest" = '$(SEMV_MIN_SUPPORT)' ] && ok=1 ;; \
	  exact) [ "$$ver" = '$(SEMV_MIN_SUPPORT)' ] && ok=1 ;; \
	esac; \
	if [ "$$ok" -ne 1 ]; then \
	  echo "semv $$ver incompatible with policy $(SEMV_COMPAT) >= $(SEMV_MIN_SUPPORT)"; \
	  echo 'SEMV_UNAVAIL=1' > '$(SEMV_CACHE)'; \
	  exit 0; \
	fi; \
	echo "SEMV_UNAVAIL=0" > '$(SEMV_CACHE)'; \
	echo "SEMV_VERSION=$$ver" >> '$(SEMV_CACHE)'; \
	echo "semv $$ver OK"

semv.status: semv.detect
	@. '$(SEMV_CACHE)'; if [ "$$SEMV_UNAVAIL" = 1 ]; then \
	  echo 'semv unavailable'; exit 0; fi; \
	$(SEMV) info $(SEMV_FLAGS)

SEMV_AUTO_INIT ?= 0
semv.init: semv.detect
	@set -e; . '$(SEMV_CACHE)'; if [ "$$SEMV_UNAVAIL" = 1 ]; then \
	  echo 'semv unavailable; init skipped'; exit 0; fi; \
	if $(SEMV) can >/dev/null 2>&1; then \
	  echo 'semv already initialized'; \
	else \
	  if [ "$(SEMV_AUTO_INIT)" = "1" ]; then \
	    echo 'Initializing semv (new)…'; $(SEMV) new $(SEMV_FLAGS); \
	  else \
	    echo 'semv not initialized. Run `make semv:init SEMV_AUTO_INIT=1` to initialize.'; \
	  fi; \
	fi

version: semv.detect
	@. '$(SEMV_CACHE)'; if [ "$$SEMV_UNAVAIL" = 1 ]; then echo 'semv unavailable'; exit 0; fi; \
	$(SEMV) $(SEMV_FLAGS)

version.next: semv.detect
	@. '$(SEMV_CACHE)'; if [ "$$SEMV_UNAVAIL" = 1 ]; then echo 'semv unavailable'; exit 0; fi; \
	$(SEMV) next $(SEMV_FLAGS)

version.tag: semv.detect
	@. '$(SEMV_CACHE)'; if [ "$$SEMV_UNAVAIL" = 1 ]; then echo 'semv unavailable'; exit 0; fi; \
	$(SEMV) tag

version.pend: semv.detect
	@. '$(SEMV_CACHE)'; if [ "$$SEMV_UNAVAIL" = 1 ]; then echo 'semv unavailable'; exit 0; fi; \
	$(SEMV) pend

version.file: semv.detect
	@. '$(SEMV_CACHE)'; if [ "$$SEMV_UNAVAIL" = 1 ]; then echo 'semv unavailable'; exit 0; fi; \
	$(SEMV) file

version.get.bash: semv.detect
	@. '$(SEMV_CACHE)'; if [ "$$SEMV_UNAVAIL" = 1 ]; then echo 'semv unavailable'; exit 0; fi; \
	if [ -z "$(SEMV_BASH_FILES)" ]; then echo 'No SEMV_BASH_FILES set; skipping'; exit 0; fi; \
	for f in $(SEMV_BASH_FILES); do \
	  echo "$$f:"; $(SEMV) get bash "$$f" || true; \
	done

version.set.bash: semv.detect
	@test -n "$(VER)" || { echo 'VER is required, e.g., make version:set:bash VER=1.2.3'; exit 2; }
	@. '$(SEMV_CACHE)'; if [ "$$SEMV_UNAVAIL" = 1 ]; then echo 'semv unavailable'; exit 0; fi; \
	if [ -z "$(SEMV_BASH_FILES)" ]; then echo 'No SEMV_BASH_FILES set; skipping'; exit 0; fi; \
	for f in $(SEMV_BASH_FILES); do \
	  echo "set $$f -> $(VER)"; $(SEMV) set bash "$(VER)" "$$f"; \
	done

version.sync: semv.detect semv.init
	@. '$(SEMV_CACHE)'; if [ "$$SEMV_UNAVAIL" = 1 ]; then echo 'semv unavailable; skipping sync'; exit 0; fi; \
	$(SEMV) sync $(SEMV_FLAGS)

version.sync.bash: semv.detect
	@. '$(SEMV_CACHE)'; if [ "$$SEMV_UNAVAIL" = 1 ]; then echo 'semv unavailable'; exit 0; fi; \
	if [ -z "$(SEMV_BASH_FILES)" ]; then echo 'No SEMV_BASH_FILES set; skipping'; exit 0; fi; \
	cur="$$( $(SEMV) $(SEMV_FLAGS) )"; \
	for f in $(SEMV_BASH_FILES); do \
	  echo "sync $$f -> $$cur"; $(SEMV) set bash "$$cur" "$$f"; \
	done
