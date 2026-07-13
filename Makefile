ASM    = acme
EMU    = x64sc
SRC    = main.asm
SRCS   = $(wildcard *.asm)
TARGET = main.prg

UNAME_S := $(shell uname -s)

.PHONY: build run clear rebuild rebuildrun deps

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
	rm -f $(TARGET)

rebuild: clear build

rebuildrun: clear build run
