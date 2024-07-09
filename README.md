![](img/kronos.png)

Kronos - A Mythic Agent written in Nim


## Commands


| Command                                 | Description                                                                                                   |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| ls <path>                               | Lists the file in a table of the current/or specified directory                                               |
| cat <path>                              | Will return the content of the file                                                                           |
| cd <path>                               | Will set the working directory to the specified path                                                          |
| rm <path>                               | Remove the specified file                                                                                     |
| mkdir <path>                            | Create a new directory                                                                                        |
| ps                                      | List all running processes                                                                                    |
| sleep <seconds>                         | Sets the sleep and jitter time of the agent                                                                   |
| download <path>                         | Download the specified file from the victim (Client -> Mythic)                                                |
| upload <path>                           | Uploads the specified file to the victim (Mythic -> Client)                                                   |
| steal_token <pid>                       | Steals the token of a process                                                                                 |
| make_token <credential>                 | Creates a new token with `LogonUserA` that can be used in later (network) actions                             |
| rev2self                                | Uses the `rev2self()` api call to revert to the own token after impersonating a user                          |
| register_assembly <local-.net-assembly> | Register Assembly/PS to be usable with `inline_assembly` or `powerscript`                                     |
| register_artifact <pipeline-artifac>    | Register Assembly/PE/PS to be usable with `inline_assembly`, where the file is gathered from the pipeline API |
| inline_assembly <Assembly> <Arguments>  | Executes a .NET assembly in-memory in the current process                                                     |
| powershell <Arguments>                  | Executes a Powershell command via COM                                                                         |
| powerscript <Script> <Arguments>        | Loads a powershell module that was imported with `register_assembly` and executes a given command             |
| lsshares <Host>                         | Lists the shares of a local/remote host                                                                       |
| run <Executable> <Arguments>            | Run the executable with given arguments and return output                                                     |
| whoami                                  | Outputs the current user details (or impersonated user)                                                       |
| ifconfig                                | Outputs the local network interface configuration                                                             |
| socks <port>                            | Opens a SOCKS5 tunnel to the agent                                                                            |
| screenshot                              | Takes a screenshot of the desktop                                                                             |
| link <pipename>                         | Links an implant to another P2P Implant (SMB)                                                                 |



## SOCKS Support

The agent contains a basic SOCKS5 implementation, some things must be considered:

- No authentication
- currently only supports `SetupTCP` (no UDP, no Binding)
- Make sure to set the sleep time of the agent quite low (`sleep 0`)
- When tunneling RDP with xfreerdp, increase the timeout (`/timeout:20000`)


**Proxychains setup:**

```conf
# file: /etc/proxychains.conf
strict_chain
proxy_dns

[ProxyList]
socks5 10.42.30.10 7003
```


