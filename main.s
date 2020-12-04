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

SCREENPTR   = $fe
COLOURPTR   = $fc
ANIMPTR     = $fa
MONKEYPTR   = $f8   ; pointer to the current monkey
MONKEYTBLPTR= $f6   ; pointer to the monkey table
CMONKEYPTR  = $f4   ; pointer to the current coconut of interest to test for collision against current monkey


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


; -------
getCurrentMonkeyAnim
; -------
; Copy Anim from Monkey's PANIMPTRLO/HI to ANIMPTR in zero-page
  ldy #PANIMPTRLO
  lda (MONKEYPTR),y
  sta ANIMPTR
  ldy #PANIMPTRHI
  lda (MONKEYPTR),y
  sta ANIMPTR+1
  rts

; -------
loadAnim
; -------
  ldy #PANIMPTRLO
  sta (MONKEYPTR),y
  sta ANIMPTR
  txa
  ldy #PANIMPTRHI
  sta (MONKEYPTR),y
  sta ANIMPTR+1
  rts


; Load Anim into Monkey's PANIMPTRLO/HI and copy it into zero-page too.
#define LOADANIM(anim)  \
  lda #<anim  : \
  ldx #>anim : \
  jsr loadAnim

; --------
loadMonkey
; --------
  clc : tya : pha :
  lda pctr :
  asl :
  tay :
  lda (MONKEYTBLPTR),y :
  sta MONKEYPTR :
  iny :
  lda (MONKEYTBLPTR),y :
  sta MONKEYPTR+1  :
  pla : tay
  rts

#define LOADMONKEY jsr loadMonkey

#define LOADCMONKEY \
  clc : tya : pha : \
  lda cctr : \
  asl : \
  tay : \
  lda (MONKEYTBLPTR),y : \
  sta CMONKEYPTR : \
  iny : \
  lda (MONKEYTBLPTR),y : \
  sta CMONKEYPTR+1  : \
  pla : tay

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
drawMonkeys
; ----------
            lda #$00
            sta pctr

dploop
            LOADMONKEY

            ldy #PVIS
            lda (MONKEYPTR),y
            beq dpskip

            ; draw player
            ldy #PCOLOUR
            lda (MONKEYPTR),y
            sta color
            
            jsr getCurrentMonkeyAnim
            
            ldy #PANMIDX
            lda (MONKEYPTR),y
            tay
            lda (ANIMPTR),y
            pha

            ldy #PX
            lda (MONKEYPTR),y
            tax

            ldy #PY
            lda (MONKEYPTR),y
            tay

            pla
            jsr drawImg2x2

dpskip
            inc pctr
            lda pctr
            cmp #06
            bne dploop

            rts

; ----------
drawCoconuts
; ----------
            lda #$00
            sta pctr

dfloop
            LOADMONKEY

            ; draw fire
            ldy #PFIREFLAG
            lda (MONKEYPTR),y
            beq dfskip

            lda #$00
            sta color ; coconuts are black

            ldy #PFIREX
            lda (MONKEYPTR),y
            tax

            ldy #PFIREY
            lda (MONKEYPTR),y
            tay

            lda #IMG_COCONUT1
            jsr drawImg

            ldy #PFIREBUF
            sta (MONKEYPTR),y

            ldy #PFIRECOLBUF
            txa
            sta (MONKEYPTR),y

dfskip
            inc pctr
            lda pctr
            cmp #06
            bne dfloop
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
clearCoconuts
; ---------
            lda #$05
            sta pctr

cfloop
            LOADMONKEY

            ; clear fire
            ldy #PFIREFLAG
            lda (MONKEYPTR),y
            beq cfskip

            ldy #PFIRECOLBUF
            lda (MONKEYPTR),y
            sta color

            ldy #PFIREBUF
            lda (MONKEYPTR),y
            pha

            ldy #PFIREX
            lda (MONKEYPTR),y
            tax

            ldy #PFIREY
            lda (MONKEYPTR),y
            tay

            pla
            jsr drawImg
cfskip
            lda pctr
            cmp #00
            beq cfend
            dec pctr
            jmp cfloop
cfend
            rts

; ----------
animateCoconuts
; ----------
            lda #$00
            sta pctr

afloop
            LOADMONKEY

            ; clear fire
            ldy #PFIREFLAG
            lda (MONKEYPTR),y
            bne afcont
            jmp afskip

afcont
            ; handle horizontal
            ldy #PFIREFLAG
            lda (MONKEYPTR),y

            ; fire left?
            cmp #$01
            bne af4

            ldy #PFIREBOUNCE
            lda (MONKEYPTR),y
            beq afl1
            ldy #PFIREX
            lda (MONKEYPTR),y
            clc
            adc #$01
            sta (MONKEYPTR),y
            jmp af4

afl1
            ldy #PFIREX
            lda (MONKEYPTR),y
            sec
            sbc #$01
            sta (MONKEYPTR),y
            clc
            bne af4
            ; if x=0, then set bounce flag
            lda #$01
            ldy #PFIREBOUNCE
            sta (MONKEYPTR),y

            ; fire right?
af4
            ldy #PFIREFLAG
            lda (MONKEYPTR),y
            cmp #$03
            bne af5

            ldy #PFIREBOUNCE
            lda (MONKEYPTR),y
            beq afr1

            ldy #PFIREX
            lda (MONKEYPTR),y
            sec
            sbc #$01
            sta (MONKEYPTR),y
            clc
            jmp af5

afr1
            ldy #PFIREX
            lda (MONKEYPTR),y
            clc
            adc #$01
            sta (MONKEYPTR),y
            
            cmp #21
            bne af5

            ; if x=21, then set bounce flag
            lda #$01
            ldy #PFIREBOUNCE
            sta (MONKEYPTR),y

            ; otherwise fire up
af5
            ldy #PFIRETIME
            lda (MONKEYPTR),y
            clc
            adc #$01
            sta (MONKEYPTR),y

            ; handle vertical
            cmp #$06
            bcs af1

            ldy #PFIREY
            lda (MONKEYPTR),y
            sec
            sbc #$01
            clc
            sta (MONKEYPTR),y
            jmp af2
af1
            ldy #PFIREY
            lda (MONKEYPTR),y
            clc
            adc #$01
            sta (MONKEYPTR),y
af2
            ldy #PFIRETIME
            lda (MONKEYPTR),y
            cmp #$0d
            bne af3
            ldy #PFIREFLAG
            lda #$00
            sta (MONKEYPTR),y

af3
afskip
            lda pctr
            cmp #00
            beq afend
            dec pctr
            jmp afloop
afend
            rts

; ---------
checkAllCoconutHits
; ---------
            lda #$00
            sta cctr

            stx cachx
            sty cachy

cachloop
            LOADCMONKEY

            ldy #PFIREFLAG
            lda (CMONKEYPTR),y

            beq cachskip

            ldx cachx
            ldy cachy

            jsr checkCoconutHit
            bcc cachskip

            ; if we found a hit (carry set), then exit early
            rts

cachskip
            inc cctr
            lda cctr
            cmp #06
            bne cachloop
            clc
            rts

; ---------
checkCoconutHit
; ---------
            sty tmp4

            ldy #PFIREX
            txa
            cmp (CMONKEYPTR),y
            bne cxyh1

            lda tmp4 ; this holds the y-value initially fed in
            ldy #PFIREY
            cmp (CMONKEYPTR),y
            bne cxyh1

            ; we got a hit, so hide this coconut
            lda #$00
            ldy #PFIREFLAG
            sta (CMONKEYPTR),y
            sec
            rts

cxyh1
            clc
            rts

; ---------
checkAllCollisions
; ---------
            lda #$00
            sta pctr

cacloop
            LOADMONKEY

            jsr checkCollision

cacskip
            inc pctr
            lda pctr
            cmp #06
            bne cacloop
            rts


; ----------
changeFrames
; ----------
            lda #$00
            sta pctr

chgfloop
            LOADMONKEY
            
            ; change frame
            ldy #PANMIDX
            lda (MONKEYPTR),y
            clc
            adc #$01
            sta (MONKEYPTR),y
            cmp #$04
            bne chgfskip

            lda #$00
            ldy #PANMIDX
            sta (MONKEYPTR),y

chgfskip
            inc pctr
            lda pctr
            cmp #06
            bne chgfloop

chgfend
            rts

; ---------
checkCollision
; ---------
            ldy #PVIS
            lda (MONKEYPTR),y
            bne cc0
            rts

cc0
            ; check collision between all coconuts and this player
            ldy #PX
            lda (MONKEYPTR),y
            tax
            stx ccx

            ldy #PY
            lda (MONKEYPTR),y
            tay
            sty ccy

            jsr checkAllCoconutHits
            bcc cc1
            jmp ccHit

cc1
            inc ccx
            ldx ccx
            ldy ccy
            jsr checkAllCoconutHits
            bcc cc2
            jmp ccHit

cc2
            inc ccy
            ldx ccx
            ldy ccy
            jsr checkAllCoconutHits
            bcc cc3
            jmp ccHit

cc3
            dec ccx
            ldx ccx
            ldy ccy
            jsr checkAllCoconutHits
            bcc cc4
            jmp ccHit

cc4
            rts

ccHit
            ; switch to hit-dizzy anim
            lda #$00
            ldy #PFIREFLAG
            sta (MONKEYPTR),y
            LOADANIM(anmdizzy)
            rts


; ----------
clearMonkeys
; ----------
            lda #$05
            sta pctr

cmloop
            LOADMONKEY

            ; check for monkey visibility first
            ldy #PVIS
            lda (MONKEYPTR),y
            beq cmskip

            ; clear player image
            ldy #POLDX
            lda (MONKEYPTR),y
            tax

            ldy #POLDY
            lda (MONKEYPTR),y
            tay

            jsr clearImg2x2

cmskip
            lda pctr
            cmp #00
            beq cmend
            dec pctr
            jmp cmloop
cmend
            rts

; ----------
initMonkeys
; ----------
            lda #<monkeytable
            sta MONKEYTBLPTR
            lda #>monkeytable
            sta MONKEYTBLPTR+1 

            ; initialise player position
            lda #$00
            sta pctr
            LOADMONKEY

            lda #04
            ldy #PX
            sta (MONKEYPTR),y
            lda #20
            ldy #PY
            sta (MONKEYPTR),y
            
            ; common initialisation for all monkeys
            lda #$00
            sta pctr
            
imloop
            LOADMONKEY
            
            lda #$00
            ldy #PFIREFLAG
            sta (MONKEYPTR),y

            lda #$01
            ldy #PVIS
            sta (MONKEYPTR),y
            
            LOADANIM(anmwalk)

            lda pctr
            cmp #06
            beq imend
            inc pctr
            jmp imloop
imend
            rts


; ----------
animateMonkeys
; ----------
            lda #$00
            sta pctr
            LOADMONKEY

            ; preserve old monkey position (for clearing frame from screen later)
            ldy #PX
            lda (MONKEYPTR),y
            ldy #POLDX
            sta (MONKEYPTR),y
            
            ldy #PY
            lda (MONKEYPTR),y
            ldy #POLDY
            sta (MONKEYPTR),y
            
            ; get keyboard input
            ldx keyinpause
            inx
            cpx #$03
            bne skipJoy
            jsr actOnJoystickInput
            ldx #$00

skipJoy
            stx keyinpause
            rts

; ----------
; MAIN
; ----------
main
            ; store current animation ptr at $fa-fb

            jsr drawGameScreen

            jsr initMonkeys
            

mainloop
            jsr drawMonkeys
            jsr drawCoconuts

            jsr loopDelay

            jsr clearCoconuts
            jsr animateCoconuts
            jsr animateMonkeys

            jsr checkAllCollisions

            jsr changeFrames

            jsr clearMonkeys

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
; NOTE - Currently hardcoded for player 1 in caller (in future, would like this to support player2 via keyboard)

            ldy #PX
            lda (MONKEYPTR),y
            tax
            inx
            txa
            ldy #PFIREX
            sta (MONKEYPTR),y

            ldy #PY
            lda (MONKEYPTR),y
            tay
            dey
            tya
            ldy #PFIREY
            sta (MONKEYPTR),y

            lda #$00
            ldy #PFIRETIME
            sta (MONKEYPTR),y
            rts

; --------
actOnJoystickInput
; --------
            jsr getJoystickInput

; NOTE - again, this is hardcoded to be just for player1 (try get it to work for keyboard player 2 in future)
            lda #$00
            sta pctr
            LOADMONKEY

actCheckFire
            ; act on fire button?
            lda pjoy
            and #PJOY_FIRE
            beq actCheckLeft

            ; assure that monkey's coconut isn't already thrown yet
            ldy #PFIREFLAG
            lda (MONKEYPTR),y
            bne actCheckLeft

            ; initialise a few coconut vars in preparation
            lda #$00
            ldy #PFIRETIME
            sta (MONKEYPTR),y
            ldy #PFIREBOUNCE
            sta (MONKEYPTR),y

actCheckFireRight
            lda pjoy
            and #PJOY_RIGHT
            beq actCheckFireLeft
            LOADANIM(anmthrowright)
            lda #$03
            ldy #PFIREFLAG
            sta (MONKEYPTR),y
            
            ; check for right-most position gotchya
            ldy #PX
            lda (MONKEYPTR),y
            cmp #20
            bne acfri1
            ; force it to bounce from the get-go
            lda #$01
            ldy #PFIREBOUNCE
            sta (MONKEYPTR),y
acfri1
            jsr initPlayerFire
            jmp actEnd

actCheckFireLeft
            lda pjoy
            and #PJOY_LEFT
            beq actFireOnly
            LOADANIM(anmthrowleft)
            lda #$01
            ldy #PFIREFLAG
            sta (MONKEYPTR),y
            jsr initPlayerFire
            jmp actEnd

actFireOnly
            LOADANIM(anmthrowup)
            lda #$02
            ldy #PFIREFLAG
            sta (MONKEYPTR),y
            jsr initPlayerFire
            jmp actEnd

actCheckLeft
            lda pjoy
            and #PJOY_LEFT
            beq actCheckRight
            LOADANIM(anmwalk)
            ; move player left (if not at x=0 already)
            ldy #PX
            lda (MONKEYPTR),y
            beq actEnd
            lda (MONKEYPTR),y
            tax
            dex
            txa
            sta (MONKEYPTR),y
            jmp actEnd

actCheckRight
            lda pjoy
            and #PJOY_RIGHT
            beq actCheckUp
            LOADANIM(anmwalk)
            ; move player right (if not at x=20 already)
            ldy #PX
            lda (MONKEYPTR),y
            cmp #20
            beq actEnd
            lda (MONKEYPTR),y
            tax
            inx
            txa
            sta (MONKEYPTR),y
            jmp actEnd

actCheckUp
            lda pjoy
            and #PJOY_UP
            beq actCheckDown
            LOADANIM(anmclimb)
            ; move player up (if not at y=0 already)
            ldy #PY
            lda (MONKEYPTR),y
            cmp #0
            beq actEnd
            lda (MONKEYPTR),y
            tax
            dex
            txa
            sta (MONKEYPTR),y
            jmp actEnd

actCheckDown
            lda pjoy
            and #PJOY_DOWN
            beq actEnd
            LOADANIM(anmclimb)
            ; move player down (if not at y=21 already)
            ldy #PY
            lda (MONKEYPTR),y
            cmp #21
            beq actEnd
            lda (MONKEYPTR),y
            tax
            inx
            txa
            sta (MONKEYPTR),y

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
            sta SCREENPTR
            lda loc+1
            sta SCREENPTR+1

            lda #<COLOURRAM
            sta loc
            lda #>COLOURRAM
            sta loc+1
            jsr calcXYloc

            ; put to zero page at $fc-$fd
            lda loc
            sta COLOURPTR
            lda loc+1
            sta COLOURPTR+1
            rts

; --------
clearImg2x2
; --------
            jsr prepareScreenPtrs

            ; top-left char
            ldy #PBUFF
            lda (MONKEYPTR),y
            ldy #$00
            sta (SCREENPTR),y

            ldy #PCOLBUFF
            lda (MONKEYPTR),y
            ldy #$00
            sta (COLOURPTR),y

            ; top-right char
            ldy #(PBUFF+1)
            lda (MONKEYPTR),y
            ldy #$01
            sta (SCREENPTR),y

            ldy #(PCOLBUFF+1)
            lda (MONKEYPTR),y
            ldy #$01
            sta (COLOURPTR),y

            ; bot-left char
            tya
            clc
            adc #21
            tay
            sty cimgy ; buffer this somewhere, so we don't lose it

            ldy #(PBUFF+2)
            lda (MONKEYPTR),y
            ldy cimgy
            sta (SCREENPTR),y
            ldy #(PCOLBUFF+2)
            lda (MONKEYPTR),y
            ldy cimgy
            sta (COLOURPTR),y

            ; bot-right char
            iny
            sty cimgy

            ldy #(PBUFF+3)
            lda (MONKEYPTR),y
            ldy cimgy
            sta (SCREENPTR),y

            ldy #(PCOLBUFF+3)
            lda (MONKEYPTR),y
            ldy cimgy
            sta (COLOURPTR),y
            rts

; --------
drawImg
; --------
            pha
            jsr prepareScreenPtrs
            ldy #$00
            lda (SCREENPTR),y ; preserve value written over
            tax
            pla
            sta (SCREENPTR),y

            lda (COLOURPTR),y ; preserve colour value written over
            sta tmp4
            lda color
            sta (COLOURPTR),y
            txa ; return a = char value written over
            ldx tmp4  ; return x = colour value written over
            rts

; --------
drawImg2x2
; --------
            sta drwa
            jsr prepareScreenPtrs

            ; put character here (preserve old character in pbuff and pcolbuff)
            ldy #$00
            sty cimgy

            lda (SCREENPTR),y
            ldy #(PBUFF)
            sta (MONKEYPTR),y

            lda drwa
            ldy cimgy
            sta (SCREENPTR),y

            lda (COLOURPTR),y
            ldy #PCOLBUFF
            sta (MONKEYPTR),y

            lda color
            ldy cimgy
            sta (COLOURPTR),y

            ; draw next char to right
            clc
            lda drwa
            adc #1
            sta drwa

            iny
            sty cimgy

            lda (SCREENPTR),y
            ldy #(PBUFF+1)
            sta (MONKEYPTR),y

            lda drwa
            ldy cimgy
            sta (SCREENPTR),y

            lda (COLOURPTR),y
            ldy #(PCOLBUFF+1)
            sta (MONKEYPTR),y

            lda color
            ldy cimgy
            sta (COLOURPTR),y

            ; draw in bottom-left
            clc
            lda drwa
            adc #1
            sta drwa

            tya
            adc #$15
            tay
            sty cimgy

            lda (SCREENPTR),y
            ldy #(PBUFF+2)
            sta (MONKEYPTR),y

            lda drwa
            ldy cimgy
            sta (SCREENPTR),y
            lda (COLOURPTR),y
            ldy #(PCOLBUFF+2)
            sta (MONKEYPTR),y
            lda color
            ldy cimgy
            sta (COLOURPTR),y

            ; draw in bottom-right
            clc
            lda drwa
            adc #1
            sta drwa

            iny
            sty cimgy

            lda (SCREENPTR),y
            ldy #(PBUFF+3)
            sta (MONKEYPTR),y

            lda drwa
            ldy cimgy
            sta (SCREENPTR),y

            lda (COLOURPTR),y
            ldy #(PCOLBUFF+3)
            sta (MONKEYPTR),y

            lda color
            ldy cimgy
            sta (COLOURPTR),y
            
            rts

;------------
; DATA
;------------
message     .asc "HELLO, WORLD!" : .byt 0
pjoy        .byt 00   ; bit0=left, bit1=right, bit2=up, bit3=down, bit4=fire
loc         .word 0000
color       .byt 00
anmwalk       .byt IMG_WALK1, IMG_WALK2, IMG_WALK3, IMG_WALK2
anmclimb      .byt IMG_CLIMB1, IMG_CLIMB2, IMG_CLIMB3, IMG_CLIMB2
anmthrowright .byt IMG_THROWDOWN3, IMG_THROWDOWN2, IMG_THROWDOWN1, IMG_THROWDOWN2
anmthrowup    .byt IMG_THROWDOWN2, IMG_THROWDOWN1, IMG_THROWUP1, IMG_THROWDOWN1
anmthrowleft  .byt IMG_THROWDOWN1, IMG_THROWUP1, IMG_THROWUP2, IMG_THROWUP1
anmcoconut    .byt IMG_COCONUT1, IMG_COCONUT2, IMG_COCONUT3, IMG_COCONUT2
anmdizzy      .byt IMG_HIT1, IMG_HIT2, IMG_HIT1, IMG_HIT2
keyinpause  .byt 00
tmp1        .byt 00
tmp2        .byt 00
tmp3        .byt 00
tmp4        .byt 00
pctr        .byt 00
cctr        .byt 00
cachx       .byt 00
cachy       .byt 00
cimgy       .byt 00
drwa        .byt 00
ccx         .byt 00
ccy         .byt 00

; --------
; ARRAY OF MONKEY DATA
; --------
#define MONKEYDATA(x,y,col) \
.(: \
/*pvis*/        .byt 01 : \
/*px*/          .byt x : \
/*py*/          .byt y : \
/*pcolour*/     .byt col : \
/*pbuff*/       .dsb 4, 00 : \
/*pcolbuff*/    .dsb 4, 00 : \
/*pfireflag*/   .byt 00 : \
/*pfirebounce*/ .byt 00 : \
/*pfirex*/      .byt 00 : \
/*pfirey*/      .byt 00 : \
/*pfiretime*/   .byt 00 : \
/*pfirebuf*/    .byt 00 : \
/*pfirecolbuf*/ .byt 00 : \
/*panmidx*/     .byt 00 : \
/*pfanmidx*/    .byt 00 : \
/*panimptr*/    .byt 00, 00 : \
/*poldx*/       .byt x : \
/*poldy*/       .byt y :.)

PVIS = 0 ; visibility flag for all characters
PX = 1
PY = 2
PCOLOUR = 3
PBUFF = 4
PCOLBUFF = 8
PFIREFLAG = 12 ; 0 = fire off, 1 = fire left, 2 = fire up, 3 = fire right
PFIREBOUNCE = 13
PFIREX = 14
PFIREY = 15
PFIRETIME = 16 ; how long the fire of the coconut has been active
PFIREBUF = 17 ; what char was written on top of
PFIRECOLBUF = 18 ; what char colour was written on top of
PANMIDX = 19 ; player animation index
PFANMIDX = 20 ; player fire (coconut) index
PANIMPTRLO = 21
PANIMPTRHI = 22
POLDX = 23
POLDY = 24


; Gimme 6 monkeys!
monkey0
MONKEYDATA(4,20,6)
monkey1
MONKEYDATA(4,13,2)
monkey2
MONKEYDATA(18,13,7)
monkey3
MONKEYDATA(2,6,3)
monkey4
MONKEYDATA(10,6,4)
monkey5
MONKEYDATA(17,6,5)

monkeytable
  .word monkey0
  .word monkey1
  .word monkey2
  .word monkey3
  .word monkey4
  .word monkey5

MONKEYDATA_SIZE = monkeytable - monkey0
#print MONKEYDATA_SIZE

endCode

            ; fill to charset
            * = $1a00
            .dsb (*-endCode), 0
            * = $1a00

; During compilation, show how many free bytes are left (to help me keep track of things)
; upper limit of my mem is start of charset, at $1800
FREE_BYTES = $1800 - endCode
#print FREE_BYTES


;------------
; CHARSET
;------------
startCharset
            ; add my unique characters here
            ; currently 464 bytes long (58 chars)
            ; mem range is 1a00 (6656) to 1fd0 (7120)
#include "charset.s"
endCharset
CHARSET_SIZE = endCharset - startCharset
#print CHARSET_SIZE