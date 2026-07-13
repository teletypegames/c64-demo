; -----------------------------------------------------------
; main.asm - C64 demo: giant TTG logo + credits scroller
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
BORDER  = $d020          ; border color register
BG      = $d021          ; background color register
RASTER  = $d012          ; current raster line
SCREEN  = $0400          ; screen RAM (40x25 chars)
COLRAM  = $d800          ; color RAM

; ---- colors ----
BLACK   = 0
WHITE   = 1
CYAN    = 3
YELLOW  = 7
LGREEN  = 13
LGREY   = 15

; ---- screen layout ----
BIGROW      = 2                  ; top row of the giant letters
BIGCOL      = 6                  ; left column (3*8 + 2*2 = 28 wide, centered)
TITLE_POS   = 12*40 + 13         ; "TELETYPE GAMES" (14 chars, centered)
SCROLLROW   = 14                 ; scroller row
WWW_POS     = 17*40 + 9          ; "WWW.TELETYPEGAMES.ORG" (21 chars)
CITY_POS    = 19*40 + 14         ; "SZEGED, 2026" (12 chars)
SCROLL_SPEED = 4                 ; frames per scroll step

; ---- zero page pointers ----
scrlo = $fb
scrhi = $fc
collo = $fd
colhi = $fe

start:
    lda #BLACK
    sta BORDER
    sta BG

    ; clear screen RAM, fill color RAM with white
    ldx #0
clear_loop:
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
    bne clear_loop

; ---- draw the giant TTG letters from 8x8 bitmaps ----
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

; ---- static texts ----
    ldx #0
title_loop:
    lda txt_title,x
    sta SCREEN+TITLE_POS,x
    lda #WHITE
    sta COLRAM+TITLE_POS,x
    inx
    cpx #txt_title_end - txt_title
    bne title_loop

    ldx #0
www_loop:
    lda txt_www,x
    sta SCREEN+WWW_POS,x
    lda #LGREEN
    sta COLRAM+WWW_POS,x
    inx
    cpx #txt_www_end - txt_www
    bne www_loop

    ldx #0
city_loop:
    lda txt_city,x
    sta SCREEN+CITY_POS,x
    lda #LGREY
    sta COLRAM+CITY_POS,x
    inx
    cpx #txt_city_end - txt_city
    bne city_loop

    ; scroller row color
    ldx #39
    lda #CYAN
scrollcol_loop:
    sta COLRAM+SCROLLROW*40,x
    dex
    bpl scrollcol_loop

    lda #SCROLL_SPEED
    sta framecnt
    lda #0
    sta scrollidx

; ---- main loop: scroll the credits line ----
main:
wait_raster:             ; wait for raster line $fe (bottom of screen)
    lda RASTER
    cmp #$fe
    bne wait_raster
wait_raster2:            ; ...and wait until it passes -> exactly one frame
    lda RASTER
    cmp #$fe
    beq wait_raster2

    dec framecnt
    bne main
    lda #SCROLL_SPEED
    sta framecnt

    ; shift scroller row one char to the left
    ldx #0
shift_loop:
    lda SCREEN+SCROLLROW*40+1,x
    sta SCREEN+SCROLLROW*40,x
    inx
    cpx #39
    bne shift_loop

    ; fetch next char of the scrolltext into the rightmost column
    ldx scrollidx
    lda scrolltext,x
    sta SCREEN+SCROLLROW*40+39
    inx
    cpx #scrolltext_end - scrolltext
    bne no_wrap
    ldx #0
no_wrap:
    stx scrollidx
    jmp main

; ---- data ----

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

; texts in screen codes (!scr); lowercase source shows as uppercase on C64
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

; ---- variables ----
letter:    !byte 0
rowcount:  !byte 0
curbits:   !byte 0
framecnt:  !byte 0
scrollidx: !byte 0
