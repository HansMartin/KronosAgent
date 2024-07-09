#[
  This file implements some basic function
  for mapping PE files into memory, fixing (and hooking) IAT
]#
import hooks
import utils
import winim/lean
import strformat
import winapi_wrapper
import ptr_math


var enableCmdLineHooking = false

#[
  This is the setter function for the global
  CommandLine Arguments. It should hopefully work for
  _every_ program that somehow gets any arguments
]#
proc setCommandline*(commandline: string) =
  enableCmdLineHooking = true
  hooks.setCommandline(commandline)

# Additional to return the OriginalFirstThunk from a PIMAGE_IMPORT_DESCRIPTOR
proc OriginalFirstThunk*(self: PIMAGE_IMPORT_DESCRIPTOR): DWORD {.inline.} = self.union1.OriginalFirstThunk


type
  BASE_RELOCATION_ENTRY* {.bycopy.} = object
    Offset* {.bitsize: 12.}: WORD
    Type* {.bitsize: 4.}: WORD


const
  RELOC_32BIT_FIELD* = 3

#[
  Initial loading step of the PE
  - Parses the DOS and NT Header and returns the
    NT Header
]#
proc parsePE*(baseAddr: pointer): PIMAGE_NT_HEADERS =


  # Parse the DOS header from the executable
  var dosHeader: PIMAGE_DOS_HEADER = cast[PIMAGE_DOS_HEADER](baseAddr)

  # check if the DOS Signature fits (is it an PE File)
  if dosHeader.e_magic != IMAGE_DOS_SIGNATURE:
    DBG("[-] Wrong DOS Header Signature")
    return nil

  DBG("[+] DOS Signature correct")

  var ntHeader: PIMAGE_NT_HEADERS = cast[PIMAGE_NT_HEADERS](baseAddr + dosHeader.e_lfanew)

  # check if the NT Signature fits (is it an PE File)
  if ntHeader.Signature != IMAGE_NT_SIGNATURE:
    DBG("[-] Wrong NT Header Signature")
    return nil
  DBG("[+] NT Signature correct")
  return ntHeader



#[
  Return the specified PE directory
]#
proc getPEDirectory*(peHeader: PVOID; directoryID: csize_t): PIMAGE_DATA_DIRECTORY =

  # Not a valid DIRECTORY_ENTRY ID
  if directoryID >= IMAGE_NUMBEROF_DIRECTORY_ENTRIES:
    return nil

  var ntHeader = parsePE(peHeader)
  var directory = addr ntHeader.OptionalHeader.DataDirectory[directoryID]

  # Return the directory if correctly parsed
  if directory.VirtualAddress == 0:
    return nil
  return directory


# Apply the relocation of
# the binary to the mapped addr
proc applyReloc*(newBase: ULONGLONG; oldBase: ULONGLONG; modulePtr: PVOID;
                moduleSize: SIZE_T): bool =
  echo "    [!] Applying Reloc "
  var relocDir: ptr IMAGE_DATA_DIRECTORY = getPEDirectory(modulePtr, IMAGE_DIRECTORY_ENTRY_BASERELOC)

  if relocDir == nil:
    return false
  var maxSize: csize_t = csize_t(relocDir.Size)
  var relocAddr: csize_t = csize_t(relocDir.VirtualAddress)
  var reloc: ptr IMAGE_BASE_RELOCATION = nil
  var parsedSize: csize_t = 0
  while parsedSize < maxSize:
    reloc = cast[ptr IMAGE_BASE_RELOCATION]((
        SIZE_T(relocAddr) + SIZE_T(parsedSize) + cast[SIZE_T](modulePtr)))
    if reloc.VirtualAddress == 0 or reloc.SizeOfBlock == 0:
      break
    var entriesNum: csize_t = csize_t((reloc.SizeOfBlock - sizeof((IMAGE_BASE_RELOCATION)))) div
        csize_t(sizeof((BASE_RELOCATION_ENTRY)))
    var page: csize_t = csize_t(reloc.VirtualAddress)
    var entry: ptr BASE_RELOCATION_ENTRY = cast[ptr BASE_RELOCATION_ENTRY]((
        cast[SIZE_T](reloc) + sizeof((IMAGE_BASE_RELOCATION))))
    var i: csize_t = 0
    while i < entriesNum:
      var offset: csize_t = entry.Offset
      var entryType: csize_t = entry.Type
      var reloc_field: csize_t = page + offset
      if entry == nil or entryType == 0:
        break
      if entryType != RELOC_32BIT_FIELD:
        echo "    [!] Not supported relocations format at ", cast[cint](i), " ", cast[cint](entryType)
        return false
      if SIZE_T(reloc_field) >= moduleSize:
        echo "    [-] Out of Bound Field: ", reloc_field
        return false
      var relocateAddr: ptr csize_t = cast[ptr csize_t]((
          cast[SIZE_T](modulePtr) + SIZE_T(reloc_field)))
      echo "    [V] Apply Reloc Field at ", repr(relocateAddr)
      (relocateAddr[]) = ((relocateAddr[]) - csize_t(oldBase) + csize_t(newBase))
      entry = cast[ptr BASE_RELOCATION_ENTRY]((
          cast[SIZE_T](entry) + sizeof((BASE_RELOCATION_ENTRY))))
      inc(i)
    inc(parsedSize, reloc.SizeOfBlock)
  return parsedSize != 0



#[
  This mapps a PE into memory by:

  - Parsing the Headers (DOS, NT)
  - Allocating Memory for the Headers
  - Writing the Headers to the allocated region
  - Going through the PE sections
  - Writing the sections to the desired address

]#
proc mapPEToMemory*(bytes: seq[byte]): uint =

  var
    status: NTSTATUS # return status variable
    zeroBits: ULONG_PTR
    lHandle: HANDLE = -1 # -1 = current process
    allocImageBuffer: PVOID # holds the address of the remotely allocated buffer
    moduleBuffer = unsafeAddr bytes[0]

  # Get the NT Header
  var nt_header = parsePE(moduleBuffer)

  # This is the preferred address to load the PE file to
  # If it cannot be loaded at this addr, it must be relocated
  # in memory
  allocImageBuffer = cast[PVOID](nt_header.OptionalHeader.ImageBase)
  DBG(fmt"Preffered Image Base: {cast[uint32](nt_header.OptionalHeader.ImageBase):#X}")

  # Check the relocation directory
  var relocationDirectory = getPEDirectory(moduleBuffer, IMAGE_DIRECTORY_ENTRY_BASERELOC)

  if relocationDirectory == nil:
    DBG("[-] No relocation information available")




  # parse file_header and optional header
  var fileHeader = nt_header.FileHeader
  var optionalHeader = nt_header.OptionalHeader

  # size that is needed for allocation of memory
  var imageSizeForAllocation = cast[SIZE_T](optional_header.SizeOfImage)

  # Allocate `alloc_size` bytes of memory using wNtAllocateVirtualMemory
  # This buffer is used for the `mapping` of the PE file in memory
  status = wNtAllocateVirtualMemory(
    lHandle,
    addr allocImageBuffer,
    zeroBits,
    addr imageSizeForAllocation,
    MEM_COMMIT.or(MEM_RESERVE),
    PAGE_EXECUTE_READWRITE
  )


  # Check whether it is possible to allocate memory at the preferred base address.
  # If not (and there is relocation data available) -> Try to allocate some memory at some
  # arbitrary OS choosen address and relocate
  if status == 0:
    DBG(fmt"[+] wNtAllocateVirtualMemory() succesfull -> Buffer @ {cast[uint](allocImageBuffer):#X}")
  elif status != 0 and relocationDirectory != nil:
    DBG("[-] wNtAllocateVirtualMemory() failed -> Trying to allocate at another address + relocating the binary")
    allocImageBuffer = NULL

    # Allocate `alloc_size` bytes of memory using wNtAllocateVirtualMemory
    # This buffer is used for the `mapping` of the PE file in memory
    status = wNtAllocateVirtualMemory(
      lHandle,
      addr allocImageBuffer,
      zeroBits,
      addr imageSizeForAllocation,
      MEM_COMMIT.or(MEM_RESERVE),
      PAGE_EXECUTE_READWRITE
    )

    if status == 0:
      DBG(fmt"[+] wNtAllocateVirtualMemory() at arbitrary address: Buffer @ {cast[uint](allocImageBuffer):#X}")

      # Applying the relocation
      DBG("[*] Applying relocation")
      discard applyReloc(cast[ULONGLONG](allocImageBuffer), cast[ULONGLONG](nt_header.OptionalHeader.ImageBase), cast[PVOID](allocImageBuffer), nt_header.OptionalHeader.SizeOfImage)

    else:
      DBG("[-] Failed to allocate Memory twice, giving up...")
      return 0


  var backupImageBase = allocImageBuffer

  #[
    Copy the image headers into the newly created Memory Buffer
  ]#

  var bytes_written: ULONG
  status = wNtWriteVirtualMemory(
    lHandle,
    allocImageBuffer,
    unsafeAddr bytes[0],
    cast[ULONG](optional_header.SizeOfHeaders),
    addr bytesWritten)

  # Restore after every NtWriteVirtualMemory (as its doing weird stuff)
  allocImageBuffer = backupImageBase

  if status == 0:
    DBG("[+] WriteProcessMemory: All PE Headers are written to the new memory buffer")
    DBG(fmt"    \\-- bytes written: {bytesWritten}")
    DBG("")
  else:
    DBG(fmt"[-] NtWriteVirtualMemory() failed [{GetLastError()}]")
    return 0


  # Get the number of Sections in the binary
  var numOfSections = cast[int](fileHeader.NumberOfSections)
  DBG(fmt"[*] Identified {numOfSections} sections")

  #[
    Loop all sections and:
     1) Copy the sections at their virtual offsets to local memory
     2) Identify the section that contains the export directory
  ]#

  for i in 0 ..< numOfSections:

    # VA of the next section to be parsed
    var sectionAddr = cast[int](ntHeader) + sizeof(DWORD) + sizeof(IMAGE_FILE_HEADER) + cast[int](fileHeader.SizeOfOptionalHeader) + cast[int](i *  sizeof(IMAGE_SECTION_HEADER))

    # Parse secton to IMAGE_SECTION_HEADER struct
    var section = cast[PIMAGE_SECTION_HEADER](sectionAddr)


    # read raw and virtual addresses of section
    var virtSectionBase = cast[uint64](allocImageBuffer) + cast[uint64](section.VirtualAddress)
    var rawSectionBase = cast[uint64](unsafeAddr bytes[0]) + cast[uint64](section.PointerToRawData)


    # write section to memory
    status = wNtWriteVirtualMemory(
      lHandle,
      cast[PVOID](virtSectionBase),   # source
      cast[PVOID](rawSectionBase),    # destination
      cast[ULONG](section.SizeOfRawData),
      addr bytesWritten)

    # Restore after every NtWriteVirtualMemory (as its doing weird stuff)
    allocImageBuffer = backupImageBase


    if bytesWritten != section.SizeOfRawData:
      DBG(fmt"[-] Failed to write section {section.Name.toString()} to memory [Error: {GetLastError()}], aborting")
      return 0

    DBG(fmt"[*] Section {section.Name.toString()} @ {section.VirtualAddress:#X} written to {virt_section_base:#X}")


  # return the address of the mapped ntdll
  return cast[uint](allocImageBuffer)



#[
  This function tries to fix the Import Address Table
  in memory. It does this by:

  - Looping through the imports
  - Loading the Library (LoadLibrary)
  - Loading the imported modules (GetProcAddress)
  - Mapping the mapped address into the IAT

]#
proc fixIAT*(moduleBase: PVOID): bool =

  DBG("[*] Fixing Import Address Table")

  # Getting the IMPORT DIRECTORY from the PE Header
  var importDir = getPEDirectory(moduleBase, IMAGE_DIRECTORY_ENTRY_IMPORT)

  if importDir == nil:
    DBG("[-] Failed to get IMPORTS directory")
    return false
  else:
    DBG(fmt"[+] Imports @ {cast[uint64](importDir):#X}")


  var impSize: csize_t = cast[csize_t](importDir.Size)
  var impAddr: csize_t = cast[csize_t](importDir.VirtualAddress)
  var impDescriptor: PIMAGE_IMPORT_DESCRIPTOR

  var parsedSize: csize_t = 0

  DBG("Looping through imports")

  # Loop through all the imported libraries
  while parsedSize < impSize:
    impDescriptor = cast[PIMAGE_IMPORT_DESCRIPTOR]((cast[uint64](moduleBase) + impAddr + parsedSize))

    # Break if we have no Think and no Original Think
    if (impDescriptor.OriginalFirstThunk) == 0 and (impDescriptor.FirstThunk == 0):
      break

    # Extract the Name of the DLL
    var libraryName = cast[LPSTR](cast[ULONGLONG](moduleBase) + impDescriptor.Name)
    DBG(fmt" [*] DLL: {libraryName.toString}")

    var calledVia: csize_t = cast[csize_t](impDescriptor.FirstThunk)
    var thunkAddr: csize_t = cast[csize_t](impDescriptor.OriginalFirstThunk)

    if thunkAddr == 0:
      thunkAddr = impDescriptor.FirstThunk.csize_t

    var offsetField: csize_t = 0
    var offsetThunk: csize_t = 0

    while true:

      var fieldThunk: PIMAGE_THUNK_DATA = cast[PIMAGE_THUNK_DATA](
        cast[csize_t](moduleBase) + offsetField + calledVia
        )

      var originalThunk: PIMAGE_THUNK_DATA = cast[PIMAGE_THUNK_DATA](
        cast[csize_t](moduleBase) + offsetField + thunkAddr
        )

      var isOrdinal: bool = false

      # Check if the x64 or x86 version is using the Ordinal repr.
      if (originalThunk.u1.Ordinal.and(IMAGE_ORDINAL_FLAG32) != 0) or
      (originalThunk.u1.Ordinal.and(IMAGE_ORDINAL_FLAG64) != 0):
        isOrdinal = true

      # If the ordinal is used for imports, resolve the Ordinal with LoadLibrary
      # and GetProcAddress
      if isOrdinal:
        var ordinal = originalThunk.u1.Ordinal.and(0xFFFF)
        # Resolving the func addr by Ordinal
        var funcAddr = GetProcAddress(LoadLibraryA(libraryName.toString), cast[LPSTR](ordinal))

        # Assign the resolved Addr to the thunk
        fieldThunk.u1.Function = ULONGLONG(cast[SIZE_T](funcAddr))

        DBG(fmt"    [F] API (ord): {originalThunk.u1.Ordinal.and(0xFFFF)} @ [{cast[uint64](funcAddr):#X}]")


      if fieldThunk.u1.Function == 0:
        break

      # Resolve the impored Function by Name
      if fieldThunk.u1.Function == originalThunk.u1.Function:

        DBG("[*] Hooking all functions")

        var nameData: PIMAGE_IMPORT_BY_NAME = cast[PIMAGE_IMPORT_BY_NAME](originalThunk.u1.AddressOfData)
        var byName: PIMAGE_IMPORT_BY_NAME = cast[PIMAGE_IMPORT_BY_NAME](cast[ULONGLONG](moduleBase) + cast[DWORD](nameData))
        var functionName = cast[LPCSTR](addr byName.Name)

        # Resolve the function
        var funcAddr = GetProcAddress(LoadLibraryA(libraryName.toString), $functionName)

        DBG(fmt"    [F] API: {functionName} @ [{cast[uint64](funcAddr):#X}]")

        if enableCmdLineHooking: # only if the hooking is enabled
          # Hooking all the different 'Argument' parsing functions that are available under Windows
          if $functionName == "GetCommandLineA":
            fieldThunk.u1.Function = ULONGLONG(cast[SIZE_T](hook_GetCommandLineA))
          elif $functionName == "GetCommandLineW":
            fieldThunk.u1.Function = ULONGLONG(cast[SIZE_T](hook_GetCommandLineW))
          elif $functionName == "__p___argc":
            fieldThunk.u1.Function = ULONGLONG(cast[SIZE_T](hook_p_argc))
          elif $functionName == "__p___argv":
            fieldThunk.u1.Function = ULONGLONG(cast[SIZE_T](hook_p_argv))
          elif $functionName == "__wgetmainargs":
            fieldThunk.u1.Function = ULONGLONG(cast[SIZE_T](hook_wgetmainargs))
          elif $functionName == "__getmainargs":
            fieldThunk.u1.Function = ULONGLONG(cast[SIZE_T](hook_getmainargs))
          else:
            # The original function addr
            fieldThunk.u1.Function = ULONGLONG(cast[SIZE_T](funcAddr))
        else:
          fieldThunk.u1.Function = ULONGLONG(cast[SIZE_T](funcAddr))

      # Increment Thunk and Offset
      offsetField += cast[csize_t](sizeof(IMAGE_THUNK_DATA))
      offsetThunk += cast[csize_t](sizeof(IMAGE_THUNK_DATA))

    # Increment sructu
    parsedSize += cast[csize_t](sizeof(IMAGE_IMPORT_DESCRIPTOR))


  return false
