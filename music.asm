; -----------------------------------------------------------
; music.asm - SID music driver
;   called once per frame from wait_frame
;   music_init: clear SID, set instruments, restart the song
;   music_play: pattern player tick (once per frame)
;   music_mute / music_unmute: volume control
;
;   The tune is track 0 ("room work") of the Impostor TIC-80
;   cart, converted from inc/meta/meta.assets.lua:
;     voice 1: bass line (sfx 59 -> SID 50% pulse; the original
;              is a soft sine, but pulse carries better here)
;     voice 2: drums (sfx 61, TIC-80 noise -> SID noise,
;              C-1 = kick, C-4 = snare)
;     voice 3: echo canon: repeats the bass melody 2 rows
;              (~170 ms) later, 3 octaves up, with the sfx 56
;              pluck timbre (triangle, decaying envelope);
;              repeated notes bounce up one more octave. The
;              echo data lives on the same 128-row grid as the
;              bass, so the two voices can never drift apart.
;   Original timing: tempo 150, speed 5 = 12 rows/s at 60 Hz.
;   On PAL (50 Hz) we run 4 frames/row = 12.5 rows/s, a touch
;   faster than the original on purpose (see spd_tbl).
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
BASS_ON   = $41                 ; pulse + gate (much louder than triangle,
BASS_OFF  = $40                 ;   so the bass stands out from the drums)
DRUM_ON   = $81                 ; noise + gate
DRUM_OFF  = $80
LEAD_ON   = $11                 ; triangle + gate (soft pluck, stays
LEAD_OFF  = $10                 ;   behind the bass and the drums)

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
    lda #$f3                    ; short release, so the tail does not
    sta SID_V1_SR               ;   fill the rests between the notes
    lda #$08                    ; bass pulse width: 50% square, the
    sta SID_V1_PH               ;   fattest setting ($0800 of $0fff)
    lda #$00
    sta SID_V1_PL
    lda #$04                    ; drums: instant attack, ~110 ms decay
    sta SID_V2_AD
    lda #$00
    sta SID_V2_SR
    lda #$06                    ; lead: pluck, ~200 ms decay to zero
    sta SID_V3_AD               ;   (matches the sfx 56 envelope)
    lda #$00
    sta SID_V3_SR

    lda #$0f                    ; master volume = 15
    sta SID_VOL

    lda #0
    sta mus_muted
    sta mus_row
    sta mus_spd_ix
    sta mus_bcut
    lda #1                      ; first music_play tick starts row 0
    sta mus_tick
    rts

; ---- play one tick: called once per frame ----
; Preserves A/X/Y: the transition loops keep counters in the
; registers across their wait_frame calls.
music_play:
    pha
    txa
    pha
    tya
    pha
    jsr mp_core
    pla
    tay
    pla
    tax
    pla
    rts

mp_core:
    lda mus_muted
    bne mp_done                 ; muted: song position frozen too
    lda mus_bcut                ; scheduled bass gate-off: opens a small
    beq mp_tick                 ;   gap before the next note, so the
    dec mus_bcut                ;   notes don't run into each other
    bne mp_tick
    lda #BASS_OFF
    sta SID_V1_CR
mp_tick:
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
    beq mp_lead
    cmp #1
    bne mp_drum_note
    lda #DRUM_OFF
    sta SID_V2_CR
    jmp mp_lead
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

    ; ---- voice 3: arpeggio lead ----
mp_lead:
    lda lead_pat,x              ; only notes here, no key-off events:
    beq mp_next                 ;   the envelope decays to silence
    and #$7f
    tay
    lda lead_flo,y
    sta SID_V3_FL
    lda lead_fhi,y
    sta SID_V3_FH
    lda #LEAD_OFF
    sta SID_V3_CR
    lda #LEAD_ON
    sta SID_V3_CR

mp_next:
    inx
    cpx #SONG_LEN
    bne mp_store
    ldx #0                      ; loop the song
    stx mus_spd_ix              ; restart the 4,4,4,4,4,5 cycle with it
mp_store:
    stx mus_row
    lda bass_pat,x              ; peek at the next row: if a note comes,
    bpl mp_nocut                ;   cut the bass 2 frames before it
    lda mus_tick
    sec
    sbc #2
    sta mus_bcut
mp_nocut:
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
mus_bcut:      !byte 0          ; frames until the pre-note bass gate-off
                                ;   (0 = none scheduled)

spd_tbl:       !byte 4,4,4,4,4,4    ; 4 frames/row = 12.5 rows/s, a hair
                                    ;   faster than the original 12
                                    ;   (4,4,4,4,4,5 would be exact)

; ---- note tables (PAL SID: reg = Hz * 16777216 / 985248) ----
; bass: 0 = C-2, 1 = A#1, 2 = D#2, 3 = F-2
bass_flo: !byte $5a,$e0,$2d,$cf
bass_fhi: !byte $04,$03,$05,$05
; drums: noise pitch from the TIC-80 note (x32 waveform steps)
;        0 = C-1 kick (low rumble), 1 = C-4 snare (bright)
drum_flo: !byte $9c,$ff
drum_fhi: !byte $45,$ff
; lead echo: bass notes +3 octaves (0-3), +4 octaves (4-7)
;   0 = C-5, 1 = A#4, 2 = D#5, 3 = F-5, 4 = C-6, 5 = A#5, 6 = D#6, 7 = F-6
lead_flo: !byte $ce,$02,$64,$76,$9c,$04,$c8,$eb
lead_fhi: !byte $22,$1f,$29,$2e,$45,$3e,$52,$5c

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
; the bass_pat notes shifted 2 rows later; repeated notes take the
; octave-up variant (indices 4-7), alternating with the base octave
lead_pat:
    !byte $00,$00,$80,$00,$00,$00,$00,$00,$84,$00,$00,$00,$00,$00,$81,$00
    !byte $80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    !byte $00,$00,$84,$00,$00,$00,$00,$00,$80,$00,$00,$00,$00,$00,$81,$00
    !byte $80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    !byte $00,$00,$84,$00,$00,$00,$00,$00,$80,$00,$00,$00,$00,$00,$81,$00
    !byte $80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    !byte $00,$00,$82,$00,$86,$00,$00,$00,$82,$00,$00,$00,$00,$00,$86,$00
    !byte $83,$00,$00,$00,$87,$00,$00,$00,$83,$00,$87,$00,$00,$00,$83,$00
