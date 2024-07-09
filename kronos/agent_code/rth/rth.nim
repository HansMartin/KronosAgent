#[
  This is the base for the Nim "Red Team Helper"
  The file contains the structures and interfaces to
  the main library
]#


type
  PayloadType* = enum
    Shellcode,
    Assembly,
    PE,
    DLL

type
  Architecture* = enum
    x64,
    x86

type
  Payload* = object
    ptype*: PayloadType
    bytes*: seq[byte]
    architecture*: Architecture
    arguments*: seq[string]
    isEncrypted*: bool
    redirectStdout*: bool
    output*: string
    payloadName*: string


type
  SyscallType* = enum
    Default,
    Dynamic,
    Static
