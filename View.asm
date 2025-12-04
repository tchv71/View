MSX		equ	1
VDP		equ	98h
        .8080
        dseg
;IFDEF   MSX
        org 0f00h
;ELSE
        org 900h
;ENDIF
        cseg
        .phase    103h
include vfile.asm
include vdisp.asm
include vend.asm
        end strt
