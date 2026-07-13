# C64 Demo — `main.asm`

A Commodore 64 intro written in 6502 assembly (compiled with the ACME assembler). The screen shows:

- giant **TTG** letters in the top half (built from 8×8 bitmaps, drawn with solid block characters),
- **TELETYPE GAMES** centered below,
- a horizontally scrolling credits line (`MR.ZERO - TASNADI ZSOLT / MR.ONE - TARI BALAZS / MR.TWO - TIMAR ZOLTAN / MR.THREE - MEZO BELA`),
- **WWW.TELETYPEGAMES.ORG**,
- **SZEGED, 2026**.

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

A hand-encoded one-line BASIC program (`10 SYS 2064`) so the user only has to type `RUN`; it jumps to the machine-code entry point at `$0810`.

### 2. Initialization

Border and background are set to black, then screen RAM (`$0400`) is filled with spaces and color RAM (`$D800`) with white. Everything is drawn by writing to screen RAM directly — the KERNAL `CHROUT` routine is not used.

### 3. Giant letters

Each big letter is an 8×8 bitmap (`bigfont`, one byte per row, MSB = left pixel). The drawing loop walks the three letters, shifts each bitmap row out bit by bit, and writes an inverse-space block (`$A0`) plus yellow into color RAM for every set bit. Letters are 8 columns wide with a 2-column gap, so the 28-column logo is centered starting at column 6, row 2.

### 4. Static texts

Null-loop copies place the screen-code strings (`!scr`) at fixed, centered screen offsets:

| Text                    | Row | Color       |
|-------------------------|-----|-------------|
| `TELETYPE GAMES`        | 12  | white       |
| scroller line           | 14  | cyan        |
| `WWW.TELETYPEGAMES.ORG` | 17  | light green |
| `SZEGED, 2026`          | 19  | light grey  |

### 5. Scroller (main loop)

The main loop synchronizes to the display by waiting for raster line `$FE` (`$D012`), giving one iteration per frame. Every `SCROLL_SPEED` (4) frames it shifts row 14 one character to the left and feeds the next character of `scrolltext` into the rightmost column; the index wraps at the end of the text, so the credits loop forever.

## Memory map

```
$0801 .. $080F   BASIC stub (10 SYS 2064)
$0810 .. ...     machine code + font bitmaps + texts + variables
$0400 .. $07E7   screen RAM (written directly)
$D800 ..         color RAM
$D012            raster line (frame sync)
$D020 / $D021    border / background color
```
