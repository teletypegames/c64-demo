; -----------------------------------------------------------
; slide4.asm - CONTACT
;   pulsing big title, contact lines, three-layer starfield
;   drifting left, six star sprites floating on sine paths
;   behind the text
; -----------------------------------------------------------

s4_init:
    jsr clear_screen
    +prbig   2,  6, WHITE,  big_contact, 7
    +prtext 10,  7, LGREEN, txt_web, txt_web_end - txt_web
    +prtext 13,  6, YELLOW, txt_bbs, txt_bbs_end - txt_bbs
    +prtext 16,  4, CYAN,   txt_irc, txt_irc_end - txt_irc

    ; starfield: draw the stars at their current positions so
    ; the in-transition reveals them together with the text
    ldx #11
s4i_star:
    jsr star_ptr
    ldy star_x,x
    lda #$2e             ; '.'
    sta (scrlo),y
    lda star_col,x
    sta (collo),y
    dex
    bpl s4i_star

    ; sprites: same star shape on all six, floating behind the
    ; characters; enabled by the update, so they pop in only
    ; after the slide's in-transition is done
    lda #(sprdata >> 6)
    ldx #5
s4i_ptr:
    sta SCREEN+$3f8,x
    dex
    bpl s4i_ptr
    ldx #5
s4i_col:
    lda sprcols,x
    sta SPR_COL,x
    dex
    bpl s4i_col
    lda #0
    sta SPR_MC
    sta SPR_XEX
    sta SPR_YEX
    lda #%00111111
    sta SPR_PRIO         ; behind the text
    lda #%00100000       ; sprite 5 lives right of x=255
    sta SPR_MSBX
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

    ; starfield: three layers, each layer steps left on its own
    ; frame mask (fast/mid/slow parallax)
    ldx #11
s4u_star:
    lda framectr
    and star_mask,x
    bne s4u_next
    jsr star_ptr
    ldy star_x,x
    lda #$20             ; erase at the old position
    sta (scrlo),y
    lda star_x,x         ; step left, wrap at the edge
    bne s4u_dec
    lda #40
    sta star_x,x
s4u_dec:
    dec star_x,x
    ldy star_x,x
    lda #$2e
    sta (scrlo),y
    lda star_col,x
    sta (collo),y
s4u_next:
    dex
    bpl s4u_star

    ; sprites: y from a sine table, x = base + slower sine wobble
    lda #%00111111
    sta SPR_EN
    ldx #5
s4u_spr:
    txa
    asl
    sta sprofs           ; register offset = sprite * 2
    lda framectr
    lsr
    clc
    adc spr_yph,x
    and #63
    tay
    lda ysin,y
    ldy sprofs
    sta SPRPOS+1,y
    lda framectr
    lsr
    lsr
    clc
    adc spr_xph,x
    and #63
    tay
    lda xwob,y
    clc
    adc spr_xbase,x
    ldy sprofs
    sta SPRPOS,y
    dex
    bpl s4u_spr
    rts

; ---- scrlo/hi + collo/hi = screen/color RAM row of star X ----
star_ptr:
    ldy star_row,x
    lda mul40lo,y
    sta scrlo
    sta collo
    lda mul40hi,y
    clc
    adc #>SCREEN
    sta scrhi
    clc
    adc #$d4             ; COLRAM - SCREEN high byte distance
    sta colhi
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

; starfield: rows avoid the title (2-6) and text (10, 13, 16) rows
star_row:
    !byte  0,  8, 11, 14, 17, 19,  1,  9, 12, 15, 21, 23
star_mask:               ; move on framectr & mask == 0
    !byte  1,  3,  7,  1,  3,  7,  1,  3,  7,  1,  3,  7
star_col:                ; fast = white, mid = lgrey, slow = dgrey
    !byte WHITE, LGREY, DGREY, WHITE, LGREY, DGREY
    !byte WHITE, LGREY, DGREY, WHITE, LGREY, DGREY

sprcols:
    !byte YELLOW, LBLUE, LGREEN, WHITE, ORANGE, CYAN
spr_xbase:               ; spread across the screen; sprite 5 gets
    !byte 40, 85, 130, 175, 220, 20   ;   +256 via SPR_MSBX
spr_yph:                 ; sine phase offsets per sprite
    !byte  0, 11, 21, 32, 43, 53
spr_xph:
    !byte  0, 26, 52, 13, 39,  7

ysin:                    ; 64-entry sine, 134 +/- 60 (sprite y)
    !byte $86, $8c, $92, $97, $9d, $a2, $a7, $ac
    !byte $b0, $b4, $b8, $bb, $bd, $bf, $c1, $c2
    !byte $c2, $c2, $c1, $bf, $bd, $bb, $b8, $b4
    !byte $b0, $ac, $a7, $a2, $9d, $97, $92, $8c
    !byte $86, $80, $7a, $75, $6f, $6a, $65, $60
    !byte $5c, $58, $54, $51, $4f, $4d, $4b, $4a
    !byte $4a, $4a, $4b, $4d, $4f, $51, $54, $58
    !byte $5c, $60, $65, $6a, $6f, $75, $7a, $80

xwob:                    ; 64-entry sine, 12 +/- 12 (x wobble)
    !byte $0c, $0d, $0e, $0f, $11, $12, $13, $14
    !byte $14, $15, $16, $17, $17, $17, $18, $18
    !byte $18, $18, $18, $17, $17, $17, $16, $15
    !byte $14, $14, $13, $12, $11, $0f, $0e, $0d
    !byte $0c, $0b, $0a, $09, $07, $06, $05, $04
    !byte $04, $03, $02, $01, $01, $01, $00, $00
    !byte $00, $00, $00, $01, $01, $01, $02, $03
    !byte $04, $04, $05, $06, $07, $09, $0a, $0b

; 24x21 four-pointed star sprite (must sit on a 64-byte boundary
; and below $4000, the top of the VIC's bank)
!align 63, 0
sprdata:
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $18, $00
    !byte $00, $18, $00
    !byte $00, $18, $00
    !byte $00, $3c, $00
    !byte $00, $3c, $00
    !byte $00, $7e, $00
    !byte $07, $ff, $e0
    !byte $00, $7e, $00
    !byte $00, $3c, $00
    !byte $00, $3c, $00
    !byte $00, $18, $00
    !byte $00, $18, $00
    !byte $00, $18, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00

; ---- variables ----
star_x:                  ; star columns (start scattered)
    !byte  3, 17, 29,  8, 35, 22, 13, 31,  5, 26, 19, 37
sprofs:    !byte 0       ; sprite register offset in the update loop
