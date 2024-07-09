import winim/lean

#[
  Delegates for Windows Syscalls
]#

type NtOpenProcess* = (proc(ProcessHandle: PHANDLE, DesiredAccess: ACCESS_MASK, ObjectAttributes: POBJECT_ATTRIBUTES, ClientId: PCLIENT_ID):NTSTATUS{.stdcall, gcsafe.})
type NtAllocateVirtualMemory* = (proc(ProcessHandle: HANDLE, BaseAddress: PVOID, ZeroBits: ULONG_PTR, RegionSize: PSIZE_T, AllocationType: ULONG, Protect: ULONG) : NTSTATUS {.stdcall, gcsafe.})
type NtWriteVirtualMemory* = (proc(ProcessHandle: HANDLE, BaseAddress: PVOID, Buffer: PVOID, BufferSize: ULONG, NumberOfBytesWritten: PULONG) : NTSTATUS {.stdcall, gcsafe.})
type NtReadVirtualMemory* = (proc(ProcessHandle: HANDLE, BaseAddress: PVOID, Buffer: PVOID, BufferSize: ULONG, NumberOfBytesRead: PULONG) : NTSTATUS {.stdcall, gcsafe.})
type NtCreateThreadEx* = (proc(hThread: PHANDLE, DesiredAccess: ACCESS_MASK, ObjectAttributes: LPVOID, ProcessHandle: HANDLE, lpStartAddress: LPTHREAD_START_ROUTINE, lpParameter: LPVOID, CreateSuspended: BOOL, StacKZeroBits: ULONG, SizeOfStackCommit: SIZE_T, SizeOfStackReserve: SIZE_T, lpBytesBuffer: LPVOID) : NTSTATUS {.stdcall, gcsafe.})
type NtProtectVirtualMemory* = (proc(ProcessHandle: HANDLE, BaseAddress: ptr PVOID, NumberOfBytesToProtect: PSIZE_T, NewAccessProtection: ULONG, OldAccessProtection: PULONG) : NTSTATUS {.stdcall, gcsafe.})
type NtFreeVirtualMemory* = (proc(ProcessHandle: HANDLE, BaseAddress: PVOID, RegionSize: PSIZE_T, FreeType: ULONG) : NTSTATUS {.stdcall, gcsafe.})
type WaitForSingleObject* = (proc(hHandle: HANDLE, dwMilliseconds: DWORD): DWORD {.stdcall, gcsafe.})
type NtResumeThread* = (proc(ThreadHandle: HANDLE, PreviousSuspendedCount: PULONG) : NTSTATUS  {.stdcall, gcsafe.})
