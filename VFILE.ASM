;****************** IBM PC file viewer ******************
;*       Filer  module     -       CP/M version 	*
;*(c) TCHV  	       		     7-nov-1991, 2:28 pm*
;				     5-dec-2025         *
;********************************************************

PageSize	equ	ScrHeight-1
;@8255_1		equ	0f782h
;@8255_1		equ	0C200h
;extrn	_in, _out

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
@fsize	 equ	35



RamDelim	equ	1
BuffDelim	equ	2
BuffDelimE	equ	4

RamSize	equ	4000h


syscall	macro	call_number
	mvi	c,call_number
	push	d
	call	5
	pop	d
	endm

;extrn	DispInit	; Initialise displaying of a text
;extrn	DisplyScr	; Display a screen from HL position

;extrn	@RamStart	; External label - start of
			; unused ram

;public	RamStart

Strt:
	lxi	h, fcb
	lxi	b, DataEnd - fcb
	call	RtlZeroMemory
IFDEF SHELL
	xchg
	shld	fs_selfName
	xchg
	shld	fs_cmdLine
	mov	h,b
	mov	l,c
	shld	fs+1
ENDIF
	lxi	sp,100h

IFNDEF SHELL
	lxi	d,VRAM_ADR
	call	BIOS_CONFIG	; Configure ports
ENDIF

	call	SaveScreen

	lxi	h,@RamStart
	shld	RamStart
	call	OpenFil	; Open file, set RecSize

	call	BuffInit
	call	RdIntoBuff	; Read first records into file

	call	DispInit
nxt:	lhld	DispldText
	lda	DispHex
	ora	a
	jz	nxt00
	xchg
	lhld	BuffStart
	call	SubDE_HL
	mov	a, e
	ani	0F0h
	mov	e, a
	lhld	BuffStart
	dad	d
	shld	DispldText
nxt00:
	call	DisplyScr
	call	BIOS_CONIN
	call	CheckKey
	jmp	nxt

fs:
	jmp	0f800h

RtlZeroMemory:
	mvi	m,0
	inx	h
	dcx	b
	mov	a,b
	ora	c
	jnz	RtlZeroMemory
	ret

CheckKey:
	cpi	3 ; ^C
	jz	_exit
	cpi	27
	jz	_exit
	cpi	'4'
	jz	_disp_hex
	cpi	0
	jnz	nxt01
	lda	PalmCtrByte
	cpi	90H
	jnz	nxt02
	mvi	a,80h
	jmp	nxt03
nxt02:	mvi	a,90h
nxt03:	sta	PalmCtrByte
	jmp	SetPalmCtr

nxt01:
	mov	b,a
	;lda	@8255_1+2
	push	h
	lhld	PPI_ADR
	inx	h
	inx	h
	call	_in
	pop	h
	ani	40h
	mov	a,b
	jz	Page
	cpi	19h
	jz	_StrUp
	cpi	1ah
	jz	_StrDn
	cpi	8
	jz	GotoStart
	cpi 18h
	jz	GotoEnd
	jmp	nxt

IFNDEF SHELL
BIOS_CONFIG:
	LHLD	1
	LXI	B,30H
	DAD	B
	MOV	A,M
	CPI	JMP
	RNZ
	INX	H
	PUSH	D
	MOV	E,M
	INX	H
	MOV	D,M
	XCHG
	POP	D
	PCHL


BIOS_CONIN:
	LHLD	1
	LXI	D,6
	DAD	D
	INX	H
	MOV	E,M
	INX	H
	MOV	D,M
	XCHG
	INX	H
	MOV	E,M
	INX	H
	MOV	D,M
	XCHG
	PCHL
ELSE
	jmp	0f803h
ENDIF

BuffInit:
	lxi	h,0
	shld	StartRec
	shld	EndRec

	lxi	h,@RamStart
	shld	BuffStart
	mvi	m,BuffDelim OR BuffDelimE
	;dcx	h
	;mvi	m, RamDelim
	;inx	h
	;xchg
	;lhld	RecSize
	;dad	d
	shld	BuffEnd
	shld	DispldText

	lxi	h,@RamStart+RamSize
	shld	RamEnd
	;mvi	m,RamDelim
	ret

;+--+ @RamStart
;|  |
;+--+
;|  |
;+--+
;|  |
;+--+


GotoStart:
	call	BuffInit
	jmp	RdIntoBuff

GotoEnd:
	call	BuffInit
	lhld	EndRec

	lxi	d,fcb
	syscall	@fsize

	lhld	fcb+21h
	dcx	h
	shld	EndRec
	shld	StartRec

	xra	a
	sta	fcb+23h

	call	RdAtEnd
	lhld	BuffEnd
	shld	FileEnd
	lxi	b,-16
	dad	b
	shld	DispldText

	jmp	PgUp

Page:	cpi	19h
	jz	PgUp
	cpi	1ah
	jz	PgDn
	ret

_disp_hex:
	lda	DispHex
	xri	1
	sta	DispHex
	jmp	nxt

_exit:
	lxi	b,8150h ; Unset increment by one
	mov	a,c
	out	VDP+1
	mov	a,b
	out	vdp+1
	call	RestoreScreen
IFNDEF SHELL
	jmp	0
ELSE
	lxi	h, ShPath
	lxi	d, cmdStr
	xra	a
	call	fs
ENDIF

ShPath:
	DB	"BOOT/SHELL.RK",0
cmdStr:	Db	0

PgUp:	mvi	b,PageSize
_Pg:	push	b
	call	_StrUp
	pop	b
	dcr	b
	jnz	_Pg
	ret

PgDn:	mvi	b,PageSize
	call	_StrDn
	dcr	b
	jnz	$-4
	ret

_StrUp:
	lhld	DispldText
	lda	DispHex
	ora	a
	jnz	_StrUpHex
	call	SymBack
	cpi	BuffDelim
	jz	@StrU0
@StrU1:	call	SymBack
	cpi	0ah
	jz	@StrU0
	cpi	BuffDelim
	jnz	@StrU1
	;jmp	@StrU2
@StrU0:	inx	h
@StrU2:
	shld	DispldText
	ret

_StrUpHex:
	mvi	c,0
	xchg
	lhld	RamStart
	xchg
	call	?cdehl
	jnz	@StrU5
	xchg
	lhld	BuffStart
	shld	BuffStartBack
	xchg
	call	?cdehl
	jnz	@StrU5
	mvi	c,1
@StrU5:	xchg
	lhld	BuffStartBack
	xchg
	call	?cdehl
	jnz	@StrU7

	push	h
	lhld	StartRec
	mov	a,h
	ora	l
	pop	h
	rz
	mov	a, c
	ora	a
	jz	@StrU8
	push	h
	lhld	RamEnd
	shld	BuffStart
	pop	h
@StrU8:
	push	h
	call	RdAtStart
	pop	h
@StrU7:	lxi	b, -16
	dad	b
	jmp	@StrU2


@sbck:	lhld	RamEnd
	ret

SymBack:
	dcx	h
	push	h
	xchg
	lhld	BuffStart
	dcx	h
	call	?cdehl
	ldax	d
	jnz	$+5
	mvi	a, BuffDelim
	pop	h
	jnz	@sbck01
	push	h
	call	RdAtStart
	mov	a,m
	pop	h
	rnc
	mvi	a,BuffDelim
	ret
@sbck01:
	xchg
	lhld	RamStart
	dcx	h
	xchg
	call	?cdehl
	mvi	a, RamDelim
	jz	@sbck
	mov	a, m
	ret

_StrDn:	lhld	DispldText
	lda	DispHex
	ora	a
	jnz	_StrDnHex
ChgLp:	mov	a,m
	cpi	1ah
	inx	h
	rz
	xchg
	lhld	RamEnd
	xchg
	mov	a, e
	cmp	l
	jnz	@strd0
	mov	a, d
	cmp	h
	jnz	@strd0

	lxi	h,@RamStart
	jmp	ChgLp

@strd0:	mov	a, m
	cpi	0ah
	jnz	ChgLp
@strd1:
	shld	DispldText
	ret

BuffStartBack:	ds	2

_StrDnHex:
	push	b
	lxi	b,16
	dad	b
	pop	b
	xchg
	lhld	RamEnd
	xchg
	call	?cdehl
	jnz	@strd2
	lxi	h,@RamStart
	jmp	@strd1
@strd2:
	push	h
	push	b
	lxi	b,(PageSize-1)*16
	dad	b
	pop	b
	xchg
	lhld	FileEnd
	xchg
	call	?cdehl
	pop	h
	rz
	jmp	@strd1
;----------------------------------------------
?neghl:	mov	a,h
	cma
	mov	h,a
	mov	a,l
	cma
	mov	l,a
	inx	h
	ret

?cdehl:
	mov	a,d
	cmp	h
	rnz
	mov	a,e
	cmp	l
	ret

Back:	lxi	d,@RamStart
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
	lxi	h,@RamStart
	ret


; Set BuffStart and buffer delimeters
; HL = BuffEnd
SetBuffInfo:
	lhld	BuffStart
	mvi	a,BuffDelim
	ora	m
	mov	m,a
	lhld	BuffEnd
	mvi	a,BuffDelimE
	ora	m
	mov	m,a
	ret

; Allocates RecSize bytes at start of buffer
; Last buffer record will be lost
; Returns pointer to start of allocated area
AllocStart:
	lhld	BuffStart
	call	Back
	push	h
	shld	BuffStart
	xchg
	lhld	BuffEnd
	call	?cdehl
	jnz	as0
	call	Back
	shld	BuffEnd
as0:	call	SetBuffInfo
	pop	h
	ret

; Allocates RecSize bytes at end of buffer
; First buffer record will be lost
AllocEnd:
	lhld	BuffEnd
	push	h
	call	Forv
	shld	BuffEnd
	xchg
	lhld	BuffStart
	call	?cdehl
	jnz	ae0
	call	Forv
	shld	BuffStart
ae0:	call	SetBuffInfo
	pop	h
	ret


DefFCB1	equ	5ch	; CP/M default fcb 1
EXTRN	parsfn,prnt
OpenFil:
IFNDEF	SHELL
	lxi	h,128
ELSE
	lxi	h,512
ENDIF
	shld	RecSize
IFNDEF SHELL
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
ENDIF
	jmp	opn_f

nextfil:call	askfn
	lxi	d,fcb
	push	d
	call	PARSFN
	pop	d
opn_f:
IFNDEF SHELL
	syscall	@open
ELSE
O_OPEN	equ	0
	lhld	fs_cmdLine
	MVI	D,O_OPEN
	mvi	a, 2
	call	fs
ENDIF
	inr	a
	rnz
	call	PRNT
	db	10,13,'File not found',0
	jmp	nextfil


RdIntoBuff:
	lhld	BuffStart
IFNDEF SHELL
@rdbuf:
	xchg
	syscall	@setdma
	lhld	RecSize
	dad	d
	lxi	d,fcb
	push	h
	lhld	EndRec
	shld	fcb+21h
	inx	h
	shld	EndRec
	xra	a
	sta	fcb+23h
	syscall	@randrd;@seqread
	pop	h
	ora	a
	jnz	_Eof
	xchg
	lhld	RamEnd
	xchg
	call	?cdehl
	jnz	@rdbuf
	shld	BuffEnd
	ret
ELSE
SEEK_START	equ	0
SEEK_PTR	equ	1
SEEK_END	equ	2

	push	h
	lxi	h,0
	mvi	b,100
	mvi	a,3
	call	fs
	shld	fileSize
	mov	a,e
	sta	fileSizeHi
	pop	d
@rdbuf:
	push	d
	lhld	EndRec
IFNDEF SHELL
	call	mul128
ELSE
	call	mul512
ENDIF
	lda	fileSizeHi
	cmp	c
	jnz	rdb00
	 push	d
	xchg
	lhld	fileSize
	xchg
	call	?cdehl
	 pop	d
	jz	rdb01
rdb00:
	mov	e, c
	mvi	d, 0
	mvi	b, SEEK_START
	mvi	a, 3
	call	fs
	pop	d
	push	d
	lhld	RecSize
	mvi	a,4
	call	fs
	mov	e,a
	 push	d
	xchg
	lhld	RecSize
	xchg
	call	?cdehl
	 pop	d
	mov	a,e
	pop	d
	jz	_FullRec
	dad	d
rdb01:
	shld	BuffEnd
	shld	FileEnd
	pop	h
	ret
_FullRec:
	pop	h
	ora	a
	jnz	_Eof
	xchg
	lhld	RecSize
	mov	b,h
	mov	c,l
	dad	d
	xchg
	lhld	EndRec
	inx	h
	shld	EndRec
	lhld	RamEnd
	call	?cdehl
	jz	stopRead
	xchg
	push	d
	lhld	fileSize
	xchg
	lhld	EndRec
	call	mul512
	inx	h
	call	?cdehl
	pop	d
	jp	@rdbuf
	xchg
	shld	RamEnd
	shld	FileEnd
stopRead:
	shld	BuffEnd
	ret
ENDIF

_Eof:	
	call	@back1
	shld	FileEnd
	shld	BuffEnd
	ret

; Read at end of ram buffer
RdAtEnd:
	push	h
	push	d
	push	b
	lhld	EndRec
IFNDEF SHELL
	shld	fcb+21h
	inx	h
	shld	EndRec
	call	AllocEnd
	xchg
	syscall	@setdma
	xra	a
	sta	fcb+23h

	;lhld	StartRec
	;inx	h
	;shld	StartRec

	lxi	d,fcb
	syscall	@randrd
	pop	b
	pop	d
	pop	h
	ret
ELSE
	inx	h
	shld	EndRec
	call	mul512
	lda	fileSizeHi
	cmp	c
	jc	rdate_exit
	push	h
	xchg
	lhld	fileSize
	xchg
	call	?cdehl
	pop	h
	jc	rdate_exit
	push	h
	call	AllocEnd
	xchg
	pop	h
	push	d
	mvi	d,0
	mov	e,c
	mvi	a,3
	call	fs
	pop	d
	lhld	RecSize
	mvi	a,4
	call	fs
	jmp	rdate_00
rdate_exit:
	mvi	a,1
rdate_00:
	ora	a
	pop	b
	pop	d
	pop	h
	rnz
	xchg
	lhld	RamStart
	xchg
	ret
ENDIF

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
IFNDEF	SHELL
	shld	fcb+21h
ELSE
	call	mul512
	lxi	d,0
	mvi	a,3
	call	fs
ENDIF
	call	AllocStart
	xchg
IFDEF SHELL
	syscall	@setdma
	lxi	d,fcb
	syscall	@randrd
ELSE
	lhld	RecSize
	mvi	a,4
	call	fs
ENDIF
	;lhld	EndRec
	;dcx	h
	;shld	EndRec
	pop	h
	ora	a
	ret

_BegFil:pop	h
	stc
	ret

IFNDEF SHELL
; C,HL = HL * 128
mul128:
	mov	a, h
	rar
	mov	c,a
	mvi	h,80h
	jc	$+5
	mvi	h, 0
	mov	a,l
	rar
	push	psw
	ora	h
	mov	h,a
	pop	psw
	mvi	l,80h
	rc
	mvi	l,0
	ret
ELSE
; C,HL = HL * 512
mul512:
	xra	a
	mov	a, h
	ral
	mov	c,a
	xra	a
	mov	a,l
	ral
	mov	h,a
	jnc	$+4
	inr	c
	mvi	l,0
	ret
ENDIF

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
;------------------------------------
strbuff:db	14,0
	ds	15
TheEnd:
IFNDEF SHELL
VRAM_ADR:	DW 0B770h	; VRAM buffer visible start address - 0B7C2h
PPI_ADR:	DW 0C200h	; VV55 keyboard Controller - 0C200h
PPI2_ADR:	DW 0C400h	; VV55 additional PPI  - 0C400h
DISP_ADR:	DW 0C000h	; VG75 Display Controller - 0C000h
DMA_ADR:	DW 0E000h	; VT57 DMA Controller - 0E000h

PALM_CTR_ADR:	DW 0CE00h	; Palmira Control Byte
		DW 0,0,0	; Reserved for future use
ELSE
VRAM_ADR:	DW 0		; VRAM buffer visible start address - 0B7C2h
PPI_ADR:	DW 0C200h	; VV55 keyboard Controller - 0C200h
PPI2_ADR:	DW 0C400h	; VV55 additional PPI  - 0C400h
DISP_ADR:	DW 0C000h	; VG75 Display Controller - 0C000h
DMA_ADR:	DW 0C600h	; VT57 DMA Controller - 0E000h

PALM_CTR_ADR:	DW 0CE00h	; Palmira Control Byte
		DW 0,0,0	; Reserved for future use
ENDIF
;	end	strt
