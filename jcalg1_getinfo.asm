; JCALG1 r5.xx, (c)1999-2001 by Jeremy Collake - All Rights Reserved.
; ***************************************************************
; Please read license agreement in LICENSE.TXT, if this document
; is not included with this distribution, please email the author
; at collake@charter.net.
; ***************************************************************
;
 ;ifndef Adler32
 ; include adler32.asm
 ;endif

ifndef JCALG1_Decompress_Small
 include jcalg1_d.asm
endif
ifndef JCALG1_Decompress_Fast
 include jcalg1_d_fast.asm
endif

.code
JCALG1_GetInfo PROC stdcall pInfoStruct:DWORD
	mov	eax,pInfoStruct
	mov	[eax+_JCALG1_Info.MajorRevision],MAJOR_REV
	mov	[eax+_JCALG1_Info.MinorRevision],MINOR_REV
	mov	[eax+_JCALG1_Info.SmallDecompressorSize],(offset JCALG1_Decompress_Small_ends-offset JCALG1_Decompress_Small)
	mov	[eax+_JCALG1_Info.FastDecompressorSize],(offset JCALG1_Decompress_Fast_ends-offset JCALG1_Decompress_Fast)
	ret
JCALG1_GetInfo ENDP
ifndef GETINFO_OBJ
GETINFO_OBJ equ
endif
GETINFO_OBJ

