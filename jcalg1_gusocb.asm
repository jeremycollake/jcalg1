include jccomp.inc
.code 	
JCALG1_GetUncompressedSizeOfCompressedBlock proc stdcall pBlock:DWORD
	mov	eax,pBlock
	or	eax,eax
	jz	BadPtr
	cmp	word ptr [eax],'CJ'
	jnz	BadPtr
	mov	eax,[eax+2]
	ret
BadPtr:
	xor	eax,eax	
	ret
JCALG1_GetUncompressedSizeOfCompressedBlock endp 
