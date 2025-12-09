;****************** IBM PC file viewer ******************
;*              Memory allocation module		*
;*(c) TCHV  	       		     7-nov-1991, 2:28 pm*
;				     5-dec-2025         *
;********************************************************

malloc	macro	label,size
	;public	label
label	equ	ptr
ptr	set	ptr+size
	endm
	;cseg

	dseg
ptr	set	$

IFNDEF	MSX
	malloc	Scr1,1100h	; Screen buffers
	malloc	Scr2,1100h
ELSE
	malloc	Scr1, 4814
ENDIF
	malloc	TransTbl,512+1	; Transcode Table + RamDelim
ptr	set (ptr/128+1)*128
	malloc	RamStart,0

;	end
