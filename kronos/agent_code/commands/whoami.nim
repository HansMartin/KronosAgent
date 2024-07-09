# This is the source for the CAT command
import ../structs
import ../utils
import ../identityManager
import json

#[
  Shows the current user and state of impersonation
]#
proc cmd_whoami*(task: Task): seq[TaskResponse] {.cdecl.} =

  # return the login info and parse on server-side
  let loginInfo = getLoginInformation()
  var output = $(%* loginInfo)

  # return the response
  return buildReturnData(task.id, output)

