#!/bin/bash

wine ../Gecko_dNet/powerpc-gekko-as -mregnames fly.asm -o fly.o
wine ../Gecko_dNet/powerpc-gekko-objcopy -O binary fly.o fly.bin

if [ -f fly.o ]; then rm fly.o; fi
