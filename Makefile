ifeq ($(PREFIX),)
    PREFIX := /usr
endif

DESTDIR ?=

.PHONY: help build check test install install-user uninstall

.DEFAULT_GOAL := help

help:
	@echo "TinkerGame install targets:"
	@echo "  make install       system-wide install to PREFIX (default /usr, needs sudo)"
	@echo "  make install-user  install for the current user (~/.local, no sudo)"
	@echo "  make uninstall     remove TinkerGame (user settings are kept)"
	@echo ""
	@echo "Development targets:"
	@echo "  make build         syntax-check the entry point and all modules"
	@echo "  make check         run the smoke checks"
	@echo "  make test          run the full unit test suite"
	@echo ""
	@echo "Variables:"
	@echo "  PREFIX=/path       install location (default /usr)"
	@echo "  DESTDIR=/path      staging directory for packaging builds"

build:
	bash -n tinkergame
	bash -n uninstall.sh
	bash -n install.sh
	find lib -name '*.sh' -exec bash -c 'for script do bash -n "$$script" || exit; done' bash {} +
	test -f lib/core/common.sh

check:
	./tests/smoke.sh

test:
	./tests/run.sh unit

# hand PREFIX and DESTDIR to the recipes through the environment, unexpanded,
# so no character in them can break the shell commands or the PREFIX rewrite
export TG_PREFIX := $(value PREFIX)
export TG_DESTDIR := $(value DESTDIR)

# rewrites a script's PREFIX="/usr" line to the install PREFIX, single-quoted for bash
SET_PREFIX = awk 'BEGIN { \
		q = sprintf("%c", 39); p = ENVIRON["TG_PREFIX"]; r = ""; \
		while ((i = index(p, q)) > 0) { r = r substr(p, 1, i - 1) q "\\" q q; p = substr(p, i + 1) } \
		r = r p; \
	} \
	$$0 == "PREFIX=\"/usr\"" { $$0 = "PREFIX=" q r q } { print }'

install:
	@tmp="$$(mktemp)"; trap 'rm -f "$$tmp"' EXIT; \
		$(SET_PREFIX) tinkergame > "$$tmp"; \
		install -Dm755 "$$tmp" "$$TG_DESTDIR$$TG_PREFIX/bin/tinkergame"

	install -d "$$TG_DESTDIR$$TG_PREFIX/share/tinkergame"
	cp -r collections data eval guicfgs lang misc lib "$$TG_DESTDIR$$TG_PREFIX/share/tinkergame"
	@lib="$$TG_DESTDIR$$TG_PREFIX/share/tinkergame/lib/core/common.sh"; tmp="$$(mktemp)"; trap 'rm -f "$$tmp"' EXIT; \
		$(SET_PREFIX) "$$lib" > "$$tmp" && cat "$$tmp" > "$$lib"

	install -Dm644 README.md -t "$$TG_DESTDIR$$TG_PREFIX/share/doc/tinkergame"
	install -Dm644 MIGRATION.md -t "$$TG_DESTDIR$$TG_PREFIX/share/doc/tinkergame"

ifneq ($(value DESTDIR),)
	@echo "Skipping TinkerGame Steam compatibility-tool registration (DESTDIR staging build)"
else
	@# older releases installed a settings menu entry and its icon; drop stale copies
	@for f in "$$TG_PREFIX/share/applications/tinkergame.desktop" \
		"$$TG_PREFIX/share/icons/hicolor/scalable/apps/tinkergame.svg"; do \
		if [ -e "$$f" ]; then rm -f "$$f" && echo "Removed the legacy '$$f'"; fi; \
	done
	@echo "Registering TinkerGame as a Steam compatibility tool"
	@if [ -n "$$SUDO_USER" ] && [ "$$SUDO_USER" != "root" ]; then \
		REGCMD="sudo -u $$SUDO_USER"; \
	else \
		REGCMD=""; \
	fi; \
	if $$REGCMD "$$TG_PREFIX/bin/tinkergame" compat add; then :; else \
		echo "warning: registration did not complete - run 'tinkergame compat add' once Steam is set up"; \
	fi
endif

install-user:
	@$(MAKE) --no-print-directory install PREFIX="$$HOME/.local"

uninstall:
	bash uninstall.sh --yes --prefix="$$TG_PREFIX"
