; -----------------------------------------------------------
; slide5.asm - the assembly confession
; -----------------------------------------------------------

s5_init:
    jsr clear_screen
    +prtext  3, 11, WHITE, txt_conf1, txt_conf1_end - txt_conf1
    +prtext  7,  3, LGREY, txt_conf2, txt_conf2_end - txt_conf2
    +prtext  9,  3, LGREY, txt_conf3, txt_conf3_end - txt_conf3
    +prtext 12,  3, WHITE, txt_conf4, txt_conf4_end - txt_conf4
    +prtext 15,  3, LGREY, txt_conf5, txt_conf5_end - txt_conf5
    +prtext 17,  3, LGREY, txt_conf6, txt_conf6_end - txt_conf6
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
txt_conf1:
    !scr "a quick confession"
txt_conf1_end:
; body lines are justified: extra spaces pad each line to
; exactly 34 chars, so both edges line up at columns 3 and 36
txt_conf2:
    !scr "we speak c/c++, lua, python, java,"
txt_conf2_end:
txt_conf3:
    !scr "go,   ruby,  js,  elixir,  pascal."
txt_conf3_end:
txt_conf4:
    !scr "but  6502  assembly?  not  a word."
txt_conf4_end:
txt_conf5:
    !scr "so   this  slideshow  was  written"
txt_conf5_end:
txt_conf6:
    !scr "with  a  little  help  from an ai."
txt_conf6_end:
txt_conf7:
    !scr "(the ai says hi.)"
txt_conf7_end:
