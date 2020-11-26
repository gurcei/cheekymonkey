; BASIC stub code borrowed from:
; https://techtinkering.com/articles/adding-basic-stubs-to-assembly-language-on-the-commodore-vic-20/

#include "spridx.s"

BSPACE    = $14               ; Backspace character
COLON     = $3A               ; Colon character
TOK_REM   = $8F               ; REM token
TOK_SYS   = $9E               ; SYS token

SCREENRAM   = $1E00
COLOURRAM   = $9600 ; (or $9400 for expanded vic)

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
            ; lda #$1c
            ; sta $34
            ; sta $38

            ; move character set to ram at 6144
            lda #$fe
            sta $9005

            ; copy character set from 32768 to 7168 (only first 512 bytes, this gets me alphanumerics)
            ldy #$00
charsetCopy
            lda $8000,y
            sta $1800,y
            lda $8100,y
            sta $1900,y
            iny
            bne charsetCopy

            lda #IMG_WALK1
            ldx px
            ldy py
            jsr drawImg
            rts

; --------
drawImg
; --------
            pha
            lda #<SCREENRAM
            sta loc
            lda #>SCREENRAM
            sta loc+1

            ; add 40 for each y
            cpy #$00
            beq _diAddX
_diLoopY
            lda loc
            clc
            adc #40
            sta loc
            lda loc+1
            adc #00
            sta loc+1

            dey
            bne _diLoopY
            
_diAddX
            clc
            txa
            adc loc
            sta loc
            lda loc+1
            sta loc+1

            ; put to zero page
            lda loc
            sta $fe
            lda loc+1
            sta $ff

            ; put character here
            pla
            sta ($fe)
            rts

message     .asc "HELLO, WORLD!" : .byt 0
px          .byt 00
py          .byt 00
loc         .word 0000

endCode

            ; fill to charset
            * = $1a00
            .dsb (*-endCode), 0
            * = $1a00

            ; add my unique characters here
            ; currently 464 bytes long (58 chars)
            ; mem range is 1a00 (6656) to 1fd0 (7120)
#include "charset.s"
