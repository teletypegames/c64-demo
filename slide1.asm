; -----------------------------------------------------------
; slide1.asm - giant TTG logo + credits scroller
;   effects: gold wash on the logo, smooth pixel scroll,
;   pulsing title
; -----------------------------------------------------------

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
xscroll:   !byte 0
scrollidx: !byte 0
