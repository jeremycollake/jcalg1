;
; -- file: jcalg1_c.asm --
;
; JCALG1 r5.xx, (c)1999-2001 by Jeremy Collake - All Rights Reserved.
; http://www.collakesoftware.com
; ***************************************************************
; Please read license agreement in LICENSE.TXT, if this document
; is not included with this distribution, please email the author
; at collake@charter.net or jeremy@collakesoftware.com.
; ***************************************************************
;
; some notes:
;  +I've started commenting this source, but haven't finished yet.
;  +ebx must be preserved for the bit output procedures.
;  +esi,edi must be preserved as they are pointers to the source
;   and destination, respectively.
;
; virtual memory management:
;  pMap holds table of byte size booleans, each boolean indicates
;   whether or not that block (size of Node) is allocated in the
;   pMemory buffer.
;
; linked list management:
;  pEndTable holds pointers to the most recently added node for every
;   linked list (64k of them, one for each 16bit number). The linked
;   list are traversed backwards from the most recent node added (closest
;   to current source pointer) to the oldest.
;  The oldest nodes are deleted as necessary when pMap (meaning all
;   of pMemory has been allocated) becomes full.
;
;
;Revision history:
;
;5.21:
;	+ Added block orientation. Improved compression significantly for
;	  data that is, at any portion(s), uncompressible. For example,
;	  JCALG1 can now compress (slightly) some compressed archives (i.e. zip).
;	+ Jordan Russell contributed delphi interface; see JCALG1.PAS.
;	+ Updated jcalg1_test.
;
;5.15:
;	+ Included static link library and import library, for static
;	  and dynamic linking, respectively.
;	+ Fixed stdcall incompatibility with JCALG1_GetInfo and other
;	  exports.
;	+ Included C function prototypes.
;
;5.14:
;	+ Added functions GetUncompressedSizeOfCompressedBlock
;	  and GetNeededBufferSize.
;	+ Memory allocated by user-defined allocation functions
;	  no longer needs to be zero initialized.
;	+ Added word signature, 'JC' at the beginning a compressed
;	  block, followed by a dword indicating the uncompressed
;	  size of the block.
;	+ Jordan Russell added some error handling in cases where
;	  a given memory block could not be allocated.
;
;1.00-5.13: Whoops, I didn't keep a revision history :)
;
;

;DEBUG equ 1

include jccomp.inc
include jcalg1_proto.inc
include string.asm
ifndef JCALG1_GetUncompressedSizeOfCompressedBlock
include JCALG1_gusocb.asm
endif
.code

ifdef DEBUG
OutputDebugStringA PROTO :DWORD
OutputDebugString equ <OutputDebugStringA>
wvsprintfA PROTO :DWORD,:DWORD,:DWORD
wvsprintf equ <wvsprintfA>
includelib kernel32.lib
includelib c:\dev\assemblers\masm32\lib\user32.lib

;---------------------------
; debug support
;---------------------------
CondOutputDebugString MACRO pStr
	pushad
	lea	eax,pStr
	invoke OutputDebugString,eax
	popad
ENDM
endif

; --------------------------
; encoding types
; --------------------------
; literal - 0
StoreLiteralPrefix MACRO
        StoreOne
ENDM
; normal phrase - 01
StoreNormalPrefix MACRO
        StoreZero
        StoreOne
ENDM
; short phrase- 000
StoreShortPrefix MACRO
        StoreZero
        StoreZero
        StoreZero
ENDM
; one byte phrase - 001
StoreOneBytePrefix MACRO
        StoreZero
        StoreZero
        StoreOne
ENDM
StoreLiteralSizeChangePrefix MACRO
	StoreOneBytePrefix
	xor	eax,eax
	StoreXBits ONEBYTE_PHRASE_BITS
	StoreZero
ENDM

StoreLiteralBlock MACRO
	LOCAL StoreBlockAsLiterals,DidCompressLastBlock,DidNotCompressLastBlock
	cmp	bCompressedLastBlock,0
	jnz	DidCompressLastBlock
	StoreOne
	jmp	DidNotCompressLastBlock
DidCompressLastBlock:
	StoreOneBytePrefix
	xor	eax,eax
	StoreXBits ONEBYTE_PHRASE_BITS
	StoreOne
DidNotCompressLastBlock:
	mov	ecx,BLOCK_SIZE
StoreBlockAsLiterals:
	mov	al,byte ptr [esi]
	inc	esi
	push	ecx
	StoreByte
	pop	ecx
	dec	ecx
	jnz	StoreBlockAsLiterals
ENDM

StoreLiteralSizeChange MACRO MinLit, LitBits
	LOCAL SkipMinLit
	StoreLiteralSizeChangePrefix
	mov	eax,LitBits
	sub	eax,7
	StoreXBits LITERAL_BITSIZE
	cmp	LitBits,8
	jz	SkipMinLit
	xor	eax,eax
	mov	al,MinLit
	StoreByte
SkipMinLit:
ENDM

; store literal
StoreLiteral MACRO MinLit
	LOCAL tizok3
	StoreLiteralPrefix
	sub	al,MinLit
	StoreXBits nLiteralBits
ENDM

; --------------------------
; bit i/o support macros
; ---------------------------
StoreBit MACRO
LOCAL MoreInDWord, DWordStored
        mov     edx,eax                 ; save eax
        and     eax,1                   ; we only want lowest bit
        add     ebx,ebx                 ; time to out a dword?
        jnc     MoreInDWord             ; if not, then just or bit in
        add     eax,ebx                 ; add/or in bit
        _stosd                          ; emit dword
        mov     ebx,1                   ; start count over
        jmp     DWordStored
MoreInDWord:
        add     ebx,eax                 ; and/or in bit
DWordStored:
        mov     eax,edx                 ; restore eax
ENDM

StoreZero MACRO
LOCAL MoreInDWord, DWordStored
        mov     edx,eax
        xor     eax,eax
        add     ebx,ebx
        jnc     MoreInDWord
        add     eax,ebx
        _stosd
        mov     ebx,1
        jmp     DWordStored
MoreInDWord:
        add     ebx,eax
DWordStored:
        mov     eax,edx
ENDM

StoreOne MACRO
LOCAL MoreInDWord, DWordStored
        mov     edx,eax
        mov     eax,1
        add     ebx,ebx
        jnc     MoreInDWord
        add     eax,ebx
        _stosd
        mov     ebx,1
        jmp     DWordStored
MoreInDWord:
        add     ebx,eax
DWordStored:
        mov     eax,edx
ENDM


StoreByte MACRO
        mov     ecx,8
        StoreBits
ENDM

; on entry, ecx=number of bits to store
StoreBits MACRO
LOCAL   StoreBitsLoop
        push    eax
        push    ecx
        mov     edx,ecx
        mov     ecx,32
        sub     ecx,edx
        rol     eax,cl                  ; rotate left 32-numbits
        pop     ecx
 StoreBitsLoop:
        push    ecx
        rol     eax,1
        StoreBit
        pop     ecx
        dec     ecx
        jnz     StoreBitsLoop
        pop     eax
ENDM


StoreXBits MACRO NumBits
        mov     ecx,NumBits
        StoreBits
ENDM


; ---------------------------
; index/length gamma encoding macros
; ---------------------------

EncodeGammaForLength MACRO
LOCAL EncodeLoop, MidEncode
        push    ecx
        push    eax
        GetTotalBits
        dec     ecx
        pop     eax
        ror     eax,cl
        jmp     MidEncode
EncodeLoop:
        StoreOne
MidEncode:
        rol     eax,1
        StoreBit
        dec     ecx
        jnz     EncodeLoop
        StoreZero
        pop     ecx
ENDM

EncodeIndex MACRO
LOCAL NormalEncode, Type3Done
        push    eax
        cmp     LastIndexUsed,eax
        jnz     NormalEncode
        mov     eax,2
        EncodeGammaForLength
        jmp     Type3Done
NormalEncode:
        mov     ecx,CurrentBase
        shr     eax,cl
        push    ecx
        add     eax,3
        EncodeGammaForLength
        pop     ecx
        pop     eax
        push    eax
        StoreBits
Type3Done:
        pop     eax
ENDM

GetTotalBits MACRO
LOCAL GetTotBitsLoop
        push    eax
        xor     ecx,ecx
GetTotBitsLoop:
        inc     ecx
        shr     eax,1
        jnz     GetTotBitsLoop
        pop     eax
ENDM

EstimateBitsForLength MACRO
        GetTotalBits
        dec     ecx
        shl     ecx,1
ENDM

EstimateBitsForIndex MACRO
        LOCAL NormalEncode,EstimateType3Ends
        push    eax
        cmp     LastIndexUsed,eax
        jnz     NormalEncode
        mov     ecx,-1
        jmp     EstimateType3Ends
NormalEncode:
        mov     ecx,CurrentBase
        shr     eax,cl
        add     eax,3
        EstimateBitsForLength
        add     ecx,TYPE3_BITS+2
EstimateType3Ends:
        pop     eax
ENDM

; -------------------------------------------------------
; linked list macros (virtual memory management included)
; --------------------------------------------------------
; assume ecx->Node
DeleteNode MACRO
LOCAL NoWorries, DoDeleteNode
        push    ebx
        push    edx
        mov     edx,[ecx+Node.NpEnd]
        mov     ebx,[edx]
        cmp     ebx,ecx		; is this the last node we are deleting?
        jnz     NoWorries
        mov     dword ptr [edx],0 ; if so, kill the end node pointer        
NoWorries:
        mov     edx,[ecx+Node.Next]
        or      edx,edx
        jz      DoDeleteNode
        mov     [edx+Node.Prev],0
DoDeleteNode:
        pop     edx
        pop     ebx
ENDM

AddNode MACRO
LOCAL   NextNodeInRange,NodeIsFree,EndSet,NoEnd,HaveEnd,NotLastNode
        pushad  ; 5 cycles, compared to 6 in pushes?
        xor     eax,eax
        mov     ax,word ptr [esi]
        shl     eax,2           ; *4
        mov     ebx,pEndTable
        push	esi		;;;
        add     ebx,eax
        mov     edx,ebx         ; edx->->last node
        mov     ebx,[edx]       ; ebx->last node
        mov     edi,pMap
        mov     ecx,MapSize
        mov     eax,CurNodePtr
        mov     byte ptr [edi+eax],1
;-- locate/free next node
        mov     ecx,eax
        inc     ecx
        cmp     ecx,MapSize
        jb      NextNodeInRange
        xor     ecx,ecx			; round-buffer
NextNodeInRange:
        cmp     byte ptr [edi+ecx],0	; is node free?
        jz      NodeIsFree
        mov     byte ptr [edi+ecx],0	; mark node as free
        push    ecx
        shl     ecx,4
        add     ecx,pMemory
        cmp	ebx,ecx			; is it the last node we are deleting?
        jnz	NotLastNode
        xor	ebx,ebx			; zero ebx
NotLastNode:        
        DeleteNode			; delete node ECX
        pop     ecx
NodeIsFree:
        mov     CurNodePtr,ecx
        shl     eax,4
        add     eax,pMemory
        or      ebx,ebx			; is there a last node?
        jz      NoEnd
        mov     [ebx+Node.Next],eax	; if so, set its next pointer
NoEnd:
        mov     [eax+Node.Prev],ebx
        pop	ebx
        mov     [eax+Node.Index],ebx
        mov     [eax+Node.NpEnd],edx	; save pointer to pEndTable entry
        mov     [edx],eax		; save pointer to last node in pEndTable
        popad
ENDM

; ---------------------------
; misc macros
; ---------------------------

;
; decrement phrase length depending on index
; entry: eax=index
;        ecx=phrase length
;
PerformIndexRangeLengthDecrementation MACRO
LOCAL DecrementationDone, DecrementTwo
        cmp     eax,SHORT_RANGE
        ja      DecrementTwo
        sub     ecx,MAXIMUM_SHORT_SIZE-1
        jmp     DecrementationDone
DecrementTwo:
        cmp     eax,DecrementIndex1
        jb      DecrementationDone
        dec     ecx
        cmp     eax,DecrementIndex2
        jb      DecrementationDone
        dec     ecx
        cmp     eax,DecrementIndex3
        jb      DecrementationDone
        dec     ecx
DecrementationDone:
ENDM

PerformBaseChange MACRO NewBase
LOCAL NoBaseChg
        mov     eax,NewBase     ; eax=new base
        cmp     CurrentBase,eax ; if base=old base, no change
        jz      NoBaseChg
        mov     CurrentBase,eax
        push    eax
        StoreShortPrefix        ; store short prefix
        xor     eax,eax
        StoreXBits SHORT_BITS   ; store zero to indicate special
        mov     eax,1
        StoreXBits 2
        pop     eax
        StoreXBits 4            ; store new base
NoBaseChg:
ENDM

PerformDeallocations MACRO
        invoke  DoCallDealloc,DeallocFunc,pEndTable
        invoke  DoCallDealloc,DeallocFunc,pMap
        invoke  DoCallDealloc,DeallocFunc,pMemory
ENDM

DoCallAlloc proc pAllocFunc:DWORD, Needed:DWORD
        push    ebx
        push    ecx
        push    edx
        push    edi
        push    esi
        push    Needed
        mov	eax,pAllocFunc
        call    eax
        ; zero the memory
        push	eax
        mov	ecx,Needed
        mov	edi,eax
        xor	eax,eax
        rep	stosb
        pop	eax
        pop     esi
        pop     edi
        pop     edx
        pop     ecx
        pop     ebx
        ret
DoCallAlloc endp

DoCallDealloc proc pDeallocFunc:DWORD, pBlock:DWORD
	cmp	pBlock,0
	je	NothingToDealloc
        push    ebx
        push    ecx
        push    edx
        push    edi
        push    esi
        push    pBlock
        mov	eax,pDeallocFunc
        call    eax
        pop     esi
        pop     edi
        pop     edx
        pop     ecx
        pop     ebx
NothingToDealloc:
        ret
DoCallDealloc endp

ALIGN 16
JCALG1_Compress proc stdcall pSrc:DWORD, _Length:DWORD, pDest:DWORD, \
                 WindowSize:DWORD, pAlloc:DWORD,pDealloc:DWORD, \
                 pCallback:DWORD, bDisableChecksum:DWORD

        LOCAL EndOfSource:DWORD
        LOCAL EndOfDestination:DWORD
        LOCAL CurrentPhraseLength:DWORD
        LOCAL MaxPhraseLength:DWORD
        LOCAL UsedALazy:DWORD
        LOCAL LazySaves:DWORD
        LOCAL WindowSaves:DWORD
        LOCAL CurrentIndex:DWORD
        LOCAL IterationCount:DWORD
        LOCAL ByteCount:DWORD
        LOCAL nLiteralBits:DWORD
        LOCAL tempnLiteralBits:DWORD
        LOCAL AllocFunc:DWORD
        LOCAL DeallocFunc:DWORD
        LOCAL CurrentBase:DWORD
        LOCAL pMemory:DWORD
        LOCAL pEndTable:DWORD
        LOCAL pMemoryEnd:DWORD
	LOCAL pMap:DWORD
	LOCAL MapSize:DWORD
	LOCAL CurrentWindowSize:DWORD
	LOCAL LastIndexUsed:DWORD
	LOCAL PhraseInfo:_PhraseInfo
	LOCAL CurNodePtr:DWORD

	LOCAL pLastBlockSrc:DWORD
	LOCAL pLastBlockDest:DWORD
	LOCAL nLastBlockBitOutEbx:DWORD
	LOCAL nLastBlockLastIndexUsed:DWORD
	LOCAL nLastBlockCurrentBase:DWORD
	LOCAL bCompressedLastBlock:DWORD
	LOCAL nLastBlockLiteralBits:DWORD
	LOCAL nLastBlockMinimumLiteral:BYTE

	LOCAL MinimumLiteral:BYTE
	LOCAL tempMinimumLiteral:BYTE

        push	ebx
        push	edi
        push	esi

        cld

        ; initialize variables
        mov     CurrentBase,INITIAL_BASE
        mov     IterationCount,0
        mov     UsedALazy,0
        mov     CurrentIndex,0
        mov     CurrentPhraseLength,1
        mov     CurNodePtr,0
        mov	ByteCount,0
        mov	nLiteralBits,8
        mov	MinimumLiteral,0
        mov	LastIndexUsed,1
       	mov	pEndTable,0
	mov	pMemory,0
	mov	pMap,0

        lea	edi,PhraseInfo
        xor	eax,eax
        mov	ecx,6
        rep 	stosd

        lea	eax,MinimumLiteral
        lea	ebx,nLiteralBits
	mov     ecx,LITERAL_SCAN_LENGTH
	cmp     ecx,_Length
	jbe     InitialScanLengthOk
	mov     ecx,_Length
 InitialScanLengthOk:
	invoke	FindOptimalLiteralSize,pSrc,ecx,eax,ebx
	mov	al,MinimumLiteral
	;mov     MinimumLiteral,0
	;mov     nLiteralBits,8

        ; set pointers to allocation and deallocation procedures
        mov     eax,pAlloc
        mov     AllocFunc,eax
        mov     eax,pDealloc
        mov     DeallocFunc,eax

        ; verify MAX_WINDOW_SIZE <= WindowSize >= MIN_WINDOWSIZE
        ; && WindowSize <= _Length of source
        cmp     WindowSize,MAX_WINDOW_SIZE
        jbe     TizOkHigh
        mov     WindowSize,MAX_WINDOW_SIZE
TizOkHigh:
        cmp     WindowSize,MIN_WINDOW_SIZE
        jae     TizOkLow
        mov     WindowSize,MIN_WINDOW_SIZE
TizOkLow:
        mov     ecx,_Length
        cmp     WindowSize,ecx
        jbe     TizOkHigh2
        mov     WindowSize,ecx
TizOkHigh2:
        mov	ecx,WindowSize
        dec	ecx
        mov	MaxPhraseLength,ecx

        ; allocate table holding pointers to most recently
        ; added nodes to linked lists.
        invoke  DoCallAlloc,AllocFunc,10000h*4
	test	eax,eax
	jz	ReturnFailure
        mov     pEndTable,eax

        ; allocate memory for Node storage, we'll need
        ; WindowSize*size Node(16)
        mov     eax,WindowSize
        inc     eax
        shl     eax,4
	add	eax,4096	; add another page for fun r5.34        
        invoke  DoCallAlloc,AllocFunc,eax
       	test	eax,eax
	jz	ReturnFailure
        mov     pMemory,eax

        ; initialize memory for mapping of pMemory buffer, each
        ; byte will be a boolean indicating whether the associated
        ; node in pMemory is allocated.
        mov     eax,WindowSize
        inc     eax
        mov     MapSize,eax
        invoke  DoCallAlloc,AllocFunc,eax
	test	eax,eax
	jz	ReturnFailure
        mov     pMap,eax

        ; calculate end of source and end of destination pointers
        mov     esi,pSrc
        mov     edi,pDest
        mov     ecx,_Length

        push    ecx
        add     ecx,esi
        mov     EndOfSource,ecx
        pop     ecx
        add     ecx,edi
        mov     EndOfDestination,ecx
SkipAddition:

        ; initialize ebx for bit output procedures
        mov     ebx,1

        mov	(_JCALG1_HEADER ptr [edi]).wSig,'CJ'
        mov	eax,_Length
        mov	(_JCALG1_HEADER ptr [edi]).dwUncompressedSize,eax
        cmp     bDisableChecksum,1
        jnz     DoChecksum
        mov	(_JCALG1_HEADER ptr [edi]).dwChecksum,0
        jmp     SkippedChecksum
DoChecksum:
        pushad
        mov     esi,pSrc
        mov     ecx,eax
        CHECKSUM32_MACRO
        mov	(_JCALG1_HEADER ptr [edi]).dwChecksum,eax
        popad
        SkippedChecksum:
        add	edi,size _JCALG1_HEADER

	; store literal information
	StoreLiteralSizeChange MinimumLiteral, nLiteralBits

        ; emit first literal
        AddNode
        _lodsb
        test    al,al
        jnz     FirstIsNotZero
        push    eax
        StoreOneBytePrefix
        mov	eax,1
        StoreXBits ONEBYTE_PHRASE_BITS
        pop     eax
        jmp     DidStoreFirstLiteral
 FirstIsNotZero:
        StoreLiteral MinimumLiteral
 DidStoreFirstLiteral:
        AddNode
        dec     esi

	jmp	DoSetNewBlock
;
; The main compression loop
;
EncodeLoop:
        sub	ecx,pLastBlockSrc
        cmp	ecx,BLOCK_SIZE
        jb	NotNewBlock
        ; could we compress this block?
        mov	edx,edi
        sub	edx,pLastBlockDest
        cmp	edx,ecx
        ja	CouldNotCompressBlock
DoSetNewBlock:
	mov	pLastBlockSrc,esi
	mov	ecx,CurrentPhraseLength
	add	pLastBlockSrc,ecx
	mov	pLastBlockDest,edi
	mov	nLastBlockBitOutEbx,ebx
	mov	eax,LastIndexUsed
	mov	nLastBlockLastIndexUsed,eax
	mov	eax,CurrentBase
	mov	nLastBlockCurrentBase,eax
	mov	al,MinimumLiteral
	mov	nLastBlockMinimumLiteral,al
	mov	eax,nLiteralBits
	mov	nLastBlockLiteralBits,eax
	mov	bCompressedLastBlock,1
	jmp	NotNewBlock
CouldNotCompressBlock:
        ; if new block, then add number of nodes up to block limit
        mov	edx,esi
        sub	edx,pLastBlockSrc
        mov	ecx,BLOCK_SIZE
        sub	ecx,edx
        inc	esi
        dec	ecx
        jz	BlockAlignPerfect
BlockAddNodeLoop:
        inc	esi
        AddNode
        dec	ecx
        jnz	BlockAddNodeLoop
BlockAlignPerfect:
	mov	esi,pLastBlockSrc
	mov	edi,pLastBlockDest
	mov	ebx,nLastBlockBitOutEbx
	mov	eax,nLastBlockCurrentBase
	mov	CurrentBase,eax
	mov	eax,nLastBlockLastIndexUsed
	mov	LastIndexUsed,eax
	mov	eax,nLastBlockLiteralBits
	mov	nLiteralBits,eax
	mov	al,nLastBlockMinimumLiteral
	mov	MinimumLiteral,al
	StoreLiteralBlock
	mov	bCompressedLastBlock,0
	mov	pLastBlockSrc,esi
	mov	pLastBlockDest,edi
	mov	nLastBlockBitOutEbx,ebx
	mov	UsedALazy,0
	mov	ByteCount,LITERAL_SIZE_CHANGE_FREQUENCY+1
	StoreZero
	jmp	SkipAddNode
NotNewBlock:
        ; We've already added an additional node during the lazy
        ; evaluation so we only need to add CurrentPhraseLength-1
        ; nodes starting at P+1.
        ; CurrentPhraseLength holds size of last encoded phrase
        mov     ecx,CurrentPhraseLength
        add	ByteCount,ecx
        inc     esi
        dec     ecx
        jz      SkipAddNode
AddNodeLoop:
        inc     esi
        AddNode
        dec     ecx
        jnz     AddNodeLoop
SkipAddNode:
        ; verify we're not at the end of the source
        mov     ecx,EndOfSource
        cmp     ecx,esi
        jbe     ReturnComp
        ; recalculate MaxPhraseLength, we don't want a phrase
        ; extending beyond EndOfSource (clearly)
        sub     ecx,esi
        cmp     ecx,MaxPhraseLength
        jae     NoChangeMaxPhraseLength
        mov     MaxPhraseLength,ecx
NoChangeMaxPhraseLength:
        cmp     MaxPhraseLength,3
        jbe     EncodeLiteralNoLazy

        cmp	ByteCount,LITERAL_SIZE_CHANGE_FREQUENCY
        jb	NoChangeLiteralSize
        mov	ByteCount,0
        push	ebx
	mov	al,MinimumLiteral
	mov	tempMinimumLiteral,al
        mov	eax,nLiteralBits
        mov	tempnLiteralBits,eax
        lea	eax,tempMinimumLiteral
        lea	ebx,tempnLiteralBits
        mov	ecx,MaxPhraseLength
        cmp	ecx,LITERAL_SCAN_LENGTH
        jb	UseMaxPhraseLength
        mov	ecx,LITERAL_SCAN_LENGTH
UseMaxPhraseLength:
	invoke	FindOptimalLiteralSize,esi,ecx,eax,ebx
	pop	ebx
	mov	eax,tempnLiteralBits
	cmp	eax,nLiteralBits
	jnz	DoChangeLiteralSize
	mov	al,tempMinimumLiteral
	cmp	al,MinimumLiteral
	jz	NoChangeLiteralSize
DoChangeLiteralSize:
	mov	eax,tempnLiteralBits
	mov	nLiteralBits,eax
	mov	al,tempMinimumLiteral
	mov	MinimumLiteral,al
	StoreLiteralSizeChange MinimumLiteral, nLiteralBits
NoChangeLiteralSize:

        ; adjust the current window size
        mov     ecx,esi
        sub     ecx,pSrc
        cmp     ecx,WindowSize
        jbe     TizOkWindow
        mov     ecx,WindowSize
TizOkWindow:
        mov     CurrentWindowSize,ecx

        ; ecx=window size
        ; check for necessary ""base" change for phrase encoding
        cmp     ecx,BASE1_WINDOW
        jbe     ChgedBase
        mov	eax,BASE1
        cmp	ecx,BASE2_WINDOW
        jbe	DoChgBase
        PerformBaseChange BASE2
        jmp	ChgedBase
DoChgBase:
        PerformBaseChange BASE1
ChgedBase:

        ; if we selected a phrase we found during a lazy evaluation,
        ; or encoded a literal, then we've already done the search
        ; for a phrase at P when we searched for a phrase at P+1
        ; during th previous iteration.
        cmp     UsedALazy,0
        jz      DidNtUseLazy
TwoLiterals:
        ; slap lazy evaluation phrase (P+1 on prev iter) information
        ; into first phrase evaluation (P on current iter)
        push    edi
        push    esi
        lea     esi,PhraseInfo.SecondIndex
        lea     edi,PhraseInfo.FirstIndex
        mov     ecx,3
        rep_movsd
        add     PhraseInfo.FirstSaves,LAZY_WEIGHT_ITERATION_INCREASE
        xor     eax,eax
        lea     edi,PhraseInfo.SecondIndex
        mov     ecx,3
        rep_stosd
        pop     esi
        pop     edi
        jmp     DoLazyEvaluation        ; skip to evaluation of P+1

DidNtUseLazy:
        ; Perform search for phrase at P
        invoke  SearchForLongestPhrase,pSrc,esi,WindowSize,0,MaxPhraseLength,CurrentBase,pEndTable,LastIndexUsed
        mov     PhraseInfo.FirstLength,ecx
        mov     PhraseInfo.FirstSaves,edx
        mov     PhraseInfo.FirstIndex,eax
DoLazyEvaluation:
        ; add node for search for phrase at P+1
        inc     esi                  ; move source ptr to P+1
        AddNode
        ; decrement the maximum phrase length since we're one
        ; step closer to EndOfSource
        mov     ecx,MaxPhraseLength
        dec     ecx
        invoke  SearchForLongestPhrase,pSrc,esi,WindowSize,0,ecx,CurrentBase,pEndTable,LastIndexUsed
        mov     PhraseInfo.SecondLength,ecx
        mov     PhraseInfo.SecondIndex,eax
        dec     esi                 ; decrement esi from above increment

        cmp     edx,LAZY_WEIGHT_ITERATION_INCREASE
        jb      NoLazySub
        sub     edx,LAZY_WEIGHT_ITERATION_INCREASE
NoLazySub:
        mov     PhraseInfo.SecondSaves,edx

        cmp     PhraseInfo.SecondLength,0    ; did we find phrase at P+1
        jz      UseNormalWindow              ; if not, then use phrase at P
        mov     ecx,PhraseInfo.SecondSaves   ; else, compare to phrase at P and
        cmp     ecx,PhraseInfo.FirstSaves    ; select one that saves the most bits
        ja      EncodeLiteral                ; if P+1 selected, encode literal this
                                             ; iteration.
UseNormalWindow:
        cmp     PhraseInfo.FirstLength,0     ; do we have a phrase at P?
        jz      EncodeLiteral                ; if not, encode literal
        mov	eax,8
        sub	eax,nLiteralBits
        cmp	PhraseInfo.FirstSaves,eax
        jb	EncodeLiteral


        ; setup eax->phrase, CurrentPhraseLength=ecx=Length
        mov     eax,PhraseInfo.FirstIndex
        mov     ecx,PhraseInfo.FirstLength
        mov     CurrentPhraseLength,ecx
        jmp     EncodePhrase

; Encode literal or one byte phrase.
EncodeLiteral:
        mov     UsedALazy,1              ; indicate we encoded one byte
EncodeLiteralNoLazy:
        xor     eax,eax
        _lodsb                            ; load source byte
	or	al,al
	jnz	IsNotZero
	; encode zero
        StoreOneBytePrefix
        mov	eax,1
        StoreXBits ONEBYTE_PHRASE_BITS
	jmp	FinishOneByte
IsNotZero:
        ;cmp	nLiteralBits,7
        ;jbe	NotOneBytePhraseNoPop
        ; check to see if there is a matching byte within a 10h
        ; window, if so then encode a one byte phrase
        push    edi
        push    ebx

        cmp     CurrentWindowSize,ONEBYTE_PHRASE_RANGE
        jae     UseFull
        mov     ecx,CurrentWindowSize
        jmp     UsedSmaller
UseFull:
        mov     ecx,ONEBYTE_PHRASE_RANGE
UsedSmaller:
        mov     edi,esi
        mov     ebx,ecx
        sub     edi,2
        repne_std_scasb
        jnz     @NotOneBytePhrase
        dec     ecx

        mov     eax,ebx
        sub     eax,ecx
        inc	eax
        pop     ebx
        pop     edi
        StoreOneBytePrefix
        StoreXBits ONEBYTE_PHRASE_BITS
FinishOneByte:
        dec     esi
        mov     CurrentPhraseLength,1
        jmp     FinishIteration

@NotOneBytePhrase:
        pop     ebx
        pop     edi
NotOneBytePhraseNoPop:
        StoreLiteral MinimumLiteral
        ;StoreLiteralPrefix
        ;StoreXBits nLiteralBits
EncodedLiteral:
        dec     esi
        mov     CurrentPhraseLength,1
        jmp     FinishIteration

; Encode normal or short phrase
EncodePhrase:
        mov     UsedALazy,0
EncodePhraseForceLazy:
	mov     CurrentIndex,eax
        cmp     eax,LastIndexUsed
        jnz     NotLastUsed
        StoreNormalPrefix
        EncodeIndex
        mov     eax,CurrentPhraseLength
        EncodeGammaForLength
        jmp     FinishIteration
NotLastUsed:
        cmp     eax,SHORT_RANGE
        ja      NotShortEncode
        mov     ecx,CurrentPhraseLength
        cmp     ecx,MAXIMUM_SHORT_SIZE
        ja      NotShortEncode
ifdef extra_data
        inc     ShortCount
endif
NotShortSameAsLast:
        mov     LastIndexUsed,eax
        StoreShortPrefix
        sub     ecx,2
        push    ecx
        StoreXBits SHORT_BITS
        pop     eax
        StoreXBits 2
        jmp     FinishIteration
        ; ---
NotShortEncode:
        PerformIndexRangeLengthDecrementation

DecrementationDone:
        ifdef extra_data
        inc     NormalCount
        endif

        push    ecx
        StoreNormalPrefix
        EncodeIndex
        mov     LastIndexUsed,eax
        pop     eax
        EncodeGammaForLength

FinishIteration:
        cmp     pCallback,0
        jz      NoCallback
        mov     ecx,IterationCount
        inc     ecx
        mov     IterationCount,ecx
        cmp     ecx,CALLBACK_ON_ITERATION
        jnz     NoCallback
        mov     IterationCount,0
        pushad
        sub     esi,pSrc
        sub     edi,pDest
        push    edi
        push    esi
        call    [pCallback]
        test    eax,eax
        jnz     SkipCallback
        popad
        jmp     ReturnFailure
SkipCallback:
        popad
NoCallback:
        cmp     edi,EndOfDestination
        ja      ReturnFailure
        jmp     EncodeLoop
        cmp     esi,EndOfSource
        jb      EncodeLoop

ReturnComp:
        cmp     pCallback,0
        jz      SkipCallback2
        pushad
        sub     esi,pSrc
        sub     edi,pDest
        push    edi
        push    esi
        call    [pCallback]
        popad
SkipCallback2:

        StoreShortPrefix
        xor     eax,eax
        ;dec     eax
        StoreXBits SHORT_BITS
        xor     eax,eax
        StoreXBits 2

FlushBits:
        cmp     ebx,1
        jz      FlushDone
        StoreBit
        jmp     FlushBits
        FlushDone:

        PerformDeallocations

        mov     eax,edi
        sub     eax,pDest

        pop	esi
        pop	edi
        pop	ebx

        ret

ReturnFailure:

        PerformDeallocations

        xor     eax,eax

        pop	esi
        pop	edi
        pop	ebx

        ret
JCALG1_Compress endp
;
; SearchForLongestPhrase
; returns:
;    eax->index (or null if no phrases found)
;    ecx=length
;    edx=estimation of # of bits saved
;
; ebx holds last node pointer in linked list through this
;  function and SearchForPhrase.
;
;
ALIGN 16
SearchForLongestPhrase proc pSrc:DWORD,pString:DWORD, \
        WindowSize:DWORD,PreviousFind:DWORD,MaximumPhraseLength:DWORD, \
        CurrentBase:DWORD, pEndTable:DWORD, LastIndexUsed:DWORD

        LOCAL   LastIndex:DWORD
        LOCAL   LastLength:DWORD
        LOCAL   LastIndexEncode:DWORD
        LOCAL   BestPhraseSaves:DWORD
        LOCAL   LastPhraseMaximumSize:DWORD
        LOCAL   LastPhrasePointer:DWORD

        push    ebx

        mov     LastLength,0
        mov     LastIndex,0
        mov     LastIndexEncode,0
        mov     BestPhraseSaves,0
        mov     LastPhraseMaximumSize,0

        mov     ecx,2

        xor     ebx,ebx         ; no initial node pointer

; ecx=current phrase search length
LongestLoop:
        invoke  SearchForPhrase,pSrc,pString,ecx,WindowSize,MaximumPhraseLength,pEndTable        
        jnc     GotMax
        ;
        ; make sure current phrase isn't the same as last phrase in length and location
        ; this should never really happen... but what the hell
        cmp     ecx,LastPhraseMaximumSize
        jnz     NotSame
        cmp     eax,LastPhrasePointer
        jz      GotMax
NotSame:

	;
	; save the index and size of the last found phrase
	;
        mov     LastPhraseMaximumSize,ecx
        mov     LastPhrasePointer,eax
        ;---- perform estimation of bits saved
        push    eax
        push    ecx

        cmp     eax,LastIndexUsed
        jz      NoShortEncode
        cmp     eax,SHORT_RANGE
        ja      NoShortEncode
        cmp     ecx,MAXIMUM_SHORT_SIZE
        ja      NoShortEncode
        mov     LastIndexEncode,SHORT_BITS+2
        xor     ecx,ecx
        jmp     GotShort

NoShortEncode:
        EstimateBitsForIndex            ; estimate bits to encode index

        mov     LastIndexEncode,ecx     ; store number of bits to encode index
        pop     ecx                     ; ecx=length
        pop     eax                     ; eax=index
        push    eax
        push    ecx

        cmp     eax,LastIndexUsed	; compare pointer to last used index (more efficient encoding if it is)
        jz      IndexGood

	;
	; else, if not the same as the last index perform range decrementaion on the index
	;
        PerformIndexRangeLengthDecrementation ; decrement phrase length according to
                                        ; index ranges.
        cmp     ecx,2                   ; if we decremented below 2, then can't use this phrase
        jge     IndexGood
        mov     ecx,0fffffh             ; fake extremly high count to encode length
        jmp     GotShort
IndexGood:
        mov     eax,ecx                 ; eax=adjusted length
        EstimateBitsForLength           ; estimate bits to encode length
GotShort:
        add     LastIndexEncode,ecx
        pop     ecx                     ; pop phrase length
        pop     eax                     ; pop index
        push    eax                     ; save index
        push    ecx                     ; save phrae length
        shl     ecx,3                   ; size *8 (bits per byte)
        inc     ecx                     ; plus one control but for first literal (assumed)
        ; ecx=number of bits in phrase+1
        mov     eax,LastIndexEncode
        cmp     ecx,eax                 ; if number of bits in phrase <=
        jbe     NoUpdateBest            ; # of bits to encode, then we don't want it
        sub     ecx,eax                 ; # of bits in phrase - # of bits to encode = bits saved
        cmp     ecx,BestPhraseSaves     ; if # of bits saved <= best found so far,
        jbe     NoUpdateBest            ; then throw this one out
        mov     BestPhraseSaves,ecx     ; else, update best phrase saves
        pop     ecx                     ; restore phrase length
        pop     eax                     ; restore index
        mov     LastIndex,eax           ; store last found index
        mov     LastLength,ecx          ; store last found phrase length

        cmp	eax,1			; if we are not in a single-byte run, continue seaaching for sure
        ja	LongestLoop        
        cmp	ecx,RUN_BREAK		; else, see if we've reached the maximum run size we want (for speedier encoding..)
        jbe	LongestLoop		;   we don't want to search all day on this run
        ;; todo: try this instead: mov     ebx,[ebx+Node.Prev]     ; grab less recent node 
        ;		then continue search
        jmp	GotMax

ContinueSearch:
NoUpdateBest:
        pop     ecx
        pop     eax
        jmp     LongestLoop
GotMax:
        mov     eax,LastIndex
        mov     ecx,LastLength
        cmp     ecx,MaximumPhraseLength
        jbe     PhraseLenOk
        mov     ecx,MaximumPhraseLength
PhraseLenOk:
        mov     edx,BestPhraseSaves
        pop     ebx
        ret
SearchForLongestPhrase endp
;
; SearchForPhrase
; fastcall mix: ebx assumed to be pointer to last node searched
;
; returns:
;  carry if phrase of specified length found
;  eax->phrase index
;  ecx=maximum phrase length at index
;
;  ebx holds last linked list node pointer on entry and exit. Note that we search
;	backwards in the linked list.
;
;
;
ALIGN 16
SearchForPhrase proc pSrc:DWORD,pString:DWORD,_Length:DWORD,WindowSize:DWORD,MaximumPhraseLength:DWORD,pEndTable:DWORD

ifdef DEBUG
	.data 
	D1 db 13,10,'JCALG1: Entering SearchForPhrase',0
	D4 db 128 dup(0)
	D5 db 13,10,'ebx: %x  pString:%x  pSrc:%x',0	
	v1 dd 0
	v2 dd 0
	v3 dd 0
	v4 dd 0	
	.code	
	pushad		
	mov	v1,ebx
	mov	eax,pString
	mov	v2,eax
	mov	eax,pSrc
	mov	v3,eax
	
	invoke	wvsprintf,offset D4,offset D5,offset v1
	CondOutputDebugString D1
	CondOutputDebugString D4		
	popad
endif
	
        push    esi
        push    edi

        mov     edi,pString             ; edi->phrase
        mov     esi,pSrc                ; esi->start of window
        ;mov    ecx,_Length

        mov     esi,edi                 ; esi->phrase
        xor     eax,eax
        mov     ax,word ptr [esi]       ; load first word of phrase

	;
	; first word (2 bytes) of phrase is used as an index in the array
	;  of linked lists. If we already have located the appropriate
	;  linked list (ebx is set), we go on searching through it. Else,
	;  we find the appropriate linked list and start at the first
	;  node.
	;
	
        test    ebx,ebx                 ; do we have a previous node?
        jnz     TraverseListLoop        ; if so, use it

        shl     eax,2                   ; multiply by 4 to get index into
                                        ; linked list end node pointers
        mov     ebx,pEndTable		; we want to start at the end of the linked list
        add     ebx,eax                 ; ebx->end node ptr
        mov     ebx,[ebx]		; dereference node
        test    ebx,ebx                 ; no nodes for this word?
        jz      strstrNotFound          ; return failure
        
        ;
        ; get the index into the source data for this node
        ;
        mov     edi,[ebx+Node.Index]    ; else, grab index of word
        jmp     GotNode                 ; start iterations

	;
	; -- main linked list traversion loop (phrase searching)
	;
TraverseListLoop:
	 	
        mov     ebx,[ebx+Node.Prev]     ; grab less recent node
 	
        test    ebx,ebx                 ; outta nodes?
        jz      strstrNotFound          ; return phrase not found
        mov     edi,[ebx+Node.Index]    ; load pointer to word occurance
GotNode:
        cmp     edi,esi                 ; is pointer > source
        jae     TraverseListLoop        ; if so, skip this index

        push    edx
        push    ebx

        push    esi
        push    edi

        push    ecx

        mov     edx,MaximumPhraseLength

        sub     ecx,2
        mov     ax,word ptr [esi+ecx]
        cmp     word ptr [edi+ecx],ax
        jnz     dotraverse
        ;add     esi,2
        ;add     edi,2
        ;sub     ecx,2
        ;or      ecx,ecx
        ;js      foundphrase
        ;cmp     edx,4           ;503
        ;jbe     foundphrase
        special_rep_cmps
        jnz     dotraverse
foundphrase:
        pop     ecx
        pop     edi
        pop     esi
        push    esi
        push    edi
        add     edi,ecx
        add     esi,ecx

        sub     ecx,4
_rep_cmps_loop:
        add     ecx,4
        mov     eax,edx
        sub     eax,4
        js      _ext_cmp_end    ;r523
        cmp     ecx,eax
        jae     _ext_cmp_end    ;ja->jae503
        _cmpsd
        jz      _rep_cmps_loop
        dec     ecx
        sub     esi,4
        sub     edi,4
_rep_db_loop:
        inc     ecx
        cmp     ecx,edx
        jae     _ext_cmp_end    ;ja->jae503
        _cmpsb
        jz      _rep_db_loop
_ext_cmp_end:
        cmp     ecx,edx
        jbe     size_fine
IsMaximumSize:
        mov     ecx,edx
size_fine:

        pop     edi
        pop     esi

        pop     ebx
        pop     edx
strstrFound:                            ; return phrase found
        mov     eax,edi                 ; eax->location in window (index)
Exitstrstr:
        ; calculate relative index
        mov     esi,pString             ; esi->current pointer
        sub     esi,eax
        mov     eax,esi                 ; eax=pString-ptr to found phrase (relative index)
ReturnSFP:
        pop     edi
        pop     esi
        stc                             ; carry=found
        ret

dotraverse:

        pop     ecx
dotraverse_nopopecx:
        pop     edi
        pop     esi
        pop     ebx
        pop     edx
        jmp     TraverseListLoop        ; onwards to next phrase

strstrNotFound:                         ; return phrase not found
        pop     edi
        pop     esi
        clc
        ret

SearchForPhrase endp

FindOptimalLiteralSize proc pSrc:DWORD, _Length:DWORD, pMinimumLiteral:DWORD, pLiteralBitSize:DWORD
        LOCAL MinimumLiteral:BYTE
        LOCAL MaximumLiteral:BYTE

	pushad
ifdef DEBUG	
	.data
	szD2 db 'Entering FindOptimalLiteralSize',0
	.code
	CondOutputDebugString szD2
endif	

        mov	MinimumLiteral,0ffh
        mov	MaximumLiteral,0

        ; find largest and smallest bytes in source buffer
        ; (for possible literal optimization)
        mov	esi,pSrc
        mov	ecx,_Length
        xor	eax,eax
 MinMaxLoop:
 	;lodsb
 	mov	al,byte ptr [esi]
 	inc	esi
 	cmp	al,MinimumLiteral
 	jae	NotNewMinimum
 	;or	al,al			; don't allow zero
 	;jz	NotNewMinimum
 	mov	MinimumLiteral,al
 NotNewMinimum:
 	cmp	al,MaximumLiteral
 	jbe	NotNewMaximum
 	mov	MaximumLiteral,al
 NotNewMaximum:
        dec     ecx
        jnz     MinMaxLoop		;; faster than loop
 	;loop	MinMaxLoop

	mov	al,MaximumLiteral
 	sub	al,MinimumLiteral
 	jnz	NoForgetChange
 	mov	esi,pSrc
 	mov	al,byte ptr [esi]
 	cmp	al,MinimumLiteral
 	jz	SkipLiteralBitChange
NoForgetChange:
 	cmp	al,127
 	jbe	DoUseSevenBits
 	mov	ecx,8
 	mov	MinimumLiteral,0
 	jmp	SetLiteralBits
 DoUseSevenBits:
 	mov	ecx,7
 	jmp	SetLiteralBits

 SetLiteralBits:
 	mov	al,MinimumLiteral
 	mov	edi,pMinimumLiteral
 	mov	byte ptr [edi],al

 	mov	edi,pLiteralBitSize
 	mov	dword ptr [edi],ecx
 SkipLiteralBitChange:
ifdef DEBUG	
	.data
	szD3 db 'Entering FindOptimalLiteralSize',0
	.code
	CondOutputDebugString szD3
endif	

 	popad
 	ret
FindOptimalLiteralSize endp

JCALG1_GetNeededBufferSize proc stdcall nLength:DWORD
	mov	eax,nLength
	add	eax,4
	ret
JCALG1_GetNeededBufferSize endp

ConditionalEnd