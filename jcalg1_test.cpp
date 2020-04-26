/*
	JCALG1 Test Application v2.10, (c)1999-2001 by Jeremy Collake
	http://www.collakesoftware.com
	collake@charter.net
	jeremy@collakesoftware.com

	This is a short and sweet program to test JCALG1 and show its
	usage in VC++. This is utter crap for code.

	Notes: Win32 Only.

*/

#include<stdio.h>
#include<windows.h>
#include<winuser.h>
#include"jcalg1.h"


void * _stdcall AllocFunc(DWORD nMemSize)
{	
	return (void *)GlobalAlloc(GMEM_FIXED,nMemSize);
}

bool _stdcall DeallocFunc(void *pBuffer)
{
	GlobalFree((HGLOBAL)pBuffer);
	return true;
}

bool _stdcall CallbackFunc(DWORD pSourcePos, DWORD pDestinationPos)
{	
	printf("\r %u",(unsigned int)pSourcePos);
	return true;
}

main(int argc, char **argv)
{
	HANDLE hInputFile;
	HANDLE hOutputFile;
	char *pData;
	char *pBuffer;
	bool bCompress;	
	unsigned int nFilesize;
	unsigned long nBytesRead;
	unsigned int nCompressedSize;
	unsigned int nWindowSize;
	_JCALG1_Info Jcalg1_Info;

	printf("\n -------------------------------------------");
	printf("\n JCALG1 Test Application v2.10");
	printf("\n (c)2001 Jeremy Collake");
	printf("\n http://www.collakesoftware.com");
	printf("\n jeremy@collakesoftware.com");
	printf("\n -------------------------------------------\n");
	
	if(argc!=4)
	{
		printf("\n Command line syntax error!");
		printf("\n USAGE: jcalg1_test [cX|d] infile outfile[/TEMP]");
		printf("\n  Where X is the compression level, 1 to 9.");
		printf("\n Examples: ");
		printf("\n  jcalg1_test c6 myfile.tst comp.tst");
		printf("\n   -compressed myfile.tst to comp.tst with 6th level of compression.");
		printf("\n  jcalg1_test d comp.tst myfile.tst");
		printf("\n   -decompresses comp.tst to myfile.tst.");
		return 6;
	}
	if(toupper(argv[1][0])=='C')
	{
		bCompress=true;		
		switch(argv[1][1])
		{
		case '1':
			nWindowSize=4*1024;
			break;
		case '2':
			nWindowSize=8*1024;
			break;
		case '3':
			nWindowSize=16*1024;
			break;
		case '4':
			nWindowSize=32*1024;
			break;
		case '5':
			nWindowSize=64*1024;
			break;
		case '6':
			nWindowSize=128*1024;
			break;
		case '7':
			nWindowSize=256*1024;
			break;
		case '8':
			nWindowSize=512*1024;
			break;
		case '9':
			nWindowSize=1024*1024;
			break;
		default:
			printf("\n Error: Invalid compression level.");
			return 9;			
		}
	}
	else
	{
		bCompress=false;
	}
	
	JCALG1_GetInfo(&Jcalg1_Info);

	printf("\n Algorithm revision: %d.%d", Jcalg1_Info.majorVer, Jcalg1_Info.minorVer);
	printf("\n Small decompressor size: %d", Jcalg1_Info.nSmallSize);
	printf("\n Fast decompressor size:  %d\n", Jcalg1_Info.nFastSize);
	
	char szInFile[MAX_PATH];

	strcpy(szInFile,argv[2]);

	hInputFile=CreateFile(szInFile,GENERIC_READ,0,0,OPEN_EXISTING,0,0);
	
	if(hInputFile==INVALID_HANDLE_VALUE)
	{
		printf("\n Error: Opening input file.");
		return 1;
	}
	
	char szOutFile[MAX_PATH];
	char szTest[256];	
	strcpy(szTest,argv[3]);
	strupr(szTest);
	DWORD dwFlags=FILE_ATTRIBUTE_NORMAL;	
	
	if(strstr(szTest,"/TEMP"))
	{
		char szTempPath[MAX_PATH];
		GetTempPath(MAX_PATH-1,szTempPath);
		GetTempFileName(szTempPath,"jc",0,szOutFile);				
		dwFlags|=FILE_ATTRIBUTE_TEMPORARY|FILE_FLAG_DELETE_ON_CLOSE;		
	}
	else
	{		
		strcpy(szOutFile,argv[3]);
	}
		
	hOutputFile=CreateFile(szOutFile,GENERIC_WRITE,0,0,CREATE_ALWAYS,dwFlags,0);
	if(hOutputFile==INVALID_HANDLE_VALUE)
	{
		printf("\n Error: Opening output file.");
		return 1;
	}
	nFilesize=GetFileSize(hInputFile,NULL);
	
	pData=(char *)malloc(nFilesize);	
	if(bCompress)
	{
		ReadFile(hInputFile,(void *)pData,nFilesize,&nBytesRead,0);
		if(!nBytesRead)
		{
			printf("\n Error: No data read from input file!");
			CloseHandle(hOutputFile);
			CloseHandle(hInputFile);
			return 7;
		}			
		pBuffer=(char *)malloc(JCALG1_GetNeededBufferSize(nFilesize));		
		printf("\n Compressing ..\n");				
		nCompressedSize=
			JCALG1_Compress((void *)pData,nFilesize,(void *)pBuffer,nWindowSize,&AllocFunc,&DeallocFunc,&CallbackFunc,0);
		
		if(!nCompressedSize)
		{
			printf("\n Error: Could not compress!");
			CloseHandle(hOutputFile);
			CloseHandle(hInputFile);
			free((void *)pBuffer);
			free((void *)pData);
			return 3;
		}
		printf("\r Original Size: %u Compressed Size: %u Ratio: %.02f", 
			nFilesize, nCompressedSize, (float)nCompressedSize/nFilesize);			

		WriteFile(hOutputFile,(void *)pBuffer,nCompressedSize,&nBytesRead,0);			

		printf("\n Testing decompression of fast decompressor ... ");
		char *pTestDecomp=(char *)malloc(JCALG1_GetUncompressedSizeOfCompressedBlock((void *)pBuffer));
		unsigned int nExpandedSize=JCALG1_Decompress_Fast((void *)pBuffer,(void *)pTestDecomp);				
		if(nExpandedSize!=nFilesize)
		{			
failedmsg:			
			printf("FAILED!");
			return -1;
		}				
		for(unsigned int nI=nFilesize-1;nI>0;nI--)
		{			
			if(*(pData+nI)!=*(pTestDecomp+nI))
				goto failedmsg;
		}
		printf("OK.");	
		
		printf("\n Testing decompression of small decompressor ... ");
		ZeroMemory(pTestDecomp,nFilesize);
		nExpandedSize=JCALG1_Decompress_Small((void *)pBuffer,(void *)pTestDecomp);	
		if(!nExpandedSize)
		{
			printf("\n Checksum error..");
			goto failedmsg;
		}

		for(nI=nFilesize-1;nI>0;nI--)
		{			
			if(*(pData+nI)!=*(pTestDecomp+nI))
				goto failedmsg;
		}
		printf("OK.");	

	}
	else
	{
		nCompressedSize=nFilesize;		
		ReadFile(hInputFile,(void *)pData,nCompressedSize,&nBytesRead,0);
		nFilesize=JCALG1_GetUncompressedSizeOfCompressedBlock((void *)pData);
		if(!nFilesize)
		{
			printf("\n Error: Not a valid compressed file.");
			return 8;
		}		
		printf("\n Uncompressed Size: %u", nFilesize);
		pBuffer=(char *)malloc(nFilesize);		
		if(!nBytesRead)
		{
			printf("\n Error: No data read from input file!");
			CloseHandle(hOutputFile);
			CloseHandle(hInputFile);
			return 7;
		}	
		nFilesize=JCALG1_Decompress_Fast((void *)pData,pBuffer);
		WriteFile(hOutputFile,pBuffer,nFilesize,&nBytesRead,0);
		printf("\n Compressed Size: %u Uncompressed Size: %u",
			nCompressedSize,nFilesize);		
	}
	free(pBuffer);
	free((void *)pData);
	CloseHandle(hInputFile);
	CloseHandle(hOutputFile);
	printf("\n All done!");
	return 0;
}


