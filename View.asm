MSX	equ	1
VDP	equ	98h
SHELL   equ     1

        .8080
        aseg;dseg
        org 9a0h

        cseg
        .phase    103h
include vfile.asm
include vdisp.asm
include vend.asm
        end strt
