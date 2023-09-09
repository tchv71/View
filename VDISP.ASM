;****************** IBM PC file viewer ******************
;*       Displaying module   -    Radio-86rk version 	*
;*(c) TCHV  	       		     7-nov-1991, 2:00 pm*
;*  Display 8275 and DMA 8257 controllers are required	*
;********************************************************

;	16-Feb-1992 - change Ram_Start to be variable

;ScrWidth	equ	80
;ScrHeight	equ	24
ScrWidth	equ	78
ScrHeight	equ	24
;@8275		equ	0f7c0h
;@8257		equ	0f7e0h
;@8275		equ	0C000h
;@8257		equ	0E000h
;@PALM_CTR	equ	0CE00h


; Global routines (see apropriate def. for more info)
	public	DispInit	; Initialise displaying
 	public	DisplyScr	; Display a screen of text

; External adresses
	extrn	Scr1,Scr2,TransTbl
; External variable
	extrn	Ram_Start
; Text delimiters
	extrn	RamDelim
	extrn	BuffDelim
; External routines
	extrn	RdAtEnd	; Read next portion at and of
			; ram buffer
_in::	INR	H
	DCR	H
	JZ	_in_port
	MOV	A,M
	RET
_in_port:
	MOV	A,L
	STA	$+4
	IN	0
	RET

_out::	INR	H
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

; Note: this routine should be called once at start of program
DispInit:
	;sta	@PALM_CTR
	LHLD	PALM_CTR_ADR##
	mov	a,h
	ora	l
	jz	DispI01
	mvi	a,80h
	call	_out
DispI01:
	lxi	h,0
	shld	RomCounter
	lxi	h,Scr1
	shld	ScrAdr
	lxi	h,Scr2
	shld	AltScr
	call	ClrScr
	call	ChgScrAdr
	call	ClrScr
	call	SetScr
	lxi	h,TransTbl
	mvi	c,0
@init0:	mov	a,c
	;call	TransSym
	mov	m,a
	inx	h
	call	CharSet
	mov	m,b
	inx	h
	inr	c
	jnz	@init0
	ret

ChgScrAdr:
	lhld	ScrAdr
	xchg
	lhld	AltScr
	shld	ScrAdr
	xchg
	shld	AltScr
	ret



ClrScr:	lhld	ScrAdr
	lxi	b,1000h
ClrLp:	mvi	m,0
	inx	h
	dcx	b
	mov	a,b
	ora	c
	jnz	ClrLp
	ret

;	.	.	.	.	.	.	.
; Display the screen from HL - pointer to the text
DisplyScr:
	call	DsplScr
	call	SetDma
	jmp	ChgScrAdr

; Variables and registers:
;	hl - screen pointer
;	de - text pointer
;	b - symbols to end of line
;	c - not used (globally)
;	RomSet - ROM set for current chain
;       CurStr - lines to end of screen
DsplScr:xchg
	lxi	h,0
	shld	RomCounter
	lhld	ScrAdr
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
	mvi	b,2*ScrWidth
_ClrEnd:mvi	m,0
	inx	h
	dcr	b
	jnz	_ClrEnd
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
	inx	h	; Reserve space for ROM selection byte
	mvi	a,0fh
	sta	RomSet	; Initial set of ROMs for this chain
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
	mvi	m,20h
	inx	h
	dcx	d
	dcr	b
	jz	_NxtStr
	jmp	NextSym
StSym:	mvi	a,20h	; Other CNTRL symbols are not displayed
SetSym:	TrnsSym	; a = Translated symbol , c=its ROM set
	mov	m,a
	lda	RomSet
	ana	c
	jz	_EndChain
	sta	RomSet
	inx	h
	dcr	b
	jnz	NextSym
	jmp	_NxtStr

_EndStr:inr	b
	dcr	b
	jz	_NxtStr
_SetEnd:mvi	m,20h	; We can freely fill with space
	inx	h
	dcr	b
	jnz	_SetEnd

_NxtStr:mvi	b,ScrWidth
	lda	CurStr
	dcr	a
	sta	CurStr
	jnz	NextSym
	mvi	m,0	; Terminate chain
	stc	; The end of screen
	ret

_EndRam:xchg
	lhld	Ram_Start
	xchg
	jmp	NextSym

_EndBuff:
	push	h
	lhld	BuffEnd##
	dcx	d
	call	?cdehl##
	inx	d
	mvi	a,BuffDelim
	pop	h
	jnz	SetSym

	call	RdAtEnd
	dcx	d
	jmp	NextSym

_Tab:	mov	a,b
	dcr	a
  	ani	7
	inr	a
_SetTab:mvi	m,20h	;   Space is located in any ROM
	inx	h	; and current ROM set are to be
	dcr	b	; unchanged
	jz	_NxtStr
	dcr	a
	jnz	_SetTab
	jmp	NextSym

_EndChain:
	mvi	m,0	; Terminate chain
	dcx	d	; ungetc last symbol
	ora	a	; Clear cy - not the end of screen
	ret

;	.	.	.	.	.	.	.

; The second pass - translate intermediate codes
;		    into screen codes
SecondPass:
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
Rom2:	mvi	a,81h	; Latin table
	ret
Rom4:	mvi	a,85h	; Russian table
	ret
Rom1:	mvi	a,80h	; Original RK ROM
	ret
Rom3:	mvi	a,84h	; Extended RK table
	ret

;	.	.	.	.	.	.

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

SetTable:
	db	1101b	; RK special symbols
	db	1101b	; Digits and special symbols
	db	0101b	; Big latin letters
	db	0110b	; Small latin letters
	db	0010b	; IBM PC graphic symbols
	db	0010b	;  --""-
	db	1010b	; Small russian letters
	db	1001b	; Big russian letters

;	.	.	.	.	.	.
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

SETSCR:	;LXI	H,@8275+1
	lhld	DISP_ADR##
	inx	h
	;MVI	M,0
	xra	a
	call	_out

	DCX	H
;	MVI	M,4FH
;	MVI	M,1CH
;	MVI	M,99H
;	MVI	M,09DH

;	MVI	M,4DH
;	MVI	M,5DH
;	MVI	M,0FFH
;	MVI	M,18H
;	INX	H
;	MVI	M,27H

	MVI	A,4DH
	call	_out
	MVI	A,5DH
	call	_out
	MVI	A,0FFH
	call	_out
	MVI	A,18H
	call	_out
	INX	H
	MVI	A,27H
	call	_out

SetDma:	;lxi	h,@8275+1
	lhld	DISP_ADR##
	inx	h

;	MOV	A,M
	call	_in
WtRvv:
;	MOV	A,M
	call	_in
	ANI	20H
	JZ	WtRvv

	;LXI	H,@8257+8
	LHLD	DMA_ADR##
	lxi	b,8
	dad	b

	MVI	A,80H
	call	_out

	;MVI	L,low(@8257)+4
	mov	a,l
	sui	4
	mov	l,a
	xchg
	lhld	ScrAdr
	xchg
	mov	a,e
	call	_out
	mov	a,d
	call	_out
	INX	H
	xchg
	lhld	RomCounter
;	lxi	b,490fh
	lxi	b,4923h
	dad	b
	xchg
	mov	a,e
	call	_out
	mov	a,d
	call	_out
	inx	h
	inx	h
	inx	h
	;MVI	L,low(@8257)+8
	MVI	a,0a4h
	jmp	_out
	;RET

	dseg
ScrAdr:		ds	2
AltScr:		ds	2
RomCounter:	ds	2
RomSet:		ds	1
CurStr:		ds	1
	end
