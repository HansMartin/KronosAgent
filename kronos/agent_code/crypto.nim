import nimcrypto
import b64

#[
  Implements the crypto stuff for the
  communication with the server
]#


# PKCS #7 Padding
proc pad(inp: var seq[byte]) =
  var pLen = len(inp)
  var numPads = 16 - (pLen mod 16)

  for i in 0..<numPads:
    inp.add(cast[byte](numPads))

proc unpad(inp: var seq[byte]) =
  # get last byte as padding var
  var numPads = cast[int](inp[inp.len()-1])

  for i in 0..<numPads:
    discard inp.pop()


proc encrypt*(inp: string, b64key: string): seq[byte] =

  # use a fixed IV first
  var
    iv  = @[byte 0x1, 0x1, 0x1, 0x1,0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1,0x1, 0x1, 0x1, 0x1]
    key = decode(Base64Pad, b64key)
    bInp = cast[seq[byte]](inp)
    bOut: seq[byte]
    ectx: CBC[aes256]

  # Initialize Crypto Provider
  ectx.init(key, iv)

  # PKCS #7 padding
  pad(bInp)

  bOut = newSeq[byte](len(bInp))
  ectx.encrypt(bInp, bOut)

  var hmac = sha256.hmac(key, iv & bOut)
  return iv & bOut & @(hmac.data)


#[
  Decypt a message and return the string repr.
]#
proc decrypt*(inp: seq[byte], b64key: string): string =

  var
    hmac = inp[len(inp)-32..len(inp)-1] # not really required
    iv = inp[0..15]
    key = decode(Base64Pad, b64key)
    dctx: CBC[aes256]
    bInp = inp[16..len(inp)-33]
    bOut = newSeq[byte](len(bInp))

  # decrypt and unpad
  dctx.init(key, iv)
  dctx.decrypt(bInp, bOut)

  unpad(bOut)
  return cast[string](bOut)
