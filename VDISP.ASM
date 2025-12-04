;****************** IBM PC file viewer ******************
;*       Displaying module   -    Radio-86rk version 	*
;*(c) TCHV  	       		     7-nov-1991, 2:00 pm*
;*  Display 8275 and DMA 8257 controllers are required	*
;********************************************************

;	16-Feb-1992 - change Ram_Start to be variable

ScrWidth	equ	80
IFNDEF	MSX
ScrHeight	equ	24
ELSE
ScrHeight	equ	30
ENDIF
	cseg

; Global routines (see apropriate def. for more info)
	;public	DispInit	; Initialise displaying
	;public	DisplyScr	; Display a screen of text

; External adresses
	;extrn	Scr1,Scr2,TransTbl
; External variable
	;extrn	Ram_Start
; Text delimiters
	;extrn	RamDelim
	;extrn	BuffDelim
; External routines
	;extrn	RdAtEnd	; Read next portion at and of
			; ram buffer
_in:	INR	H
	DCR	H
	JZ	_in_port
	MOV	A,M
	RET
_in_port:
	MOV	A,L
	STA	$+4
	IN	0
	RET

_out:	INR	H
	DCR	H
	jz	_out_port
	MOV	M,A
	RET
_out_port:
	PUSH	PSW
	MOV	A,L
	STA	$+5
	POP	PSW
	OUT	0
	RET

SetPalmCtr:
	mov	c,a
	LHLD	PALM_CTR_ADR
	mov	a,h
	ora	l
	rz
	mov	a,c
	jmp	_out


; Note: this routine should be called once at start of program
DispInit:
	mvi	a,80h+10h
	sta	PalmCtrByte
	call	SetPalmCtr

	lxi	h,0
	shld	RomCounter
IFNDEF	MSX
	lxi	h,Scr1
	shld	ScrAddr
	lxi	h,Scr2
	shld	AltScr
	call	ClrScr
	call	ChgScrAddr
	call	ClrScr
	call	SetScr
ELSE
	call	ClrScr
ENDIF
	lxi	h,TransTbl
	mvi	c,0
@init0:	mov	a,c
	;call	TransSym
	cpi	0bah
	jnz	@init1
	mvi	a,'-'
@init1:
	mov	m,a
	inx	h
	call	CharSet
	mov	m,b
	inx	h
	inr	c
	jnz	@init0
	ret

ChgScrAddr:
	lhld	ScrAddr
	xchg
	lhld	AltScr
	shld	ScrAddr
	xchg
	shld	AltScr
	ret


IFDEF	MSX
ClrScr:	lxi	h,0
	;call	ClrScr2
ClrScr2:
	mov	a,l
	out	VDP+1
	mov	a,h
	ori	40h
	out	vdp+1
	lxi	b,ScrWidth*ScrHeight
ClrLp:	xra	a
	out	VDP
	mvi	a,4fh
	out	VDP
	dcx	b
	mov	a,b
	ora	c
	jnz	ClrLp
	ret
ELSE
ClrScr:	lhld	ScrAddr
	lxi	b,1000h
ClrLp:	mvi	m,0
	inx	h
	dcx	b
	mov	a,b
	ora	c
	jnz	ClrLp
	ret
ENDIF
;	.	.	.	.	.	.	.
; Display the screen from HL - pointer to the text
DisplyScr:
IFDEF	MSX
	xra	a
	out	VDP+1
	ori	40h
	out	VDP+1
	lxi	b,8154h ; Set increment by one
	mov	a,c
	out	VDP+1
	mov	a,b
	out	vdp+1
	jmp	DsplScr
SaveScreen:
	lxi	h,Scr1
	LXI	D, 0F759h
	LXi	B, ScrWidth * ScrHeight * 2
	xra	a
	out	VDP+1
	out	VDP+1
SS01:
	IN	VDP
	mov	m,a
	inx	h
	dcx	b
	mov	a,b
	ora	c
	jnz	SS01
	mvi	c, 13
ss02:
	ldax	d
	inx	d
	mov	m,a
	inx	h
	dcr	c
	jnz	ss02
	ret
RestoreScreen:
	lxi	h,Scr1
	LXI	D, 0F759h
	LXi	B, ScrWidth * ScrHeight * 2
	xra	a
	out	VDP+1
	ori	40h
	out	VDP+1
rs01:
	mov	a,m
	inx	h
	out	VDP
	dcx	b
	mov	a,b
	ora	c
	jnz	rs01
	mvi	c, 13
rs02:
	mov	a, m
	inx	h
	stax	d
	inx	d
	dcr	c
	jnz	rs02
	ret
ELSE
	call	DsplScr
	call	SetDma
	jmp	ChgScrAddr
ENDIF

; Variables and registers:
;	hl - screen pointer
;	de - text pointer
;	b - symbols to end of line
;	c - not used (globally)
;	RomSet - ROM set for current chain
;	CurStr - lines to end of screen
DsplScr:xchg
	lxi	h,0
	shld	RomCounter
	lhld	ScrAddr
	lxi	b,3*ScrWidth
	dad	b
	mvi	a,ScrHeight
	sta	CurStr
	mvi	b,ScrWidth
loop:	push	h
	call	FirstPass
	lhld	RomCounter
	inx	h
	shld	RomCounter
	pop	h
	push	psw
	call	SecondPass
	pop	psw
	jnc	loop
IFNDEF	MSX
	mvi	b,2*ScrWidth
_ClrEnd:mvi	m,0
	inx	h
	dcr	b
	jnz	_ClrEnd
ENDIF
	ret

; The first pass - Transcode symbol's
;		 - Output them to the screen (translate CR/LF)
;		 - Determine ROM code for this chain
;		 - Terminate chain
TrnsSym	macro
	push	h
	push	d
	lxi	h,TransTbl
	mov	e,a
	mvi	d,0
	dad	d
	dad	d
	mov	a,m
	inx	h
	mov	c,m
	pop	d
	pop	h
	endm

FirstPass:
IFNDEF	MSX
	inx	h	; Reserve space for ROM selection byte
	mvi	a,0fh
	sta	RomSet	; Initial set of ROMs for this chain
ENDIF
	lda	DispHex
	ora	a
	jz	NextSym

	mvi	b, ScrHeight
	lxi	h,4000h
	mov	a,l
	out	VDP+1
	mov	a,h
	out	VDP+1
dh_s:
	push	d
	mvi	c,16
	lhld	BuffStart
	call	SubDE_HL
	jnc	dh00

	lhld	BuffEnd
	xchg
	lhld	Ram_Start
	call	SubDE_HL

	lhld	RamEnd
	mov	a, l
	add	l
	mov	e, a
	mov	a, h
	adc	d
	mov	d, a

	lhld	BuffStart
	call	SubDE_HL
dh00:
	lhld	StartRec
	mov	a,l
	rlc
	ani	128
	add	e
	mov	e,a
	jnc	$+4
	inr	d
	mov	a,l
	rrc
	ani	7fh
	adc	d
	mov	d,a
	mov	a,h
	rrc
	lxi	h,StrBuf
	call	ByteHexToBuf
	mov	a,d
	call	ByteHexToBuf
	mov	a,e
	call	ByteHexToBuf
	mvi	m, 0
	inx	h
	pop	d
	push	d
dh01:	ldax	d
	inx	d
	call	ByteHexToBuf
	mvi	m, 0
	inx	h
	dcr	c
	jnz	dh01
	pop	d
	mvi	c,16
dh02:	ldax	d
	inx	d
	cpi	20h
	jnc	$+5
	mvi	a, '.'
	mov	m, a
	inx	h
	dcr	c
	jnz	dh02

	push	d
	mvi	c,71
	xchg
	lhld	ScrAddr
	xchg
	lxi	d, StrBuf
dh03:	ldax	d
	inx	d
	out	VDP
	dcr	c
	jnz	dh03
	mvi	c,9
	call	ClrLine
	pop	d
	ldax	d
	cpi	RamDelim
	jnz	dh04
	xchg
	lhld	Ram_Start
	xchg
dh04:
	cpi	BuffDelim
	jnz	dh05 ; Read next record of file
	call	_eb01
dh05:
	lhld	FileEnd
	call	?cdehl
	jz	dh06
IF 0
	push	b
	lhld	ScrAddr
	lxi	b, ScrWidth
	dad	b
	pop	b
	shld	ScrAddr
ENDIF
	dcr	b
	jnz	dh_s
	stc
	ret

dh06:	mvi	c,ScrWidth
	call	ClrLine
	dcr	b
	jnz	dh06
	stc
	ret

ClrLine:
	xra	a
dh07:
	out	VDP
	dcr	c
	jnz	dh07
	ret

ByteHexToBuf:
	push	psw
	rrc
	rrc
	rrc
	rrc
	call	bhtb_dig
	pop	psw
bhtb_dig:
	ani	0Fh
	cpi	10
	jc	bhtb01
	adi	7
bhtb01:
	adi	'0'
	mov	m, a
	inx	h
	ret

SubDE_HL:
	mov	a, e
	sub	l
	mov	e, a
	mov	a, d
	sbb	h
	mov	d, a
	ret

	
NextSym:ldax	d
	inx	d
	cpi	20h
	jnc	SetSym
	cpi	9h
	jz	_Tab
	cpi	0dh
	jz	_EndStr
	cpi	0ah
	jz	NextSym	; Skip LF symbol
	cpi	RamDelim
	jz	_EndRam
	cpi	BuffDelim
	jz	_EndBuff ; Read next record of file
	cpi	1ah
	jnz	StSym
IFNDEF	MSX
	mvi	m,20h
ELSE
	mvi	a, 20h
	OUT	VDP
	;mvi	a, 4fh
	;out	VDP
ENDIF
	inx	h
	dcx	d
	dcr	b
	jz	_NxtStr
	jmp	NextSym
StSym:	mvi	a,20h	; Other CNTRL symbols are not displayed
SetSym:	;TrnsSym	; a = Translated symbol , c=its ROM set
IFNDEF	MSX
	mov	m,a
	lda	RomSet
	ana	c
	jz	_EndChain
	sta	RomSet
ELSE
	OUT	VDP
	;mvi	a, 4fh
	;out	VDP
ENDIF
	inx	h
	dcr	b
	jnz	NextSym
	jmp	_NxtStr

_EndStr:inr	b
	dcr	b
	jz	_NxtStr
_SetEnd:
IFNDEF	MSX
	mvi	m,20h	; We can freely fill with space
	inx	h
ELSE
	mvi	a, 20h
	out	VDP
	;mvi	a,4fh
	;out	VDP
ENDIF
	dcr	b
	jnz	_SetEnd

_NxtStr:mvi	b,ScrWidth
	lda	CurStr
	dcr	a
	sta	CurStr
	jnz	NextSym
IFNDEF	MSX
	mvi	m,0	; Terminate chain
ENDIF
	stc	; The end of screen
	ret

_EndRam:xchg
	lhld	Ram_Start
	xchg
	jmp	NextSym

_EndBuff:
	call	_eb01
	jnz	SetSym
	jmp	NextSym

_eb01:
	push	h
	lhld	BuffEnd
	dcx	d
	call	?cdehl
	inx	d
	mvi	a,BuffDelim
	pop	h
	rnz;jnz	SetSym

	call	RdAtEnd
	dcx	d
	xra	a
	ret

_Tab:	mov	a,b
	dcr	a
  	ani	7
	inr	a
_SetTab:
IFNDEF	MSX
	mvi	m,20h	;   Space is located in any ROM
ELSE
	mvi	a, 20h
	OUT	VDP
	;mvi	a, 4fh
	;OUT	VDP
ENDIF
	inx	h	; and current ROM set are to be
	dcr	b	; unchanged
	jz	_NxtStr
	dcr	a
	jnz	_SetTab
	jmp	NextSym

_EndChain:
IFNDEF	MSX
	mvi	m,0	; Terminate chain
	dcx	d	; ungetc last symbol
ENDIF
	ora	a	; Clear cy - not the end of screen
	ret

;****************************************************
; The second pass - translate intermediate codes
;		    into screen codes
SecondPass:
IFDEF	MSX
	ret
ELSE
	lda	RomSet
	call	GetRomCode
	mov	m,a
	cpi	80h
	jz	CrRom1
	cpi	81h
	jz	CrRom2
	cpi	84h
	jz	CrRom3

check	macro
	inx	h
	mov	a,m
	ora	a
	rz
	endm

cont	macro	label
	mov	m,a
	jmp	label
	endm

CrRom4:	check
	cpi	40h	; Digits and special symbols
	jc	@set4
	ani	7fh
	xri	20h
@set4:	cont	CrRom4

CrRom3:	check
	cont	CrRom3

CrRom2:	check
	cpi	20h
	jnz	@22
	xra	a
	jmp	@set2
@22:	cpi	80h
	jnc	@21
	ani	1fh
	adi	40h
	jmp	@set2
@21:	cpi	80h+40h
	jnc	@23
	ani	7fh
	jnz	@set2
	mvi	a,3fh
	jmp	@set2

@23:	ani	1fh
	adi	60h
@set2:	cont	CrRom2

CrRom1:	check
	cpi	60h
	jc	@set1
	ani	1fh
	adi	60h
@set1:	cont	CrRom1


GetRomCode:
	mov	c,a
	ani	0100b
	jnz	Rom3
	mov	a,c
	ani	0001b
	jnz	Rom1
	mov	a,c
	ani	1000b
	jnz	Rom4
Rom2:	mvi	a,81h	; Extended RK table
	ret
Rom4:	mvi	a,85h	; Russian table
	ret
Rom1:	mvi	a,80h	; Original RK ROM
	ret
Rom3:	mvi	a,84h	; Latin table
	ret
ENDIF

;****************************************************
CharSet:cpi	20h	; Space
	mvi	b,1111b
	rz
	push	h
	push	b
	rlc
	rlc
	rlc
	ani	111b
	lxi	h,SetTable
	mvi	b,0
	mov	c,a
	dad	b
	pop	b
	mov	b,m
	pop	h
	ret

; Table of symbol's 3 high order bits to font number
; Bits in record corresponds fonts 3210
SetTable:
IF	0
 IF	1
; Apogee symbols in font 1 - don't use it
	db	1101b	; RK special symbols
	db	1101b	; Digits and special symbols
	db	0101b	; Big latin letters
	db	0100b	; Small latin letters
	db	0000b	; IBM PC graphic symbols
	db	0000b	;  --""-
	db	1000b	; Small russian letters
	db	1001b	; Big russian letters
 ELSE
	db	1101b	; RK special symbols
	db	1101b	; Digits and special symbols
	db	0101b	; Big latin letters
	db	0110b	; Small latin letters
	db	0010b	; IBM PC graphic symbols
	db	0010b	;  --""-
	db	1010b	; Small russian letters
	db	1001b	; Big russian letters
 ENDIF
ELSE
; Use only two last fonts
	db	1100b	; RK special symbols
	db	1100b	; Digits and special symbols
	db	0100b	; Big latin letters
	db	0100b	; Small latin letters
	db	0000b	; IBM PC graphic symbols
	db	0000b	;  --""-
	db	1000b	; Small russian letters
	db	1000b	; Big russian letters
ENDIF
;****************************************************
; Transcode symbol from alt code to KOI8
TransSym:
	cpi	80h
	rc
	push	b
	SUI	80H
	MVI	C,128
	CPI	20H
	JC	RUS
	MVI	C,128-20H
	SUI	20H
	CPI	10H
	JC	RUS
	cpi	40h
	JC	Trns01
	SUI	30H
	CPI	20H
	JNC	Trns02
RUS:	PUSH	H
	push	d
	LXI	H,RUSTABL
	MOV	E,A
	MVI	D,0
	DAD	D
	MOV	A,M
	ADD	C
	pop	d
	POP	H
	POP	B
	JMP	End_Tr
Trns02:	adi	20h
Trns01:	adi	70h
	pop	b
End_Tr:	ret

RUSTABL:DB	'abwgdevzijklmnoprstufhc~{}yx|`q'

_@out	macro	val
	mvi	a,val
	call	_out
	endm

IFNDEF	MSX
;****************************************************
SETSCR:
	lhld	DISP_ADR
	inx	h
	xra	a
	call	_out

	DCX	H
;	MVI	M,4FH
;	MVI	M,1CH
;	MVI	M,99H
;	MVI	M,09DH

	_@out	4FH
	_@out	5DH
	_@out	0FFH
	_@out	19H
	INX	H
	_@out	27H

SetDma:
	lhld	DISP_ADR
	inx	h
	call	_in
WtRvv:
	call	_in
	ANI	20H
	JZ	WtRvv
	
	LHLD	DMA_ADR
	lxi	b,0fh
	dad	b
	call	_in
	inr	a
	jz	VT37

	mov	a,l
	sui	7
	mov	l,a

	_@out	80H

	mov	a,l
	sui	4
	mov	l,a
	xchg
	lhld	ScrAddr
	xchg
	mov	a,e
	call	_out
	mov	a,d
	call	_out
	inx	h
	xchg
	lhld	RomCounter
;	lxi	b,490fh
;	lxi	b,4923h
	lxi	b,495fh
	dad	b
	xchg
	mov	a,e
	call	_out
	mov	a,d
	call	_out
	inx	h
	inx	h
	inx	h
	;mvi	l,low(@8257)+8
	mvi	a,0a4h
	jmp	_out
VT37:
	xra	a
	dcx	h
	dcx	h
	call	_out	; dma+0dh
	mvi	l,4
	xchg
	lhld	ScrAddr
	xchg
	mov	a,e
	call	_out
	mov	a,d
	call	_out
	inx	h
	xchg
	lhld	RomCounter
;	lxi	b,490fh
	lxi	b,095fh;0923h
	dad	b
	xchg
	mov	a,e
	call	_out
	mov	a,d
	call	_out
	mvi	l,9
	mvi	a,1ah
	call	_out	; dma+0bh
	mov	a,l
	sui	3
	mov	l,a
	_@out	8
	mov	a,l
	adi	4+3
	mov	l,a
	mvi	a,0bh
	call	_out	; dma+0fh
	ret
ENDIF
	dseg
ScrAddr:		ds	2
AltScr:		ds	2
RomCounter:	ds	2
RomSet:		ds	1
CurStr:		ds	1
DispHex:	db	0
StrBuf:		ds	ScrWidth
;	end
