# C64 Demo — `main.asm`

A minimal Commodore 64 demo written in 6502 assembly (compiled with the ACME assembler). The program prints two lines of text on the screen, then enters an infinite loop that cycles the border color.

## Build and run

```sh
make build       # produce main.prg
make run         # build + launch in VICE (x64sc)
make rebuildrun  # clean rebuild + run
make deps        # on macOS: install acme + vice via Homebrew
```

Loading the `.prg` on a real or emulated C64:

```
LOAD"*",8,1
RUN
```

## Structure of `main.asm`

### 1. BASIC stub (from `$0801`)

The C64 looks for programs at the start of the BASIC memory area (`$0801`). We place a one-line BASIC program here:

```
10 SYS 2064
```

This lets the user just type `RUN` — the BASIC interpreter then transfers control to the machine-code entry point at address `2064` ($0810). The `!byte` directives hand-encode the BASIC line: link pointer, line number, `SYS` token (`$9e`), the `" 2064"` ASCII digits, end-of-line zero, and end-of-program marker.

### 2. Entry point (`$0810` = 2064)

```asm
* = $0810
```

Machine code starts here.

### 3. KERNAL and VIC-II addresses

| Symbol    | Address| Meaning                          |
|-----------|--------|----------------------------------|
| `CHROUT`  | `$FFD2`| KERNAL character output routine  |
| `BORDER`  | `$D020`| VIC-II border color register     |
| `BG`      | `$D021`| VIC-II background color register |

### 4. `start` — initialization

- **Background:** light blue (`14`) into `$D021`.
- **Border:** dark blue (`6`) into `$D020`.
- **Clear screen:** PETSCII control code `$93` sent to `CHROUT`.
- **Text color:** white (`$05`).

### 5. `print_loop` — printing the text

Classic null-terminated string output:

```asm
ldx #0
print_loop:
    lda message,x    ; load character using X as index
    beq color_loop   ; if 0 → done
    jsr CHROUT       ; otherwise print it
    inx
    jmp print_loop
```

At the `message` label there is PETSCII text separated by line breaks (`13`), terminated with a `0` byte.

### 6. `color_loop` — infinite border flashing

```asm
color_loop:
    inc BORDER       ; border color +1
    ; two nested delay loops (256*256 iterations)
    jmp color_loop
```

`inc $D020` increments the lower 4 bits of the border color on every iteration (the VIC-II only uses those anyway), cycling through all 16 colors. The nested `dex`/`dey` loop is pure busy-wait so the eye can perceive the change — the C64 runs at ~1 MHz, and without the delay the flashing would be invisibly fast.

### 7. `message` — data

```asm
message:
    !text "HELLO, COMMODORE 64!"
    !byte 13, 13               ; two line breaks
    !text "TELETYPE GAMES DEMO"
    !byte 13, 0                ; line break + end-of-string
```

## Memory map

```
$0801 .. $080F   BASIC stub (10 SYS 2064)
$0810 .. ...     machine code (start, print_loop, color_loop, message)
$D020            border color  (visible while being written)
$D021            background color
$FFD2            KERNAL CHROUT
```
