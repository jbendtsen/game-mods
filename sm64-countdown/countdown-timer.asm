; Activate timer (at all times)
; Set timer to 30 seconds on level start
; If Mario is in a level {
;	If a coin is collected, add 5 seconds to the timer
;	If the timer isn't 0 and the game isn't busy (paused/cutscene/textbox), decrement timer
;	If timer is equal to 0, then set health to 0
; }
;
; Variables:
; - Music Tempo: 80222622
; - Textbox and Paused Flags: 80331470
; - Coins: 8033B21A
; - Health: 8033B21E
; - Level status: 8033B26B
; - Timer: 8033B26C
; - Cutscene Timer: 8033CA5C

;-------------------------------------------------------------------------------------------
; Location: Loading HUD attributes - In a level (8024B194) (place at 8024B194)
;-------------------------------------------------------------------------------------------
ORI T2, R0, $007F		; Activate timer (modified instruction)
;-------------------------------------------------------------------------------------------
; Location: Loading HUD attributes - In a level (8024B198) (place at 8033C010)
;-------------------------------------------------------------------------------------------
SW V0, $1000 (T7)		; Save some registers we'll use
SW T0, $1004 (T7)
SW T1, $1008 (T7)
SW T2, $100C (T7)
LUI T0, $8033			; Upper half of an address
LB V0, $1470 (T0)		; Are we reading a textbox?
BNE V0, R0, $B0			; If so, then get out of here, I'm not that cheap
LUI T0, $8034			; Another upper address (should be $8033, but this is MIPS)
LH V0, $CA5C (T0)		; Are we watching a cutscene?
BNE V0, R0, $A4			; If so, same deal as before
LB V0, $C000 (T0)		; Get our custom level status
BNE V0, R0, $4C			; If it hasn't yet been set, set it and start the timer
ORI V0, R0, $0001		; status = 1 (activated and counting down)
SB V0, $C000 (T0)		; Store custom level status to its address
ORI V0, R0, $0384		; timer = 900 frames (30 seconds)
LB T1, $B249 (T0)		; Get level index
ORI T2, R0, $001E		; If it's the first Bowser fight
BEQ T1, T2, $1C			; Go to multiply by 2
ORI T2, R0, $0021		; Else if it's the second Bowser fight
BEQ T1, T2, $14			; Also go to multiply by 2
ORI T2, R0, $0022		; Else if it's the third and final Bowser fight
BEQ T1, T2, $18			; Go to multiply by 4
NOP				; There aren't any coins in the bowser fights, so 30 seconds usually isn't enough
BEQ R0, R0, $14			; Since this level is not a bowser fight, go to store timer and leave
NOP				; The MIPS CPU always executes the instruction after the conditional branch
SLL V0, V0, 0x1			; Multiply timer by 2 ( = 60 seconds)
BEQ R0, R0, $8			; Go to store timer
NOP				; Sometimes it doesn't matter if the instruction after a branch is run, but here it does
SLL V0, V0, 0x2			; Multiply timer by 4 ( = 120 seconds)
SH V0, $B26C (T0)		; Store timer
BEQ R0, R0, $50			; Starting the timer and updating the timer are mutually exclusive events
LH V0, $B26C (T0)		; "But I'm too young to die!" Well, let's check the timer and see...
BNE V0, R0, $C			; If you're a bit slow, then health = 0
NOP
SB R0, $B21E (T0)		; RIP Mario
BEQ R0, R0, $3C			; Well, you've already hit rock bottom, the timer can't go any further down
ORI T1, R0, $0001		; Well done. You win this round.
SUB V0, V0, T1			; One tick per frame, cause I'm not THAT mean
SH V0, $B26C (T0)		; Store the new timer
LUI T1, $8022			; Music tempo address part 1
LH T2, $B26C (T0)		; Get our timer
LH T0, $C002 (T0)		; Get the original tempo again from our safe spot
SH T0, $2622 (T1)		; Store it back to the original address in case we don't end up changing the tempo
ORI V0, R0, $0258		; V0 = 600 frames (20 seconds). So, here's the plan:
SLT T1, T2, V0			; In the last 20 seconds, the tempo gradually increases
BEQ T1, R0, $14			; So if we have >= 20 seconds, then this next part doesn't matter
SUB T2, V0, T2			; But if there's less than 20 seconds left, we subtract the timer from 20 seconds
SLL T2, T2, 0x3			;  and multiply the result by 2^3 (8)
ADD T2, T2, T0			; And then we add THAT to the original tempo
LUI T1, $8022			; (I had to abuse T1 because in MIPS there's no such thing as SUBI)
SH T2, $2622 (T1)		; And store the final result to the real tempo address
LW V0, $1000 (T7)		; Restore our used registers
LW T0, $1004 (T7)
LW T1, $1008 (T7)
LW T2, $100C (T7)
J $8024B1B8			; Go back to the previous routine
;-------------------------------------------------------------------------------------------
; Location: On collecting a coin (8024DB54) (place at 8033C0E0)
;-------------------------------------------------------------------------------------------
SH T0, $00A8 (T6)		; Store coins (original instruction)
SW V0, $1000 (T6)		; Save some registers
LB V0, $00FB (T6)		; Get level status
ANDI V0, V0, $0002		; If it ain't a level
BEQ V0, R0, $2C			;  then restore the registers and get outta here!
LH V0, $00FC (T6)		; Get timer
ADDI V0, V0, $0096		; Add 150 frames (5 seconds) to the timer
ORI T0, R0, $0002		; If it's a red coin
BNE T9, T0, $8			;  then add 2 extra seconds
NOP
ADDI V0, V0, $003C		;  totalling 7 seconds
ORI T0, R0, $0005		; Else if it's a blue coin
BNE T9, T0, $8			;  then add an extra 5 seconds
NOP
ADDI V0, V0, $0096		;  totalling 10 seconds
SH V0, $00FC (T6)		; Store new timer to timer address ($8033B26C)
LH T0, $00A8 (T6)		; Restore our used registers
LW V0, $1000 (T6)
J $8024DB58			; Go back to the previous routine
;-------------------------------------------------------------------------------------------
; Location: Setting new tempo (8031DEB0) (place at 8033C140)
;-------------------------------------------------------------------------------------------
SLL V0, V0, 0x4			; These first three instructions are part the original tempo calculations
SUBU T8, T8, V0			; Finish tempo calculatus
SH T8, $000A (S1)		; Store the new tempo to the official tempo address
BEQ T0, R0, $8			; If T0 = 0, it means we get the wrong tempo
LUI V0, $8034			; V0 is overwritten later, so we can use it as our upper address
SH T8, $C002 (V0)		; Store the new tempo to our tempo address as well
J $8031DEDC			; The code originally unconditionally branches to here anyway
;-------------------------------------------------------------------------------------------
; Location: Loading a level (8024BAA8) (place at 8024BAA8)
;-------------------------------------------------------------------------------------------
SW R0, $C000 (AT)		; Reset our custom level status
;-------------------------------------------------------------------------------------------
; Location: Setting timer to 0 (80249690) (place at 80249690)
;-------------------------------------------------------------------------------------------
NOP				; Thanks, but our timer is fine as it is