# -----------------------------------------
# Makefile – C64 project builder (ACME + VICE)
# -----------------------------------------

PROJECT = c64-demo

ASM    = acme
EMU    = x64sc
SRC    = main.asm
SRCS   = $(wildcard *.asm)
TARGET = main.prg

METADATA = metadata.json

UNAME_S := $(shell uname -s)

# CI/CD variables
VERSION_FILE = .version
UPDATE_SERVER ?= https://teletypegames.org

all: build

deps:
ifeq ($(UNAME_S),Darwin)
	@command -v brew >/dev/null 2>&1 || { echo "Homebrew kell ehhez. Telepitsd: https://brew.sh"; exit 1; }
	brew install acme vice
else
	@echo "A 'deps' target csak macOS-en (Darwin) automatikus. Detektalt OS: $(UNAME_S)"
	@echo "Telepitsd kezzel: acme assembler + VICE emulator (x64sc)."
	@exit 1
endif

build: $(TARGET)

$(TARGET): $(SRCS)
	$(ASM) -f cbm -o $(TARGET) $(SRC)

run: build
	$(EMU) $(TARGET)

clear:
	rm -f $(TARGET) $(PROJECT)-*.prg $(PROJECT)-*.metadata.json $(VERSION_FILE)

rebuild: clear build

rebuildrun: clear build run

# -----------------------------------------
# CI/CD Pipeline targets
# -----------------------------------------

ci-version:
	@VERSION=$$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' $(METADATA) | head -n 1); \
	if [ -z "$$VERSION" ]; then \
		echo "ERROR: no \"version\" field in $(METADATA)!"; \
		exit 1; \
	fi; \
	BRANCH=$${CI_COMMIT_BRANCH:-$${WOODPECKER_BRANCH}}; \
	BRANCH=$$(echo "$$BRANCH" | tr '/' '-'); \
	if [ "$$BRANCH" != "main" ] && [ "$$BRANCH" != "master" ] && [ -n "$$BRANCH" ]; then \
		VERSION=dev-$$VERSION-$$BRANCH; \
	fi; \
	echo "VERSION is: $$VERSION"; \
	echo $$VERSION > $(VERSION_FILE)

ci-build: build
	@VERSION=$$(cat $(VERSION_FILE)); \
	echo "==> Creating versioned files for $$VERSION"; \
	cp $(TARGET) $(PROJECT)-$$VERSION.prg; \
	cp $(METADATA) $(PROJECT)-$$VERSION.metadata.json; \
	ls -lh $(PROJECT)-$$VERSION.*

ci-artifact:
	@VERSION=$$(cat $(VERSION_FILE)); \
	echo "==> Uploading artifacts for version $$VERSION"; \
	for f in $(PROJECT)-$$VERSION.prg $(PROJECT)-$$VERSION.metadata.json; do \
		curl -fsS -H "X-Update-Secret: $(UPDATE_SECRET)" \
			-F "file=@$$f" \
			"$(UPDATE_SERVER)/build/upload?name=$(PROJECT)&version=$$VERSION" || exit 1; \
	done

ci-publish:
	@VERSION=$$(cat $(VERSION_FILE)); \
	echo "==> Triggering update for version $$VERSION"; \
	curl -fsS -X POST -H "X-Update-Secret: $(UPDATE_SECRET)" "$(UPDATE_SERVER)/build/publish?name=$(PROJECT)&platform=c64&version=$$VERSION"

.PHONY: all deps build run clear rebuild rebuildrun ci-version ci-build ci-artifact ci-publish
