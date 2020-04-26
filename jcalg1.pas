unit JCALG1;

{
  Delphi interface for JCALG1 r5.15
  by Jordan Russell
}

interface

uses
  Windows;

type
  TJCALG1_AllocFunc = function(Size: Integer): Pointer; stdcall;
  TJCALG1_DeAllocFunc = function(Memory: Pointer): BOOL; stdcall;
  TJCALG1_CallbackFunc = function(CurrentSrc, CurrentDest: Integer): BOOL; stdcall;
  TJCALG1_Info = packed record
    MajorRev: Integer;
    MinorRev: Integer;
    FastDecompressorSize: Integer;
    SmallDecompressorSize: Integer;
  end;

function JCALG1_Compress(Source: Pointer; Length: Integer; Destination: Pointer;
  WindowSize: Integer; pAlloc: TJCALG1_AllocFunc; pDealloc: TJCALG1_DeAllocFunc;
  pCallback: TJCALG1_CallbackFunc, bDisableChecksum: Integer): Integer;
  stdcall; external;

function JCALG1_Decompress_Fast(Source, Destination: Pointer): Integer;
  stdcall; external;

function JCALG1_Decompress_Small(Source, Destination: Pointer): Integer;
  stdcall; external;

function JCALG1_GetUncompressedSizeOfCompressedBlock(Block: Pointer): Integer;
  stdcall; external;

function JCALG1_GetNeededBufferSize(Size: Integer): Integer;
  stdcall; external;

procedure JCALG1_GetInfo(var Info: TJCALG1_Info);
  stdcall; external;

implementation

{$L jcalg1_borland.obj}

end.
