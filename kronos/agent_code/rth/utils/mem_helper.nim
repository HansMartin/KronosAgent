import winapi_wrapper
import utils
import winim/lean

#[
  The most used feature: Making a region writable,
  writing the desired shellcode/patch/... to it and
  making the region executable again
]#
proc protectAndWrite*(bufferPtr: pointer, bufferSize: int, dstPtr: pointer): bool =

  var
    success: NTSTATUS
    destination = dstPtr
    oldProtect: ULONG
    patchSize: SIZE_T = bufferSize
    bytesWritten: ULONG = 0

  let procHandle: HANDLE = -1

  #DBG(fmt"Addess to write patch: {cast[int](destination):#X}")
  DBG("Addess to write patch: " & $cast[int](destination))

  # The next VirtualProtect will turn the memory
  # region to be writable to apply the patch
  success = wNtProtectVirtualMemory(procHandle,
      cast[ptr PVOID](addr destination),
      addr patchSize,
      PAGE_READWRITE,
      addr oldProtect)

  if success == STATUS_SUCCESS:
    DBG("[+] Made Region writable")
  else:
    DBG("[-] Failed to make region writable")
    return false

  # reset because of weird effects...
  destination = dstPtr
  # Writing the patch to the desired patch
  success = wNtWriteVirtualMemory(procHandle,
      destination,
      bufferPtr,
      cast[ULONG](bufferSize),
      addr bytesWritten)

  if success == STATUS_SUCCESS:
    DBG("[+] Wrote patch")
  else:
    DBG("[-] Failed to write patch to memory")
    return false

  # Reset the payload size
  patchSize = bufferSize

  # Turn the potection back to read/execute
  success = wNtProtectVirtualMemory(procHandle,
      cast[ptr PVOID](addr destination),
      addr patchSize,
      PAGE_EXECUTE_READ,
      addr oldProtect)

  if success == STATUS_SUCCESS:
    DBG("[+] Turned region back to executable")
  else:
    DBG("[-] Failed to make region executable")
    return false
  return true


