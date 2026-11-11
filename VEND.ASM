;****************** IBM PC file viewer ******************
;*              Memory allocation module		*
;*(c) TCHV  	       		     7-nov-1991, 2:28 pm*
;				     5-dec-2025         *
;********************************************************

	dseg
	.dephase
	.phase 9B0h

fcb:	ds	25h
RamStart:	ds	2
DispldText:	ds	2
RamEnd:		ds	2
FileEnd:	ds	2
BuffStart:	ds	2
BuffEnd:	ds	2
RecSize:	ds	2
StartRec:	ds	2
EndRec:		ds	2
PalmCtrByte:	ds	1
fileSize:	ds	2
fileSizeHi:	ds	1
IFDEF SHELL
fs_cmdLine:	DS	2
fs_selfName:	DS	2
ENDIF

	dseg
ScrAddr:	ds	2
AltScr:		ds	2
RomCounter:	ds	2
RomSet:		ds	1
CurStr:		ds	1
DispHex:	db	0
StrBuf:		ds	ScrWidth
DataEnd:	ds	1

malloc	macro	label,size
	;public	label
label	equ	ptr
ptr	set	ptr+size
	endm

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
	malloc	@RamStart,0

;	end
