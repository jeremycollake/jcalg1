CHECKSUM32_MACRO MACRO 
   LOCAL Checksum32Loop, Checksum32Done
        ; todo: reverse direction checksum sometime
        xor     eax,eax
        cmp     ecx,4
        jb      Checksum32Done
    align 16
    Checksum32Loop:
        mov     ebx,dword ptr [esi]
        add     eax,ebx
        shl     ebx,1
        adc     ebx,1
        xor     eax,ebx
        add     esi,4
        sub     ecx,4
        jz      Checksum32Done
        cmp     ecx,4
        jae     Checksum32Loop       
        mov     edx,4        
        sub     edx,ecx        
        sub     esi,edx
        mov     ecx,4
        jmp     Checksum32Loop
   Checksum32Done:     
ENDM
