# This is the source for the CAT command
import ../structs
import ../utils
import ../identityManager
import winim/lean

#[
  After impersonating a token of another user,
  the active logon token can be restored using the
  rev2self api call
]#
proc cmd_rev2self*(task: Task): seq[TaskResponse] {.cdecl.} =

  # Configure Output
  var
    output = ""
    status = ""

  # Do the Magic
  if RevertToSelf() == FALSE:
    status = "error"

  #  mark the current token as reverted
  revertImpersonated()

  # return the response
  return buildReturnData(task.id, output, status)

