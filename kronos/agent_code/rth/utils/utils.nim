#[
  This file contains helper functions
  that are used across the project.
]#
import ../rth
import std/enumerate
import winim


# For debugging output
# By using a Template, it evaluates in-place
# meaning that when compiling for release, the
# DBG() message will not result in the binary
template DBG*(msg: string) =
  when defined(debug):
    echo msg


#[
  Decrypt a the Payload buffer with an xor key
]#
proc decrypt*(payload: var Payload, key: byte) =
  for i, b in enumerate(payload.bytes):
    payload.bytes[i] = b.xor(key)

  # set encrypted to false
  payload.isEncrypted = false




#[
  The following utilities hold
  helper for reading from (raw) memory
]#

# Memory Helper

#[
  The following utilities hold
  helper for reading from (raw) memory
]#

proc toStringW(chars: openArray[WCHAR]): string =
    result = ""
    for c in chars:
        if cast[char](c) == '\0':
            break
        result.add(cast[char](c))


proc toString*(p: pointer): string =
  var c: byte = 1
  var idx = 0
  while c != 0x00:
    var fp = cast[pointer](cast[int](p) + idx)
    copyMem(addr c, fp, 1)
    if c != 0x00:
      result.add(char(c))
    idx += 1
  return result

#[
  converts an array of type `T` to a string (usefull for windows structs)
]#
proc toString*[I, T](a: array[I, T]):  string =
  for byte in a:
    result.add(cast[char](byte))
    if byte == 0x00:
      return result
#[
  Read a unsigned int32 from a pointer `p`
]#
proc readU32*(p: pointer): uint32 =
  var result: uint32 = 0
  copyMem(addr result, p, 4)
  return result

proc readU64*(p: pointer): uint64 =
  var result: uint64 = 0
  copyMem(addr result, p, 8)
  return result

#[
  Gets the addr of the PEB by using
  the NtQueryInformationProcess()
  API Function
]#
proc getPEB*(): PPEB  =

  let
    currProcHandle: HANDLE = -1
  var
    procBasicInfo: PROCESS_BASIC_INFORMATION
    outSize: ULONG
    status: NTSTATUS

  status = NtQueryInformationProcess(currProcHandle, cast[PROCESSINFOCLASS](0), cast[PVOID](addr procBasicInfo), cast[ULONG](sizeof(procBasicInfo)), addr outSize)

  if status == 0:
    DBG("[+] NtQueryinformationProcess()")
    return procBasicInfo.PebBaseAddress
  else:
    DBG("[-] NtQueryinformationProcess() failed")
    return NULL

# get a PID by process name
proc GetProcessByName*(process_name: string): DWORD =
    var
        pid: DWORD = 0
        entry: PROCESSENTRY32
        hSnapshot: HANDLE

    entry.dwSize = cast[DWORD](sizeof(PROCESSENTRY32))
    hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    defer: CloseHandle(hSnapshot)

    if Process32First(hSnapshot, addr entry):
        while Process32Next(hSnapshot, addr entry):
            if entry.szExeFile.toStringW == process_name:
                pid = entry.th32ProcessID
                break

    return pid

