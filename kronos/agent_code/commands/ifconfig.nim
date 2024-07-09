# This is the source for the CAT command
import ../structs
import ../utils
import json
import winim
import winim/winstr

#[
  Struct to send the data to the
  Mythic server
]#
type
  AdapterInfo = object
    AdapterName: string
    AdapterId: string
    Description: string
    AddressesV4: seq[string]
    AddressesV6: seq[string]
    DnsServers: seq[string]
    Gateways: seq[string]
    DhcpAddresses: seq[string]
    Status: string
    DnsSuffix: string
    DnsEnabled: string
    DynamicDnsEnabled: string



#[
  Loops through the IP Linked List for Type T
  and returns a list of IPS
]#
proc resolveIps[T](firstEntry: T): seq[string] =
  var unicastAddr = cast[T](firstEntry)

  while cast[int](unicastAddr) != 0:

    # IPv4
    if unicastAddr.Address.lpSockaddr.sa_family == AF_INET:
      var si: ptr sockaddr_in = cast[ptr sockaddr_in](unicastAddr.Address.lpSockaddr)

      var ipAddr: PSTR = cast[PSTR](alloc(16)) # An IP should have max 15 bytes + nullbyte
      RtlIpv4AddressToStringA(si[].sin_addr, ipAddr)
      result.add($ipAddr)
      unicastAddr = unicastaddr.Next
    else:
      var si: ptr sockaddr_in6 = cast[ptr sockaddr_in6](unicastAddr.Address.lpSockaddr)
      var ipAddr: PSTR = cast[PSTR](alloc(40)) # max 39 character + nullbyte
      RtlIpv6AddressToStringA(si[].sin6_addr, ipAddr)



#[
  Goes through the output of GetAdaptersAddresses() and return
  all adapter Information as structured data
]#
proc getIps(): seq[AdapterInfo] =

  const WORKING_BUFFER_SIZE = 15000 # 15kb to start off
  var adpAddresses = cast[PIP_ADAPTER_ADDRESSES](alloc(WORKING_BUFFER_SIZE))
  var bufSize: ULONG
  var status = GetAdaptersAddresses(AF_INET, GAA_FLAG_INCLUDE_GATEWAYS, NULL, adpAddresses, addr bufSize)


  # Allocate the right amount of memory
  if status == ERROR_BUFFEROVERFLOW:
    adpAddresses = cast[PIP_ADAPTER_ADDRESSES](alloc(bufSize))

    status = GetAdaptersAddresses(AF_INET, GAA_FLAG_INCLUDE_GATEWAYS, NULL, adpAddresses, addr bufSize)

    if status == ERROR_SUCCESS:
      DBG("[+] Got Infos")
    else:
      return @[]
  elif status == ERROR_SUCCESS:
    discard
  else:
      return @[]

  while cast[int](adpAddresses) != 0:

    var status = ""

    if adpAddresses[].OperStatus == ifOperStatusUp:
      status = "up"
    else:
      status = "down"

    result.add(AdapterInfo(
                AdapterName: $adpAddresses[].FriendlyName,
                Description: $adpAddresses[].Description,
                AdapterId: $adpAddresses[].AdapterName,
                Status: status,
                AddressesV4: resolveIps(adpAddresses[].FirstUnicastAddress),
                DnsServers: resolveIps(adpAddresses[].FirstDnsServerAddress),
                DnsSuffix: $adpAddresses[].DnsSuffix
                ))


    # Goto next entry in LL
    adpAddresses = adpAddresses.Next

#[
Short Command Description
  {"path": "anwiththestruct"}

]#
proc cmd_ifconfig*(task: Task): seq[TaskResponse] {.cdecl.} =

  # Configure Output
  var
    output = ""
    status = ""

  # Do the Magic
  #
  let ips = getIps()

  if len(ips) == 0:
    status = "error"
  else:
    output = $(%* ips)

  # return the response
  return buildReturnData(task.id, output, status)

