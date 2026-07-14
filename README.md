# C64 Demo — Teletype Games slide show

A Commodore 64 slide show written in 6502 assembly (built with the ACME assembler). Five slides rotate automatically with per-slide transitions through black, and the show can also be driven from the keyboard.

## The slides

1. **TTG logo + credits scroller** — giant TTG letters built from 8×8 bitmaps with a gold color wash running across them, a pulsing **TELETYPE GAMES** title, and a smooth pixel scroller with the crew credits.
2. **Our first game** — *DEFINITELY NOT AN IMPOSTOR* in big 3×5 block letters with the gold wash, "introduced on TIC-80".
3. **Our second game** — *IS COMING* in big letters with a drop shadow; raster bars run on the border only, so the text stays readable. A new point and click adventure, will be available on Steam.
4. **Contact** — pulsing big *CONTACT* title, web / BBS / IRC lines, a 12-cell three-layer parallax starfield, and six hardware sprites (four-pointed stars) floating on sine-wave paths behind the text.
5. **The assembly confession** — a justified-text apology explaining that this slide show was written with a little help from an AI. The body types in live (one character per frame with a white block cursor); a closing line appears and pulses when the typing is done.

Each slide is shown for 6 seconds (`SLIDE_TIME` in `defs.asm`, PAL frames); slide 5 gets 9 seconds (`S5_TIME`) to let the typewriter finish.

## Controls

| Key | Action |
|-----|--------|
| `SPACE` | next slide immediately |
| `INST/DEL` (backspace) | previous slide |
| `P` | pause toggle — the countdown freezes and a white `P` marker appears in the top-right corner; effects keep running, and SPACE/DEL still work while paused |
| `M` | mute/unmute — toggles the SID music on or off |

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
| `main.asm` | BASIC stub, main loop, slide sequencer, keyboard scanning (SPACE / DEL / P / M); includes the other files via `!src` |
| `defs.asm` | hardware registers (VIC-II, CIA, sprites), colors, layout/timing constants, zero page assignments, the `+prtext` / `+prbig` macros |
| `transitions.asm` | slide transition engine: show/hide dispatch, three transition types (fade, dissolve, wipe), `wait_frame` raster sync, color snapshot/restore |
| `common.asm` | shared routines (`clear_screen`, `print_text`, `draw_big`), shared tables (row×40 lookup, 3×5 block font, wash/pulse/fade color ramps), shared variables |
| `music.asm` | SID music driver skeleton: `music_init` (clear SID, set volume), `music_play` (called every frame from `wait_frame`), mute/unmute; ready for a real SID player routine |
| `slide1.asm` … `slide5.asm` | one file per slide: `sN_init` (draws the screen), `sN_update` (runs once per frame), plus slide-local data and variables |

Everything is assembled in a single ACME pass, so labels can be referenced freely across files.

## How it works

### Slide framework

Every slide consists of an **init** routine (draws the whole screen), an **update** routine (called once per frame through a vector, must return after exactly one frame), and a duration in frames. The main loop in `main.asm` calls the current update, counts the frames down, and steps to the next slide when time runs out — or immediately on SPACE/DEL. Adding a slide means writing a new `slideN.asm`, `!src`-ing it, adding its entries to the vector tables and bumping `NUM_SLIDES`.

### Timing

There are no interrupts: the code polls the raster line register (`$D012`) and does all screen updates while the beam is in the lower border (`RAS_BOTTOM`). Slide 1 additionally splits the frame mid-screen to enable horizontal fine scrolling (`$D016`) for the scroller row only; slide 3 chases the beam down the frame, recoloring the border every 4 lines to draw the raster bars.

### Transitions

Each slide has its own in-transition and out-transition, chosen from three types via `tin_tbl` / `tout_tbl` in `main.asm`:

- **Fade** — steps every color RAM cell through `fadetbl` (each color → one shade darker; every chain hits black within 4 steps). The new slide is drawn with the display off, its colors are snapshotted to `$C000` and blanked, then the fade-in walks each cell back up to its snapshot color.
- **Dissolve** — a 10-bit Galois LFSR (period 1023) visits every screen cell exactly once in pseudo-random order. 25 cells per frame = 40-frame (~0.8 s) full reveal.
- **Wipe** — column-by-column sweep from left to right, one column per frame.

All transitions start with a short white-to-grey border flash to mark the beat.

### Text rendering

Normal lines are printed by `print_text` (row/column/color parameters, driven by the `+prtext` macro). Big titles use `draw_big` (`+prbig`): a 3×5-pixel block font (17 glyphs, only the letters actually used), each letter drawn 3 cells wide + 1 gap from inverse-space blocks — narrow enough to fit "DEFINITELY" (10 letters) on a 40-column row.

### Sprites

Slide 4 uses all six visible hardware sprites (24×21 four-pointed star shape). Y positions follow a 64-entry sine table; X positions add a slower sine wobble to a per-sprite base. All sprites are drawn behind the character layer (`SPR_PRIO`).

### Music

`music.asm` provides a SID driver skeleton. `music_init` clears all SID registers and sets master volume; `music_play` is called once per frame from `wait_frame`, so music keeps playing through transitions. The `M` key toggles mute by zeroing/restoring the SID volume register. To add music, replace the body of `music_play` with a real SID player routine (e.g. a GoatTracker or SID Wizard export).

## Memory map

```
$0801 .. $080F   BASIC stub (10 SYS 2064)
$0810 .. ...     machine code + fonts + texts + variables
$0400 .. $07E7   screen RAM (written directly)
$C000 .. $C3E7   color RAM snapshot buffer for transitions
$D400 .. $D418   SID registers (music)
$D800 ..         color RAM
$D000 .. $D02E   VIC-II registers (display, sprites)
$D011            display on/off (hidden slide redraw)
$D012            raster line (frame sync, raster bars)
$D016            horizontal fine scroll (slide 1 scroller)
$D020 / $D021    border / background color
$DC00 / $DC01    CIA1 keyboard matrix (SPACE / DEL / P / M)
$F5 .. $FE       zero page pointers
```
