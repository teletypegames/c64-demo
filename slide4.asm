; -----------------------------------------------------------
; slide4.asm - CONTACT
;   pulsing big title, contact lines below
; -----------------------------------------------------------

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

; ---- data ----
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
