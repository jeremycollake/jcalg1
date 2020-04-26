; --- file: jcalg1_d_fast.asm ---
;
; JCALG1 r5.xx, (c)1999-2001 by Jeremy Collake - All Rights Reserved.
; ***************************************************************
; Please read license agreement in LICENSE.TXT, if this document
; is not included with this distribution, please email the author
; at collake@charter.net.
; ***************************************************************
;
; Fast decompressor source.
;
;
; notes: edx used as holder for bits read from the input (compressed)
;        stream. It must be preserved throughout.
;
include jccomp.inc
ifndef NOCHANGETOCODE
.code
endif
ifndef JCALG1_GetUncompressedSizeOfCompressedBlock
include JCALG1_gusocb.asm
endif
; =================================================================
; support macros - macros have been used to reduce the overhead
; in call and ret instructions.
; =================================================================
; returns bit in carry
_getbit MACRO
 LOCAL _noload
        add     edx,edx         ; edx*2, equiv. to shl edx,1
                                ; if placeholder bit (1) is shifted
                                ; off into carry then result is zero.
        jnz     _noload         ; if not, then return carry bit
        mov	edx,dword ptr [esi]
        add	esi,4
        stc
        adc     edx,edx         ; -minimum
                                ; value now one, lowest bit used
                                ; as placeholder, highest bit shifted
                                ; off for return
_noload:
ENDM

; returns byte in al
_getbyte MACRO
        mov     ecx,8           ; 8 bits
        _getbits
ENDM

; on entry: ecx=number of bits to retrieve
; returns: eax=bits retrieved
_getbits MACRO
 LOCAL _getbitsloop_
        xor     eax,eax
align 16
_getbitsloop_:
        _getbit                 ; retrieve bit, result in carry
        adc     eax,eax         ; add bit to eax
        dec     ecx
        jnz     _getbitsloop_   ; speed optimized, preferred over loop
ENDM

; decodes gamma encoded integer from input stream
; returns: ecx=decoded gamma integer
_getgamma MACRO
 LOCAL _getgammaloop
        mov	ecx,1
                                ; remember, it was assumed that at
                                ; least one significant bit existed
                                ; in the integer, this is it.
align 16
_getgammaloop:
        _getbit                 ; retrieve a bit from the input stream
        adc     ecx, ecx        ; add it to destination
        _getbit                 ; retrieve another bit
        jc      _getgammaloop   ; if one, continue on, if zero, end of
                                ; integer
ENDM

; =================================================================
; Entry: pSrc->compressed data
;        pDest->uncompressed data
; Returns: eax=size of uncompressed data
;
; register usage:
;       ebx=last encoded index.
;       edx=holder for bits read from stream, with placeholder
;           bit as least significant on bit.
; =================================================================

JCALG1_Decompress_Fast  proc stdcall pSrc:DWORD, pDest:DWORD

	LOCAL 	IndexBase:DWORD		;-4
	LOCAL	LiteralBits:DWORD	;-8
	LOCAL	MinimumLiteral:BYTE	;-12

	cld

	push	ebx
	push	edi
	push	esi

        mov     esi,[esp+8+18h]  ;pSrc        ; esi->source
        mov     edi,[esp+0ch+18h] ;pDest       ; edi->destination

	cmp	(_JCALG1_HEADER ptr [esi]).wSig,'CJ'
	jnz	DecompDone
	add	esi,size _JCALG1_HEADER

        xor     ebx,ebx         ; zero ebx
        mov     edx,80000000h   ; initialize edx, placeholder bit at
                                ; highest position, force load of
                                ; new dword.
	mov	dword ptr [esp-4+18h],INITIAL_BASE  ;IndexBase,INITIAL_BASE
        inc     ebx             ; most recently encoded index assumed
                                ; to be one at start.

align 16
; the main decompression loop
DecodeLoop:
        _getbit                 ; retrieve bit
        jnc     IsntLiteral     ; if not zero bit, then is not literal
DoLiteral:
        mov	ecx,[esp-8+18h]
        _getbits
        add	al,[esp-12+18h];MinimumLiteral
DecodeZero:
        mov	[edi],al
        inc	edi
        jmp     DecodeLoop      ; loop

IsntLiteral:
        _getbit                 ; grab next control bit
        jc      NormalPhrase    ; if 1, then normal phrase (01)
        _getbit                 ; else grab next control bit
        jnc     ShortMatch      ; if 0, then short phrase (000)
                                ; else, one byte phrase or literal size change
        mov     ecx,ONEBYTE_PHRASE_BITS
        _getbits                ; get one byte phrase index
	dec	eax
	jz	DecodeZero
	jns	docopy_inc

	_getbit
	jnc	GetNewLiteralSize

NextBlock:
	mov	ebp,BLOCK_SIZE
CopyMe:
        _getbyte
        mov	byte ptr [edi],al
        inc	edi
        dec	ebp
        jnz	CopyMe
        _getbit
        jc	NextBlock
        jmp	DecodeLoop


GetNewLiteralSize:
	; retrieve literal information
	mov	ecx,LITERAL_BITSIZE
	_getbits
	add	eax,7
	mov	[esp-8+18h],eax
	mov	byte ptr [esp-12+18h],0
	cmp	eax,8
	jz	DecodeLoop
	_getbyte
	mov	[esp-12+18h],al
	jmp	DecodeLoop

ShortMatch:
        mov	ecx,SHORT_BITS
        _getbits
        mov	ebp,eax
        mov	ecx,2
        _getbits
        mov	ecx,eax
        mov	eax,ebp
        add	ecx,2
        test	eax,eax
        jz	extendedshort
        mov     ebx,eax         ; store last used index
        jmp     docopy          ; go copy the phrase
extendedshort:
        cmp	ecx,2
        jz      DecompDone      ; if carry flag nonzero, then
                                ; decompression finished.
        inc	ecx		; 3+1=4
        _getbits                ; retrieve new index base
        mov     [esp-4+18h],eax  ; store index base
        jmp     DecodeLoop      ; loop

NormalPhrase:
        _getgamma               ; get gamma encoded high index
        dec     ecx             ; decrement once
        ;loop   notsamefull     ; not preferred for speed
        dec     ecx             ; decrement twice
        jnz     notsamefull     ; if not zero, then low bits follow
        mov     eax,ebx         ; else, index is same as last used
        _getgamma               ; decode the phrase length
        jmp     docopy          ; copy the phrase
notsamefull:
        dec     ecx             ; third decrementation
        mov     eax,ecx         ; store the high bits of index in eax
        mov     ecx,[esp-4+18h]   ; ecx=current index base
        mov     ebp,eax         ; save the high bits of index
        xor	eax,eax
        shl     ebp,cl          ; shift high bits CURRENT_BASE bits lt
        _getbits                ; get CURRENT_BASE bits
        or      eax,ebp 	; or together high and low bits
        mov     ebx,eax         ; store last used index

        _getgamma               ; retrieve the phrase length

                                ; perform index range decremenation
        cmp     eax,DecrementIndex3
        jae     docopy_threeincs
        cmp     eax,DecrementIndex2
        jae     docopy_twoincs
        cmp     eax,DecrementIndex1
        jae     docopy_inc
        cmp     eax,SHORT_RANGE
        ja      docopy
        inc	ecx
docopy_threeincs:
        inc	ecx
docopy_twoincs:
        inc     ecx
docopy_inc:
        inc     ecx
docopy:
        mov	ebp,esi
        mov     esi,edi         ; esi=P
        sub     esi,eax         ; subtract relative index for absolute
	rep	movsb
        mov	esi,ebp
        jmp     DecodeLoop      ; loop

DecompDone:
	lea	ebp,[esp+18h]
	mov     esi,[esp+8+18h]
	cmp     (_JCALG1_HEADER ptr [esi]).dwChecksum,0
	jz      DecompGood
	mov     ecx,(_JCALG1_HEADER ptr [esi]).dwUncompressedSize
	mov     esi,[esp+0ch+18h]	;pDest
	CHECKSUM32_MACRO
	mov     esi,[esp+8+18h]
	cmp     eax,(_JCALG1_HEADER ptr [esi]).dwChecksum
	jz      DecompGood
DecompBad:
        xor     eax,eax
        jmp     DecompExit
DecompGood:
        mov     eax,edi         ; eax->end of uncomprssed data
        sub     eax,[esp+0ch+18h]      ; eax=end of uncompressed data-
                                ;    start of uncompressed data
                                ;    =size of uncompressed data

DecompExit:
        pop	esi
        pop	edi
        pop	ebx
        ret
JCALG1_Decompress_Fast endp
JCALG1_Decompress_Fast_ends:

ConditionalEnd