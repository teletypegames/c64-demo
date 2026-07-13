# C64 Demo — Teletype Games slide show

A Commodore 64 slide show written in 6502 assembly (built with the ACME assembler). Five slides rotate automatically, cross-fading through black between switches, and the show can also be driven from the keyboard.

## The slides

1. **TTG logo + credits scroller** — giant TTG letters built from 8×8 bitmaps with a gold color wash running across them, a pulsing **TELETYPE GAMES** title, and a smooth pixel scroller with the crew credits.
2. **Our first game** — *DEFINITELY NOT AN IMPOSTOR* in big 3×5 block letters with the gold wash, "introduced on TIC-80".
3. **Our second game** — *IS COMING* in big letters with a drop shadow; raster bars run on the border only, so the text stays readable. A new point and click adventure, will be available on Steam.
4. **Contact** — pulsing big *CONTACT* title, web / BBS / IRC lines.
5. **The assembly confession** — a justified-text apology explaining that this slide show was written with a little help from an AI.

Each slide is shown for 6 seconds (`SLIDE_TIME` in `defs.asm`, PAL frames).

## Controls

| Key | Action |
|-----|--------|
| `SPACE` | next slide immediately |
| `INST/DEL` (backspace) | previous slide |
| `P` | pause toggle — the countdown freezes and a white `P` marker appears in the top-right corner; effects keep running, and SPACE/DEL still work while paused |

Keys are read directly from the CIA1 keyboard matrix (the KERNAL is switched off).

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

## Source layout

| File | Contents |
|------|----------|
| `main.asm` | BASIC stub, main loop, slide sequencer, fade transition, keyboard scanning; includes the other files via `!src` |
| `defs.asm` | hardware registers, colors, layout/timing constants, zero page assignments, the `+prtext` / `+prbig` macros |
| `common.asm` | shared routines (`clear_screen`, `print_text`, `draw_big`), shared tables (row×40 lookup, 3×5 block font, wash/pulse/fade color ramps), shared variables |
| `slide1.asm` … `slide5.asm` | one file per slide: `sN_init` (draws the screen), `sN_update` (runs once per frame), plus slide-local data and variables |

Everything is assembled in a single ACME pass, so labels can be referenced freely across files.

## How it works

### Slide framework

Every slide consists of an **init** routine (draws the whole screen), an **update** routine (called once per frame through a vector, must return after exactly one frame), and a duration in frames. The main loop in `main.asm` calls the current update, counts the frames down, and steps to the next slide when time runs out — or immediately on SPACE/DEL. Adding a slide means writing a new `slideN.asm`, `!src`-ing it, adding its entries to the vector tables and bumping `NUM_SLIDES`.

### Timing

There are no interrupts: the code polls the raster line register (`$D012`) and does all screen updates while the beam is in the lower border (`RAS_BOTTOM`). Slide 1 additionally splits the frame mid-screen to enable horizontal fine scrolling (`$D016`) for the scroller row only; slide 3 chases the beam down the frame, recoloring the border every 4 lines to draw the raster bars.

### Transition

Slides cross-fade through black. Fading out repeatedly steps every color RAM cell through `fadetbl` (each color → one shade darker; every chain hits black within 4 steps). The new slide is then drawn with the display switched off (`$D011`), its color RAM is snapshotted to a buffer at `$C000` and blanked, the display is switched back on, and the fade-in walks each cell from black back up to its snapshot color. Works cleanly because every slide sits on a black background.

### Text rendering

Normal lines are printed by `print_text` (row/column/color parameters, driven by the `+prtext` macro). Big titles use `draw_big` (`+prbig`): a 3×5-pixel block font (17 glyphs, only the letters actually used), each letter drawn 3 cells wide + 1 gap from inverse-space blocks — narrow enough to fit "DEFINITELY" (10 letters) on a 40-column row.

## Memory map

```
$0801 .. $080F   BASIC stub (10 SYS 2064)
$0810 .. ...     machine code + fonts + texts + variables
$0400 .. $07E7   screen RAM (written directly)
$C000 .. $C3E7   color RAM snapshot buffer for the fade-in
$D800 ..         color RAM
$D011            display on/off (hidden slide redraw)
$D012            raster line (frame sync, raster bars)
$D016            horizontal fine scroll (slide 1 scroller)
$D020 / $D021    border / background color
$DC00 / $DC01    CIA1 keyboard matrix (SPACE / DEL / P)
$F5 .. $FE       zero page pointers
```
