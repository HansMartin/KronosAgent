#[
  This is the place all the Windows
  low-level API functions are implemented (and wrapped)

  - NtOpenProcess

]#

import winim/lean


#[

  NTSTATUS NtOpenProcess(
    PHANDLE            ProcessHandle,
    ACCESS_MASK        DesiredAccess,
    POBJECT_ATTRIBUTES ObjectAttributes,
    PCLIENT_ID         ClientId
  );

]#
proc NtOpenProcess*(ProcessHandle: PHANDLE, DesiredAccess: ACCESS_MASK, ObjectAttributes: POBJECT_ATTRIBUTES, ClientId: PCLIENT_ID) : NTSTATUS {.winapi, stdcall, dynlib: "ntdll", importc, gcsafe.}

#[

  NTSTATUS NtAllocateVirtualMemory(
    HANDLE    ProcessHandle,
    PVOID     *BaseAddress,
    ULONG_PTR ZeroBits,
    PSIZE_T   RegionSize,
    ULONG     AllocationType,
    ULONG     Protect
  );

]#

proc NtAllocateVirtualMemory*(ProcessHandle: HANDLE, BaseAddress: PVOID, ZeroBits: ULONG_PTR, RegionSize: PSIZE_T, AllocationType: ULONG, Protect: ULONG) : NTSTATUS {.winapi, stdcall, dynlib: "ntdll", importc, gcsafe.}


#[

  NTSTATUS NtWriteVirtualMemory(
    IN  HANDLE ProcessHandle,
    OUT PVOID BaseAddress,
    IN  PVOID Buffer,
    IN  ULONG BufferSize,
    OUT PULONG NumberOfBytesWritten OPTIONAL
    );

]#

proc NtWriteVirtualMemory*(ProcessHandle: HANDLE, BaseAddress: PVOID, Buffer: PVOID, BufferSize: ULONG, NumberOfBytesWritten: PULONG) : NTSTATUS {.winapi, stdcall, dynlib: "ntdll", importc, gcsafe.}


proc NtReadVirtualMemory*(ProcessHandle: HANDLE, BaseAddress: PVOID, Buffer: PVOID, BufferSize: ULONG, NumberOfBytesRead: PULONG) : NTSTATUS {.winapi, stdcall, dynlib: "ntdll", importc, gcsafe.}

#[

  typedef NTSTATUS (WINAPI *LPFUN_NtCreateThreadEx)
  (
    OUT PHANDLE hThread,
    IN ACCESS_MASK DesiredAccess,
    IN LPVOID ObjectAttributes,
    IN HANDLE ProcessHandle,
    IN LPTHREAD_START_ROUTINE lpStartAddress,
    IN LPVOID lpParameter,
    IN BOOL CreateSuspended,
    IN ULONG StackZeroBits,
    IN SIZE_T SizeOfStackCommit,
    IN SIZE_T SizeOfStackReserve,
    OUT LPVOID lpBytesBuffer
  );

]#

proc NtCreateThreadEx*(hThread: PHANDLE, DesiredAccess: ACCESS_MASK, ObjectAttributes: LPVOID, ProcessHandle: HANDLE, lpStartAddress: LPTHREAD_START_ROUTINE, lpParameter: LPVOID, CreateSuspended: BOOL, StackZeroBits: ULONG, SizeOfStackCommit: SIZE_T, SizeOfStackReserve: SIZE_T, lpBytesBuffer: LPVOID) : NTSTATUS {.winapi, stdcall, dynlib: "ntdll", importc, gcsafe.}


#[

  NtProtectVirtualMemory(
    IN HANDLE               ProcessHandle,
    IN OUT PVOID            *BaseAddress,
    IN OUT PULONG           NumberOfBytesToProtect,
    IN ULONG                NewAccessProtection,
    OUT PULONG              OldAccessProtection );

]#


proc NtProtectVirtualMemory*(ProcessHandle: HANDLE, BaseAddress: ptr PVOID, NumberOfBytesToProtect: PSIZE_T, NewAccessProtection: ULONG, OldAccessProtection: PULONG) : NTSTATUS {.winapi, stdcall, dynlib: "ntdll", importc, gcsafe.}


#[

  NTSTATUS NtFreeVirtualMemory(
    HANDLE  ProcessHandle,
    PVOID   *BaseAddress,
    PSIZE_T RegionSize,
    ULONG   FreeType
  );

]#

proc NtFreeVirtualMemory*(ProcessHandle: HANDLE, BaseAddress: PVOID, RegionSize: PSIZE_T, FreeType: ULONG) : NTSTATUS {.winapi, stdcall, dynlib: "ntdll", importc, gcsafe.}



proc WaitForSingleObject*(hHandle: HANDLE, dwMilliseconds: DWORD): DWORD {.winapi, stdcall, dynlib: "kernel32", importc, gcsafe.}


proc NtResumeThread*(ThreadHandle: HANDLE, PreviousSuspendedCount: PULONG) : NTSTATUS {.winapi, stdcall, dynlib: "ntdll", importc, gcsafe.}

