; -----------------------------------------------------------
; main.asm - C64 demo: slide show (6 seconds per slide)
;   slide 1: giant TTG logo + credits scroller
;   slide 2: OUR FIRST GAME - Definitely not an Impostor
;   slide 3: OUR SECOND GAME IS COMING (border raster bars)
;   slide 4: CONTACT
;   slide 5: the assembly confession
;   slides cross-fade through black between switches
;   all timed by polling the raster beam
;
; Files:
;   defs.asm    - constants, zero page, macros
;   common.asm  - shared routines, tables, variables
;   slideN.asm  - one file per slide: sN_init, sN_update + data
;
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

!src "defs.asm"

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

    ; 'p' toggles pause - edge detected, so holding the key
    ; does not keep flipping the state
    jsr scan_p
    bne p_up
    lda pheld
    bne p_done
    lda #1
    sta pheld
    jsr toggle_pause
    jmp p_done
p_up:
    lda #0
    sta pheld
p_done:

    lda paused           ; paused: keep the marker in the top-right
    beq no_pdraw         ;   corner alive (slide switches clear it)
    lda #$10             ; screen code of 'p'
    sta SCREEN+39
    lda #WHITE
    sta COLRAM+39
no_pdraw:

    jsr scan_del         ; backspace: one slide back
    beq go_back

    jsr scan_space       ; space: next slide right away
    beq advance

    lda paused           ; paused: the countdown stands still
    bne main

    lda durlo            ; 16-bit frame countdown
    bne dur_dec
    dec durhi
dur_dec:
    dec durlo
    lda durlo
    ora durhi
    bne main

advance:
    jsr fade_out         ; fade the old slide to black
adv_release:
    jsr scan_space       ; a held space must not race through
    beq adv_release      ;   the whole show

    ldx slide            ; advance to the next slide
    inx
    cpx #NUM_SLIDES
    bne slide_ok
    ldx #0
slide_ok:
    stx slide
    jsr show_slide       ; draw it hidden, then fade it in
    jmp main

go_back:
    jsr fade_out
back_release:
    jsr scan_del
    beq back_release

    ldx slide            ; step back one slide, wrap to the last
    dex
    bpl back_ok
    ldx #NUM_SLIDES-1
back_ok:
    stx slide
    jsr show_slide
    jmp main

; ---- flip the pause state, remove the marker when resuming ----
toggle_pause:
    lda paused
    eor #1
    sta paused
    bne tp_done          ; turned on: the main loop draws the marker
    lda #$20             ; turned off: clear it
    sta SCREEN+39
tp_done:
    rts

; ---- keyboard matrix scanning ----
; in: A = column select mask, Y = row mask
; out: Z set if the key is held down (rows read active low)
scan_key:
    sta CIA1_PA
    tya
    and CIA1_PB
    rts

scan_space:              ; space: column 7, row 4
    lda #$7f
    ldy #$10
    jmp scan_key

scan_p:                  ; 'p': column 5, row 1
    lda #$df
    ldy #$02
    jmp scan_key

scan_del:                ; inst/del: column 0, row 0
    lda #$fe
    ldy #$01
    jmp scan_key

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

; ============================================================
; shared routines and the slides
; ============================================================
!src "common.asm"
!src "slide1.asm"
!src "slide2.asm"
!src "slide3.asm"
!src "slide4.asm"
!src "slide5.asm"

; ---- slide table: init vector, update vector, duration ----
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

; ---- variables ----
slide:     !byte 0       ; current slide index
durlo:     !byte 0       ; frames left on this slide (16 bit)
durhi:     !byte 0
fadecnt:   !byte 0       ; fade step counter
bmcnt:     !byte 0       ; build_map inner counter
curmap:    !fill 16, 0   ; current fade-in color map
paused:    !byte 0       ; 1 = slide countdown frozen
pheld:     !byte 0       ; 'p' key edge detection state
