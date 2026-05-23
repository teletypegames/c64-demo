; -----------------------------------------------------------
; main.asm - C64 demo: text output + border flashing
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

; ---- KERNAL routines ----
CHROUT  = $ffd2          ; character output
BORDER  = $d020          ; border color register
BG      = $d021          ; background color register

start:
    lda #14              ; light blue background
    sta BG
    lda #6               ; dark blue border
    sta BORDER

    lda #$93             ; CLR/HOME - clear screen
    jsr CHROUT
    lda #$05             ; white text color
    jsr CHROUT

    ldx #0
print_loop:
    lda message,x
    beq color_loop       ; if 0 -> text done
    jsr CHROUT
    inx
    jmp print_loop

; infinite color flasher
color_loop:
    inc BORDER           ; increment border color
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
