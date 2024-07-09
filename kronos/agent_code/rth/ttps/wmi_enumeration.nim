import winim/com

proc main() =
  echo "[*] Getting installed AV products"

  var wmi = GetObject(r"winmgmts:{impersonationLevel=impersonate}!\\.\root\securitycenter2")
  for i in wmi.execQuery("SELECT displayName FROM AntiVirusProduct"):
      echo "AntiVirusProduct: ", i.displayName

  echo "\n"

  echo "[*] Gathering running processes"

  wmi = GetObject(r"winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
  for i in wmi.execQuery("select * from win32_process"):
    echo i.handle, ", ", i.name

  echo "[*] Gathering running Services"

  wmi = GetObject(r"winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
  for i in wmi.execQuery("select * from win32_service"):
    echo i.name, ", ", i.state


if isMainModule:
  main()
