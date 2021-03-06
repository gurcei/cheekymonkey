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
SFXPTR  = $f2   ; pointer to currently playing sound effect
TMPPTR  = $f0

MONKEY_MOVE_WIDTH = 3

#define MLDA(field) ldy #field : lda (MONKEYPTR),y
#define MLSTA(field,val) lda val : ldy #field : sta (MONKEYPTR),y
#define MSTA(field) ldy #field : sta (MONKEYPTR),y

#define LOADSFX(sfx) \
    lda #<sfx : \
    sta SFXPTR : \
    lda #>sfx : \
    sta SFXPTR+1 : \
    lda #$00 : \
    sta sfxtmr

#define ADD16(ptr,val) \
    clc : \
    lda val : \
    adc ptr : \
    sta ptr : \
    lda #$00 : \
    adc ptr+1 : \
    sta ptr+1


CHROUT   = $FFD2             ; Output character to current output device
PLOT     = $FFF0             ; Set (clc) or get (sec) cursor position

            .byt  $01, $10    ; Load address ($1001)

            * = $1001
            .word basicEnd    ; Next Line link, here end of Basic program
            .word 2020        ; The line number for the SYS statement
            .byt  TOK_SYS     ; SYS token
            .asc  " "
            .asc  "4110"      ; Start of machine language (0x1036)
            .byt  0           ; End of Basic line
basicEnd    .word 0           ; End of Basic program

; ----------
; INIT
; ----------
            ; turn on volume
            lda #15
            sta $900e
            ; switch on current state
stateloop
            ; no longer copying first 512 bytes of charset (the alphanumerics), to save 512 bytes ;)
            
            ; State Machine
            ; -------------
            
            ; Title Screen?
            lda state
            bne checkStateGame
            jsr stateGameTitle
            jmp stateloop
            
            ; Game
checkStateGame
            cmp #STATE_GAME
            bne initGameOver
            jsr stateGame
            jmp stateloop
            
            ; Game Over
initGameOver
            jsr stateGameOver
            
            jmp stateloop


; -------
getCurrentMonkeyAnim
; -------
; Copy Anim from Monkey's PANIMPTRLO/HI to ANIMPTR in zero-page
  MLDA(PANIMPTRLO)
  sta ANIMPTR
  MLDA(PANIMPTRHI)
  sta ANIMPTR+1
  rts

; -------
loadAnim
; -------
  MSTA(PANIMPTRLO)
  sta ANIMPTR
  txa
  MSTA(PANIMPTRHI)
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

; ------------
drawGrass
; ------------
    ldx tmp1
    lda #IMG_GRASS
    jsr drawImg
    rts

; ------------
drawGameScreen
; ------------
            ; clear the screen
            lda #147
            jsr CHROUT

            lda #00
            sta tmp1
            lda #05 ; green
            sta color

grassloop
            ; lower layer
            ldy #22
            jsr drawGrass

            ; mid layer
            ldy #15
            jsr drawGrass

            ; top layer
            ldy #8
            jsr drawGrass

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
            MLDA(PFIREFLAG)
            beq dfskip

            lda #$00
            sta color ; coconuts are black

            ; figure out coconut frame
            MLDA(PFANMIDX)
            cmp #$03
            bne dfanmcnt
            sec
            sbc #02
dfanmcnt
            clc
            adc #IMG_COCONUT1
            sta tmp4    ; store the desired coconut frame here
            
            ldy #PFIREX
            lda (MONKEYPTR),y
            tax

            ldy #PFIREY
            lda (MONKEYPTR),y
            tay

            lda tmp4
            jsr drawImg
            pha
            
            ; advance coconut-frame
            MLDA(PFANMIDX)
            clc
            adc #$01
            cmp #$04
            bne dfanmcnt2
            lda #$00
dfanmcnt2
            MSTA(PFANMIDX)

            ; update screen+colour buffer info for coconut
            pla
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
            
            lda state
            cmp #STATE_GAME
            beq m2
            ldx#$60
m2
            ldy#$00
m1
            dey
            bne m1

            dex
            bne m2
            
            ; playing sfx?
            ldy sfxtmr
            cpy #$ff
            beq mldend
            
            ; play sound on voice1
            lda (SFXPTR),y
            sta $900a
            bne mldcont
            lda #$ff
            sta sfxtmr
            rts
            
mldcont
            cmp #$02    ; this value means to repeat
            bne mldcont2
            ldy #$00
            sty sfxtmr
            rts
            
mldcont2
            inc sfxtmr
            
            
mldend
            rts

; ---------
clearCoconuts
; ---------
            lda #$05
            sta pctr

cfloop
            LOADMONKEY

            ; is fireflag clear? then skip
            MLDA(PFIREFLAG)
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

            ; is fireflag clear? then skip
            MLDA(PFIREFLAG)
            bne afcont
            jmp afskip

afcont
            ; handle horizontal
            MLDA(PFIREFLAG)

            ; fire left?
            ; ----------
            cmp #PFIREFLAG_LEFT
            bne af4

            MLDA(PFIREBOUNCE)
            beq afl1
            MLDA(PFIREX)
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
            ; -----------
af4
            MLDA(PFIREFLAG)
            cmp #PFIREFLAG_RIGHT
            bne afrd0

            MLDA(PFIREBOUNCE)
            beq afr1

            MLDA(PFIREX)
            sec
            sbc #$01
            sta (MONKEYPTR),y
            clc
            jmp afrd0

afr1
            MLDA(PFIREX)
            clc
            adc #$01
            sta (MONKEYPTR),y
            
            cmp #21
            bne afrd0

            ; if x=21, then set bounce flag
            MLSTA(PFIREBOUNCE, #01)
     
            ; fire down?
            ; ----------
afrd0
            MLDA(PFIREFLAG)
            cmp #PFIREFLAG_DOWN
            bne af5

            MLDA(PFIRETIME)
            clc
            adc #$01
            sta (MONKEYPTR),y
            
            MLDA(PFIREY)
            clc
            adc #$01
            sta (MONKEYPTR),y
            
            MLDA(PFIRETIME)
            cmp #07
            bne afskip
            MLSTA(PFIREFLAG, #PFIREFLAG_OFF)
            jmp afskip

            ; otherwise fire up
            ; -----------------
af5
            MLDA(PFIRETIME)
            clc
            adc #$01
            sta (MONKEYPTR),y

            ; handle vertical
            cmp #$06
            bcs af1

            MLDA(PFIREY)
            sec
            sbc #$01
            clc
            sta (MONKEYPTR),y
            jmp af2
af1
            MLDA(PFIREY)
            clc
            adc #$01
            sta (MONKEYPTR),y
af2
            MLDA(PFIRETIME)
            cmp #$0d
            bne af3
            MLSTA(PFIREFLAG, #PFIREFLAG_OFF)

af3
afskip
            inc pctr
            lda pctr
            cmp #06
            beq afend
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
            MLDA(PVIS)
            bne cc0
            rts

cc0
            ; check collision between all coconuts and this player
            MLDA(PX)
            tax
            stx ccx

            MLDA(PY)
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
            LOADSFX(sfxdizzy)
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
            
            lda #$03
            sta lives

            MLSTA(PX, #02)
            MLSTA(PY, #20)
            
            ; common initialisation for all monkeys
            
imloop
            LOADMONKEY
            
            MLSTA(PFIREFLAG, #00)

            MLSTA(PVIS, #01)
            
            LOADANIM(anmwalk)

            inc pctr
            lda pctr
            cmp #06
            bne imloop

imend
            rts

; ----------
actEnemyFire
; ----------
            ; has the monkey already expired? then skip
            MLDA(PVIS)
            beq aefend
            
            ; is the monkey's coconut already thrown?
            MLDA(PFIREFLAG)
            bne aefend

            ; is player monkey within y-range?
            lda pposy
            ldy #PY
            sec
            sbc (MONKEYPTR),y
            cmp #08
            bcs aefend
            
            ; initialise a few coconut vars in preparation
            MLSTA(PFIRETIME, #00)
            MSTA(PFIREBOUNCE)

            ; fire a coconut simply downwards for now
            LOADSFX(sfxthrowdown)
            LOADANIM(anmthrowdown)
            MLSTA(PFIREFLAG, #PFIREFLAG_DOWN)
            
            jsr initPlayerFire

            ; adjust enemy coconut starting position
            MLDA(PY)
            clc
            adc #$02
            MSTA(PFIREY)
            
            jmp actEnd

aefend
            rts
            

; ----------
moveEnemyMonkey
; ----------
            jsr actEnemyFire

            ldy #PMVT
            lda (MONKEYPTR),y
            cmp #MONKEY_MOVE_WIDTH
            bcs mem23

mem01       ; move to left
            ldy #PX
            lda (MONKEYPTR),y
            tax
            dex
            txa
            sta (MONKEYPTR),y
            jmp memincmvt
            
mem23       ; move to right
            ldy #PX
            lda (MONKEYPTR),y
            tax
            inx
            txa
            sta (MONKEYPTR),y
            
memincmvt
            ; now increment mvt timer
            ldy #PMVT
            lda (MONKEYPTR),y
            tax
            inx
            cpx #(MONKEY_MOVE_WIDTH*2)
            bne memskipreset
            ldx #$00
            
memskipreset
            txa
            sta (MONKEYPTR),y
            rts

; ----------
assessDizzy
; ----------
            MLDA(PDIZZYCNT)
            tax
            inx
            txa
            sta (MONKEYPTR),y
            
            cpx #$04        ; have we been dizzy for long enough?
            bne assdizend
            
            lda #$00        ; reset the dizzy counter
            sta (MONKEYPTR),y
            
            LOADANIM(anmwalk)
            
            lda pctr    ; if player, skip over these extra initialisations
            beq assdizplayer
                        
assdizenemy
            MLSTA(PVIS, #00)
            
            ; clear the last frame of the monkey
            MLDA(POLDX)
            tax

            MLDA(POLDY)
            tay

            jsr clearImg2x2
            jmp assdizend

assdizplayer
            dec lives
            lda lives
            bne assdizend
            lda #STATE_GAMELOSE
            sta state
assdizend
            rts
            
; ----------
animateMonkeys
; ----------
            lda #$00
            sta pctr

anmmloop
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
            
            ; don't move monkey if pause-time not reached yet
            ldx keyinpause
            cpx #$02
            bne anmmskip

            ; don't move monkey if he's dizzy
            MLDA(PANIMPTRLO)
            cmp #<anmdizzy
            bne anmmmove
            
            MLDA(PANIMPTRHI)
            cmp #>anmdizzy
            bne anmmmove
            
            jsr assessDizzy
            jmp anmmskip
            
anmmmove
            lda pctr    ; is this 1st monkey?
            bne anmmenemy
            
            ; then move it based on joystick
            jsr actOnJoystickInput
            jmp anmmskip

anmmenemy
            ; move individual enemy monkeys
            jsr moveEnemyMonkey
            
anmmskip
            inc pctr
            lda pctr
            cmp #06
            bne anmmloop
            
anmmincpause
            ldx keyinpause
            inx
            cpx #$03
            bne anmmskipreset
            ldx #$00
anmmskipreset
            stx keyinpause
            rts

#define OUTTEXT(txt) \
    lda #<txt : \
    sta $fe : \
    lda #>txt : \
    sta $ff : \
    jsr outText
    
; ------
outText
; ------
            ldy #$00
otloop
            lda ($fe),y
            beq otend
            jsr CHROUT
            iny
            bne otloop
otend
            rts

; ----------
ldtmpptr
; ----------
    sta TMPPTR
    stx TMPPTR+1
    rts

; ----------
ldanim
; ----------
            jsr ldtmpptr
            
            inc tmp3
            lda #$01
            and tmp3
            beq cja2
            
            ADD16(TMPPTR, #32)

cja2
            jsr drawImgJumbo
            jsr loopDelay
            rts


; ----------
checkJumboAnim
; ----------
            lda state
            cmp #STATE_GAMEWIN
            bne cjacheck2
            
            lda #<throwup1
            ldx #>throwup1
            jsr ldanim
            rts

cjacheck2
            cmp #STATE_GAMELOSE
            bne cjacheck3
            
            lda #<hit1
            ldx #>hit1
            jsr ldanim            
            rts

cjacheck3
            cmp #STATE_TITLE
            bne cjaend

            lda #<walk1
            ldx #>walk1
            jsr ldanim
            
cjaend
            rts


; ----------
waitFire
; ----------
sgtwaitfiredown
            jsr loopDelay
            jsr getJoystickInput
            jsr checkJumboAnim
            lda pjoy
            and #PJOY_FIRE
            beq sgtwaitfiredown

sgtwaitfireup
            jsr getJoystickInput
            lda pjoy
            and #PJOY_FIRE
            bne sgtwaitfireup
            
            lda #STATE_GAME
            sta state
            rts

; ----------
; STATE: TITLE
; ----------
stateGameTitle
            ; move character set back to original character rom
            lda #240
            sta $9005

            OUTTEXT(message)
            LOADSFX(sfxtitle)
            
            jsr waitFire

            rts

; ----------
; STATE: GAME
; ----------
stateGame
            ; move character set to ram at 6144
            lda #$fe
            sta $9005

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

            lda state
            cmp #STATE_GAME
            bne endgame

            jmp mainloop
            
endgame
            rts

; ----------
; STATE: GAMEOVER
; ----------
stateGameOver
            ; move character set back to original character rom
            lda #240
            sta $9005

            lda state
            cmp #STATE_GAMEWIN
            bne sgolose
            OUTTEXT(winmsg)
            LOADSFX(sfxwin)
            jmp sgocont

            lda #BLUE
            sta color

sgolose
            OUTTEXT(losemsg)
            LOADSFX(sfxlose)

sgocont

            jsr waitFire
            
            lda #STATE_TITLE
            sta state

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

            MLDA(PX)
            tax
            inx
            txa
            MSTA(PFIREX)

            MLDA(PY)
            tay
            dey
            tya
            MSTA(PFIREY)

            MLSTA(PFIRETIME, #00)
            rts


; --------
actOnJoystickInput
; --------
            MLDA(PY)
            sta pposy      ; store player's y-pos somewhere to compare against enemies

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
            MLDA(PFIREFLAG)
            bne actCheckLeft

            ; initialise a few coconut vars in preparation
            lda #$00
            ldy #PFIRETIME
            sta (MONKEYPTR),y
            ldy #PFIREBOUNCE
            sta (MONKEYPTR),y
            
            ; play coconut throw up sfx
            LOADSFX(sfxthrowup)

actCheckFireRight
            lda pjoy
            and #PJOY_RIGHT
            beq actCheckFireLeft
            LOADANIM(anmthrowright)
            MLSTA(PFIREFLAG, #PFIREFLAG_RIGHT)
            
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
            MLSTA(PFIREFLAG, #PFIREFLAG_LEFT)
            jsr initPlayerFire
            jmp actEnd

actFireOnly
            LOADANIM(anmthrowup)
            MLSTA(PFIREFLAG, #PFIREFLAG_UP)
            jsr initPlayerFire
            jmp actEnd

actCheckLeft
            ; confirm we are on either platform
            MLDA(PY)
            cmp #20
            beq aclcont
            cmp #13
            beq aclcont
            jmp actCheckUp
            
aclcont
            lda pjoy
            and #PJOY_LEFT
            beq actCheckRight
            LOADANIM(anmwalk)
            ; move player left (if not at x=0 already)
            ldy #PX
            lda (MONKEYPTR),y
            beq actCheckRight
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
            beq actCheckUp
            lda (MONKEYPTR),y
            tax
            inx
            txa
            sta (MONKEYPTR),y
            jmp actEnd
            
actCheckUp
            ; check right ladder range
            MLDA(PX)
            cmp #18
            bne acuCheckLeftLadder
            MLDA(PY)
            cmp #14
            bcc acuCheckLeftLadder
            jmp acuCont
acuCheckLeftLadder
            MLDA(PX)
            cmp #02
            bne actCheckDown
            MLDA(PY)
            cmp #07
            bne acul1
            lda #STATE_GAMEWIN
            sta state
acul1
            cmp #07
            bcc actCheckDown
            cmp #15
            bcs actCheckDown
acuCont
            lda pjoy
            and #PJOY_UP
            beq actCheckDown
            ; start climb anim
            LOADANIM(anmclimb)
            ; move player up (if not at y=0 already)
            MLDA(PY)
            cmp #6
            beq actEnd
            lda (MONKEYPTR),y
            tax
            dex
            txa
            sta (MONKEYPTR),y
            jmp actEnd

actCheckDown
            ; check right ladder range
            MLDA(PX)
            cmp #18
            beq acdCont
acdCheckLeftLadder
            cmp #02
            bne actEnd
            MLDA(PY)
            cmp #13
            bcs actEnd
acdCont
            cmp #18
            lda pjoy
            and #PJOY_DOWN
            beq actEnd
            ; start climb anim
            LOADANIM(anmclimb)
            ; move player down (if not at y=21 already)
            MLDA(PY)
            cmp #20
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

JUMBOX = $04
JUMBOY = $06

; -----------
drawJumboIter
; -----------
            jsr prepareScreenPtrs
            jsr drawJumboChar
            ADD16(TMPPTR, #8)
            rts

; -----------
drawImgJumbo
; -----------
            ldx #JUMBOX
            ldy #JUMBOY
            jsr drawJumboIter

            ldx #JUMBOX + 8
            ldy #JUMBOY
            jsr drawJumboIter
            
            ldx #JUMBOX
            ldy #JUMBOY + 8
            jsr drawJumboIter

            ldx #JUMBOX + 8
            ldy #JUMBOY + 8
            jsr drawJumboIter

            rts

            
; -----------
drawJumboChar
; -----------
            ; draw first row of char
            ldy #$00
            sty cimgy

            lda #08
            sta tmp4    ; tmp4 = row-count of char

dijDoRowsInCharLoop

            ldy cimgy       ; cimgy = byte-index into current char's char-data
            lda (TMPPTR),y
            
            ldx #08
            ldy #00
dijDoBitsInRowLoop
            rol
            pha
            lda #$a0        ; solid reverse char
            bcs dijCont
dijDoClear
            lda #$20        ; blank space char
dijCont
            sta (SCREENPTR),y
            lda #06
            sta (COLOURPTR),y
            pla
            
            iny
            dex
            bne dijDoBitsInRowLoop
            
            ADD16(SCREENPTR, #22)
            ADD16(COLOURPTR, #22)
            inc cimgy
            lda tmp4
            sec
            sbc #$01
            sta tmp4
            bne dijDoRowsInCharLoop
            
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

CLS = $93
BLACK = $90
GREEN = $1e
BLUE = $1f
RIGHT = $1d
DOWN = $11
RETURN = $0d

;------------
; DATA
;------------
message     .byt CLS, GREEN, DOWN, RIGHT, RIGHT, RIGHT
            .asc "CHEEKY MONKEY"
            .byt RETURN, DOWN, RIGHT, BLUE
            .asc "(C) GURCE ISIKYILDIZ"
            .byt RETURN, DOWN, RIGHT, RIGHT, RIGHT, RIGHT, RIGHT, BLACK
            .asc "PRESS FIRE"
            .byt 0
winmsg      .byt CLS, GREEN, DOWN, DOWN, DOWN
            .asc "YOU WIN THE BIG BANANA"
            .byt 00
losemsg     .byt CLS, GREEN, DOWN, DOWN, DOWN, RIGHT, RIGHT, RIGHT, RIGHT, RIGHT, RIGHT, RIGHT, RIGHT
            .asc "LOSER!"
            .byt 00
pjoy        .byt 00   ; bit0=left, bit1=right, bit2=up, bit3=down, bit4=fire
loc         .word 0000
color       .byt 00
anmwalk       .byt IMG_WALK1, IMG_WALK2, IMG_WALK3, IMG_WALK2
anmclimb      .byt IMG_CLIMB1, IMG_CLIMB2, IMG_CLIMB3, IMG_CLIMB2
anmthrowright .byt IMG_THROWDOWN3, IMG_THROWDOWN2, IMG_THROWDOWN1, IMG_THROWDOWN2
anmthrowup    .byt IMG_THROWDOWN2, IMG_THROWDOWN1, IMG_THROWUP1, IMG_THROWDOWN1
anmthrowdown  .byt IMG_THROWDOWN1, IMG_THROWDOWN2, IMG_THROWDOWN3, IMG_THROWDOWN2
anmthrowleft  .byt IMG_THROWDOWN1, IMG_THROWUP1, IMG_THROWUP2, IMG_THROWUP1
anmcoconut    .byt IMG_COCONUT1, IMG_COCONUT2, IMG_COCONUT3, IMG_COCONUT2
anmdizzy      .byt IMG_HIT1, IMG_HIT2, IMG_HIT1, IMG_HIT2
sfxthrowup    .byt 240, 242, 244, 246, 0
sfxdizzy      .byt 210, 208, 206, 204, 0
sfxthrowdown  .byt 220, 218, 216, 214, 0
sfxtitle      .byt 195, 1, 195, 235, 225, 235
              .byt 195, 1, 195, 235, 225, 235
              .byt 195, 1, 195, 237, 225, 237
              .byt 195, 1, 195, 237, 225, 237
              .byt 195, 1, 195, 239, 225, 239
              .byt 195, 1, 195, 239, 225, 239
              .byt 195, 1, 195, 240, 225, 240
              .byt 195, 1, 195, 240, 225, 240
              
              .byt 195, 1, 195, 235, 232, 231
              .byt 195, 1, 195, 235, 237, 235
              .byt 195, 1, 195, 237, 235, 232
              .byt 195, 1, 195, 237, 239, 237
              .byt 195, 1, 195, 239, 237, 235
              .byt 195, 1, 195, 239, 240, 239
              .byt 195, 1, 195, 240, 235, 231
              .byt 195, 1, 195, 215, 219, 225
              .byt 2
              
sfxwin        .byt 225, 215, 225, 231, 225, 231, 235, 231, 235, 240, 240, 240, 0
sfxlose       .byt 235, 237, 235, 232, 235, 232, 231, 232, 231, 228, 231, 228, 225, 225, 0
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
pposy       .byt 00
state       .byt $00
    STATE_TITLE = $00
    STATE_GAME  = $01
    STATE_GAMEWIN = $02
    STATE_GAMELOSE = $03
sfxtmr      .byt $ff     ; $ff = flag for sfx not currently playing
lives       .byt 3

; --------
; ARRAY OF MONKEY DATA
; --------
#define MONKEYDATA(x,y,col,mvt) \
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
/*poldy*/       .byt y : \
/*pmvt*/        .byt mvt : \
/*pdizzycnt*/   .byt 0 :.)

PVIS = 0 ; visibility flag for all characters
PX = 1
PY = 2
PCOLOUR = 3
PBUFF = 4
PCOLBUFF = 8
PFIREFLAG = 12
    PFIREFLAG_OFF = 0
    PFIREFLAG_LEFT = 1
    PFIREFLAG_UP = 2
    PFIREFLAG_RIGHT = 3
    PFIREFLAG_DOWN = 4
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
PMVT = 25 ; this is a movement timer (0,1 are moves to the left, 2,3 are moves to the right, and then it cycles)
PDIZZYCNT = 26 ; a counter for how long player has been dizzy


; Gimme 6 monkeys!
monkey0
MONKEYDATA(4,20,6,0)
monkey1
MONKEYDATA(4,13,2,1)
monkey2
MONKEYDATA(17,13,5,2)
monkey3
MONKEYDATA(2,6,3,3)
monkey4
MONKEYDATA(10,6,4,2)
monkey5
MONKEYDATA(17,6,7,1)

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
            * = $1c00
            .dsb (*-endCode), 0
            * = $1c00

; During compilation, show how many free bytes are left (to help me keep track of things)
; upper limit of my mem is start of my custom charset chars, at $1c00
; (not $1800 anymore, as I'm forgoing the alphanumerics and a bit beyond, to save space ;))
FREE_BYTES = $1c00 - endCode
#print FREE_BYTES


;------------
; CHARSET
;------------
startCharset
            ; add my unique characters here
            ; currently 464 bytes long (58 chars)
            ; mem range is 1c00 (7168) to 1fd0 (7120)
#include "charset.s"
endCharset
CHARSET_SIZE = endCharset - startCharset
#print CHARSET_SIZE