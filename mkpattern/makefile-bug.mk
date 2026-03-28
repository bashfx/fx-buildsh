## mkpattern/makefile-bug.mk — Bug lock module (reusable)

BUG_STATE_FILE ?= .bugmode

.PHONY: bug:on bug:off bug:status guard:bug-off

bug:on:
	@touch "$(BUG_STATE_FILE)"; echo "🔒 BUG MODE ON ($(BUG_STATE_FILE))"

bug:off:
	@rm -f "$(BUG_STATE_FILE)"; echo "🔓 BUG MODE OFF"

bug:status:
	@if [ -f "$(BUG_STATE_FILE)" ]; then echo "Bug mode: ON ($(BUG_STATE_FILE))"; else echo "Bug mode: OFF"; fi

guard:bug-off:
	@if [ -f "$(BUG_STATE_FILE)" ]; then \
	  echo "❌ Blocked: BUG MODE is ON (found $(BUG_STATE_FILE))."; \
	  echo "   Toggle with 'make bug:off' to proceed."; \
	  exit 2; \
	fi

