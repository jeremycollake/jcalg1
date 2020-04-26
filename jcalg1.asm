; JCALG1 r5.xx, (c)1999-2001 by Jeremy Collake - All Rights Reserved.
; http://www.collakesoftware.com
; ***************************************************************
; Please read license agreement in LICENSE.TXT, if this document
; is not included with this distribution, please email the author
; at collake@charter.net.
; ***************************************************************
;
include jccomp.inc
include jcalg1_proto.inc

.data
db 'JCALG1 r5.28, (c)1999-2001 by Jeremy Collake. All Rights Reserved.',0
.code
align 16
DllEntry proc hInstDLL:DWORD, reason:DWORD, reserved1:DWORD
    	xor	eax,eax
        inc	eax
        ret
DllEntry Endp
dll_compile equ 1
include jcalg1_gusocb.asm
include checksum32.asm
include jcalg1_d.asm		; decompression procedure
include jcalg1_c.asm		; compression procedure
include jcalg1_d_fast.asm
include jcalg1_getinfo.asm
END DllEntry
END