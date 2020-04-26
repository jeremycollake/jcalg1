typedef bool (__stdcall *PFNCALLBACKFUNC)(DWORD, DWORD);
typedef void * (__stdcall *PFNALLOCFUNC)(DWORD);
typedef bool (__stdcall *PFNDEALLOCFUNC)(void *);

struct _JCALG1_Info
{
	DWORD majorVer;
	DWORD minorVer;
	DWORD nFastSize;
	DWORD nSmallSize;
};


extern "C" DWORD _stdcall JCALG1_Compress(
	const void *Source,
	DWORD Length,
	void *Destination,
	DWORD WindowSize,
	PFNALLOCFUNC,
	PFNDEALLOCFUNC,
	PFNCALLBACKFUNC,
	BOOL bDisableChecksum);

extern "C" DWORD _stdcall JCALG1_Decompress_Fast(
	const void *Source,
	void *Destination);

extern "C" DWORD _stdcall JCALG1_Decompress_Small(
	const void *Source,
	void *Destination);

extern "C" DWORD _stdcall JCALG1_GetNeededBufferSize(
	DWORD nSize);

extern "C" DWORD _stdcall JCALG1_GetInfo(
	_JCALG1_Info *JCALG1_Info);

extern "C" DWORD _stdcall JCALG1_GetUncompressedSizeOfCompressedBlock(
	const void *pBlock);

extern "C" DWORD _stdcall JCALG1_GetNeededBufferSize(
	DWORD nSize);











