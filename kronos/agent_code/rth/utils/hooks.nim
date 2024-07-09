#[
  There are the hooks for the IAT when using `execute_pe`
  The following functions are hooked:

  - GetCommandLineA()
  - GetCommandLineB()
  - __p___argc()
  - __p___argv()
  - __wgetmainargs()
  - __getmainargs()

  Furthermore, the CommandLine in the PEB is changed:

  - PEB -> Process Parameters -> CommandLine

  This was tested with a Argument Testing Binary and Mimikatz

]#

import winim/winstr
import strutils
import strformat
import utils
import winapi_wrapper
import ptr_math
import winim/lean
from winim import CommandLineToArgvW

#[

  The C code for CommandLineToArgvA() as this is not available
  in the Windows API. For some reasons, this code cannot be put into
  a separate file (Returns a weird address to argv if done)
]#

{.emit: """
#include <windows.h>

LPSTR* WINAPI CommandLineToArgvA(LPSTR lpCmdline, int* numargs)
{
  DWORD argc;
  LPSTR  *argv;
  LPSTR s;
  LPSTR d;
  LPSTR cmdline;
  int qcount,bcount;

  if(!numargs || *lpCmdline==0)
    {
      SetLastError(ERROR_INVALID_PARAMETER);
      return NULL;
    }

  /* --- First count the arguments */
  argc=1;
  s=lpCmdline;
  /* The first argument, the executable path, follows special rules */
  if (*s=='"')
    {
      /* The executable path ends at the next quote, no matter what */
      s++;
      while (*s)
        if (*s++=='"')
          break;
    }
  else
    {
      /* The executable path ends at the next space, no matter what */
      while (*s && *s!=' ' && *s!='\t')
        s++;
    }
  /* skip to the first argument, if any */
  while (*s==' ' || *s=='\t')
    s++;
  if (*s)
    argc++;

  /* Analyze the remaining arguments */
  qcount=bcount=0;
  while (*s)
    {
      if ((*s==' ' || *s=='\t') && qcount==0)
        {
          /* skip to the next argument and count it if any */
          while (*s==' ' || *s=='\t')
            s++;
          if (*s)
            argc++;
          bcount=0;
        }
      else if (*s=='\\')
        {
          /* '\', count them */
          bcount++;
          s++;
        }
      else if (*s=='"')
        {
          /* '"' */
          if ((bcount & 1)==0)
            qcount++; /* unescaped '"' */
          s++;
          bcount=0;
          /* consecutive quotes, see comment in copying code below */
          while (*s=='"')
            {
              qcount++;
              s++;
            }
          qcount=qcount % 3;
          if (qcount==2)
            qcount=0;
        }
      else
        {
          /* a regular character */
          bcount=0;
          s++;
        }
    }

  /* Allocate in a single lump, the string array, and the strings that go
   * with it. This way the caller can make a single LocalFree() call to free
   * both, as per MSDN.
   */
  argv=LocalAlloc(LMEM_FIXED, (argc+1)*sizeof(LPSTR)+(strlen(lpCmdline)+1)*sizeof(char));
  if (!argv)
    return NULL;
  cmdline=(LPSTR)(argv+argc+1);
  strcpy(cmdline, lpCmdline);

  /* --- Then split and copy the arguments */
  argv[0]=d=cmdline;
  argc=1;
  /* The first argument, the executable path, follows special rules */
  if (*d=='"')
    {
      /* The executable path ends at the next quote, no matter what */
      s=d+1;
      while (*s)
        {
          if (*s=='"')
            {
              s++;
              break;
            }
          *d++=*s++;
        }
    }
  else
    {
      /* The executable path ends at the next space, no matter what */
      while (*d && *d!=' ' && *d!='\t')
        d++;
      s=d;
      if (*s)
        s++;
    }
  /* close the executable path */
  *d++=0;
  /* skip to the first argument and initialize it if any */
  while (*s==' ' || *s=='\t')
    s++;
  if (!*s)
    {
      /* There are no parameters so we are all done */
      argv[argc]=NULL;
      *numargs=argc;
      return argv;
    }

  /* Split and copy the remaining arguments */
  argv[argc++]=d;
  qcount=bcount=0;
  while (*s)
    {
      if ((*s==' ' || *s=='\t') && qcount==0)
        {
          /* close the argument */
          *d++=0;
          bcount=0;

          /* skip to the next one and initialize it if any */
          do {
            s++;
          } while (*s==' ' || *s=='\t');
          if (*s)
            argv[argc++]=d;
        }
      else if (*s=='\\')
        {
          *d++=*s++;
          bcount++;
        }
      else if (*s=='"')
        {
          if ((bcount & 1)==0)
            {
              /* Preceded by an even number of '\', this is half that
               * number of '\', plus a quote which we erase.
               */
              d-=bcount/2;
              qcount++;
            }
          else
            {
              /* Preceded by an odd number of '\', this is half that
               * number of '\' followed by a '"'
               */
              d=d-bcount/2-1;
              *d++='"';
            }
          s++;
          bcount=0;
          /* Now count the number of consecutive quotes. Note that qcount
           * already takes into account the opening quote if any, as well as
           * the quote that lead us here.
           */
          while (*s=='"')
            {
              if (++qcount==3)
                {
                  *d++='"';
                  qcount=0;
                }
              s++;
            }
          if (qcount==2)
            qcount=0;
        }
      else
        {
          /* a regular character */
          *d++=*s++;
          bcount=0;
        }
    }
  *d='\0';
  argv[argc]=NULL;
  *numargs=argc;

  return argv;
}

"""}

#[
  Nim Import for the above C implementation
]#
proc CommandLineToArgvA*(CmdLine: LPSTR, argc: ptr int): ptr LPSTR
    {.importc: "CommandLineToArgvA", nodecl.}


# -------[ Argument/Commandline Hooking Functions ]------- #

var CommandLine*: cstring

# this will be set automatically
var argc: int
var argv: cstringArray

proc patchCommandlinePEB(newCmdLine: string) =

  let peb = getPEB()

  const offsetPP = 0x20
  DBG(fmt"PEB is @ {cast[uint64](peb):#X}")

  let cmdLine = peb.ProcessParameters.CommandLine.Buffer
  DBG(fmt"PEB->ProcessParameters->CommandLine @ {cast[uint64](cmdLine):#X}")

  # convert the commandline to a wide (unicode) string
  var cmdLineWide: wstring = +$newCmdLine
  # length of the string, including the null-bytes
  var cmdLineWideLen = (len(cmdLineWide) * 2) + 1

  # set the length in-memory of the new commandline
  peb.ProcessParameters.CommandLine.Length = cast[USHORT](cmdLineWideLen)

  # Copy the new unicode CommandLine to the PEB
  copyMem(cast[pointer](cmdLine), &cmdLineWide, cmdLineWideLen)




#[
  This is the setter function for the global
  CommandLine Arguments. It should hopefully work for
  _every_ program that somehow gets any arguments
]#
proc setCommandline*(commandline: string) =
  CommandLine = commandline
  let split = commandline.split(" ")
  argc = len(split)
  argv = allocCStringArray(split)

  # patch the PEB ($ casts a stringable (cstring, wstring, ...) to a string)
  DBG("[*] Setting PEB!CommandLine")
  patchCommandlinePEB($CommandLine)


#[
  Simply returns the cstring (pointer to the string)
  Check: DONE
]#
proc hook_GetCommandLineA*(): cstring {.stdcall.} =
  DBG("[*] Callback from hooked `GetCommandLineA`")
  return CommandLine
#[
  Simply returns the pointer to a wstring (&)
  Check: DONE
]#
proc hook_GetCommandLineW*(): pointer {.stdcall.} =
  DBG("[*] Callback from hooked `GetCommandLineW`")

  # The `+$` converts a regular stringable object to a wstring
  # The `&` for a wstring/string/cstring object returns the address of the first character
  return &(+$CommandLine)

#[
  Hook the function __p__argc
  Returns a pointer to an integer that holds the number of
  arguments passed
  Check: DONE
]#
proc hook_p_argc*(): pointer {.stdcall.} =
  DBG("[*] Callback from hooked `hook___p___argc()`")
  return addr argc

#[
  Hook the function __p__argv
  Returns a pointer to an cstringArray
  Check: DONE
]#
proc hook_p_argv*(): pointer {.stdcall.} =
  DBG("[*] Callback from hooked `hook___p___argv()`")
  #return newWString("the unicode commandline")
  return addr argv


#[
  Pretty annoying function that is used by the default Mimikatz version to
  parse the arguments...
  Check: DONE
]#
proc hook_wgetmainargs*(pArgc: ptr int, pArgv: ptr wstring, unknown: pointer, unknown2: pointer): pointer {.stdcall.} =
  DBG("[*] Callback from hooked `hook_wgetmainargs()`")

  # Convert the Commandline to an argv string
  var outArgc: int32

  # The `+$` converts a regular stringable object to a wstring
  # The `&` for a wstring/string/cstring object returns the address of the first character

  var tmpArgv = CommandLineToArgvW(cast[LPCWSTR](&(+$CommandLine)), addr outArgc)
  argc = outArgc

  copyMem(pArgc, addr argc, sizeof(pointer))
  copyMem(pArgv, addr tmpArgv, sizeof(type(tmpArgv)))



#[
  The non-widestring version  of the __wgetmainargs  version.
  Problem: required the CommandLineToArgvA() function that is implemented above.
]#
proc hook_getmainargs*(pArgc: ptr int, pArgv: ptr LPCSTR, unknown: pointer, unknown2: pointer): pointer {.stdcall.} =
  DBG("[*] Callback from hooked `hook_getmainargs()`")
  # Convert the Commandline to an argv string
  var outArgc: int

  # The `&` for a wstring/string/cstring object returns the address of the first character

  var tmpArgv = CommandLineToArgvA(cast[LPSTR](&CommandLine), addr outArgc)
  argc = outArgc

  # write them to the arguments
  copyMem(pArgc, addr argc, sizeof(pointer))
  copyMem(pArgv, addr tmpArgv, sizeof(type(pointer)))


# -------[ Exit Hooking Functions ]------- #
# TBD
