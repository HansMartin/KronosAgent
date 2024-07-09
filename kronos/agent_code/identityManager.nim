import utils
import winim/lean


type
  LoginInformation* = object
    username*: string
    domain*: string
    impersonated: bool
    impUser: string
    impToken: HANDLE


var currentUserInfo: LoginInformation
var isProp = false




#[
  This can impersonate the logged-on user in the
  current thread.
]#
proc impersonateThread*() =
  if currentUserInfo.impersonated:
    let bStatus = ImpersonateLoggedOnUser(currentUserInfo.impToken)
    if bStatus:
      DBG("[+] ImpersonatedLoggedOnUser on Thread()")

proc getLoginInformation*(): LoginInformation =
  # If not already filled-in
  if not isProp:
    currentUserInfo.username = getUser()
    var tmpDomain = getDomain()

    if tmpDomain == "":
      tmpDomain = getHost()
    currentUserInfo.domain = tmpDomain
    isProp = true # set struct to be populated

  return currentUserInfo

#[
  Set the current state to `impersonated` and
  set the impersonated user.
]#
proc setImpersonated*(impUser: string, token: HANDLE) =
  currentUserInfo.impersonated = true
  currentUserInfo.impUser = impUser
  currentUserInfo.impToken = token

proc revertImpersonated*() =
  currentUserInfo.impersonated = false
  currentUserInfo.impUser = ""




#[
  Takes the credential-information of a user and
  creates a new token with it using the API call
]#
proc loginAsUser*(loginInfo: LoginInformation, password: string): bool =


  var
    bStatus: BOOL
    hToken: HANDLE


  # Revert current session
  RevertToSelf()
  revertImpersonated()

  bStatus = LogonUserA(loginInfo.username, loginInfo.domain, password, LOGON32_LOGON_NEW_CREDENTIALS, LOGON32_PROVIDER_DEFAULT, addr hToken)

  if bStatus:
    DBG("[+] successfull created token")

    if bStatus:
      bStatus = ImpersonateLoggedOnUser(hToken)
      setImpersonated(loginInfo.domain & "\\" & loginInfo.username, hToken)
    else:
      DBG("[-] Failed to ImpersonateLoggedOnUser()")
      return false
  else:
    DBG("[-] Failed to login user -> wrong password?")
    return false

  return true

