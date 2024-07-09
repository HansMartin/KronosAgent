# This is the source for the CAT command
import ../structs
import ../utils
import json
import os

#[
Short Command Description
  {"path": "anwiththestruct"}

]#
proc cmd_cp*(task: Task): seq[TaskResponse] {.cdecl.} =

  let params = parseJson(task.parameters)
  let source = params["source"].getStr()
  let destination = params["destination"].getStr()

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
      #"Source File is a directory"
      output = $cast[int](StatusCodes.SourceFileIsADir)
    else:
      # Its a file and destination must be checked

      # 3) Check if the destination exists, if not: copyFile
      if not fileExists(destination):
        try:
          DBG("Copy " & source & " To: " & destination)

          copyFile(source, destination)
          # 6) Done
          #output = "Source file copied successfully to destination"
          output = $cast[int](StatusCodes.CopySuccess)
        except OSError:
          let msg = getCurrentExceptionMsg()
          DBG(msg)
          status = "error"
          #output = "An error occured copying the file. Error: " & $osLastError()
          output = $cast[int](StatusCodes.FileCopyError)
      else:
        let dstInfo = getFileInfo(destination)
        # 4) if the destination is a directory, copy to that dir
        if dstInfo.kind == pcDir:
          try:
            copyFileToDir(source, destination)
            #output = "Source file copied successfully to destination"
            output = $cast[int](StatusCodes.SourceFileCopiedSuccessfully)
          except OSError:
            let msg = getCurrentExceptionMsg()
            DBG(msg)
            status = "error"
            # "An error occured copying the file. Error: " & $osLastError()
            output = $cast[int](StatusCodes.FileCopyError)
        else:
          status = "error"
          #"Destination file already exists"
          output = $cast[int](StatusCodes.DestinationExists)

  else: # File exists
    status = "error"
    #"Source File does not exist"
    output = $cast[int](StatusCodes.SourceFileNonexistent)


  # return the response
  return buildReturnData(task.id, output, status)

