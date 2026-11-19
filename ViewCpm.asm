MSX	equ	1
VDP	equ	98h
;SHELL   equ     1

        .8080
        dseg
        org 0b00h

        cseg
        .phase    103h
include vfile.asm
include vdisp.asm
include vend.asm
        end strt
