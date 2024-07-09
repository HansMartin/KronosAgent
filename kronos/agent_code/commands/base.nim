# This is the source for the CAT command
import ../structs
import ../utils
import json

#[
Short Command Description
  {"path": "anwiththestruct"}

]#
proc cmd_name*(task: Task): seq[TaskResponse] {.cdecl.} =

  let params = parseJson(task.parameters)
  let path = params["TBD"].getStr()

  # Configure Output
  var
    output = ""
    status = ""

  # Do the Magic


  # return the response
  return buildReturnData(task.id, output, status)

