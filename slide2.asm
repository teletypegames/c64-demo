; -----------------------------------------------------------
; slide2.asm - OUR FIRST GAME: Definitely not an Impostor
;   big block letters with the gold wash running across them
; -----------------------------------------------------------

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

; ---- data ----
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
