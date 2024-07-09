# This is the source for the CAT command
import ../structs
import ../utils

#[
Exit the Agent
  No arguments
]#
proc cmd_exit*(task: Task): seq[TaskResponse] {.cdecl.} =

  # Do the Magic
  # kill the process
  DBG("Adios")
  quit()


