; -----------------------------------------------------------
; main.asm - C64 demo: slide show (6 seconds per slide)
;   slide 1: giant TTG logo + credits scroller
;   slide 2: OUR FIRST GAME - Definitely not an Impostor
;   slide 3: OUR SECOND GAME IS COMING (border raster bars)
;   slide 4: CONTACT
;   slide 5: the assembly confession (typewriter)
;   slides transition through black between switches
;   (fade / random dissolve / column wipe, per slide)
;   all timed by polling the raster beam
;
; Files:
;   defs.asm        - constants, zero page, macros
;   transitions.asm - slide transitions: fade, dissolve, wipe
;   common.asm      - shared routines, tables, variables
;   slideN.asm      - one file per slide: sN_init, sN_update + data
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

    jsr music_init       ; set up SID and start the music

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

    jsr scan_m           ; 'm' toggles mute - edge detected
    bne m_up
    lda mheld
    bne m_done
    lda #1
    sta mheld
    jsr toggle_mute
    jmp m_done
m_up:
    lda #0
    sta mheld
m_done:

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
    jsr trans_out        ; hide the old slide (its out-transition)
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
    jsr trans_out
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

scan_m:                  ; 'm': column 4, row 4
    lda #$ef
    ldy #$10
    jmp scan_key

; ---- flip the mute state ----
toggle_mute:
    lda mus_muted
    eor #1
    sta mus_muted
    bne tm_off
    jsr music_unmute     ; was muted, now unmute
    rts
tm_off:
    jsr music_mute       ; was playing, now mute
    rts

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
    sta SPR_EN           ; a slide that wants sprites enables them itself
    jmp (vec)            ; init ends with rts -> returns to slide_setup's caller

; ============================================================
; transitions, shared routines and the slides
; ============================================================
!src "transitions.asm"
!src "common.asm"
!src "slide1.asm"
!src "slide2.asm"
!src "slide3.asm"
!src "slide4.asm"
!src "slide5.asm"
!src "music.asm"

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
    !byte <SLIDE_TIME, <SLIDE_TIME, <SLIDE_TIME, <SLIDE_TIME, <S5_TIME
slide_dur_hi:
    !byte >SLIDE_TIME, >SLIDE_TIME, >SLIDE_TIME, >SLIDE_TIME, >S5_TIME

; ---- per-slide transitions: reveal type / hide type ----
tin_tbl:
    !byte TR_FADE, TR_WIPE, TR_DISSOLVE, TR_FADE, TR_DISSOLVE
tout_tbl:
    !byte TR_DISSOLVE, TR_FADE, TR_WIPE, TR_DISSOLVE, TR_WIPE

; ---- variables ----
slide:     !byte 0       ; current slide index
durlo:     !byte 0       ; frames left on this slide (16 bit)
durhi:     !byte 0
paused:    !byte 0       ; 1 = slide countdown frozen
pheld:     !byte 0       ; 'p' key edge detection state
mheld:     !byte 0       ; 'm' key edge detection state
