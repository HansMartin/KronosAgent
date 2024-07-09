# This is the source for the CAT command
import ../structs
import ../utils
import json
import os

#[
Creates a new directory

  {"path": "newfolder"}

]#
proc cmd_mkdir*(task: Task): seq[TaskResponse] {.cdecl.} =

  let params = parseJson(task.parameters)
  let path = params["path"].getStr()

  # Configure Output
  var
    output = ""
    status = ""

  try:
    createDir(path)
    output = "Folder created successfully"
  except OSError:
    status = "error"
    output = "An error occured creating the directory"


  # return the response
  return buildReturnData(task.id, output, status)

