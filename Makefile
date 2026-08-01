ifeq ($(PREFIX),)
    PREFIX := /usr
endif

.PHONY: build check install uninstall

build:

check:
	./tests/smoke.sh

install:
	@tmp="$$(mktemp)"; trap 'rm -f "$$tmp"' EXIT; \
		sed "s:^PREFIX=\"/usr\":PREFIX=\"$(PREFIX)\":" tinkergame > "$$tmp"; \
		install -Dm755 "$$tmp" "$(PREFIX)/bin/tinkergame"

	install -d "$(PREFIX)/share/tinkergame"
	cp -r collections eval guicfgs lang misc "$(PREFIX)/share/tinkergame"

	install -Dm644 README.md -t "$(PREFIX)/share/doc/tinkergame"
	install -Dm644 MIGRATION.md -t "$(PREFIX)/share/doc/tinkergame"
	install -Dm644 "misc/tinkergame.desktop" -t "$(PREFIX)/share/applications"
	install -Dm644 "misc/tinkergame.svg" -t "$(PREFIX)/share/icons/hicolor/scalable/apps"

uninstall:
	rm -f "${PREFIX}/share/icons/hicolor/scalable/apps/tinkergame.svg"
	rm -f "${PREFIX}/share/applications/tinkergame.desktop"
	rm -rf "${PREFIX}/share/doc/tinkergame"

	rm -rf "${PREFIX}/share/tinkergame"

	rm -f "${PREFIX}/bin/tinkergame"
