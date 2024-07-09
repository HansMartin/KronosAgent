#[

  This module is supposed to map the local ntdll.dll into
  memory, resolved the EAT and finds the code segment where the
  raw syscalls are called

  This ptr can then be called (as direct Nt* function)

]#
import winim/lean
import ../winapi
import ../utils

#[
  Load the ntdll and map the sections to memory, returns addr.
]#
proc loadNtdll*(): uint =

  var status: NTSTATUS # return status variable
  var zero_bits: ULONG_PTR
  var lHandle: HANDLE = -1 # -1 = current process

  var remote_buffer: PVOID # holds the address of the remotely allocated buffer

  var as_string = readFile("C:\\Windows\\System32\\ntdll.dll")
  var as_bytes = cast[seq[byte]](as_string)

  #[
    Parsing the PE Header to read:

    1) SizeOfImage (To allocate enough memory)
    2) SizeOfHeaders (For going through the headers)
  ]#


  # parse DOS and NT Header
  var module_buffer = unsafeAddr as_bytes[0]
  var dos_header: PIMAGE_DOS_HEADER = cast[PIMAGE_DOS_HEADER](module_buffer)
  var nt_header: PIMAGE_NT_HEADERS = cast[PIMAGE_NT_HEADERS](cast[uint64](module_buffer) + cast[uint64](dos_header.e_lfanew))

  # parse file_header and optional header
  var file_header = nt_header.FileHeader
  var optional_header = nt_header.OptionalHeader

  # size that is needed for allocation of memory
  var alloc_size = cast[SIZE_T](optional_header.SizeOfImage)

  # Allocate `alloc_size` bytes of memory using NtAllocateVirtualMemory
  status = NtAllocateVirtualMemory(
    lHandle,
    addr remote_buffer,
    zero_bits,
    addr alloc_size,
    MEM_COMMIT.or(MEM_RESERVE),
    PAGE_READWRITE
  )

  if status == 0:
    DBG("[+] NtAllocateVirtualMemory() succesfull -> Buffer @ " & $cast[uint](remote_buffer))
  else:
    DBG("[-] NtAllocateVirtualMemory() failed")
    return 0


  var bytes_written: ULONG
  status = NtWriteVirtualMemory(
    lHandle,
    remote_buffer,
    unsafeAddr as_bytes[0],
    cast[ULONG](optional_header.SizeOfHeaders),
    addr bytes_written)

  if status == 0:
    DBG("[+] WriteProcessMemory")
    DBG("    \\-- bytes written: " & $bytesWritten)
    DBG("")
  else:
    DBG("[-] NtWriteVirtualMemory() failed")
    return 0


  # Number of Sections
  var num_sections = cast[int](file_header.NumberOfSections)
  DBG("[*] Identified " & $num_sections & " sections")

  #[
    Loop all sections and:
     1) Copy the sections at their virtual offsets to local memory
     2) Identify the section that contains the export directory
  ]#

  for i in 0 ..< num_sections:

    # VA of the next section to be parsed
    var section_addr = cast[int](nt_header) + sizeof(DWORD) + sizeof(IMAGE_FILE_HEADER) + cast[int](file_header.SizeOfOptionalHeader) + cast[int](i *  sizeof(IMAGE_SECTION_HEADER))

    # Parse secton to IMAGE_SECTION_HEADER struct
    var section = cast[PIMAGE_SECTION_HEADER](section_addr)


    # read raw and virtual addresses of section
    var virt_section_base = cast[uint64](remote_buffer) + cast[uint64](section.VirtualAddress)
    var raw_section_base = cast[uint64](unsafeAddr as_bytes[0]) + cast[uint64](section.PointerToRawData)


    # write section to memory
    status = NtWriteVirtualMemory(
      lHandle,
      cast[PVOID](virt_section_base),   # source
      cast[PVOID](raw_section_base),    # destination
      cast[ULONG](section.SizeOfRawData),
      addr bytes_written)


    if bytes_written != section.SizeOfRawData:
      DBG("[-] Failed to write section " & section.Name.toString() & " to memory, aborting")
      return 0

    DBG("[*] Section " & section.Name.toString() & " @ " & $section.VirtualAddress & " written to " & $virt_section_base)


  # return the address of the mapped ntdll
  return cast[uint](remote_buffer)


#[

  Parse the PE Header to find the export addr of the function_name

]#
proc getExportAddr(module_base: uint, export_name: string): uint =

  # Parse dos_header, nt_header and optional_header
  var dos_header: PIMAGE_DOS_HEADER = cast[PIMAGE_DOS_HEADER](module_base)
  var nt_header: PIMAGE_NT_HEADERS = cast[PIMAGE_NT_HEADERS](cast[uint64](module_base) + cast[uint64](dos_header.e_lfanew))
  var optional_header = nt_header.OptionalHeader

  # get the Addr of the export table and parse
  var export_va = cast[uint](optional_header.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].VirtualAddress)

  DBG("[+] Export Directory RVA: " & $export_va)

  var export_directory = cast[PIMAGE_EXPORT_DIRECTORY](module_base + export_va)

  # Get RVA of names and corresponding RVAs
  var names_addr = cast[uint](export_directory.AddressOfNames)
  var funcs_addr = cast[uint](export_directory.AddressOfFunctions)
  var ordinal_addr = cast[uint](export_directory.AddressOfNameOrdinals)


  for i in 0 ..< export_directory.NumberOfNames:

    # Get Offsets
    var names_offset    = module_base + (names_addr + cast[uint](i * 4))
    var funcs_offset    = module_base + (funcs_addr + cast[uint]((i+1) * 4))
    #var ordinal_offset  = module_base + (ordinal_addr + cast[uint](i * 2)) # ordinal currently not used

    # Resolve Export Names, Ordinal and ptr to address
    var ptr_function_name = module_base + readU32(cast[pointer](names_offset))
    var funcs_rva         = readU32(cast[pointer](funcs_offset))
    #var ordinal           = read_u16(cast[pointer](ordinal_offset))      # ordinal currently not used

    var function_name = toString(cast[pointer](ptr_function_name))
    #DBG(fmt"Name @ {nnn} with Ordinal {ordinal} and addr {ptr_funcs_addr:#X}"

    if function_name == export_name:
      return module_base + funcs_rva


#[

  proc maps the local ntdll into a memory region
  using Map

]#
proc resolveFunction*(base_addr: uint, function_name: string): uint =

  # Get the export address of a certain function
  let export_addr = getExportAddr(base_addr, function_name)
  var status: NTSTATUS
  var lHandle: HANDLE = -1 # -1 = current process
  var zero_bits: ULONG_PTR
  var bytes_written: ULONG
  var stub_buffer: PVOID
  var stub_buffer_size: SIZE_T = 0x50

  if export_addr == 0:
    DBG("[-] Failed to resolve export")
    return 0

  #DBG(fmt"[+] Found Address of `{function_name}` @ {export_addr:#X}")
  DBG("[+] Found Address of `" & function_name & " @ " & $export_addr)


  # Allocate Memory for the syscall stub
  status = NtAllocateVirtualMemory(
    lHandle,
    addr stub_buffer,
    zero_bits,
    addr stub_buffer_size,
    MEM_COMMIT.or(MEM_RESERVE),
    PAGE_READWRITE
  )

  if status == 0:
    DBG("[+] NtAllocateVirtualMemory() succesfull -> Buffer @ " & $cast[uint](stub_buffer))
  else:
    DBG("[-] NtAllocateVirtualMemory() failed")
    return 0

  status = NtWriteVirtualMemory(
    lHandle,
    stub_buffer,
    cast[PVOID](export_addr),
    cast[ULONG](stub_buffer_size),
    addr bytes_written)

  if status == 0:
    DBG("[+] WriteProcessMemory")
    DBG("    \\-- bytes written: " & $bytesWritten)
  else:
    DBG("[-] NtWriteVirtualMemory() failed")
    return 0

  var old_access_protection: ULONG
  status = NtProtectVirtualMemory(
    lHandle,
    addr stub_buffer,
    addr stub_buffer_size,
    PAGE_EXECUTE_READ,
    addr old_access_protection
    )

  if status == 0:
    DBG("[+] Switched access rights to PAGE_EXECUTE_READ")
  else:
    DBG("[-] NtProtectVirtualMemory() failed")
    return 0

  # return the addr of the stub_buffer
  return cast[uint](stub_buffer)


proc freeNtdll*(base_addr: uint) =

  var status: NTSTATUS
  var remote_buffer: PVOID = cast[PVOID](base_addr)
  let lHandle: HANDLE = -1
  let dos_header: PIMAGE_DOS_HEADER = cast[PIMAGE_DOS_HEADER](base_addr)
  let nt_header: PIMAGE_NT_HEADERS = cast[PIMAGE_NT_HEADERS](cast[uint64](base_addr) + cast[uint64](dos_header.e_lfanew))

  # parse file_header and optional header
  var file_header = nt_header.FileHeader
  var optional_header = nt_header.OptionalHeader

  # size that is needed for allocation of memory
  var alloc_size = cast[SIZE_T](optional_header.SizeOfImage)

  # Free Memory
  status = NtFreeVirtualMemory(lHandle,
    addr remote_buffer,
    addr alloc_size,
    MEM_RELEASE)

  if status == 0:
    DBG("[+] Successfully freed memory of ntdll")
  else:
    DBG("[-] NtFreeVirtualMemory() failed")


