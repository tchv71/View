MSX	equ	1 
VDP	equ	98h 
;SHELL   equ     1 
 
        .8080 
        dseg 
        org 0b00h 
 
        cseg 
        .phase    103h 
include vfile.asm 
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
 
 
IF 1 
	lxi	h, FNAME 
	lxi	d,0 
	lxi	b,0d507h;82C0h 
	jmp	Strt 
FNAME:	db	"VIEW/M80.DOC",0 



ENDIF 
Strt: 
	push	h 
	push	b 
	lxi	h, fcb 
	lxi	b, DataEnd - fcb 
	call	RtlZeroMemory 
	pop	b 
	pop	h 
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
IFDEF SHELL 
	lxi	H,fntName 
	call	LoadFont 
ENDIF 
 
 
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
	sta	?FileNotEnded 
	call	BIOS_CONIN 
	call	CheckKey 
	jmp	nxt 
 
?FileNotEnded:	ds	1 
 
FS_OPEN	equ	2 
FS_SEEK	equ	3 
FS_READ	equ	4 
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
	lhld	1 
	lxi	b,30h 
	dad	b 
	mov	a,m 
	cpi	jmp 
	rnz 
	inx	h 
	push	d 
	mov	e,m 
	inx	h 
	mov	d,m 
	xchg 
	pop	d 
	pchl 
 
 
BIOS_CONIN: 
	lhld	1 
	lxi	d,6 
	dad	d 
	inx	h 
	mov	e,m 
	inx	h 
	mov	d,m 
	xchg 
	inx	h 
	mov	e,m 
	inx	h 
	mov	d,m 
	xchg 
	pchl 
ELSE 
BIOS_CONIN: 
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
	mvi	c,@fsize 
	push	d 
	call	5 
	pop	d 
 
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
IFDEF MSX 
	mov	a,c 
	out	VDP+1 
	mov	a,b 
	out	vdp+1 
ENDIF 
	call	RestoreScreen 
IFNDEF SHELL 
	jmp	0 
ELSE 
	call	0FACEh 
	lxi	h, ShPath 
	lxi	d, cmdStr 
	xra	a ; FS_EXEC 
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
 
_StrDn: 
	lda 	?FileNotEnded 
	ora	a 
	rz 
	lhld	DispldText 
	lda	DispHex 
	ora	a 
	jnz	_StrDnHex 
ChgLp:	mov	a,m 
	cpi	1ah 
	inx	h 
	rz 
	xchg 
	lhld	FileEnd 
	call	?cdehl 
	xchg 
	rz 
	xchg 
	lhld	RamEnd 
	xchg 
	call	?cdehl 
	jnz	@strd0 
 
	lxi	h,@RamStart 
	jmp	ChgLp 
 
@strd0:	mov	a, m 
	cpi	0ah 
	jnz	ChgLp 
@strd1: 
	inx	h 
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
	ret 
	;lhld	BuffStart 
	;mvi	a,BuffDelim 
	;ora	m 
	;mov	m,a 
	;lhld	BuffEnd 
	;mvi	a,BuffDelimE 
	;ora	m 
	;mov	m,a 
	;ret 
 
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
	mvi	c,@open 
	push	d 
	call	5 
	pop	d 
ELSE 
O_OPEN	equ	0 
	lhld	fs_cmdLine 
	MVI	D,O_OPEN 
	mvi	a, FS_OPEN 
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
	mvi	c,@setdma 
	push	d 
	call	5 
	pop	d 
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
	mvi	c,@randrd 
	push	d 
	call	5 
	pop	d 
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
	mvi	a, FS_SEEK 
	call	fs 
	shld	fileSize 
	mov	a,e 
	sta	fileSizeHi 
	pop	d 
@rdbuf: 
	push	d 
	lhld	EndRec 
	call	mul512 
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
	mvi	a, FS_SEEK 
	call	fs 
	pop	d 
	push	d 
	lhld	RecSize 
	mvi	a, FS_READ 
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
	;pop	h 
	ret 
_FullRec: 
	ora	a 
	jnz	_Eof 
	lhld	RecSize 
	dad	d 
	xchg 
	lhld	EndRec 
	inx	h 
	shld	EndRec 
	lhld	RamEnd 
	call	?cdehl 
	jz	stopRead 
	push	d 
	lhld	fileSize 
	xchg 
	lhld	EndRec 
	call	mul512 
	inx	h 
	call	?cdehl 
	pop	d 
	jnc	@rdbuf 
	xchg 
	;shld	RamEnd 
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
	mvi	c,@setdma 
	push	d 
	call	5 
	pop	d 
	xra	a 
	sta	fcb+23h 
 
	;lhld	StartRec 
	;inx	h 
	;shld	StartRec 
 
	lxi	d,fcb 
	syscall	@randrd 
	mvi	c,@randrd 
	push	d 
	call	5 
	pop	d 
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
	mvi	a, FS_SEEK 
	call	fs 
	pop	d 
	lhld	RecSize 
	mvi	a, FS_READ 
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
	mvi	a, FS_SEEK 
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
	mvi	a, FS_READ 
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
	mvi	c,@getstr 
	push	d 
	call	5 
	pop	d 
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
include vdisp.asm 
;****************** IBM PC file viewer ****************** 
;*       Displaying module   -    Radio-86rk version 	* 
;*(c) TCHV  	       		     7-nov-1991, 2:00 pm* 
;*				     5-dec-2025         * 
;*  Display 8275 and DMA 8257 controllers are required	* 
;*  or 9918A emulator on PICO                           * 
;******************************************************** 
 
;	16-Feb-1992 - change @RamStart to be variable 
 
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
	;extrn	@RamStart 
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
 
SetPalmCtr: 
	mov	c,a 
	LHLD	PALM_CTR_ADR 
	mov	a,h 
	ora	l 
	rz 
	mov	a,c 
;	jmp	_out 
_out: 
	INR	H 
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
	lxi	b,8154h ; Set interleave color 
	mov	a,c 
	out	VDP+1 
	mov	a,b 
	out	vdp+1 
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
	lhld	DispldText 
	mvi	c,80 
@init2:	mov	a,m 
	cpi	0Dh 
	jz	?TextMode 
	inx	h 
@init3:	dcr	c 
	jnz	@init2 
	mvi	a,1 
	sta	DispHex 
	ret 
 
?TextMode: 
	inx	h 
	mov	a,m 
	cpi	10 
	jnz	@init3 
	xra	a 
	sta	DispHex 
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
	mvi	a,0f4h 
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
	lxi	b,8150h ; Set increment by one 
	mov	a,c 
	out	VDP+1 
	mov	a,b 
	out	vdp+1 
	jmp	DsplScr 
ELSE 
	call	DsplScr 
	push	psw 
	call	SetDma 
	call	ChgScrAddr 
	pop	psw 
	ret 
ENDIF 
 
SaveScreen: 
IFDEF MSX 
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
ENDIF 
	ret 
RestoreScreen: 
IFDEF MSX 
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
IFNDEF	MSX 
	lxi	b,3*ScrWidth 
	dad	b 
ENDIF 
	mvi	a,ScrHeight 
	sta	CurStr 
	mvi	b,ScrWidth 
DS_Loop:	push	h 
	call	FirstPass 
IFDEF MSX 
	pop	h 
	ret 
ENDIF 
	lhld	RomCounter 
	inx	h 
	shld	RomCounter 
	pop	h 
	push	psw 
	call	SecondPass 
	pop	psw 
	;ret 
	jnc	DS_Loop 
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
 
 
SPACE	equ	' ' 
 
FirstPass: 
IFNDEF	MSX 
	inx	h	; Reserve space for ROM selection byte 
	mvi	a,0fh 
	sta	RomSet	; Initial set of ROMs for this chain 
ENDIF 
	lda	DispHex 
	ora	a 
	jz	FP_Text 
 
	mvi	b, ScrHeight 
IFDEF MSX 
	lxi	h,4000h 
	mov	a,l 
	out	VDP+1 
	mov	a,h 
	out	VDP+1 
ENDIF 
	shld	ScrTemp 
FPH_Loop: 
	push	b 
	push	d 
	lhld	BuffStart 
	call	SubDE_HL 
	jnc	dh00 
 
	pop	d 
	push	d 
	lhld	RamStart 
	call	SubDE_HL 
	; if (de < @RamStart) 
	lhld	RamEnd  
	call	AddDE_HL 
	lhld	BuffStart 
	call	SubDE_HL ; de = de - @RamStart + RamEnd - BuffStart  
dh00: 
	lhld	StartRec 
IFNDEF SHELL 
	call	mul128 
ELSE 
	call	mul512 
ENDIF 
	call	AddDE_HL 
	mvi	a,0 
	adc	c 
	lxi	h,StrBuf 
	call	ByteHexToBuf 
	mov	a,d 
	call	ByteHexToBuf 
	mov	a,e 
	call	ByteHexToBuf 
	mvi	m, SPACE 
	inx	h 
	pop	d 
	call	FPH_FillBuf 
	call	FPH_CopyBuf 
	;ldax	d 
	;cpi	RamDelim 
	;jnz	dh04 
	pop	b 
	;ldax	d 
	;ani	BuffDelimE 
	lhld	BuffEnd 
	call	?cdehl 
	cz	RdAtEnd 
	lhld	FileEnd 
	call	?cdehl 
IFNDEF MSX 
	lhld	ScrTemp 
ENDIF 
	jz	FPH_FileEnd 
	dcr	b 
	jnz	FPH_Loop 
	mvi	a,1 
	stc 
	ret 
 
ScrTemp:	DS	2 
 
 
FPH_FillBuf: 
	push	d 
	push	h 
	lhld	BuffEnd 
	xchg 
	call	SubDE_HL ; de = de - @RamStart + RamEnd - BuffStart  
	mov	a, d 
	ora	a 
	jnz	_FullStr 
	mov	a,e 
	ani	0F0H 
	jnz	_FullStr 
	mov	a, e 
	ani	0fh 
	mov	c, a 
	mvi	a, 16 
	sub	c 
	mov	b, a 
	jmp	dh013 
_FullStr: 
	mvi	c,16 
	mvi	b,0 
dh013:	pop	h 
	pop	d 
	push	d 
	push	b 
dh01:	ldax	d 
	inx	d 
	call	ByteHexToBuf 
	mvi	m, SPACE 
	inx	h 
	dcr	c 
	jnz	dh01 
	call	_FillZeroB 
	call	_FillZeroB 
	call	_FillZeroB 
	pop	b 
	pop	d 
	;mvi	c,16 
dh02:	ldax	d 
	inx	d 
	cpi	SPACE 
	jnc	$+5 
	mvi	a, '.' 
	cpi	80h 
	jc	$+5 
	mvi	a, '.' 
	mov	m, a 
	inx	h 
	dcr	c 
	jnz	dh02 
	;call	_FillZeroB 
	;ret 
_FillZeroB: 
	push	b 
	inr	b 
dh012: 
	dcr	b 
	jz	dh014 
	mvi	m,SPACE 
	inx	h 
	jmp	dh012 
dh014: 
	pop	b 
	ret 
 
FPH_CopyBuf: 
	push	d 
	mvi	c,71 
	;xchg 
	lhld	ScrTemp 
	;xchg 
	lxi	d, StrBuf 
dh03:	ldax	d 
	inx	d 
IFDEF MSX 
	out	VDP 
ELSE 
	mov	m,a 
	inx	h 
ENDIF 
	dcr	c 
	jnz	dh03 
	mvi	c,9 
	call	ClrLine 
	shld	ScrTemp 
	pop	d 
	ret 
 
 
FPH_FileEnd: 
	mvi	c,ScrWidth 
_SetEnd: 
	call	ClrLine 
	dcr	b 
	jnz	FPH_FileEnd 
	xra	a 
	stc 
	ret 
 
ClrLine: 
	;xra	a 
	mvi	a,SPACE 
dh07: 
IFDEF MSX 
	out	VDP 
ELSE 
	mov	m,a 
	inx	h 
ENDIF 
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
 
AddDE_HL: 
	mov	a, e 
	add	l 
	mov	e, a 
	mov	a, d 
	adc	h 
	mov	d, a 
	ret 
 
; First pass, text 
; de - displayed text	 
FP_Text: 
	;mov	a, e 
	;ani	7fh 
	lda	RamEnd 
	cmp	e 
	jnz	ns02 
	push	h 
	lhld	RamEnd 
	call	?cdehl 
	pop	h 
	jz	_EndRam 
	;cpi	RamDelim 
	;jz	_EndRam 
ns02: 
 
	push	h 
	lhld	BuffEnd 
	call	?cdehl 
	pop	h 
	jz	_EndBuff 
	ldax	d 
	mov	c, a 
	inx	d 
	cpi	SPACE 
	jnc	SetSym 
	cpi	9h 
	jz	_Tab 
	cpi	0dh 
	jz	_EndStr 
	cpi	0ah 
	jz	FP_Text	; Skip LF symbol 
	cpi	1ah 
	jnz	StSym 
IFNDEF	MSX 
	mvi	m,SPACE 
ELSE 
	mvi	a, SPACE 
	OUT	VDP 
	;mvi	a, 4fh 
	;out	VDP 
ENDIF 
	inx	h 
	dcx	d 
	dcr	b 
	jz	_EndScr;_NxtStr 
	jmp	FP_Text 
StSym:	mvi	a,SPACE	; Other CNTRL symbols are not displayed 
SetSym: 
IFNDEF	MSX 
	TrnsSym	; a = Translated symbol , c=its ROM set 
	mov	m,a 
	lda	RomSet 
	ana	c 
	jz	_EndChain 
	sta	RomSet 
	inx	h 
ELSE 
	OUT	VDP 
	;mvi	a, 4fh 
	;out	VDP 
ENDIF 
	dcr	b 
	jnz	FP_Text 
	jmp	_NxtStr 
 
_EndStr:inr	b 
	dcr	b 
	jz	_NxtStr 
	mov	c, b 
	call	ClrLine 
_NxtStr:mvi	b,ScrWidth 
	lda	CurStr 
	dcr	a 
	sta	CurStr 
	jnz	FP_Text 
_EndScr: 
IFNDEF	MSX 
	mvi	m,0	; Terminate chain 
ENDIF 
	stc	; The end of screen 
	mvi	a, 1 
	ret 
 
 
_EndRam: 
	xchg 
	lhld	RamStart 
	xchg 
	jmp	FP_Text 
 
_EndBuff: 
	call	RdAtEnd 
	jz	FP_Text;SetSym 
	mov	c,b 
	lda	CurStr 
	mov	b,a 
	jmp	_SetEnd 
 
_Tab:	mov	a,b 
	dcr	a 
	ani	7 
	inr	a 
_SetTab: 
IFNDEF	MSX 
	mvi	m,SPACE	;   Space is located in any ROM 
ELSE 
	mov	c, a 
	mvi	a, SPACE 
	OUT	VDP 
	mov	a, c 
ENDIF 
	inx	h	; and current ROM set are to be 
	dcr	b	; unchanged 
	jz	_NxtStr 
	dcr	a 
	jnz	_SetTab 
	jmp	FP_Text 
 
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
	xri	SPACE 
@set4:	cont	CrRom4 
 
CrRom3:	check 
	cont	CrRom3 
 
CrRom2:	check 
	cpi	SPACE 
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
CharSet:cpi	SPACE	; Space 
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
SetScr: 
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
	lxi	b,895fh 
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
 
LoadFont: 
IFDEF MSX 
IFDEF	SHELL 
	MVI	D,O_OPEN 
	mvi	a, FS_OPEN 
	call	fs 
	ora	a 
	rnz 
 
	lxi	b,2000h 
	call	T_SetAddrWrite 
	mvi	c, 4096 / 512; 
lf00: 
	lxi	d,FontBuf 
	lxi	h, 512 
	push	h 
	push	d 
	push	b 
	mvi	a,FS_READ 
	call	fs 
	pop	b 
	pop	h 
	pop	d 
	ora	a 
	rnz 
	call	T_WriteBytes 
	dcr	c 
	jnz	lf00 
ENDIF 
ENDIF 
	ret 
 
IFDEF MSX 
; HL - buffer in RAm 
; DE - byte count 
T_WriteBytes: 
	MOV	A,M 
	OUT	VDP 
	INX	H 
	DCX	D 
	MOV	A,D 
	ORA	E 
	JNZ	T_WriteBytes 
	RET 
 
; BC - address to write 
T_SetAddrWrite: 
	MOV	A,B 
	ORI	40h 
	MOV	B,A 
; BC - address to read 
T_SetAddrRead: 
	DI 
	MOV	A,C 
	OUT	VDP+1 
	MOV	A,B 
	OUT	VDP+1 
	EI 
	RET 
ENDIF 
 
fntName:	DB	"BOOT/F8X16R.BIN",0 



 
;	end 
include vend.asm 
;****************** IBM PC file viewer ****************** 
;*              Memory allocation module		* 
;*(c) TCHV  	       		     7-nov-1991, 2:28 pm* 
;				     5-dec-2025         * 
;******************************************************** 
 
	;dseg 
	;.dephase 
	;.phase 0a25h 
 
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
 
	;dseg 
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
 
	;dseg 
ptr	set	$ 
 
IFNDEF	MSX 
	malloc	Scr1,1300h	; Screen buffers 
	malloc	Scr2,1300h 
ELSE 
	malloc	Scr1, 4814 
	malloc	FontBuf, 512 
ENDIF 
	malloc	TransTbl,512+1	; Transcode Table + RamDelim 
ptr	set (ptr/128+1)*128 
	malloc	@RamStart,0 
 
;	end 
        end strt 
