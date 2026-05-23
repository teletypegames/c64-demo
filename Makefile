ASM    = acme
EMU    = x64sc
SRC    = main.asm
TARGET = main.prg

.PHONY: build run clear rebuild rebuildrun

build: $(TARGET)

$(TARGET): $(SRC)
	$(ASM) -f cbm -o $(TARGET) $(SRC)

run: build
	$(EMU) $(TARGET)

clear:
	rm -f $(TARGET)

rebuild: clear build

rebuildrun: clear build run
