# This is the source for the CAT command
import ../structs
import ../utils
import json
import winim
import std/options
import winim/winstr


type
  LsSharesObj = object
    hostname: string
    shares: seq[string]

proc enumShare(hostname: string): Option[seq[string]] =

  var
    infos,shareInfo: PSHARE_INFO_0
    entriesRead: DWORD
    totalEntries: DWORD
    resumeHandle: DWORD = 0
    status: NET_API_STATUS
    res: seq[string]

  status = NetShareEnum(hostname, 0, cast[ptr LPBYTE](addr infos), MAX_PREFERRED_LENGTH, addr entriesRead, addr totalEntries, addr resumeHandle)

  if status != NERR_Success:
    return none(seq[string])

  DBG("Host: " & hostname)

  shareInfo = infos

  for i in 0..<entriesRead:
    DBG($$shareInfo[].shi0_netname)
    res.add($$shareInfo[].shi0_netname)
    shareInfo = cast[PSHARE_INFO_0](cast[int](shareInfo) + sizeof(SHARE_INFO_0))

  #Freeing the buffer
  status = NetApiBufferFree(infos)

  if status != NERR_Success:
    return none(seq[string])

  return some(res)

#[
  Shows the shares on the remote host
  {"host": "<hostname>"}

]#
proc cmd_lsshares*(task: Task): seq[TaskResponse] {.cdecl.} =

  let params = parseJson(task.parameters)
  var hostname = params["host"].getStr()

  # Configure Output
  var
    output = ""
    status = ""

  if hostname == "":
    hostname = "localhost"

  let shares = enumShare(hostname)

  if shares.isSome():
    # construct return obj
    let retShare = LsSharesObj(hostname: hostname, shares: shares.get())
    output = $(%*retShare)
  else:
    status = "error"

  # return the response
  return buildReturnData(task.id, output, status)

