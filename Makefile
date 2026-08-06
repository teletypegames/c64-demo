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

.PHONY: all deps build run clear rebuild rebuildrun
