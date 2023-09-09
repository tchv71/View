;****************** IBM PC file viewer ******************
;*              Memory allocation module		*
;*(c) TCHV  	       		     7-nov-1991, 2:28 pm*
;********************************************************

malloc	macro	label,size
	public	label
label	equ	ptr
ptr	set	ptr+size
	endm
	cseg

	dseg
ptr	set	$

	malloc	Scr1,1000h	; Screen buffers
	malloc	Scr2,1000h
	malloc	TransTbl,512+1	; Transcode Table + RamDelim
	malloc	RamStart,0

	end
