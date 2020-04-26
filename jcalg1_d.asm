; JCALG1 r5.xx,	(c)1999-2001 by Jeremy Collake - All Rights Reserved.
; ***************************************************************
; Please read license agreement	in LICENSE.TXT,	if this	document
; is not included with this distribution, please email the author
; at collake@charter.net.
; ***************************************************************
;
; Small	decompressor source. See jcalg1_d_fast.asm for fast decompressor.
;
; Note:	This decompressor has been moderatly speed optimized. A	few
;  bytes could definatly be saved, but in my opinion it	would hurt
;  decompression performance.
;
; + edx used for bit counter, must be preserved throughout.
;
include	jccomp.inc
.code
ifndef JCALG1_GetUncompressedSizeOfCompressedBlock
include JCALG1_gusocb.asm
endif
include Checksum32.asm
;-----------
align 16
JCALG1_Decompress_Small	proc stdcall pSrc:DWORD, pDest:DWORD
	LOCAL	IndexBase:DWORD
	LOCAL	LiteralBits:DWORD
	LOCAL	MinimumLiteral:BYTE

	cld

	push	ebx
	push	edi
	push	esi

	mov	esi,pSrc
	mov	edi,pDest

	cmp	(_JCALG1_HEADER ptr [esi]).wSig,'CJ'
	jnz	sDecompDone
	add	esi,size _JCALG1_HEADER

	mov	IndexBase,INITIAL_BASE

	xor	ebx,ebx
	mov	edx,80000000h
	inc	ebx
sDecodeLoop:
	xor	eax,eax
	call	getbit
	jnc	sIsntLiteral
	mov	ecx,LiteralBits
	call	getbits
	add	al,MinimumLiteral
sDecodeZero:
	stosb
	jmp	sDecodeLoop

sIsntLiteral:
	call	getbit
	jc	sGetCodeword
	call	getbit
	jnc	sshortmatch
	mov	ecx,ONEBYTE_PHRASE_BITS
	call	getbits
	dec	eax
	jz	sDecodeZero
	jns	sdocopy_inc
	call	getbit
	jnc	sGetNewLiteralSize
	push	ebp
sNextBlock:
	mov	ebp,BLOCK_SIZE
sCopyMe:
        call	getbyte
        mov	byte ptr [edi],al
        inc	edi
        dec	ebp
        jnz	sCopyMe
        call	getbit
        jc	sNextBlock
        pop	ebp
        jmp	sDecodeLoop

sGetNewLiteralSize:
	mov	ecx,LITERAL_BITSIZE
	call	getbits
	add	eax,7
	mov	LiteralBits,eax
	mov	MinimumLiteral,0
	cmp	eax,8
	jz	sDecodeLoop
	call	getbyte
	mov	MinimumLiteral,al
	jmp	sDecodeLoop

sshortmatch:
        mov	ecx,SHORT_BITS
        call	getbits
        push	eax
        mov	ecx,2
        call	getbits
        mov	ecx,eax
        ;add	ecx,2
        inc	ecx
        inc	ecx
        pop	eax
        or	eax,eax
        jz	sextendedshort
        mov     ebx,eax         ; store last used index
        jmp     sdocopy          ; go copy the phrase
sextendedshort:
	cmp	ecx,2
	jz	sDecompDone
	inc	ecx		; 3+1=4
	call	getbits
	mov	IndexBase,eax
	jmp	sDecodeLoop
sGetCodeword:
	call	getgamma
	dec	ecx
	loop	snotsamefull
	mov	eax,ebx
	call	getgamma
	jmp	sdocopy
snotsamefull:
	dec	ecx
	mov	eax,ecx
	push	ebp
	mov	ecx,IndexBase
	mov	ebp,eax
	xor	eax,eax
	shl	ebp,cl
	call	getbits
	or	eax,ebp
	pop	ebp
	mov	ebx,eax

	call	getgamma

        cmp     eax,DecrementIndex3
        jae     sdocopy_threeincs
        cmp     eax,DecrementIndex2
        jae     sdocopy_twoincs
        cmp     eax,DecrementIndex1
        jae     sdocopy_inc
        cmp     eax,SHORT_RANGE
        ja      sdocopy
        inc	ecx
sdocopy_threeincs:
        inc	ecx
sdocopy_twoincs:
        inc     ecx
sdocopy_inc:
        inc     ecx
sdocopy:
	push	esi
	mov	esi,edi
	sub	esi,eax
	rep	movsb
	pop	esi
	jmp	sDecodeLoop

sDecompDone:
	mov     esi,pSrc
	cmp     (_JCALG1_HEADER ptr [esi]).dwChecksum,0
	jz      sDecompGood
	push    esi
	mov     ecx,(_JCALG1_HEADER ptr [esi]).dwUncompressedSize
	mov     esi,pDest
	CHECKSUM32_MACRO
	pop     esi
	cmp     eax,(_JCALG1_HEADER ptr [esi]).dwChecksum
	jz      sDecompGood
sDecompBad:
        xor     eax,eax
        jmp     sDecompExit
sDecompGood:
	mov	eax,edi
	sub	eax,pDest
sDecompExit:

	pop	esi
	pop	edi
	pop	ebx
	ret

getbit:
        add     edx,edx         ; edx*2, equiv. to shl edx,1
                                ; if placeholder bit (1) is shifted
                                ; off into carry then result is zero.
        jnz     noload          ; if not, then return carry bit
        mov	edx,dword ptr [esi]
        add	esi,4
        stc
        adc     edx,edx         ; -minimum
                                ; value now one, lowest bit used
                                ; as placeholder, highest bit shifted
                                ; off for return
noload:
	db	0c3h
getbyte:
	mov	ecx,8
	call	getbits
	db	0c3h

getbits:
	xor	eax,eax
getbitsloop_:
	call	getbit
	adc	eax,eax
	loop	getbitsloop_
	db	0c3h

getgamma:
	xor	ecx,ecx
	inc	ecx
getgammaloop:
	call	getbit
	adc	ecx, ecx
	call	getbit
	jc	getgammaloop
	db	0c3h


JCALG1_Decompress_Small	endp
JCALG1_Decompress_Small_ends:
ConditionalEnd