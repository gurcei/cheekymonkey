; BASIC stub code borrowed from:
; https://techtinkering.com/articles/adding-basic-stubs-to-assembly-language-on-the-commodore-vic-20/

BSPACE    = $14               ; Backspace character
COLON     = $3A               ; Colon character
TOK_REM   = $8F               ; REM token
TOK_SYS   = $9E               ; SYS token

CCHROUT   = $FFD2             ; Output character to current output device

            .byt  $01, $10    ; Load address ($1001)

            * = $1001
            .word basicEnd    ; Next Line link, here end of Basic program
            .word 2020        ; The line number for the SYS statement
            .byt  TOK_SYS     ; SYS token
            .asc  " "
            .asc  "4150"      ; Start of machine language
            .byt  COLON       ; Colon character
            .byt  TOK_REM     ; REM token
            .asc  " "
            .dsb  15,BSPACE   ; Backspace characters to make line invisible
            .asc  "(C) GURCE ISIKYILDIZ"
            .byt  0           ; End of Basic line
basicEnd    .word 0           ; End of Basic program

            ; Print 'HELLO, WORLD!"
            ldx #$00
loop        lda message, x
            beq finished
            jsr CCHROUT
            inx
            bne loop

finished
            ; change end of basic
            lda #$1c
            sta $34
            sta $38

            ; move character set to ram at 7168
            lda #$ff
            sta $9005

            ; copy character set from 32768 to 7168 (only first 512 bytes, this gets me alphanumerics)
            ldy #$00
charsetCopy
            lda $8000,y
            sta $1c00,y
            lda $8100,y
            sta $1d00,y
            iny
            bne charsetCopy

            rts

message     .asc "HELLO, WORLD!" : .byt 0
endCode

            ; fill to charset
            * = $1e00
            .dsb (*-endCode), 0
            * = $1e00

            ; add my unique characters here
            .byt %00111100
            .byt %01000010
            .byt %10000001
            .byt %10000001
            .byt %10000001
            .byt %10000001
            .byt %01000010
            .byt %00111100
