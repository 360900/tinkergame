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
	find lib -name '*.sh' -exec bash -n {} +
	test -f lib/core/common.sh

check:
	./tests/smoke.sh

test:
	./tests/run.sh unit

install:
	@tmp="$$(mktemp)"; trap 'rm -f "$$tmp"' EXIT; \
		sed "s:^PREFIX=\"/usr\":PREFIX=\"$(PREFIX)\":" tinkergame > "$$tmp"; \
		install -Dm755 "$$tmp" "$(DESTDIR)$(PREFIX)/bin/tinkergame"
	@tmp="$$(mktemp)"; trap 'rm -f "$$tmp"' EXIT; \
		sed "s:^INSTALL_PREFIX=\"/usr\":INSTALL_PREFIX=\"$(PREFIX)\":" uninstall.sh > "$$tmp"; \
		install -Dm755 "$$tmp" "$(DESTDIR)$(PREFIX)/bin/tinkergame-uninstall"

	install -d "$(DESTDIR)$(PREFIX)/share/tinkergame"
	cp -r collections data eval guicfgs lang misc lib "$(DESTDIR)$(PREFIX)/share/tinkergame"
	sed -i "s:^PREFIX=\"/usr\":PREFIX=\"$(PREFIX)\":" "$(DESTDIR)$(PREFIX)/share/tinkergame/lib/core/common.sh"

	install -Dm644 README.md -t "$(DESTDIR)$(PREFIX)/share/doc/tinkergame"
	install -Dm644 MIGRATION.md -t "$(DESTDIR)$(PREFIX)/share/doc/tinkergame"
	install -Dm644 "misc/tinkergame.desktop" -t "$(DESTDIR)$(PREFIX)/share/applications"
	install -Dm644 "misc/tinkergame.svg" -t "$(DESTDIR)$(PREFIX)/share/icons/hicolor/scalable/apps"

ifneq ($(DESTDIR),)
	@echo "Skipping TinkerGame Steam compatibility-tool registration (DESTDIR staging build)"
else
	@echo "Registering TinkerGame as a Steam compatibility tool"
	@if [ -n "$$SUDO_USER" ] && [ "$$SUDO_USER" != "root" ]; then \
		REGCMD="sudo -u $$SUDO_USER"; \
	else \
		REGCMD=""; \
	fi; \
	if $$REGCMD "$(PREFIX)/bin/tinkergame" compat add; then :; else \
		echo "warning: registration did not complete - run 'tinkergame compat add' once Steam is set up"; \
	fi
endif

install-user:
	@$(MAKE) --no-print-directory install PREFIX="$(HOME)/.local"

uninstall:
	rm -f "${PREFIX}/bin/tinkergame-uninstall"
	rm -f "${PREFIX}/share/icons/hicolor/scalable/apps/tinkergame.svg"
	rm -f "${PREFIX}/share/applications/tinkergame.desktop"
	rm -rf "${PREFIX}/share/doc/tinkergame"

	rm -rf "${PREFIX}/share/tinkergame"

	rm -f "${PREFIX}/bin/tinkergame"
