; ---Notes---
; 80097740: Link's actor code start address
; 801DAA98: Link's velocity address
; 800F1650: Time of day "velocity" address
; 801DB2A0: Link's walk speed address

; 40B00000: Child walk speed
; 41040000: Child backwalk speed
; 40C00000: Adult walk speed
; 41100000: Adult backwalk speed

; Custom Addresses:
; 801612F0: Link's actor code start address
; 801612F4: Current actor code start address if frozen (used for determining whether time is "frozen" or not)

; 1) Disable current actor if it isn't Link, Link isn't moving, Link's sword isn't swinging, we aren't looking around in C-Up mode and we're not watching a cutscene
; 2) Adjust time of day "velocity" to Link's own and mute music if Link isn't moving
; 3) Pause music if Link isn't moving

;;;; .org 800240D8 - 1
jal $80161300

;;;; .org 8005D5E4 - 2
j $80161374

;;;; .org 800C13AC - 3
j $80161408

;;;; .org 80161300 - 1
lw a0,$066c(s2)
lui a1,$2080
ori a1,a1,$0202
and a0,a0,a1
lui a1,$8016
sw r0,$12f4(a1)
bne a0,r0,+$38
lb a0,$0835(s2)
bne a0,r0,+$30
lh a0,$d738(at)
bne a0,r0,+$28
lh a0,$0824(s2)
sltiu a0,a0,$000a
beq a0,r0,+$28
lw a0,$0828(s2)
bne a0,r0,+$14
lw a0,$12f0(a1)
beq t9,a0,+$c
sw t9,$12f4(a1)
jr ra
or a1,s1,r0
jr t9
or a0,s0,r0
lb a0,$0142(s2)
addiu at,r0,$000e
beq a0,at,-$2c
nop
beq r0,r0,-$1c
nop

;;;; .org 80161374 - 2
beq t8,r0,+$c
lhu v0,$1650(v0)
sll v0,v0,1
lui t7,$8016
lui v1,$801e
swc1 f0,$12e0(t7)
swc1 f1,$12e4(t7)
lwc1 f0,$b258(v1)
lui at,$40b8
mtc1 at,f1
div.s f0,f0,f1
mtc1 v0,f1
cvt.s.w f1,f1
mul.s f0,f0,f1
round.w.s f0,f0
mfc1 v0,f0
addu t6,t6,v0
sh t6,$000c(t4)
lwc1 f0,$12e0(t7)
lwc1 f1,$12e4(t7)
lw at,$12f4(t7)
lui t7,$8013
bne at,r0,+$18
lw v1,$8b8c(t7)
beq v1,r0,+$18
lui v1,$3f80
j $8005d620
nop
beq v1,r0,+$1c
or v1,r0,r0
sw v1,$8b8c(t7)
lw v0,$8b60(t7)
lui v1,$0400
or v0,v0,v1
sw v0,$8b60(t7)
j $8005d620
nop

;;;; .org 80161408 - 3
bne s1,s5,+$1c
lhu t6,$0008(s2)
lui t9,$8016
lw t9,$12f4(t9)
beq t9,r0,+$c
nop
or t6,r0,r0
j $800c13b4
