option casemap:none 
.486p 
.model flat,stdcall

include checksum32.asm

; for TASM compatability
ifdef TASM
	invoke equ call	
endif
ifndef ConditionalEnd
	ConditionalEnd equ 
endif

MAJOR_REV = 5
MINOR_REV = 32

BLOCK_SIZE 		equ 256
ERROR_CANNOT_COMPRESS   equ 0

_JCALG1_HEADER STRUCT
  wSig         dw ?
  dwUncompressedSize dd ?
  dwChecksum    dd ?
_JCALG1_HEADER ENDS
  
_JCALG1_Info STRUCT
  MajorRevision dd ?
  MinorRevision dd ?
  FastDecompressorSize dd ?
  SmallDecompressorSize dd ?
_JCALG1_Info ENDS  
  
Node STRUCT
  Index    dd ?
  Next     dd ?
  Prev     dd ?
  NpEnd    dd ?
Node ENDS

_PhraseInfo STRUCT
  FirstIndex  	  	dd ?
  FirstLength 	  	dd ?
  FirstSaves		dd ?
  SecondIndex 		dd ?
  SecondLength 		dd ?
  SecondSaves		dd ?
_PhraseInfo ENDS  
 
TYPE3_BITS = 8
ONEBYTE_PHRASE_RANGE = 10000b-2
ONEBYTE_PHRASE_BITS  = 4

MAXIMUM_SHORT_SIZE equ 5
SHORT_RANGE = 1111111b
SHORT_BITS  = 7

; these values may be further optimized!!
INITIAL_BASE equ 8
BASE1 	     equ 9
BASE1_WINDOW equ 48*1024 
BASE2	     equ 10	
BASE2_WINDOW equ 64*1024	
DecrementIndex1 = 027fh		
DecrementIndex2 = 037ffh		
DecrementIndex3 = 010000h	

MIN_WINDOW_SIZE = 1024
MAX_WINDOW_SIZE = 0ffffffeh 
MAX_PHRASE_LENGTH = 8000h
MIN_PHRASE_LENGTH = 2

RUN_BREAK = 64

CALLBACK_ON_ITERATION = 96

LAZY_WEIGHT_ITERATION_INCREASE = 3
LITERAL_SIZE_CHANGE_FREQUENCY = 1024
LITERAL_SCAN_LENGTH = LITERAL_SIZE_CHANGE_FREQUENCY

LITERAL_BITSIZE = 1
