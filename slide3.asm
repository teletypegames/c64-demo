; -----------------------------------------------------------
; slide3.asm - OUR SECOND GAME: IS COMING
;   raster bars on the border that also bleed into the empty
;   top and bottom of the screen; the middle stays black, so
;   the drop-shadowed big letters remain readable
; -----------------------------------------------------------

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
    ; above line 74 and from line 210 the screen rows are empty,
    ; there the bars run on the background too - in the middle
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
    ldy s3line
    cpy #74              ; top zone: bar color on the background too
    bcc s3_bg
    cpy #210             ; bottom zone likewise
    bcs s3_bg
    sta BORDER           ; middle: border only, background back to
    lda #BLACK           ;   black (the top zone left its last color)
    sta BG
    jmp s3_step
s3_bg:
    sta BG
    sta BORDER
s3_step:
    lda s3line
    clc
    adc #4
    sta s3line
    inx
    cpx #BAR_STEPS
    bne s3_bar

    lda #BLACK           ; below the bar area: back to black
    sta BORDER
    sta BG

s3_wbot:                 ; keep the one-call-per-frame contract
    lda RASTER
    cmp #RAS_BOTTOM
    bne s3_wbot
    rts

; ---- data ----
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

; ---- variables ----
s3phase:   !byte 0       ; raster bar scroll offset
s3line:    !byte 0       ; current raster line while drawing bars
