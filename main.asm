; -----------------------------------------------------------
; main.asm - C64 demo: slide show (6 seconds per slide)
;   slide 1: giant TTG logo + credits scroller
;   slide 2: OUR FIRST GAME - Definitely not an Impostor
;   slide 3: OUR SECOND GAME IS COMING (full-screen raster bars)
;   slide 4: CONTACT
;   slide 5: the assembly confession
;   slides cross-fade through black between switches
;   all timed by polling the raster beam
; Build: acme -f cbm -o main.prg main.asm
; -----------------------------------------------------------

!to "main.prg", cbm

* = $0801

; ---- BASIC stub: 10 SYS 2064 ----
; so after LOAD"*",8,1 it's enough to type RUN
!byte $0c, $08          ; address of next line
!byte $0a, $00          ; line number: 10
!byte $9e               ; SYS token
!byte $20, $32, $30, $36, $34   ; " 2064"
!byte $00               ; end of line
!byte $00, $00          ; end of program

* = $0810                ; = 2064 in decimal

; ---- hardware registers ----
SCRCTRL = $d011          ; vertical control: bit 4 switches the display on/off
BORDER  = $d020          ; border color register
BG      = $d021          ; background color register
RASTER  = $d012          ; current raster line
XCTRL   = $d016          ; horizontal fine scroll + 38/40 column mode
SCREEN  = $0400          ; screen RAM (40x25 chars)
COLRAM  = $d800          ; color RAM

; ---- colors ----
BLACK   = 0
WHITE   = 1
CYAN    = 3
YELLOW  = 7
DGREY   = 11
LGREEN  = 13
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
SLIDE_TIME  = 300                ; 6 seconds per slide (PAL, 50 frames/s)
FADE_STEPS  = 5                  ; fade steps (longest fadetbl chain is 4)
FADE_SPEED  = 4                  ; frames between two fade steps

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

start:
    sei                  ; no KERNAL IRQ - raster polling must not jitter

    lda #0
    sta framectr
    sta slide
    jsr show_slide       ; draw slide 0 hidden, then fade it in

; ============================================================
; main loop - one update call per frame; when the slide's
; duration runs out, switch to the next slide
; ============================================================
main:
    jsr call_update

    lda durlo            ; 16-bit frame countdown
    bne dur_dec
    dec durhi
dur_dec:
    dec durlo
    lda durlo
    ora durhi
    bne main

    jsr fade_out         ; time's up: fade the old slide to black

    ldx slide            ; advance to the next slide
    inx
    cpx #NUM_SLIDES
    bne slide_ok
    ldx #0
slide_ok:
    stx slide
    jsr show_slide       ; draw it hidden, then fade it in
    jmp main

call_update:
    jmp (updvec)         ; each update runs exactly one frame, ends with rts

; ---- load a slide's vectors and duration, then run its init ----
slide_setup:
    ldx slide
    lda slide_dur_lo,x
    sta durlo
    lda slide_dur_hi,x
    sta durhi
    lda slide_upd_lo,x
    sta updvec
    lda slide_upd_hi,x
    sta updvec+1
    lda slide_init_lo,x
    sta vec
    lda slide_init_hi,x
    sta vec+1
    lda #BLACK
    sta BORDER
    sta BG
    jmp (vec)            ; init ends with rts -> returns to slide_setup's caller

; ============================================================
; slide transition: fade through black
; ============================================================

; ---- draw the current slide while the display is switched off
; (everything shows border color = black), snapshot its colors,
; blacken them, switch the display back on and fade in ----
show_slide:
    lda #$0b             ; display off
    sta SCRCTRL
    jsr slide_setup
    jsr snapshot_colram
    lda #$1b             ; display on
    sta SCRCTRL

    ; fade in: fadecnt counts how many times the target color is
    ; darkened; counting 4 -> 0 walks each cell from black back
    ; up to its snapshot color
    lda #FADE_STEPS-1
    sta fadecnt
fi_step:
    jsr build_map
    jsr apply_map
    ldx #FADE_SPEED
fi_wait:
    jsr wait_frame
    dex
    bne fi_wait
    lda fadecnt
    beq fi_done
    dec fadecnt
    jmp fi_step
fi_done:
    rts

; ---- darken the whole color RAM step by step until black ----
fade_out:
    lda #FADE_STEPS
    sta fadecnt
fo_step:
    ldx #FADE_SPEED
fo_wait:
    jsr wait_frame
    dex
    bne fo_wait
    jsr apply_fade
    dec fadecnt
    bne fo_step
    rts

; ---- wait for the next bottom-border arrival of the beam ----
wait_frame:
wf_leave:
    lda RASTER           ; first leave line RAS_BOTTOM if we are on it
    cmp #RAS_BOTTOM
    beq wf_leave
wf_reach:
    lda RASTER
    cmp #RAS_BOTTOM
    bne wf_reach
    rts

; ---- one fade-out step: every color RAM cell one shade darker ----
apply_fade:
    ldx #0
af_loop:
    lda COLRAM,x
    and #15              ; color RAM reads have garbage upper bits
    tay
    lda fadetbl,y
    sta COLRAM,x
    lda COLRAM+250,x
    and #15
    tay
    lda fadetbl,y
    sta COLRAM+250,x
    lda COLRAM+500,x
    and #15
    tay
    lda fadetbl,y
    sta COLRAM+500,x
    lda COLRAM+750,x
    and #15
    tay
    lda fadetbl,y
    sta COLRAM+750,x
    inx
    cpx #250
    bne af_loop
    rts

; ---- copy color RAM to FADEBUF, then blacken color RAM ----
snapshot_colram:
    ldx #0
sn_loop:
    lda COLRAM,x
    and #15
    sta FADEBUF,x
    lda COLRAM+250,x
    and #15
    sta FADEBUF+250,x
    lda COLRAM+500,x
    and #15
    sta FADEBUF+500,x
    lda COLRAM+750,x
    and #15
    sta FADEBUF+750,x
    lda #BLACK
    sta COLRAM,x
    sta COLRAM+250,x
    sta COLRAM+500,x
    sta COLRAM+750,x
    inx
    cpx #250
    bne sn_loop
    rts

; ---- curmap[c] = color c darkened fadecnt times ----
build_map:
    ldx #15
bm_color:
    txa
    tay
    lda fadecnt
    sta bmcnt
    beq bm_store         ; 0 steps: identity map
bm_apply:
    lda fadetbl,y
    tay
    dec bmcnt
    bne bm_apply
bm_store:
    tya
    sta curmap,x
    dex
    bpl bm_color
    rts

; ---- write curmap[FADEBUF] into the whole color RAM ----
apply_map:
    ldx #0
am_loop:
    ldy FADEBUF,x
    lda curmap,y
    sta COLRAM,x
    ldy FADEBUF+250,x
    lda curmap,y
    sta COLRAM+250,x
    ldy FADEBUF+500,x
    lda curmap,y
    sta COLRAM+500,x
    ldy FADEBUF+750,x
    lda curmap,y
    sta COLRAM+750,x
    inx
    cpx #250
    bne am_loop
    rts

; ---- clear screen RAM, fill color RAM with white ----
clear_screen:
    ldx #0
cls_loop:
    lda #$20             ; space
    sta SCREEN,x
    sta SCREEN+$100,x
    sta SCREEN+$200,x
    sta SCREEN+$2e8,x
    lda #WHITE
    sta COLRAM,x
    sta COLRAM+$100,x
    sta COLRAM+$200,x
    sta COLRAM+$2e8,x
    inx
    bne cls_loop
    rts

; ---- print a text line: txtlo/hi, prow, pcol, pcolor, plen ----
print_text:
    ldx prow
    lda mul40lo,x
    clc
    adc pcol
    sta scrlo
    sta collo
    lda mul40hi,x
    adc #>SCREEN         ; carry still valid from the low-byte add
    sta scrhi
    clc
    adc #$d4             ; COLRAM - SCREEN high byte distance
    sta colhi
    ldy #0
pt_loop:
    lda (txtlo),y
    sta (scrlo),y
    lda pcolor
    sta (collo),y
    iny
    cpy plen
    bne pt_loop
    rts

; ---- draw a text line with big 3x5 block letters ----
; txtlo/hi = text (screen codes), bigrow/bigcol = top-left cell,
; bigcolor = color, biglen = char count; each letter is 3 cells
; wide + 1 gap, 5 cells tall
draw_big:
    lda #0
    sta bigi
db_char:
    ldy bigi
    lda (txtlo),y
    cmp #$20             ; space: leave the cell empty
    beq db_next
    tax
    lda bigmap,x         ; screen code -> glyph index
    sta glyphbase
    asl                  ; glyph base = index * 5
    asl
    clc
    adc glyphbase
    sta glyphbase
    lda bigi             ; cell x = bigcol + charindex * 4
    asl
    asl
    clc
    adc bigcol
    sta charx
    lda #0
    sta rowidx
db_row:
    lda bigrow           ; row pointers from the row*40 tables
    clc
    adc rowidx
    tax
    lda mul40lo,x
    sta scrlo
    sta collo
    lda mul40hi,x
    clc
    adc #>SCREEN
    sta scrhi
    clc
    adc #$d4
    sta colhi
    lda glyphbase
    clc
    adc rowidx
    tax
    lda bigglyphs,x
    asl                  ; 3-bit pattern up to bits 7-5
    asl
    asl
    asl
    asl
    sta curbits
    ldy charx
    lda #3
    sta bitcnt
db_bit:
    asl curbits          ; leftmost pixel first
    bcc db_nobit
    lda #$a0             ; inverse space = solid block
    sta (scrlo),y
    lda bigcolor
    sta (collo),y
db_nobit:
    iny
    dec bitcnt
    bne db_bit
    inc rowidx
    lda rowidx
    cmp #5
    bne db_row
db_next:
    inc bigi
    lda bigi
    cmp biglen
    beq db_done
    jmp db_char          ; too far for a relative branch
db_done:
    rts

; ---- draw the giant TTG letters from 8x8 bitmaps ----
draw_logo:
    lda #0
    sta letter
letter_loop:
    ldx letter
    lda letter_off,x
    clc
    adc #<(SCREEN + BIGROW*40 + BIGCOL)
    sta scrlo
    lda #>(SCREEN + BIGROW*40 + BIGCOL)
    adc #0
    sta scrhi
    lda letter_off,x
    clc
    adc #<(COLRAM + BIGROW*40 + BIGCOL)
    sta collo
    lda #>(COLRAM + BIGROW*40 + BIGCOL)
    adc #0
    sta colhi

    lda letter           ; bitmap index = letter * 8
    asl
    asl
    asl
    tax
    lda #8
    sta rowcount
row_loop:
    lda bigfont,x
    sta curbits
    ldy #0
bit_loop:
    asl curbits          ; leftmost pixel first
    bcc no_plot
    lda #$a0             ; inverse space = solid block
    sta (scrlo),y
    lda #YELLOW
    sta (collo),y
no_plot:
    iny
    cpy #8
    bne bit_loop
    lda scrlo            ; advance both pointers one screen row
    clc
    adc #40
    sta scrlo
    bcc scr_nocarry
    inc scrhi
scr_nocarry:
    lda collo
    clc
    adc #40
    sta collo
    bcc col_nocarry
    inc colhi
col_nocarry:
    inx
    dec rowcount
    bne row_loop

    inc letter
    lda letter
    cmp #3
    bne letter_loop
    rts

; ============================================================
; slide 1: giant logo + credits scroller
; ============================================================
s1_init:
    jsr clear_screen
    jsr draw_logo

    +prtext 12, 13, WHITE,  txt_title, txt_title_end - txt_title
    +prtext 17,  9, LGREEN, txt_www,   txt_www_end - txt_www
    +prtext 19, 14, LGREY,  txt_city,  txt_city_end - txt_city

    ; scroller row color
    ldx #39
    lda #CYAN
scrollcol_loop:
    sta COLRAM+SCROLLROW*40,x
    dex
    bpl scrollcol_loop

    lda #6               ; multiple of SCROLL_STEP -> clean 4-frame cycle
    sta xscroll
    lda #0
    sta scrollidx
    sta washphase
    rts

s1_update:
    ; switch on fine scroll + 38-column mode for the scroller row only
wait_scrtop:
    lda RASTER
    cmp #RAS_SCRTOP
    bne wait_scrtop
    lda xscroll          ; bits 0-2 = x scroll, bit 3 = 0 -> 38 columns
    sta XCTRL

wait_scrbot:
    lda RASTER
    cmp #RAS_SCRBOT
    bne wait_scrbot
    lda #$c8             ; back to default: 40 columns, no scroll
    sta XCTRL

    ; beam is in the lower border: do all updates now, invisibly
wait_bottom:
    lda RASTER
    cmp #RAS_BOTTOM
    bne wait_bottom

    inc framectr

    ; smooth scroll: move SCROLL_STEP pixels, shift chars on wrap
    lda xscroll
    sec
    sbc #SCROLL_STEP
    bcs xs_store         ; still 0..7: just store
    adc #8               ; wrap (carry clear, so this adds exactly 8)
    sta xscroll
    jsr shift_row
    jmp xs_done
xs_store:
    sta xscroll
xs_done:

    lda framectr         ; wash moves one column every 2nd frame
    and #1
    bne wash_hold
    inc washphase
wash_hold:

    jsr do_wash
    jsr do_pulse
    rts

; ---- shift the scroller row one char left, feed in the next char ----
shift_row:
    ldx #0
sr_loop:
    lda SCREEN+SCROLLROW*40+1,x
    sta SCREEN+SCROLLROW*40,x
    inx
    cpx #39
    bne sr_loop
    ldx scrollidx
    lda scrolltext,x
    sta SCREEN+SCROLLROW*40+39
    inx
    cpx #scrolltext_end - scrolltext
    bne sr_nowrap
    ldx #0
sr_nowrap:
    stx scrollidx
    rts

; ---- color wash: gold gradient running across the logo columns ----
do_wash:
    ldx #27              ; 28 logo columns
dw_loop:
    txa
    clc
    adc washphase
    and #15
    tay
    lda washtbl,y
    sta COLRAM + (BIGROW+0)*40 + BIGCOL,x
    sta COLRAM + (BIGROW+1)*40 + BIGCOL,x
    sta COLRAM + (BIGROW+2)*40 + BIGCOL,x
    sta COLRAM + (BIGROW+3)*40 + BIGCOL,x
    sta COLRAM + (BIGROW+4)*40 + BIGCOL,x
    sta COLRAM + (BIGROW+5)*40 + BIGCOL,x
    sta COLRAM + (BIGROW+6)*40 + BIGCOL,x
    sta COLRAM + (BIGROW+7)*40 + BIGCOL,x
    dex
    bpl dw_loop
    rts

; ---- pulsing title: grey-white ramp, one step per 8 frames ----
do_pulse:
    lda framectr
    lsr
    lsr
    lsr
    and #7
    tay
    lda pulsetbl,y
    ldx #txt_title_end - txt_title - 1
dp_loop:
    sta COLRAM+TITLE_POS,x
    dex
    bpl dp_loop
    rts

; ============================================================
; slide 2: OUR FIRST GAME - Definitely not an Impostor
;   big letters with the gold wash running across them
; ============================================================
s2_init:
    jsr clear_screen
    +prtext  1, 13, WHITE, txt_firstgame, txt_firstgame_end - txt_firstgame
    +prbig   4,  0, YELLOW, big_definitely, 10
    +prbig  10,  8, YELLOW, big_notan, 6
    +prbig  16,  4, YELLOW, big_impostor, 8
    +prtext 23, 10, LGREY, txt_tic80, txt_tic80_end - txt_tic80
    rts

s2_update:
    lda RASTER
    cmp #RAS_BOTTOM
    bne s2_update

    inc framectr
    lda framectr         ; wash moves one column every 2nd frame
    and #1
    bne s2_hold
    inc washphase
s2_hold:

    ; gold wash across all 15 big-letter rows (4-8, 10-14, 16-20)
    ldx #39
s2_loop:
    txa
    clc
    adc washphase
    and #15
    tay
    lda washtbl,y
    sta COLRAM +  4*40,x
    sta COLRAM +  5*40,x
    sta COLRAM +  6*40,x
    sta COLRAM +  7*40,x
    sta COLRAM +  8*40,x
    sta COLRAM + 10*40,x
    sta COLRAM + 11*40,x
    sta COLRAM + 12*40,x
    sta COLRAM + 13*40,x
    sta COLRAM + 14*40,x
    sta COLRAM + 16*40,x
    sta COLRAM + 17*40,x
    sta COLRAM + 18*40,x
    sta COLRAM + 19*40,x
    sta COLRAM + 20*40,x
    dex
    bpl s2_loop
    rts

; ============================================================
; slide 3: OUR SECOND GAME IS COMING
;   full-screen raster bars (background + border) behind the text
; ============================================================
s3_init:
    jsr clear_screen
    +prtext  4, 12, WHITE,  txt_secondgame, txt_secondgame_end - txt_secondgame
    +prbig   8,  3, DGREY,  big_iscoming, 9   ; drop shadow first (+1 row, +1 col)
    +prbig   7,  2, YELLOW, big_iscoming, 9   ; then the letters on top of it
    +prtext 15,  4, WHITE,  txt_pointclick, txt_pointclick_end - txt_pointclick
    +prtext 18,  7, LGREY,  txt_steam, txt_steam_end - txt_steam
    lda #0
    sta s3phase
    rts

s3_update:
    inc framectr
    lda framectr         ; bars scroll one step every 2nd frame
    and #1
    bne s3_hold
    inc s3phase
s3_hold:

    ; chase the beam: every 4th raster line from RAS_BARTOP down,
    ; set the BORDER color from the cyclic 64-entry bar table;
    ; the background stays black so the text remains readable
    lda #RAS_BARTOP
    sta s3line
    ldx #0               ; bar step counter
s3_bar:
    lda s3line
s3_wait:
    cmp RASTER
    bne s3_wait
    txa
    clc
    adc s3phase
    and #63
    tay
    lda rastbl,y
    sta BORDER
    lda s3line
    clc
    adc #4
    sta s3line
    inx
    cpx #BAR_STEPS
    bne s3_bar

    lda #BLACK           ; below the bar area: back to black
    sta BORDER

s3_wbot:                 ; keep the one-call-per-frame contract
    lda RASTER
    cmp #RAS_BOTTOM
    bne s3_wbot
    rts

; ============================================================
; slide 4: CONTACT
;   pulsing big title, contact lines below
; ============================================================
s4_init:
    jsr clear_screen
    +prbig   2,  6, WHITE,  big_contact, 7
    +prtext 10,  7, LGREEN, txt_web, txt_web_end - txt_web
    +prtext 13,  6, YELLOW, txt_bbs, txt_bbs_end - txt_bbs
    +prtext 16,  4, CYAN,   txt_irc, txt_irc_end - txt_irc
    rts

s4_update:
    lda RASTER
    cmp #RAS_BOTTOM
    bne s4_update

    inc framectr
    lda framectr         ; grey-white pulse on the big title rows (2-6)
    lsr
    lsr
    lsr
    and #7
    tay
    lda pulsetbl,y
    ldx #39
s4_loop:
    sta COLRAM + 2*40,x
    sta COLRAM + 3*40,x
    sta COLRAM + 4*40,x
    sta COLRAM + 5*40,x
    sta COLRAM + 6*40,x
    dex
    bpl s4_loop
    rts

; ============================================================
; slide 5: the assembly confession
; ============================================================
s5_init:
    jsr clear_screen
    +prtext  3, 11, WHITE, txt_conf1, txt_conf1_end - txt_conf1
    +prtext  7,  5, LGREY, txt_conf2, txt_conf2_end - txt_conf2
    +prtext  9,  4, LGREY, txt_conf3, txt_conf3_end - txt_conf3
    +prtext 12,  5, WHITE, txt_conf4, txt_conf4_end - txt_conf4
    +prtext 15,  5, LGREY, txt_conf5, txt_conf5_end - txt_conf5
    +prtext 17,  5, LGREY, txt_conf6, txt_conf6_end - txt_conf6
    +prtext 21, 11, CYAN,  txt_conf7, txt_conf7_end - txt_conf7
    rts

s5_update:
    lda RASTER
    cmp #RAS_BOTTOM
    bne s5_update

    inc framectr
    lda framectr         ; pulse on the "(the ai says hi.)" line
    lsr
    lsr
    lsr
    and #7
    tay
    lda pulsetbl,y
    ldx #txt_conf7_end - txt_conf7 - 1
s5_loop:
    sta COLRAM + 21*40 + 11,x
    dex
    bpl s5_loop
    rts

; ---- data ----

; slide table: init vector, update vector, duration in frames
slide_init_lo:
    !byte <s1_init, <s2_init, <s3_init, <s4_init, <s5_init
slide_init_hi:
    !byte >s1_init, >s2_init, >s3_init, >s4_init, >s5_init
slide_upd_lo:
    !byte <s1_update, <s2_update, <s3_update, <s4_update, <s5_update
slide_upd_hi:
    !byte >s1_update, >s2_update, >s3_update, >s4_update, >s5_update
slide_dur_lo:
    !byte <SLIDE_TIME, <SLIDE_TIME, <SLIDE_TIME, <SLIDE_TIME, <SLIDE_TIME
slide_dur_hi:
    !byte >SLIDE_TIME, >SLIDE_TIME, >SLIDE_TIME, >SLIDE_TIME, >SLIDE_TIME

; row * 40 lookup tables (25 rows)
mul40lo:
    !byte $00, $28, $50, $78, $a0, $c8, $f0, $18, $40, $68
    !byte $90, $b8, $e0, $08, $30, $58, $80, $a8, $d0, $f8
    !byte $20, $48, $70, $98, $c0
mul40hi:
    !byte $00, $00, $00, $00, $00, $00, $00, $01, $01, $01
    !byte $01, $01, $01, $02, $02, $02, $02, $02, $02, $02
    !byte $03, $03, $03, $03, $03

; 8x8 bitmaps of the giant letters (one byte per row, MSB = left pixel)
bigfont:
    ; T
    !byte $ff, $ff, $3c, $3c, $3c, $3c, $3c, $3c
    ; T
    !byte $ff, $ff, $3c, $3c, $3c, $3c, $3c, $3c
    ; G
    !byte $7e, $c3, $c0, $c0, $cf, $c3, $c3, $7e

letter_off:              ; column offset of each letter (8 wide + 2 gap)
    !byte 0, 10, 20

; 3x5 block font for the big slide titles (5 bytes per glyph,
; low 3 bits used, MSB side = left)
bigglyphs:
    !byte 0, 0, 0, 0, 0          ;  0 space
    !byte 2, 5, 7, 5, 5          ;  1 A
    !byte 3, 4, 4, 4, 3          ;  2 C
    !byte 6, 5, 5, 5, 6          ;  3 D
    !byte 7, 4, 6, 4, 7          ;  4 E
    !byte 7, 4, 6, 4, 4          ;  5 F
    !byte 7, 2, 2, 2, 7          ;  6 I
    !byte 4, 4, 4, 4, 7          ;  7 L
    !byte 5, 7, 7, 5, 5          ;  8 M
    !byte 6, 5, 5, 5, 5          ;  9 N
    !byte 7, 5, 5, 5, 7          ; 10 O
    !byte 6, 5, 6, 4, 4          ; 11 P
    !byte 6, 5, 6, 5, 5          ; 12 R
    !byte 3, 4, 2, 1, 6          ; 13 S
    !byte 7, 2, 2, 2, 2          ; 14 T
    !byte 5, 5, 2, 2, 2          ; 15 Y
    !byte 3, 4, 5, 5, 7          ; 16 G

bigmap:                  ; screen code (a=1..z=26) -> glyph index
    !byte  0             ; (unused)
    !byte  1,  0,  2,  3,  4,  5, 16,  0,  6,  0   ; a-j
    !byte  0,  7,  8,  9, 10, 11,  0, 12, 13, 14   ; k-t
    !byte  0,  0,  0,  0, 15,  0                   ; u-z

washtbl:                 ; gold glow ramp (16 entries, cyclic)
    !byte $09, $02, $08, $0a, $07, $07, $01, $01
    !byte $01, $01, $07, $07, $0a, $08, $02, $09

pulsetbl:                ; grey-white pulse (8 entries, cyclic)
    !byte $0b, $0c, $0f, $01, $01, $0f, $0c, $0b

fadetbl:                 ; fade-to-black: each color -> one shade darker,
                         ;   every chain reaches black in at most 4 steps
                         ;   (e.g. white -> lgrey -> mgrey -> dgrey -> black)
    ;      blk  wht  red  cyn  pur  grn  blu  yel
    !byte $00, $0f, $09, $0e, $06, $0b, $00, $08
    ;      org  brn  lrd  dgr  mgr  lgn  lbl  lgr
    !byte $02, $00, $02, $00, $0b, $05, $06, $0c

rastbl:                  ; raster bar colors (64 entries, cyclic):
                         ;   red, green, blue, grey ramps
    !byte $00, $00, $02, $02, $08, $08, $0a, $01
    !byte $0a, $08, $08, $02, $02, $00, $00, $00
    !byte $00, $00, $05, $05, $0d, $0d, $07, $01
    !byte $07, $0d, $0d, $05, $05, $00, $00, $00
    !byte $00, $00, $06, $06, $0e, $0e, $03, $01
    !byte $03, $0e, $0e, $06, $06, $00, $00, $00
    !byte $00, $00, $0b, $0b, $0c, $0c, $0f, $01
    !byte $0f, $0c, $0c, $0b, $0b, $00, $00, $00

; texts in screen codes (!scr); lowercase source shows as uppercase on C64

; slide 1
txt_title:
    !scr "teletype games"
txt_title_end:
txt_www:
    !scr "www.teletypegames.org"
txt_www_end:
txt_city:
    !scr "szeged, 2026"
txt_city_end:
scrolltext:
    !scr "mr.zero - tasnadi zsolt / mr.one - tari balazs / "
    !scr "mr.two - timar zoltan / mr.three - mezo bela / "
scrolltext_end:

; slide 2
txt_firstgame:
    !scr "our first game"
txt_firstgame_end:
big_definitely:
    !scr "definitely"
big_notan:
    !scr "not an"
big_impostor:
    !scr "impostor"
txt_tic80:
    !scr "introduced on tic-80"
txt_tic80_end:

; slide 3
txt_secondgame:
    !scr "our second game"
txt_secondgame_end:
big_iscoming:
    !scr "is coming"
txt_pointclick:
    !scr "a new point and click adventure"
txt_pointclick_end:
txt_steam:
    !scr "will be available on steam"
txt_steam_end:

; slide 4
big_contact:
    !scr "contact"
txt_web:
    !scr "web: www.teletypegames.org"
txt_web_end:
txt_bbs:
    !scr "bbs: teletypegames.org 2323"
txt_bbs_end:
txt_irc:
    !scr "irc: libera.chat #teletypegames"
txt_irc_end:

; slide 5
txt_conf1:
    !scr "a quick confession"
txt_conf1_end:
txt_conf2:
    !scr "we speak c, c++, python, java,"
txt_conf2_end:
txt_conf3:
    !scr "php, javascript and even pascal."
txt_conf3_end:
txt_conf4:
    !scr "but 6502 assembly? not a word."
txt_conf4_end:
txt_conf5:
    !scr "so this slideshow was written"
txt_conf5_end:
txt_conf6:
    !scr "with a little help from an ai."
txt_conf6_end:
txt_conf7:
    !scr "(the ai says hi.)"
txt_conf7_end:

; ---- variables ----
letter:    !byte 0
rowcount:  !byte 0
curbits:   !byte 0
framectr:  !byte 0
xscroll:   !byte 0
washphase: !byte 0
scrollidx: !byte 0
slide:     !byte 0       ; current slide index
durlo:     !byte 0       ; frames left on this slide (16 bit)
durhi:     !byte 0
s3phase:   !byte 0       ; raster bar scroll offset
s3line:    !byte 0       ; current raster line while drawing bars
prow:      !byte 0       ; print_text: row, column, color, length
pcol:      !byte 0
pcolor:    !byte 0
plen:      !byte 0
bigrow:    !byte 0       ; draw_big: row, column, color, length
bigcol:    !byte 0
bigcolor:  !byte 0
biglen:    !byte 0
bigi:      !byte 0       ; draw_big internals
glyphbase: !byte 0
charx:     !byte 0
rowidx:    !byte 0
bitcnt:    !byte 0
fadecnt:   !byte 0       ; fade step counter
bmcnt:     !byte 0       ; build_map inner counter
curmap:    !fill 16, 0   ; current fade-in color map
