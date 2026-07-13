; -----------------------------------------------------------
; slide5.asm - the assembly confession
;   the body is typed in live, one character per frame, with a
;   white block cursor; the closing line appears when the
;   typing is done and pulses
; -----------------------------------------------------------

s5_init:
    jsr clear_screen
    +prtext  3, 11, WHITE, txt_conf1, txt_conf1_end - txt_conf1
    lda #0               ; the body starts empty and gets typed in
    sta t_line
    sta t_chr
    sta t_done
    rts

s5_update:
    lda RASTER
    cmp #RAS_BOTTOM
    bne s5_update

    inc framectr
    lda t_done
    beq s5_type

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

; ---- type one character per frame ----
s5_type:
    ldx t_line
    ldy t_row,x          ; screen/color pointers to the line start
    lda mul40lo,y
    clc
    adc #3               ; body column
    sta scrlo
    sta collo
    lda mul40hi,y
    adc #>SCREEN         ; carry still clear (row starts stay low)
    sta scrhi
    clc
    adc #$d4
    sta colhi
    lda t_txtlo,x
    sta txtlo
    lda t_txthi,x
    sta txthi

    ldy t_chr
    lda (txtlo),y        ; the character lands where the cursor was
    sta (scrlo),y
    lda t_color,x
    sta (collo),y
    iny
    cpy #34              ; all body lines are exactly 34 chars
    beq s5_nextline
    sty t_chr
    lda #$a0             ; block cursor at the next cell
    sta (scrlo),y
    lda #WHITE
    sta (collo),y
    rts

s5_nextline:
    lda #0
    sta t_chr
    inc t_line
    lda t_line
    cmp #5
    bne s5_ret
    ; typing done: the closing line appears and starts pulsing
    +prtext 21, 11, CYAN, txt_conf7, txt_conf7_end - txt_conf7
    lda #1
    sta t_done
s5_ret:
    rts

; ---- data ----
txt_conf1:
    !scr "a quick confession"
txt_conf1_end:
; body lines are justified: extra spaces pad each line to
; exactly 34 chars, so both edges line up at columns 3 and 36
txt_conf2:
    !scr "we speak c/c++, lua, python, java,"
txt_conf3:
    !scr "go,   ruby,  js,  elixir,  pascal."
txt_conf4:
    !scr "but  6502  assembly?  not  a word."
txt_conf5:
    !scr "so   this  slideshow  was  written"
txt_conf6:
    !scr "with  a  little  help  from an ai."
txt_conf7:
    !scr "(the ai says hi.)"
txt_conf7_end:

t_row:                   ; body line rows
    !byte 7, 9, 12, 15, 17
t_color:
    !byte LGREY, LGREY, WHITE, LGREY, LGREY
t_txtlo:
    !byte <txt_conf2, <txt_conf3, <txt_conf4, <txt_conf5, <txt_conf6
t_txthi:
    !byte >txt_conf2, >txt_conf3, >txt_conf4, >txt_conf5, >txt_conf6

; ---- variables ----
t_line:    !byte 0       ; body line being typed (0-4)
t_chr:     !byte 0       ; next character within the line
t_done:    !byte 0       ; 1 = typing finished, closing line pulses
