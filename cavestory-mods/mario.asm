; These hexadecimal numbers (eg 4190ac) represent addresses in RAM where the code is placed.
; To convert RAM addresses into EXE offsets, simply eliminate the 4 at the front.

# ;4190ac
0x00 | 83 e0 20       | and eax,0x20    ; ensure that this code will run for every enemy. 0x20 is the enemy flag.

# ;418a7b
0x00 | 6a 01          | push 1
0x02 | 51             | push ecx
0x03 | e8 bd 2e 07 00 | call 0x48b940 # ; damage_object(ecx, 1)
0x08 | 83 c4 08       | add esp,8
0x0b | c7 05 70 e6 49 |
     | 00 00 f4 ff ff | mov [0x49e670],-3072 (-0xc00) ; set the player's Y velocity to -3072
0x15 | 31 d2          | xor edx,edx
0x17 | 89 55 fc       | mov [ebp-4],edx ; tell the game that the player was not damaged
0x1b | eb 68          | jmp 0x418aff

# ;48b940: ; damage_object(object_t *enemy, int damage)
0x40 | 8b 44 24 08    | mov eax,[esp+8] ; damage
0x44 | 8b 4c 24 04    | mov ecx,[esp+4] ; enemy object pointer
0x48 | 83 c1 40       | add ecx,0x40 # ; to save instruction space
0x4b | c7 41 5c 10 00 |
     | 00 00          | mov [ecx+0x5c],16 ; set enemy "jiggle" timer to 16
0x52 | 29 41 60       | sub [ecx+0x60],eax ; tell the game that this enemy lost <damage> amount of health
0x55 | 29 01          | sub [ecx],eax ; subtract <damage> from the total health points of the enemy
0x57 | 6a 01          | push 1        ; enable sound effect
0x59 | ff 71 fc       | push [ecx-4]  ; enemy hit sound effect
0x5c | e8 df 4c f9 ff | call 0x420640 ; play_sound_effect(enemy_hit, 1)
0x61 | 83 c4 08       | add esp,8
0x64 | 8b 01          | mov eax,[ecx] ; get the enemy's current health
0x66 | 85 c0          | test eax,eax
0x68 | 7f 07          | jg 0x48b971   ; if it's > 0, jump past this next instruction
0x6a | c7 41 c0 ff 00 |
     | 00 00          | mov [ecx-0x40],0xff ; set the enemy's state to 0xff (killed)
0x71 | c3             | ret
