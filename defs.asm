; -----------------------------------------------------------
; defs.asm - hardware registers, constants, zero page, macros
; included first by main.asm
; -----------------------------------------------------------

; ---- hardware registers ----
SCRCTRL = $d011          ; vertical control: bit 4 switches the display on/off
BORDER  = $d020          ; border color register
BG      = $d021          ; background color register
RASTER  = $d012          ; current raster line
XCTRL   = $d016          ; horizontal fine scroll + 38/40 column mode
SCREEN  = $0400          ; screen RAM (40x25 chars)
COLRAM  = $d800          ; color RAM
CIA1_PA = $dc00          ; CIA1 port A: keyboard matrix column select
CIA1_PB = $dc01          ; CIA1 port B: keyboard matrix row read

; ---- sprite registers ----
SPRPOS   = $d000         ; sprite 0 x; +1 = y, +2 = sprite 1 x, ...
SPR_MSBX = $d010         ; 9th bit of each sprite's x coordinate
SPR_EN   = $d015         ; sprite enable bits
SPR_YEX  = $d017         ; vertical expand
SPR_PRIO = $d01b         ; 1 = sprite behind the characters
SPR_MC   = $d01c         ; multicolor enable
SPR_XEX  = $d01d         ; horizontal expand
SPR_COL  = $d027         ; sprite 0 color, +1 = sprite 1, ...

; ---- colors ----
BLACK   = 0
WHITE   = 1
CYAN    = 3
YELLOW  = 7
ORANGE  = 8
DGREY   = 11
LGREEN  = 13
LBLUE   = 14
LGREY   = 15

; ---- screen layout (slide 1) ----
BIGROW      = 2                  ; top row of the giant letters
BIGCOL      = 6                  ; left column (3*8 + 2*2 = 28 wide, centered)
TITLE_POS   = 12*40 + 13         ; "TELETYPE GAMES" (14 chars, centered)
SCROLLROW   = 14                 ; scroller row

; ---- timing ----
SCROLL_STEP = 2                  ; pixels per frame (8 px / 4 frames = 1 char)
RAS_SCRTOP  = 160                ; just above the scroller row (row 14 = lines 162-169)
RAS_SCRBOT  = 171                ; just below it (rows 13 and 15 are blank, so
                                 ;   a line of jitter here is invisible)
RAS_BOTTOM  = 248                ; lower border: safe time for screen updates
RAS_BARTOP  = 16                 ; first raster line of the bar area (slide 3):
                                 ;   starts in the upper border
BAR_STEPS   = 57                 ; 57 steps * 4 lines = up to line 244

NUM_SLIDES  = 5
SLIDE_TIME  = 400                ; 8 seconds per slide (PAL, 50 frames/s)
S5_TIME     = 450                ; slide 5 is longer: the typewriter needs time
FADE_STEPS  = 5                  ; fade steps (longest fadetbl chain is 4)
FADE_SPEED  = 4                  ; frames between two fade steps

; ---- transition types (tin_tbl / tout_tbl in main.asm) ----
TR_FADE     = 0                  ; fade through black (the original)
TR_DISSOLVE = 1                  ; cells appear/vanish in random order
TR_WIPE     = 2                  ; column sweep, left to right

FADEBUF     = $c000              ; snapshot of color RAM for the fade-in

; ---- zero page pointers ----
txtlo  = $f5             ; text pointer for the print routines (2 bytes)
txthi  = $f6
vec    = $f7             ; slide init vector (2 bytes)
updvec = $f9             ; slide update vector (2 bytes)
scrlo  = $fb
scrhi  = $fc
collo  = $fd
colhi  = $fe

; ---- helper macros: print a normal / big text line ----
!macro prtext .row, .col, .color, .txt, .len {
    lda #<.txt
    sta txtlo
    lda #>.txt
    sta txthi
    lda #.row
    sta prow
    lda #.col
    sta pcol
    lda #.color
    sta pcolor
    lda #.len
    sta plen
    jsr print_text
}

!macro prbig .row, .col, .color, .txt, .len {
    lda #<.txt
    sta txtlo
    lda #>.txt
    sta txthi
    lda #.row
    sta bigrow
    lda #.col
    sta bigcol
    lda #.color
    sta bigcolor
    lda #.len
    sta biglen
    jsr draw_big
}
