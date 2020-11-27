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
; ----------
; INIT
; ----------
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

; ----------
; MAIN
; ----------
main
            ; draw stuff
            ldy anmidx
            lda anmwalk,y
            ldx px
            ldy py
            jsr drawImg

            ; add pause/delay after drawing screen contents
            ldx#$80
m2
            ldy#$00
m1
            dey
            bne m1

            dex
            bne m2

            ; clear player image
            ldx px
            ldy py
            jsr clearImg

            ; get keyboard input
            jsr getKeyboardInput

            ; change frame
            ldy anmidx
            iny
            sty anmidx
            cpy #$04
            bne main
            ldy #$00
            sty anmidx
            jmp main
            rts

; --------
getKeyboardInput
; --------
            lda #$00
            sta $9113 ; DDR for PortA on VIA#1

            ; check joyright
            lda #127
            sta $9122 ; set  bit7 as input on DDR for PortB on VIA#2
            lda #128
            bit $9120 ; PortB on VIA#2 (Bit7 = JoyRight)
            bne checkJoyLeft
            inc px

checkJoyLeft
            lda #255
            sta $9122 ; set bit7 as output DDR for PortB on VIA#2

            lda $9111 ; PortA on VIA#1 (Bit2 = JoyUp, Bit3 = JoyDown, Bit4 = JoyLeft, Bit5 = JoyFire)
            sta $ff

            ; checkLeft
            lda #$10
            bit $ff
            bne checkJoyUp
            dec px

checkJoyUp
            lda #$04
            bit $ff
            bne checkJoyDown
            dec py

checkJoyDown
            lda #$08
            bit $ff
            bne endCheck
            inc py

endCheck
            rts
            
            
; --------
calcXYloc
; --------
            pha
            txa
            pha
            tya
            pha
            ; add 22 for each y
            cpy #$00
            beq _diAddX
_diLoopY
            lda loc
            clc
            adc #22
            sta loc
            lda loc+1
            adc #00
            sta loc+1

            dey
            bne _diLoopY
            
_diAddX
            txa
            clc
            adc loc
            sta loc
            lda #$00
            adc loc+1
            sta loc+1
            pla
            tay
            pla
            tax
            pla
            rts

; --------
prepareScreenPtrs
; --------
            lda #<SCREENRAM
            sta loc
            lda #>SCREENRAM
            sta loc+1
            jsr calcXYloc

            ; put to zero page at $fe-$ff
            lda loc
            sta $fe
            lda loc+1
            sta $ff

            lda #<COLOURRAM
            sta loc
            lda #>COLOURRAM
            sta loc+1
            jsr calcXYloc

            ; put to zero page at $fc-$fd
            lda loc
            sta $fc
            lda loc+1
            sta $fd
            rts

; --------
clearImg
; --------
            jsr prepareScreenPtrs

            ; top-left char
            ldy #$00
            lda pbuff
            sta ($fe),y
            lda pcolbuff
            sta ($fc),y

            ; top-right char
            iny
            lda pbuff+1
            sta ($fe),y
            lda pcolbuff+1
            sta ($fc),y

            ; bot-left char
            tya
            clc
            adc #21
            tay
            lda pbuff+2
            sta ($fe),y
            lda pcolbuff+2
            sta ($fc),y

            ; bot-right char
            iny
            lda pbuff+3
            sta ($fe),y
            lda pcolbuff+3
            sta ($fc),y
            rts

; --------
drawImg
; --------
            pha
            jsr prepareScreenPtrs

            ; put character here (preserve old character in pbuff and pcolbuff)
            ldy #$00
            lda ($fe),y
            sta pbuff
            pla
            sta ($fe),y
            pha
            lda ($fc),y
            sta pcolbuff
            lda color
            sta ($fc),y
            pla

            ; draw next char to right
            clc
            adc #1
            iny
            pha
            lda ($fe),y
            sta pbuff+1
            pla
            sta ($fe),y
            pha
            lda ($fc),y
            sta pcolbuff+1
            lda color
            sta ($fc),y
            pla

            ; draw in bottom-left
            clc
            adc #1
            pha
            tya
            adc #$15
            tay
            lda ($fe),y
            sta pbuff+2
            pla
            sta ($fe),y
            pha
            lda ($fc),y
            sta pcolbuff+2
            lda color
            sta ($fc),y
            pla

            ; draw in bottom-right
            clc
            adc #1
            iny
            pha
            lda ($fe),y
            sta pbuff+3
            pla
            sta ($fe),y
            pha
            lda ($fc),y
            sta pcolbuff+3
            lda color
            sta ($fc),y
            pla
            
            rts

;------------
; DATA
;------------
message     .asc "HELLO, WORLD!" : .byt 0
px          .byt 04
py          .byt 04
pbuff       .byt 00, 00, 00, 00
pcolbuff    .byt 00, 00, 00, 00
loc         .word 0000
color       .byt 00
anmwalk     .byt IMG_WALK1, IMG_WALK2, IMG_WALK3, IMG_WALK2
anmidx      .byt 00

endCode

            ; fill to charset
            * = $1a00
            .dsb (*-endCode), 0
            * = $1a00

;------------
; CHARSET
;------------
            ; add my unique characters here
            ; currently 464 bytes long (58 chars)
            ; mem range is 1a00 (6656) to 1fd0 (7120)
#include "charset.s"
