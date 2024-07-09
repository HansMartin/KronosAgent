import json
import std/options
import winim/lean
import ../utils
import ../structs
import ../b64
import strformat

when defined(ENCRYPT_TRAFFIC):
  import ../config
  import ../crypto


var
  activePivots*: LinkedPivots


#[
  If the UUID changed (e.g. after linking/checkin)
]#
proc updateDstUUID*(oldUUID: string, newUUID: string) =

  var
    cnt = 0
    cIndex = -1

  for edge in activePivots.edges:
    if edge.destination == oldUUID:
      cIndex = cnt
    cnt += 1

  activePivots.edges[cnt].destination = newUUID



#[
  Helper function for reading data from
  a named pipe. Format: [len][data]
]#
proc readPipe*(hPipe: HANDLE): string =


  var
    temp: DWORD
    size: uint32
    total: uint32
    buf: seq[byte]
    status: BOOL

  # the first 4 byte is the size of the
  # data that gets transfered
  status = ReadFile(hPipe, cast[LPVOID](size.addr), 4, temp.addr, cast[LPOVERLAPPED](0))

  if status == FALSE:
    if GetLastError() == ERROR_NO_DATA:
      return ""

  #  if status == TRUE
  #  continue and read from the pipe


  # initialize buffer as empty byte seq
  buf = newSeq[byte](size)

  DBG("[*] Read #2 -> Trying to read " & $size & " bytes from pipe")
  # read the message from the pipe
  while size > total:
    ReadFile(hPipe, cast[LPVOID](addr buf[total]), cast[DWORD](size - total), temp.addr, cast[LPOVERLAPPED](0))
    total += cast[uint32](temp)

  return cast[string](buf)


#[
  As readPipe() and parsePipePckt() must be splitted because
  it gets used as client and as server
]#
proc parsePipePkt*(body: string): Option[JsonNode] =


  # if nothing was read, return none
  if body == "":
    return none(JsonNode)

  # get the response body, decode the base64 and parse the uuid and json struct
  let respBody = b64.decode(Base64Pad, body)
  var respJson: string

  when defined(ENCRYPT_TRAFFIC):
    let encRespJson = respBody[36..len(respBody)-1]
    respJson = decrypt(encRespJson, connection.encryptionKey)
  else:
    respJson = cast[string](respBody)[36..len(respBody)-1]

  let asJson = parseJson(respJson)

  return some(asJson)



#[
  Write a sequence of bytes to the named pipe
]#
proc writePipe*(hPipe: HANDLE, data: string) =

  var
    wrote: DWORD
    status: BOOL
    size = len(data)


  # write the size first
  DBG(fmt"[*] Going to write {size} bytes of data into the pipe")
  status = WriteFile(hPipe, cast[LPCVOID](size.addr), 4, wrote.addr, cast[LPOVERLAPPED](0))
  DBG(fmt"[+] First WriteFile(Status={status}, error={GetLastError()})")
  #FlushFileBuffers(hPipe)
  #DBG(fmt"[+] First FLushFileBuffers()")

  # write the data
  status = WriteFile(hPipe, cast[LPCVOID](data.cstring), DWORD(size), wrote.addr, cast[LPOVERLAPPED](0))
  DBG(fmt"[+] Second WriteFile(Status={status}, error={GetLastError()})")
  #FlushFileBuffers(hPipe)
  #DBG(fmt"[+] Second FLushFileBuffers()")

  if wrote != size:
    DBG("[-] Failed to write all bytes to Pipe [" & $wrote & "/" & $size & "]")

