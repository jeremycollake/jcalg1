; JCALG1 r5.13, by Jeremy Collake
; ---------------------------
; optimized string operations
; ---------------------------
_movsd MACRO
	mov	eax,[esi]	
	mov	[edi],eax
	add	esi,4
	add	edi,4
ENDM

rep_movsd MACRO
LOCAL _movsd_loop,_movsd_end
	test	ecx,ecx
	jz	_movsd_end
_movsd_loop:
	_movsd
	dec	ecx
	jnz	_movsd_loop
_movsd_end:	
ENDM

_stosd MACRO
	mov	[edi],eax
	add	edi,4
ENDM

rep_stosd MACRO
LOCAL _stosd_loop,_stosd_end
	test	ecx,ecx
	jz	_stosd_end
_stosd_loop:	
	_stosd
	dec	ecx
	jnz	_stosd_loop
_stosd_end:	
ENDM

_cmpsb MACRO		
	mov	al,[esi]
	mov 	ah,[edi]	
	inc 	esi
	inc	edi
	cmp	al,ah
ENDM
	
repe_cmpsb MACRO
LOCAL _cmpsb_loop,_cmpsb_end
	test	ecx,ecx
	jz	_cmpsb_end
_cmpsb_loop:
	_cmpsb
	jnz	_cmpsb_end
	dec	ecx
	jnz	_cmpsb_loop	
_cmpsb_end:	
ENDM

_cmpsd MACRO	
	mov	eax,[esi]
	xor	eax,[edi]	
	add	esi,4
	add	edi,4	
	test	eax,eax
ENDM

repe_cmpsd MACRO
LOCAL _cmpsd_loop,_cmpsd_end	
	test	ecx,ecx
	jz	_cmpsd_end
_cmpsd_loop:
	_cmpsd
	jnz	_cmpsd_end
	dec	ecx
	jnz	_cmpsd_loop
_cmpsd_end:	
ENDM

repne_std_scasb MACRO
LOCAL _scasb_loop,_scasb_end				
	test	ecx,ecx
	jz	_scasb_end
_scasb_loop:			
	cmp	[edi],al		
	jz	_scasb_end	
	dec	edi
	dec	ecx
	jnz	_scasb_loop	
	inc	ecx	; set non-zero flag	
_scasb_end:		
ENDM

_lodsb MACRO
	mov	al,[esi]
	inc	esi
ENDM

_lodsw MACRO
	mov	ax,[esi]
	add	esi,2
ENDM

_lodsd MACRO
	mov	eax,[esi]
	add	esi,4
ENDM

_movsb MACRO
	mov	al,[esi]
	inc	esi
	mov	[edi],al
	inc	edi
ENDM

; special purpose 'rep movsb' replacement which will not copy the first
; dword byte by byte for cases with src==dest-1
; does not check for 0 size case.
special_rep_movs MACRO		
LOCAL db_mov_loop,_mov_end,dd_mov_loop
	_movsb
	dec	ecx
	jz	_mov_end
	_movsb
	dec	ecx
	jz	_mov_end
	_movsb
	dec	ecx
	jz	_mov_end
	_movsb
	dec	ecx
	jz	_mov_end
dd_move_loop:
	_movsd
	sub	ecx,4
	jnc	dd_move_loop
	xor	ecx,-1
	inc	ecx
	sub	edi,ecx			
_mov_end:	
ENDM

special_rep_cmps MACRO
LOCAL _rep_cmps_loop,_rep_db_loop,_rep_cmps_end,cmpsd_loop,cmsb_loop,_db_cmp		
	mov	ebx,ecx
	sar	ecx,2
	repe_cmpsd	
	jnz	_rep_cmps_end
	add	ecx,ebx
	and	ecx,3	
	repe_cmpsb		
_rep_cmps_end:	
ENDM	