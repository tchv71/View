;****************** IBM PC file viewer ******************
;*       Filer  module     -       CP/M version 	*
;*(c) TCHV  	       		     7-nov-1991, 2:28 pm*
;********************************************************

PageSize	equ	23
;@8255_1		equ	0f782h
;@8255_1		equ	0C200h
extrn	_in, _out

	dseg
VRAM_ADR::	DW 0B770h	; VRAM buffer visible start address - 0B7C2h
PPI_ADR::	DW 0C200h 	; VV55 keyboard Controller - 0C200h
PPI2_ADR::	DW 0C400h	; VV55 additional PPI  - 0C400h
DISP_ADR::	DW 0C000h	; VG75 Display Controller - 0C000h
DMA_ADR::	DW 0E000h	; VT57 DMA Controller - 0E000h

PALM_CTR_ADR::	DW 0CE00h	; Palmira Control Byte
		DW 0,0,0	; Reserved for future use
	cseg



; BDOS system calls
@getche	 equ	1
@getstr	 equ	0ah
@open	 equ	0fh
@close	 equ	10h
@seqread equ	14h
@seqwrt	 equ	15h
@create	 equ	16h
@setdma	 equ	1ah
@randrd	 equ	21h

	public	RamDelim,BuffDelim
	public	RdAtEnd

RamDelim  equ	81H
BuffDelim equ	82H

RamSize	equ	4000h


syscall	macro	call_number
	mvi	c,call_number
	push	d
	call	5
	pop	d
	endm

extrn	DispInit	; Initialise displaying of a text
extrn	DisplyScr	; Display a screen from HL position

extrn	RamStart	; External label - start of
			; unused ram

public	Ram_Start

Strt:	lxi	h,RamStart
	shld	Ram_Start
	call	OpenFil	; Open file, set RecSize

	lxi	h,0
	shld	StartRec
	shld	EndRec

	lxi	h,RamStart
	shld	BuffEnd
	mvi	m,BuffDelim
	dcx	h
	mvi	m,RamDelim
	inx	h
	xchg
	lhld	RecSize
	dad	d
	shld	BuffStart
	shld	DispldText
	dcx	h
	mvi	m,BuffDelim

	lxi	h,RamStart+RamSize
	shld	RamEnd
	mvi	m,RamDelim


	call	RdIntoBuff	; Read first records into file

	call	DispInit
nxt:	lhld	DispldText
	call	DisplyScr
	call	0f803h
	cpi	3
	jz	ext
	mov	b,a
	;lda	@8255_1+2
	push	h
	lhld	PPI2_ADR
	inx	h
	inx	h
	call	_in
	pop	h
	ani	40h
	mov	a,b
	jz	Page
	cpi	19h
	jz	StrUp
	cpi	1ah
	jz	StrDn
	jmp	nxt

Page:	cpi	19h
	jz	PgUp
	cpi	1ah
	jz	PgDn
	jmp	nxt

StrDn:	call	_StrDn
	jmp	nxt
ext:	call	0f82dh
	jmp	0

StrUp:	call	_StrUp
	jmp	nxt

PgUp:	mvi	b,PageSize
_Pg:	push	b
	call	_StrUp
	pop	b
	dcr	b
	jnz	_Pg
	jmp	nxt

PgDn:	mvi	b,PageSize
	call	_StrDn
	dcr	b
	jnz	$-4
	jmp	nxt

_StrUp:	lhld	DispldText
	call	SymBack
	cpi	BuffDelim
	jz	@StrU0
@StrU1:	call	SymBack
	cpi	0ah
	jz	@StrU0
	cpi	BuffDelim
	jnz	@StrU1
@StrU0:	inx	h
	shld	DispldText
	ret

@sbck:	lhld	RamEnd
SymBack:dcx	h
	mov	a,m
	cpi	RamDelim
	jz	@sbck
	cpi	BuffDelim
        rnz
	call	RdAtStart
	mov	a,m
	rnc
	mvi	a,BuffDelim
	ret

_StrDn:	lhld	DispldText
ChgLp:	mov	a,m
	cpi	1ah
	inx	h
	rz
	cpi	RamDelim
	jnz	@strd0
	lxi	h,RamStart
	jmp	ChgLp
@strd0:	cpi	0ah
	jnz	ChgLp
	shld	DispldText
	ret

;----------------------------------------------
?neghl:	mov	a,h
	cma
	mov	h,a
	mov	a,l
	cma
	mov	l,a
	inx	h
	ret

?cdehl::
	mov	a,d
	cmp	h
	rnz
	mov	a,e
	cmp	l
	ret

Back:	lxi	d,RamStart
	call	?cdehl
	jnz	@back1
	lhld	RamEnd
@back1:	xchg
	lhld	RecSize
	call	?neghl
	dad	d
	ret

Forv:	xchg
	lhld	RecSize
	dad	d
	xchg
	lhld	RamEnd
	xchg
	call	?cdehl
	rnz
	lxi	h,RamStart
	ret


; Set BuffStart and buffer delimeters
; HL = BuffEnd
SetBuffInfo:
	mvi	m,BuffDelim
	xchg
	lhld	RecSize
	dad	d
	shld	BuffStart
	dcx	h
	mvi	m,BuffDelim
	ret

; Allocates RecSize bytes at start of buffer
; Last buffer record will be lost
; Returns pointer to start of allocated area
AllocStart:
	lhld	BuffEnd
	push	h
	call	Back
	shld	BuffEnd
	call	SetBuffInfo
	pop	h
	ret

; Allocates RecSize bytes at end of buffer
; First buffer record will be lost
AllocEnd:
	lhld	BuffEnd
	push	h
	call	Forv
	shld	BuffEnd
	call	SetBuffInfo
	pop	h
	ret


DefFCB1	equ	5ch	; CP/M default fcb 1
EXTRN	parsfn,prnt
OpenFil:lxi	h,128
	shld	RecSize
	lxi	d,DefFCB1+1
	ldax	d
	dcx	d
	cpi	20h
	jz	nextfil
	mvi	b,25h
	lxi	h,fcb
@cpy:	ldax	d
	mov	m,a
	inx	h
	inx	d
	dcr	b
	jnz	@cpy
	lxi	d,fcb
	jmp	opn_f

nextfil:call	askfn
	lxi	d,fcb
	push	d
	call	PARSFN
	pop	d
opn_f:	syscall	@open
	inr	a
	rnz
	call	PRNT
	db	10,13,'File not found',0
	jmp	nextfil


RdIntoBuff:
	lhld	BuffStart
@rdbuf:
	xchg
	syscall	@setdma
	lhld	RecSize
	dad	d
	lxi	d,fcb
	push	h
	syscall	@seqread
	lhld	EndRec
	inx	h
	shld	EndRec
	pop	h
        ora	a
	jnz	_Eof
	xchg
	lhld	RamEnd
	xchg
	call	?cdehl
	jnz	@rdbuf
	ret

_Eof:	ret

; Read at end of ram buffer
RdAtEnd:push	h
	push	d
	push	b
	call	AllocEnd
	xchg
	syscall	@setdma

	lhld	EndRec
	shld	fcb+21h
	inx	h
	shld	EndRec
	xra	a
	sta	fcb+23h

	lhld	StartRec
	inx	h
	shld	StartRec

	lxi	d,fcb
        syscall	@randrd

	pop	b
	pop	d
	pop	h
	ret

; Read at start of ram buffer
; Returns cy=0 ok
;	  cy=1 first record of a file already in buffer
RdAtStart:
	push	h
	lhld	StartRec
	mov	a,h
	ora	l
	jz	_BegFil
	dcx	h
	shld	StartRec
	shld	fcb+21h
	call	AllocStart
	xchg
	syscall	@setdma
	lxi	d,fcb
	syscall	@randrd
	lhld	EndRec
	dcx	h
	shld	EndRec
	pop	h
	ora	a
	ret

_BegFil:pop	h
	stc
	ret

; Ask file name
;  Returns HL - file name (ASCIIZ)
askfn:	call	prnt
	db	10,13,'FILENAME>',0
	lxi	d,strbuff
	syscall	@getstr
	lda	strbuff+1
	mov	l,a
	mvi	h,0
	lxi	d,strbuff+2
	dad	d
	mvi	m,0
	xchg
	ret

strbuff:db	14,0
	ds	15

fcb:	ds	25h
;------------------------------------

	dseg
Ram_Start:	ds	2
DispldText:	ds	2
RamEnd:		ds	2
BuffStart:	ds	2
BuffEnd::	ds	2
RecSize:	ds	2
StartRec:	ds	2
EndRec:		ds	2
	end	strt
