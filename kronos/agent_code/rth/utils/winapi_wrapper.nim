#[
  This files contains the wrapper functions for all the Windows
  API functions. In the future, the differentiation of how the functions
  is called can be decided in here. Aka call them directly, dynamic Syscalls, ...
]#

import ../rth
import winapi as api
import winim/lean
import dynamic_syscalls/dyn_syscalls
import dynamic_syscalls/delegates
import utils

# Global Variables for the Type and the
# Addr. of the loaded Ntdll
var SelectedSyscallType: SyscallType = SyscallType.Default
var LoadedNtdll: uint = 0

proc setSyscallType*(s: SyscallType) =
  SelectedSyscallType = s


#[
  The initial function that loads the ntdll
  so that it can get reused from all functions.
  If the ntdll cannot be loaded, it will set the
  global Syscall Type to `dafault` so that every
  function still works
]#
proc load() =
  # Alrady loaded, return
  if LoadedNtdll != 0:
    return

  LoadedNtdll = loadNtdll()

  if LoadedNtdll == 0:
    DBG("[-] Failed to load NTDLL")
    SelectedSyscallType = SyscallType.Default
  else:
    DBG("[+] NTDLL Loaded")


#[
  This template is used to differentiate which function is used
  from the SelectedSyscallType func
]#
template getCorrectFunction(wrapperName: untyped, functionName: untyped, exportName: string) =

  # Get the variable for the correct function, using the delegate
  # specifications
  var wrapperName: delegates.functionName

  # if the mode is set to `dynamic` but NTDLL is not yet loaded,
  # map NTDLL into memory
  if SelectedSyscallType == SyscallType.Dynamic and LoadedNtdll == 0:
    load()

  if SelectedSyscallType == SyscallType.Default:
    wrapperName = api.functionName
  elif SelectedSyscallType == SyscallType.Dynamic:
    let fAddr: uint = resolveFunction(LoadedNtdll, exportName)
    # if it fails to find the export in NTDLL,
    # use the regular API Call
    if fAddr == 0:
      wrapperName = api.functionName
    else:
      wrapperName = cast[delegates.functionName](fAddr)
  else:
    wrapperName = api.functionName





proc wWriteProcessMemory*(hProcess: HANDLE, lpBaseAddress: LPVOID, lpBuffer: LPCVOID, nSize: SIZE_T, lpNumberOfBytesWritten: ptr SIZE_T): WINBOOL =
  return


# Currently not required, keeping empty for now
proc VirtualProtect*(lpAddress: LPVOID, dwSize: SIZE_T, flNewProtect: DWORD, lpflOldProtect: PDWORD): WINBOOL  =
  return



proc wNtOpenProcess*(ProcessHandle: PHANDLE, DesiredAccess: ACCESS_MASK, ObjectAttributes: POBJECT_ATTRIBUTES, ClientId: PCLIENT_ID) : NTSTATUS =
  # Put into the f<FuncName> variable and call that
  getCorrectFunction(fNtOpenProcess, NtOpenProcess, "NtOpenProcess")
  return fNtOpenProcess(ProcessHandle, DesiredAccess, ObjectAttributes, ClientId)


proc wNtAllocateVirtualMemory*(ProcessHandle: HANDLE, BaseAddress: PVOID, ZeroBits: ULONG_PTR, RegionSize: PSIZE_T, AllocationType: ULONG, Protect: ULONG) : NTSTATUS  =
  getCorrectFunction(fNtAllocateVirtualMemory, NtAllocateVirtualMemory, "NtAllocateVirtualMemory")
  return fNtAllocateVirtualMemory(ProcessHandle, BaseAddress, ZeroBits, RegionSize, AllocationType, Protect)

proc wNtWriteVirtualMemory*(ProcessHandle: HANDLE, BaseAddress: PVOID, Buffer: PVOID, BufferSize: ULONG, NumberOfBytesWritten: PULONG) : NTSTATUS =
  getCorrectFunction(fNtWriteVirtualMemory, NtWriteVirtualMemory, "NtWriteVirtualMemory")
  return fNtWriteVirtualMemory(ProcessHandle, BaseAddress, Buffer, BufferSize, NumberOfBytesWritten)

proc wNtReadVirtualMemory*(ProcessHandle: HANDLE, BaseAddress: PVOID, Buffer: PVOID, BufferSize: ULONG, NumberOfBytesRead: PULONG) : NTSTATUS =
  getCorrectFunction(fNtReadVirtualMemory, NtReadVirtualMemory, "NtReadVirtualMemory")
  return fNtReadVirtualMemory(ProcessHandle, BaseAddress, Buffer, BufferSize, NumberOfBytesRead)


proc wNtCreateThreadEx*(hThread: PHANDLE, DesiredAccess: ACCESS_MASK, ObjectAttributes: LPVOID, ProcessHandle: HANDLE, lpStartAddress: LPTHREAD_START_ROUTINE, lpParameter: LPVOID, CreateSuspended: BOOL, StackZeroBits: ULONG, SizeOfStackCommit: SIZE_T, SizeOfStackReserve: SIZE_T, lpBytesBuffer: LPVOID) : NTSTATUS =

  getCorrectFunction(fNtCreateThreadEx, NtCreateThreadEx, "NtCreateThreadEx")
  return fNtCreateThreadEx(hThread, DesiredAccess, ObjectAttributes, ProcessHandle, lpStartAddress, lpParameter, CreateSuspended, StackZeroBits, SizeOfStackCommit, SizeOfStackReserve, lpBytesBuffer)

proc wNtProtectVirtualMemory*(ProcessHandle: HANDLE, BaseAddress: ptr PVOID, NumberOfBytesToProtect: PSIZE_T, NewAccessProtection: ULONG, OldAccessProtection: PULONG) : NTSTATUS =

  getCorrectFunction(fNtProtectVirtualMemory, NtProtectVirtualMemory, "NtProtectVirtualMemory")
  return fNtProtectVirtualMemory(ProcessHandle, BaseAddress, NumberOfBytesToProtect, NewAccessProtection, OldAccessProtection)


proc wNtFreeVirtualMemory*(ProcessHandle: HANDLE, BaseAddress: PVOID, RegionSize: PSIZE_T, FreeType: ULONG) : NTSTATUS =

  getCorrectFunction(fNtFreeVirtualMemory, NtFreeVirtualMemory, "NtFreeVirtualMemory")
  return fNtFreeVirtualMemory(ProcessHandle, BaseAddress, RegionSize, FreeType)

proc wWaitForSingleObject*(hHandle: HANDLE, dwMilliseconds: DWORD): NTSTATUS =
  # no dynamic function available, only for NTDLL functions
  return api.WaitForSingleObject(hHandle, dwMilliseconds)

proc wNtResumeThread*(ThreadHandle: HANDLE, PreviousSuspendedCount: PULONG): NTSTATUS =
  # no dynamic function available, only for NTDLL functions
  getCorrectFunction(fNtResumeThread, NtResumeThread, "NtResumeThread")
  return fNtResumeThread(ThreadHandle, PreviousSuspendedCount)



#[
  We have a hand full of regular Windows API calls that get -under the hood- replaced with the lowlevel syscall (and default values)
  to be able to still have dynamic syscalls for regular calls to e.g. `OpenProcess`

  -> This is implemented for:
    - OpenProcess
    - AllocateVirtualMemory
    - CreateThread
    - WriteVirtualMemory
    - ProtectVirtualMemory
    - ...
]#
proc wOpenProcess*(dwDesiredAccess: DWORD, bInheritHandle: WINBOOL, dwProcessId: DWORD): HANDLE =

  var
    outHndl: HANDLE
    clientId: CLIENT_ID             # required for NtOpenProcess
    attributes: OBJECT_ATTRIBUTES   # required for NtOpenProcess

  clientId.UniqueProcess = dwProcessId
  if wNtOpenProcess(addr outHndl, dwDesiredAccess, addr attributes, addr clientId) == ERROR_SUCCESS:
    return outHndl
  else:
    return 0
