; -----------------------------------------------------------
; main.asm - C64 demo: szoveg kiiratas + keret villogtatas
; Forditas: acme -f cbm -o main.prg main.asm
; -----------------------------------------------------------

!to "main.prg", cbm

* = $0801

; ---- BASIC stub: 10 SYS 2064 ----
; igy a LOAD"*",8,1 utan eleg RUN-t irni
!byte $0c, $08          ; kovetkezo sor cime
!byte $0a, $00          ; sorszam: 10
!byte $9e               ; SYS token
!byte $20, $32, $30, $36, $34   ; " 2064"
!byte $00               ; sor vege
!byte $00, $00          ; program vege

* = $0810                ; = 2064 decimalisan

; ---- KERNAL rutinok ----
CHROUT  = $ffd2          ; karakter kiiras
BORDER  = $d020          ; keret szin regiszter
BG      = $d021          ; hatter szin regiszter

start:
    lda #14              ; vilagoskek hatter
    sta BG
    lda #6               ; sotetkek keret
    sta BORDER

    lda #$93             ; CLR/HOME - kepernyo torles
    jsr CHROUT
    lda #$05             ; feher karakter szin
    jsr CHROUT

    ldx #0
print_loop:
    lda message,x
    beq color_loop       ; ha 0 -> kesz a szoveg
    jsr CHROUT
    inx
    jmp print_loop

; vegtelen szinvillogtato
color_loop:
    inc BORDER           ; novelje a keret szinet
    ldy #0
delay_outer:
    ldx #0
delay_inner:
    dex
    bne delay_inner
    dey
    bne delay_outer
    jmp color_loop

message:
    !text "HELLO, COMMODORE 64!"
    !byte 13, 13
    !text "TELETYPE GAMES DEMO"
    !byte 13, 0
