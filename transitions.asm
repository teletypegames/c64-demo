; -----------------------------------------------------------
; transitions.asm - slide transitions
;   every slide is drawn with the display switched off, its
;   colors are snapshotted into FADEBUF and blackened, then an
;   in-transition reveals it; an out-transition hides it again.
;   types (picked per slide in tin_tbl/tout_tbl in main.asm):
;     TR_FADE     - fade through black via the fadetbl ramps
;     TR_DISSOLVE - cells appear/vanish in random (LFSR) order
;     TR_WIPE     - column sweep from left to right
;   each reveal starts with a short grey border flash
; -----------------------------------------------------------

; ---- draw the current slide while the display is switched off
; (everything shows border color = black), snapshot its colors,
; blacken them, switch the display back on, flash, transition in ----
show_slide:
    lda #$0b             ; display off
    sta SCRCTRL
    jsr slide_setup
    jsr snapshot_colram
    lda #$1b             ; display on
    sta SCRCTRL

    ldx #0               ; short white-to-grey border flash: gives
ssf_loop:                ;   the reveal a beat
    lda flashtbl,x
    sta BORDER
    jsr wait_frame
    inx
    cpx #3
    bne ssf_loop
    lda #BLACK
    sta BORDER

    ldx slide            ; dispatch the slide's in-transition
    ldy tin_tbl,x
    lda tin_lo,y
    sta vec
    lda tin_hi,y
    sta vec+1
    jmp (vec)            ; the transition ends with rts

; ---- dispatch the slide's out-transition ----
trans_out:
    lda #0               ; sprites vanish with the slide
    sta SPR_EN
    ldx slide
    ldy tout_tbl,x
    lda tout_lo,y
    sta vec
    lda tout_hi,y
    sta vec+1
    jmp (vec)

tin_lo:
    !byte <fade_in, <dissolve_in, <wipe_in
tin_hi:
    !byte >fade_in, >dissolve_in, >wipe_in
tout_lo:
    !byte <fade_out, <dissolve_out, <wipe_out
tout_hi:
    !byte >fade_out, >dissolve_out, >wipe_out

flashtbl:
    !byte WHITE, LGREY, DGREY

; ============================================================
; TR_FADE - fade through black
; ============================================================

; ---- fade in: fadecnt counts how many times the target color is
; darkened; counting 4 -> 0 walks each cell from black back
; up to its snapshot color ----
fade_in:
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

; ============================================================
; TR_DISSOLVE - cells appear/vanish in random order
;   a 10-bit LFSR walks all indexes 1..1023 exactly once per
;   period; indexes >= 1000 are skipped, cell 0 (which the LFSR
;   never yields) is handled up front. 25 cells per frame ->
;   the full screen takes 40 frames (0.8 s).
; ============================================================

dissolve_in:
    lda FADEBUF          ; cell 0 first
    sta COLRAM
    lda #40
    sta frcnt
din_frame:
    jsr wait_frame
    lda #25
    sta cellcnt
din_cell:
    jsr lfsr_next        ; -> lfsrlo/hi = cell index 1..999
    lda lfsrlo
    sta scrlo
    sta collo
    lda lfsrhi
    clc
    adc #>FADEBUF
    sta scrhi
    lda lfsrhi
    clc
    adc #>COLRAM
    sta colhi
    ldy #0
    lda (scrlo),y        ; restore the snapshot color
    sta (collo),y
    dec cellcnt
    bne din_cell
    dec frcnt
    bne din_frame
    rts

dissolve_out:
    lda #BLACK           ; cell 0 first
    sta COLRAM
    lda #40
    sta frcnt
dot_frame:
    jsr wait_frame
    lda #25
    sta cellcnt
dot_cell:
    jsr lfsr_next
    lda lfsrlo
    sta collo
    lda lfsrhi
    clc
    adc #>COLRAM
    sta colhi
    ldy #0
    lda #BLACK
    sta (collo),y
    dec cellcnt
    bne dot_cell
    dec frcnt
    bne dot_frame
    rts

; ---- 10-bit Galois LFSR (x^10 + x^7 + 1, period 1023) ----
; steps until the state is a valid cell index (< 1000); the
; state is never reset, coverage holds from any starting point
lfsr_next:
    lsr lfsrhi
    ror lfsrlo
    bcc ln_notap
    lda lfsrhi
    eor #$02
    sta lfsrhi
    lda lfsrlo
    eor #$40
    sta lfsrlo
ln_notap:
    lda lfsrhi           ; skip 1000..1023 ($03e8..$03ff)
    cmp #$03
    bcc ln_ok
    lda lfsrlo
    cmp #$e8
    bcs lfsr_next
ln_ok:
    rts

; ============================================================
; TR_WIPE - column sweep, one column per frame, left to right
; ============================================================

wipe_in:
    lda #0
    sta wcol
wi_col:
    jsr wait_frame
    ldx #24
wi_row:
    lda mul40lo,x
    sta scrlo
    sta collo
    lda mul40hi,x
    clc
    adc #>FADEBUF
    sta scrhi
    lda mul40hi,x
    clc
    adc #>COLRAM
    sta colhi
    ldy wcol
    lda (scrlo),y        ; restore the snapshot color
    sta (collo),y
    dex
    bpl wi_row
    inc wcol
    lda wcol
    cmp #40
    bne wi_col
    rts

wipe_out:
    lda #0
    sta wcol
wo_col:
    jsr wait_frame
    ldx #24
wo_row:
    lda mul40lo,x
    sta collo
    lda mul40hi,x
    clc
    adc #>COLRAM
    sta colhi
    ldy wcol
    lda #BLACK
    sta (collo),y
    dex
    bpl wo_row
    inc wcol
    lda wcol
    cmp #40
    bne wo_col
    rts

; ============================================================
; shared helpers
; ============================================================

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

; ---- variables ----
fadecnt:   !byte 0       ; fade step counter
bmcnt:     !byte 0       ; build_map inner counter
curmap:    !fill 16, 0   ; current fade-in color map
lfsrlo:    !byte $37     ; LFSR state (any nonzero seed)
lfsrhi:    !byte $01
cellcnt:   !byte 0       ; dissolve: cells left this frame
frcnt:     !byte 0       ; dissolve: frames left
wcol:      !byte 0       ; wipe: current column
