; BASIC stub code borrowed from:
; https://techtinkering.com/articles/adding-basic-stubs-to-assembly-language-on-the-commodore-vic-20/

#include "spridx.s"

BSPACE    = $14               ; Backspace character
COLON     = $3A               ; Colon character
TOK_REM   = $8F               ; REM token
TOK_SYS   = $9E               ; SYS token

PJOY_LEFT  = $01
PJOY_RIGHT = $02
PJOY_UP    = $04
PJOY_DOWN  = $08
PJOY_FIRE  = $10

SCREENRAM   = $1E00
COLOURRAM   = $9600 ; (or $9400 for expanded vic)

CHROUT   = $FFD2             ; Output character to current output device
PLOT     = $FFF0             ; Set (clc) or get (sec) cursor position

            .byt  $01, $10    ; Load address ($1001)

            * = $1001
            .word basicEnd    ; Next Line link, here end of Basic program
            .word 2020        ; The line number for the SYS statement
            .byt  TOK_SYS     ; SYS token
            .asc  " "
            .asc  "4150"      ; Start of machine language (0x1036)
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
            jsr CHROUT
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

            jmp main

#define LOADANIM(anim)  \
  lda #<anim :           \
  sta $fa    :           \
  lda #>anim :           \
  sta $fb

drawGameScreen
            ; clear the screen
            lda #147
            jsr CHROUT

            ; draw the grass
            ; lda #$1E  ; green colour
            ; jsr CHROUT

            ; ldx #22
            ; ldy #21
            ; clc
            ; jsr PLOT

            lda #00
            sta tmp1
            lda #05 ; green
            sta color

grassloop
            ; lower layer
            ldx tmp1
            ldy #22
            lda #IMG_GRASS
            jsr drawImg

            ; mid layer
            ldx tmp1
            ldy #15
            lda #IMG_GRASS
            jsr drawImg

            ; top layer
            ldx tmp1
            ldy #8
            lda #IMG_GRASS
            jsr drawImg

            ldx tmp1
            inx
            stx tmp1
            cpx #22
            bne grassloop
            
            ldx #02
            ldy #09
            jsr drawLadder

            ldx #18
            ldy #16
            jsr drawLadder
            rts

; --------
drawLadder
; --------
            ; draw ladders
            stx tmp1
            sty tmp2
            lda #07 ; yellow
            sta color

            lda #00
            sta tmp3  ; tmp3 will hold the rung-index of the ladder

ladderLoop
            lda #IMG_LADDER
            ldx tmp1
            ldy tmp2
            jsr drawImg
            ldx tmp1
            ldy tmp2
            inx
            lda #IMG_LADDER+1
            jsr drawImg

            ldy tmp2
            iny
            sty tmp2

            ldx tmp3
            inx
            stx tmp3
            cpx #06
            bne ladderLoop

            rts

; ----------
drawPlayer
; ----------
            ; draw player
            lda #06   ; blue color
            sta color
            ldy anmidx
            lda ($fa),y
            ldx px
            ldy py
            jsr drawImg2x2
            rts

; ----------
drawFire
; ----------
            ; draw fire
            lda pfireflag
            beq dfend
            lda #$00
            sta color ; coconuts are black
            lda #IMG_COCONUT1
            ldx pfirex
            ldy pfirey
            jsr drawImg
            sta pfirebuf
            stx pfirecolbuf

dfend
            rts

; ---------
loopDelay
; ---------
            ; add pause/delay after drawing screen contents
            ldx#$40
m2
            ldy#$00
m1
            dey
            bne m1

            dex
            bne m2
            rts

; ---------
clearFire
; ---------
            ; clear fire
            lda pfireflag
            beq m3
            lda pfirecolbuf
            sta color
            lda pfirebuf
            ldx pfirex
            ldy pfirey
            jsr drawImg
m3
            rts

; ----------
; MAIN
; ----------
main
            ; store current animation ptr at $fa-fb
            LOADANIM(anmwalk)

            jsr drawGameScreen

            ; initialise player position
            lda #04
            sta px
            lda #20
            sta py
            
            lda #$00
            sta pfireflag

mainloop
            jsr drawPlayer
            jsr drawFire

            jsr loopDelay

            jsr clearFire

            ; clear player image
            ldx px
            ldy py
            jsr clearImg

            ; get keyboard input
            ldx keyinpause
            inx
            cpx #$03
            bne changeFrame
            jsr actOnJoystickInput
            ldx #$00

changeFrame
            stx keyinpause
            ; change frame
            ldy anmidx
            iny
            sty anmidx
            cpy #$04
            bne mainloop
            ldy #$00
            sty anmidx
            jmp mainloop
            rts

; --------
getJoystickInput
; --------
            lda #$00
            sta $9113 ; DDR for PortA on VIA#1
            sta pjoy

            ; check joyright
            lda #127
            sta $9122 ; set  bit7 as input on DDR for PortB on VIA#2
            lda #128
            bit $9120 ; PortB on VIA#2 (Bit7 = JoyRight)
            bne checkJoyLeft
            ; store in joy buffer
            lda pjoy
            ora #PJOY_RIGHT
            sta pjoy

checkJoyLeft
            lda #255
            sta $9122 ; set bit7 as output DDR for PortB on VIA#2

            lda $9111 ; PortA on VIA#1 (Bit2 = JoyUp, Bit3 = JoyDown, Bit4 = JoyLeft, Bit5 = JoyFire)
            sta $ff

            ; checkLeft
            lda #$10
            bit $ff
            bne checkJoyUp
            ; store in joy buffer
            lda pjoy
            ora #PJOY_LEFT
            sta pjoy

checkJoyUp
            lda #$04
            bit $ff
            bne checkJoyDown
            ; store in joy buffer
            lda pjoy
            ora #PJOY_UP
            sta pjoy

checkJoyDown
            lda #$08
            bit $ff
            bne checkJoyFire
            ; store in joy buffer
            lda pjoy
            ora #PJOY_DOWN
            sta pjoy

checkJoyFire
            lda #$20
            bit $ff
            bne endCheck
            ; store in joy buffer
            lda pjoy
            ora #PJOY_FIRE
            sta pjoy

endCheck
            rts

; -------
initPlayerFire
; -------
            ldx px
            inx
            stx pfirex
            ldy py
            dey
            sty pfirey
            lda #$00
            lda pfiretime
            rts

; --------
actOnJoystickInput
; --------
            jsr getJoystickInput

actCheckFire
            ; act on fire button?
            lda pjoy
            and #PJOY_FIRE
            beq actCheckLeft

actCheckFireRight
            lda pjoy
            and #PJOY_RIGHT
            beq actCheckFireLeft
            LOADANIM(anmthrowright)
            lda #$03
            sta pfireflag
            jsr initPlayerFire
            jmp actEnd

actCheckFireLeft
            lda pjoy
            and #PJOY_LEFT
            beq actFireOnly
            LOADANIM(anmthrowleft)
            lda #$01
            sta pfireflag
            jsr initPlayerFire
            jmp actEnd

actFireOnly
            LOADANIM(anmthrowup)
            lda #$02
            sta pfireflag
            jsr initPlayerFire
            jmp actEnd

actCheckLeft
            lda pjoy
            and #PJOY_LEFT
            beq actCheckRight
            LOADANIM(anmwalk)
            ; move player left (if not at x=0 already)
            lda px
            beq actEnd
            dec px
            jmp actEnd

actCheckRight
            lda pjoy
            and #PJOY_RIGHT
            beq actCheckUp
            LOADANIM(anmwalk)
            ; move player right (if not at x=20 already)
            lda px
            cmp #20
            beq actEnd
            inc px
            jmp actEnd

actCheckUp
            lda pjoy
            and #PJOY_UP
            beq actCheckDown
            LOADANIM(anmclimb)
            ; move player up (if not at y=0 already)
            lda py
            cmp #0
            beq actEnd
            dec py
            jmp actEnd

actCheckDown
            lda pjoy
            and #PJOY_DOWN
            beq actEnd
            LOADANIM(anmclimb)
            ; move player down (if not at y=21 already)
            lda py
            cmp #21
            beq actEnd
            inc py

actEnd
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
            ldy #$00
            lda ($fe),y ; preserve value written over
            tax
            pla
            sta ($fe),y

            lda ($fc),y ; preserve colour value written over
            sta tmp4
            lda color
            sta ($fc),y
            txa ; return a = char value written over
            ldx tmp4  ; return x = colour value written over
            rts

; --------
drawImg2x2
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
pjoy        .byt 00   ; bit0=left, bit1=right, bit2=up, bit3=down, bit4=fire
pbuff       .byt 00, 00, 00, 00
pcolbuff    .byt 00, 00, 00, 00
loc         .word 0000
color       .byt 00
anmwalk       .byt IMG_WALK1, IMG_WALK2, IMG_WALK3, IMG_WALK2
anmclimb      .byt IMG_CLIMB1, IMG_CLIMB2, IMG_CLIMB3, IMG_CLIMB2
anmthrowright .byt IMG_THROWDOWN3, IMG_THROWDOWN2, IMG_THROWDOWN1, IMG_THROWDOWN2
anmthrowup    .byt IMG_THROWDOWN2, IMG_THROWDOWN1, IMG_THROWUP1, IMG_THROWDOWN1
anmthrowleft  .byt IMG_THROWDOWN1, IMG_THROWUP1, IMG_THROWUP2, IMG_THROWUP1
anmcoconut    .byt IMG_COCONUT1, IMG_COCONUT2, IMG_COCONUT3, IMG_COCONUT2
anmidx      .byt 00
keyinpause  .byt 00
tmp1        .byt 00
tmp2        .byt 00
tmp3        .byt 00
tmp4        .byt 00
pfireflag   .byt 00 ; 0 = fire off, 1 = fire left, 2 = fire up, 3 = fire right
pfirex      .byt 00
pfirey      .byt 00
pfiretime   .byt 00 ; how long the fire of the coconut has been active
pfirebuf    .byt 00 ; what char was written on top of
pfirecolbuf .byt 00 ; what char colour was written on top of

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
