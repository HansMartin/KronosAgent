
#[
  This file will implement the timeline
  for the executions in the repl tool
]#

import utils
import ../rth
import std/times
import std/json
import strformat
from os import getEnv, getCurrentProcessId
import strutils
import marshal

type
  LogEntry* = object
    name*: string
    date*: string
    sourcePid*: int
    dstPid*: int
    executionMethod*: string
    hostname*: string
    username*: string
    arguments*: string


var timelineActive = true
var timelineFile: string = "C:\\temp\\timeline.json"
var username: string
var hostname: string
var currentPID: int

#[
  Sets the filename, gathers hostname and username
]#
proc initializeTimeline*(filename: string) =

  currentPID = getCurrentProcessId()
  username = getEnv("USERNAME")
  hostname = getEnv("COMPUTERNAME")

  timelineFile = filename



#[
  Method to check whether logging is enabled
  -> not sure if required
]#
proc isTimelineActivated*(): bool =
  return timelineActive

#[
  Enable the logging of the execution events
]#
proc enableTimeline*(status: bool) =
  timelineActive = status

proc setTimelineFile*(filename: string) =
  timelineFile = filename

proc logExecToTimeline*(payload: Payload, execMethod: string) =

  # Only log the if logging is enabled
  if not isTimelineActivated():
    return

  let dt = now().format("yyyy-MM-dd HH:mm")
  let cmdline = payload.arguments.join(" ")

  # Timeline Logging Debug
  DBG("[+] Timeline Logging")
  DBG(fmt"|_ Date: {dt}")
  DBG(fmt"|_ Method: {execMethod}")
  DBG(fmt"|_ Name: {payload.payloadName}")
  DBG(fmt"|_ Hostname: {hostname}")
  DBG(fmt"|_ Username: {username}")
  DBG(fmt"|_ Commandline: {cmdline}")



  var entry = LogEntry()
  entry.name = payload.payloadName
  entry.date = dt
  entry.sourcePid = currentPID
  entry.dstPid = 0
  entry.executionMethod = execMethod
  entry.hostname = hostname
  entry.username = username
  entry.arguments = cmdline

  # Write the json to the timeline file (append json to file)
  try:
    let outFile = open(timelineFile, FileMode.fmAppend)
    outFile.write($$entry)
    outFile.write("\n")
    outFile.close()
  except:
    echo(fmt"[-] Error writing file, check if path is writable: `{timelineFile}`")
