# This is the source for the CAT command
import ../structs
import ../utils
import json
import os

#[
Change Directory
  {"path": "anwiththestruct"}

]#
proc cmd_cd*(task: Task): seq[TaskResponse] {.cdecl.} =

  let
    params = parseJson(task.parameters)
    path = params["path"].getStr()

  var
    output = ""
    status = ""

  DBG("[*] cd " & path)

  if not path.dirExists():
    output = "Failed to navigate to " & path & ". Path does not exist"
    return buildReturnData(task.id, output, "error")

  try:
    setCurrentDir(path)
  except OSError:
    status = "error"
    output = "[OSError] Failed to navigate to " & path & ". Path does not exist"

  # return the response struct
  return buildReturnData(task.id, output, status)
