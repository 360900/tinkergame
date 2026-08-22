ifeq ($(PREFIX),)
    PREFIX := /usr
endif

DESTDIR ?=

.PHONY: build check install uninstall

build:

check:
	./tests/smoke.sh

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
	@$(PREFIX)/bin/tinkergame compat add
endif

uninstall:
	rm -f "${PREFIX}/bin/tinkergame-uninstall"
	rm -f "${PREFIX}/share/icons/hicolor/scalable/apps/tinkergame.svg"
	rm -f "${PREFIX}/share/applications/tinkergame.desktop"
	rm -rf "${PREFIX}/share/doc/tinkergame"

	rm -rf "${PREFIX}/share/tinkergame"

	rm -f "${PREFIX}/bin/tinkergame"
