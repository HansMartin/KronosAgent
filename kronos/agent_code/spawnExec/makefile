ComFlags := --gc:arc -d=mingw --app=console -d:DEVENV --hint:name:off

OptFlags := -d:release --passc=-flto --passl=-flto -d:danger -d:strip --opt:size -o:tiny.exe --stdout:off --hotCodeReloading:off -f --tlsEmulation:off --threads:off --nanChecks:off

DbgFlags := -d:debug
SMB := -d:PROFILE_SMB -o:main.smb.exe
DLL := --gc:arc -d:debug -d=mingw --app=lib --nomain --cpu=amd64 -d:DEVENV -o:main.dll
ENC := -d:ENCRYPT_TRAFFIC
HC := -d:HIDE_CONSOLE

default:
	nim c $(ComFlags) $(OptFlags) spawnExec.nim
	#nim c $(ComFlags) $(DbgFlags) spawnExec.nim

clientPH:
	nim c $(ComFlags) $(DbgFlags) sampleClientPH.nim

client:
	nim c $(ComFlags) $(DbgFlags) sampleClient.nim


full:
	rm -rf spawnExec.shellcode
	@nim c $(ComFlags) $(OptFlags) spawnExec.nim
	@python ../testing/toshellcode.py

