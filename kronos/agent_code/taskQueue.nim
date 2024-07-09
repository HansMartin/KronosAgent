import std/deques
import std/tables
import json


type
  ResponseQueueItem* = object
    taskId*: string
    taskResponse*: JsonNode


# The `responseQueue` will hold a HashMap
# of the taskId and a JsonNode
# When inserting into the queue, use the `addLast()` and to
# use one item, use `popFirst()`
#
# The recvResponseMap holds all the server answers and
# the tasks send to the server
var
  sendResponseQueue* = initDeque[ResponseQueueItem]()
  recvResponseMap*: Table[string, JsonNode]


