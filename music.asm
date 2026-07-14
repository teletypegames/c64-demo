; -----------------------------------------------------------
; music.asm - SID music driver skeleton
;   called once per frame from wait_frame
;   music_init: clear SID registers
;   music_play: placeholder (currently silent)
;   music_mute / music_unmute: volume control
;
;   To add music: replace music_play with a real SID player
;   routine (e.g. GoatTracker export), or write patterns into
;   this file using the SID register definitions below.
; -----------------------------------------------------------

; ---- SID registers ----
SID_BASE = $d400

SID_V1_FL = SID_BASE+0          ; voice 1 frequency low
SID_V1_FH = SID_BASE+1          ; voice 1 frequency high
SID_V1_PL = SID_BASE+2          ; voice 1 pulse width low
SID_V1_PH = SID_BASE+3          ; voice 1 pulse width high
SID_V1_CR = SID_BASE+4          ; voice 1 control (gate, waveform)
SID_V1_AD = SID_BASE+5          ; voice 1 attack/decay
SID_V1_SR = SID_BASE+6          ; voice 1 sustain/release

SID_V2_FL = SID_BASE+7          ; voice 2 frequency low
SID_V2_FH = SID_BASE+8          ; voice 2 frequency high
SID_V2_PL = SID_BASE+9          ; voice 2 pulse width low
SID_V2_PH = SID_BASE+10         ; voice 2 pulse width high
SID_V2_CR = SID_BASE+11         ; voice 2 control
SID_V2_AD = SID_BASE+12         ; voice 2 attack/decay
SID_V2_SR = SID_BASE+13         ; voice 2 sustain/release

SID_V3_FL = SID_BASE+14         ; voice 3 frequency low
SID_V3_FH = SID_BASE+15         ; voice 3 frequency high
SID_V3_PL = SID_BASE+16         ; voice 3 pulse width low
SID_V3_PH = SID_BASE+17         ; voice 3 pulse width high
SID_V3_CR = SID_BASE+18         ; voice 3 control
SID_V3_AD = SID_BASE+19         ; voice 3 attack/decay
SID_V3_SR = SID_BASE+20         ; voice 3 sustain/release

SID_FC_LO = SID_BASE+21         ; filter cutoff low (bits 0-2)
SID_FC_HI = SID_BASE+22         ; filter cutoff high
SID_FCTL  = SID_BASE+23         ; filter resonance + voice routing
SID_VOL   = SID_BASE+24         ; filter mode (hi nibble) + master volume (lo nibble)

; ---- initialize SID ----
music_init:
    ldx #24
    lda #0
mi_clr:
    sta SID_BASE,x
    dex
    bpl mi_clr

    lda #$0f                    ; master volume = 15
    sta SID_VOL

    lda #0
    sta mus_muted
    rts

; ---- play one tick: called once per frame ----
; Replace this with a real music player routine.
music_play:
    lda mus_muted
    bne mp_silent
    ; --- insert SID player call here ---
mp_silent:
    rts

; ---- mute: silence SID ----
music_mute:
    lda #$00
    sta SID_VOL
    rts

; ---- unmute: restore volume ----
music_unmute:
    lda #$0f
    sta SID_VOL
    rts

; ---- state ----
mus_muted:     !byte 0          ; 1 = muted
