; -----------------------------------------------------------
; music.asm - SID music driver
;   called once per frame from wait_frame
;   music_init: clear SID, set instruments, restart the song
;   music_play: pattern player tick (once per frame)
;   music_mute / music_unmute: volume control
;
;   The tune is track 0 ("room work") of the Impostor TIC-80
;   cart, converted from inc/meta/meta.assets.lua:
;     voice 1: bass line (sfx 59, soft sine -> SID triangle)
;     voice 2: drums (sfx 61, TIC-80 noise -> SID noise,
;              C-1 = kick, C-4 = snare)
;   Original timing: tempo 150, speed 5 = 12 rows/s at 60 Hz.
;   On PAL (50 Hz) that is 25 frames per 6 rows, so every
;   sixth row lasts 5 frames instead of 4 (see spd_tbl).
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

; ---- waveform control values ----
BASS_ON   = $11                 ; triangle + gate
BASS_OFF  = $10
DRUM_ON   = $81                 ; noise + gate
DRUM_OFF  = $80

SONG_LEN  = 128                 ; 2 frames x 64 rows

; ---- initialize SID and restart the song ----
music_init:
    ldx #24
    lda #0
mi_clr:
    sta SID_BASE,x
    dex
    bpl mi_clr

    lda #$00                    ; bass: instant attack, full sustain
    sta SID_V1_AD
    lda #$f4
    sta SID_V1_SR
    lda #$05                    ; drums: instant attack, ~170 ms decay
    sta SID_V2_AD
    lda #$00
    sta SID_V2_SR

    lda #$0f                    ; master volume = 15
    sta SID_VOL

    lda #0
    sta mus_muted
    sta mus_row
    sta mus_spd_ix
    lda #1                      ; first music_play tick starts row 0
    sta mus_tick
    rts

; ---- play one tick: called once per frame ----
music_play:
    lda mus_muted
    bne mp_done                 ; muted: song position frozen too
    dec mus_tick
    beq mp_row
mp_done:
    rts

mp_row:
    ldx mus_spd_ix              ; reload row length (4,4,4,4,4,5 frames)
    lda spd_tbl,x
    sta mus_tick
    inx
    cpx #6
    bne mp_spd_ok
    ldx #0
mp_spd_ok:
    stx mus_spd_ix

    ldx mus_row

    ; ---- voice 1: bass ----
    lda bass_pat,x
    beq mp_drums                ; 0 = no event
    cmp #1
    bne mp_bass_note
    lda #BASS_OFF               ; 1 = key off
    sta SID_V1_CR
    jmp mp_drums
mp_bass_note:
    and #$7f                    ; $80|n = trigger note n
    tay
    lda bass_flo,y
    sta SID_V1_FL
    lda bass_fhi,y
    sta SID_V1_FH
    lda #BASS_OFF               ; gate off + on restarts the envelope
    sta SID_V1_CR
    lda #BASS_ON
    sta SID_V1_CR

    ; ---- voice 2: drums ----
mp_drums:
    lda drum_pat,x
    beq mp_next
    cmp #1
    bne mp_drum_note
    lda #DRUM_OFF
    sta SID_V2_CR
    jmp mp_next
mp_drum_note:
    and #$7f
    tay
    lda drum_flo,y
    sta SID_V2_FL
    lda drum_fhi,y
    sta SID_V2_FH
    lda #DRUM_OFF
    sta SID_V2_CR
    lda #DRUM_ON
    sta SID_V2_CR

mp_next:
    inx
    cpx #SONG_LEN
    bne mp_store
    ldx #0                      ; loop the song
    stx mus_spd_ix              ; restart the 4,4,4,4,4,5 cycle with it
mp_store:
    stx mus_row
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
mus_row:       !byte 0          ; song position (0..SONG_LEN-1)
mus_tick:      !byte 1          ; frames left of the current row
mus_spd_ix:    !byte 0          ; index into spd_tbl

spd_tbl:       !byte 4,4,4,4,4,5    ; 25 frames / 6 rows = 12 rows/s

; ---- note tables (PAL SID: reg = Hz * 16777216 / 985248) ----
; bass: 0 = C-2, 1 = A#1, 2 = D#2, 3 = F-2
bass_flo: !byte $5a,$e0,$2d,$cf
bass_fhi: !byte $04,$03,$05,$05
; drums: noise pitch from the TIC-80 note (x32 waveform steps)
;        0 = C-1 kick (low rumble), 1 = C-4 snare (bright)
drum_flo: !byte $9c,$ff
drum_fhi: !byte $45,$ff

; ---- pattern data: one byte per row per voice ----
;   $00 = nothing, $01 = key off, $80|n = play note n
bass_pat:
    !byte $80,$00,$00,$00,$01,$00,$80,$00,$01,$00,$00,$00,$81,$00,$80,$00
    !byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    !byte $80,$00,$00,$00,$01,$00,$80,$00,$01,$00,$00,$00,$81,$00,$80,$00
    !byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    !byte $80,$00,$00,$00,$01,$00,$80,$00,$01,$00,$00,$00,$81,$00,$80,$00
    !byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    !byte $82,$00,$82,$00,$01,$00,$82,$00,$01,$00,$00,$00,$82,$00,$83,$00
    !byte $01,$00,$83,$00,$01,$00,$83,$00,$83,$00,$01,$00,$83,$00,$01,$00
drum_pat:
    !byte $80,$00,$00,$00,$00,$00,$00,$00,$81,$00,$00,$00,$00,$00,$00,$00
    !byte $80,$00,$00,$00,$00,$00,$80,$00,$81,$00,$00,$00,$00,$00,$00,$00
    !byte $80,$00,$00,$00,$00,$00,$00,$00,$81,$00,$00,$00,$00,$00,$00,$00
    !byte $80,$00,$00,$00,$00,$00,$80,$00,$81,$00,$00,$00,$00,$00,$00,$00
    !byte $80,$00,$00,$00,$00,$00,$00,$00,$81,$00,$00,$00,$00,$00,$00,$00
    !byte $80,$00,$00,$00,$00,$00,$80,$00,$81,$00,$00,$00,$00,$00,$00,$00
    !byte $80,$00,$00,$00,$00,$00,$00,$00,$81,$00,$00,$00,$00,$00,$00,$00
    !byte $80,$00,$00,$00,$00,$00,$80,$00,$81,$00,$00,$00,$00,$00,$00,$00
