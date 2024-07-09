ComFlags := --gc:arc -d=mingw --app=console -d:DEVENV --hint:name:off
#ComFlags := --gc:none -d=mingw --app=console -d:DEVENV --hint:name:off

OptFlags := -d:release --passc=-flto --passl=-flto -d:danger -d:strip --opt:size -o:tiny.exe --stdout:off --hotCodeReloading:off -f --tlsEmulation:off --threads:off --nanChecks:off #--t:"-nostdlib"


## GCC flags


DbgFlags := -d:debug
SMB := -d:PROFILE_SMB -o:main.smb.exe
DLL := --gc:arc -d:debug -d=mingw --app=lib --nomain --cpu=amd64 -d:DEVENV -o:main.dll
ENC := -d:ENCRYPT_TRAFFIC
HC := -d:HIDE_CONSOLE

default:
	nim c $(ComFlags) $(DbgFlags) main.nim
smb:
	nim c $(ComFlags) $(DbgFlags) $(SMB) main.nim
smb-release:
	nim c $(ComFlags) $(SMB) $(OptFlags) main.nim

smb-withenc: 
	nim c $(ComFlags) $(DbgFlags) $(ENC) $(SMB) main.nim

dll:

	nim c $(DLL) mainLib.nim

dll-release:
	nim c $(OptFlags) $(DLL) mainLib.nim

withenc:
	nim c $(ComFlags) $(DbgFlags) $(ENC) main.nim
release:
	nim c $(ComFlags) $(OptFlags) main.nim

release_withenc:
	nim c $(ComFlags) $(OptFlags) $(ENC) main.nim


clean:
	rm -rf *.exe
	rm -rf *.dll
	rm -rf main.gc.log
	rm -rf *.bin
	rm -rf *.shellcode
