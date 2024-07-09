# This is the source for the CAT command
import ../structs
import ../utils
import std/os
import json

#[
The cat command takes the parameters in the following format:
  {"path": "anwiththestruct"}

]#
proc cmd_cat*(task: Task): seq[TaskResponse] {.cdecl.} =

  let params = parseJson(task.parameters)
  let path = params["path"].getStr()

  var
    output = ""
    status = ""

  if fileExists(path):
    output = readFile(path)
  else:
    output = "[-] Path does not exist"
    status = "error"

  # return the response struct
  return buildReturnData(task.id, output, status)
