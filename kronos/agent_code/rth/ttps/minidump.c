#include <windows.h>
#include <dbghelp.h>
#include <stdio.h>

void minidump_write()
{
    HANDLE                              hFile;
    MINIDUMP_EXCEPTION_INFORMATION      mei;
    EXCEPTION_POINTERS                  ep;
    DWORD                               wine_opt;

    hFile = CreateFile("C:\\temp\\outdump.dmp", GENERIC_READ|GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
                       FILE_ATTRIBUTE_NORMAL, NULL);

    if (hFile == INVALID_HANDLE_VALUE) return;

    MiniDumpWriteDump((HANDLE)-1, 15832,
                      hFile, MiniDumpWithFullMemory/*|MiniDumpWithDataSegs*/,
                      NULL, NULL, NULL);

    CloseHandle(hFile);
}


int main() {


    minidump_write();


    return 0;
}
