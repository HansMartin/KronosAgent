from mythic_container.PayloadBuilder import *
from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *
import shutil
import json
import pathlib
import os,fnmatch,tempfile,asyncio


# Most of the stuff is shamelessly stolen from the Apollo builder file
# Ref: https://github.com/MythicAgents/Apollo/blob/master/Payload_Type/apollo/mythic/agent_functions/builder.py)
def get_nim_files(base_path: str) -> [str]:
    results = []
    for root, dirs, files in os.walk(base_path):
        for name in files:
            if fnmatch.fnmatch(name, "*.nim"):
                results.append(os.path.join(root, name))
    if len(results) == 0:
        raise Exception("No payload files found with extension .nim")
    return results

def getProfileArguments(uuid, c2info):
    
    mainCodeFile = "config.nim"

    special_files_map = {
        mainCodeFile: {
            "callback_interval": "",
            "callback_jitter": "",
            "callback_port": "",
            "callback_host": "",
            "post_uri": "",
            "proxy_host": "",
            "proxy_port": "",
            "proxy_user": "",
            "proxy_pass": "",
            # "domain_front": "",
            "killdate": "",
            # "USER_AGENT": "",
            "pipename": "",
            "port": "",
            "encrypted_exchange_check": "",
            "payload_uuid": uuid,
            "AESPSK": "",
        },
        "useEncryption": False
    }

    stdout_err = ""
    extra_variables = {}

    parameters = c2info[0].get_parameters_dict()
    profname = c2info[0].get_c2profile()["name"]

    if profname == "smb":
        parameters["callback_interval"] = 5
        parameters["callback_jitter"] = 20
        parameters["callback_port"] = 1337
    

    for c2 in c2info:
        profile = c2.get_c2profile()
        for key, val in parameters.items():
            if isinstance(val, dict):
                if key == "AESPSK":
                    stdout_err += "Setting {} to {}".format(key, val["enc_key"])
                    special_files_map[mainCodeFile][key] = val["enc_key"] if val["enc_key"] is not None else ""
                    special_files_map["useEncryption"] = True if val["enc_key"] is not None else False
                else:
                    stdout_err += f"Unhandled Dict: {val}"
            elif isinstance(val, list):
                for item in val:
                    if not isinstance(item, dict):
                        raise Exception("Expected a list of dictionaries, but got {}".format(type(item)))
                    extra_variables[item["key"]] = item["value"]
            elif isinstance(val, str):
                special_files_map[mainCodeFile][key] = val
            else:
                special_files_map[mainCodeFile][key] = json.dumps(val)

    special_files_map["extra_variables"] = extra_variables
    return special_files_map



class Kronos(PayloadType):
    name = "kronos"
    file_extension = "exe"
    author = "@mariusschwarz"
    supported_os = [SupportedOS.Windows]
    wrapper = False
    wrapped_payloads = []
    note = """This Payload uses the Nim language"""
    supports_dynamic_loading = True
    c2_profiles = ["http", "smb"]
    mythic_encrypts = True
    translation_container = None # "myPythonTranslation"
    build_parameters = [
            BuildParameter(
                name = "output_type",
                parameter_type=BuildParameterType.ChooseOne,
                choices=["WinExe", "DLL", "Shellcode"],
                default_value="WinExe",
                description="Select the output type of the agent"
            ),
            BuildParameter(
                name = "debug",
                parameter_type=BuildParameterType.Boolean,
                default_value=False,
                required=False,
                description="Create a debug build"
            ),
            BuildParameter(
                name = "dynsyscalls",
                parameter_type=BuildParameterType.Boolean,
                default_value=False,
                required=False,
                description="Use dynamic syscalls"
            ),
            BuildParameter(
                name = "hide_console",
                parameter_type=BuildParameterType.Boolean,
                default_value=False,
                required=False,
                description="Hide the console window"
            )
    ]
    agent_path = pathlib.Path(".") / "kronos"
    agent_icon_path = agent_path / "mythic" / "agent_icons" / "kronos.svg"
    agent_code_path = agent_path / "agent_code"

    build_steps = [
        BuildStep(step_name="Configuration", step_description="Adjusting the Agent Configuration"),
        BuildStep(step_name="Compilation", step_description="Compiling the Agent")
    ]

    async def build(self) -> BuildResponse:
        # this function gets called to create an instance of your payload

        
        '''
        stdout = ""
        for c2 in self.c2info:
            profile = c2.get_c2profile()
            if profile["name"] != "http":  # maybe later
                continue

            for key, val in c2.get_parameters_dict().items():
                stdout += f"{key} -> {val}"
 '''

            
        resp = BuildResponse(status=BuildStatus.Success)
        resp.payload = b""
        resp.build_message  = f"The UUID is: {self.uuid}\n"
        resp.build_message += f"The Encryption Key is: {self.c2info[0].get_parameters_dict()['AESPSK']['enc_key']}"
        
        # get changes for profiles
        special_files_map = getProfileArguments(self.uuid, self.c2info)
        resp.build_message += f"\n{special_files_map}"

        #Copy all files to tmp folder and compile there
        agent_build_path = tempfile.TemporaryDirectory(suffix=self.uuid)
        resp.build_message += f"\nAgent Code Path: {self.agent_code_path}"
        resp.build_message += f"\nTempfile: {agent_build_path.name}"
        build_path = agent_build_path.name + "/src/"
        
        # Uncommet those three lines for debug
        build_path = agent_build_path.name + "DBG"  # for debug
        os.mkdir(build_path)
        build_path = build_path + "/src/"

        # shutil to copy payload files over
        shutil.copytree(self.agent_code_path, build_path)

        # first replace everything in the c2 profiles
        for nimFile in get_nim_files(build_path):
            templateFile = open(nimFile, "rb").read().decode()
            for specialFile in special_files_map.keys():
                if nimFile.endswith(specialFile):
                    for key, val in special_files_map[specialFile].items():
                        templateFile = templateFile.replace("{{" + key + "}}", val)
                    if len(special_files_map["extra_variables"].keys()) > 0:
                        extra_data = "@["
                        for key, val in special_files_map["extra_variables"].items():
                            extra_data += "Header(key: \"" + key + "\", value: \"" + val + "\"),"
                        extra_data += "]"
                        templateFile = templateFile.replace("{{HTTP_HEADERS}}", extra_data)
                    else:
                        templateFile = templateFile.replace("{{HTTP_HEADERS}}", "@[]")

            with open(nimFile, "wb") as f:
                f.write(templateFile.encode())


        await SendMythicRPCPayloadUpdatebuildStep(MythicRPCPayloadUpdateBuildStepMessage(
                PayloadUUID=self.uuid,
                StepName="Configuration",
                StepStdout="Adjusted Kronos Configuration",
                StepSuccess=True
            ))

        buildAsDebug = self.get_parameter('debug')
        useDynSyscalls = self.get_parameter('dynsyscalls')
        command = ""

        profile = self.c2info[0].get_c2profile()


        # --passL:-Wl,--dynamicbase are required for having a relocation table (only for donut)
        flags = "-d:MYTHIC_BUILD "

        if profile["name"] == "smb":
            flags += "-d:PROFILE_SMB "

        if useDynSyscalls:
            flags += "-d:DYNSYSCALLS "
    
        # setup the usage of encryption for the compilation
        if special_files_map["useEncryption"]:
            flags += "-d:ENCRYPT_TRAFFIC "

        # when the console should be hidden
        if self.get_parameter('hide_console'):
            flags += "-d:HIDE_CONSOLE "

        if buildAsDebug:
            # debug nim build
            flags += "-d:debug "
            #command = f"nim c --gc:arc -d:debug -d=mingw --app=console --cpu=amd64 -o:kronos.exe {flags} main.nim" 
        else:
            flags += "-d:release --passc=-flto --passl=-flto -d:danger -d:strip --opt:size "

        base_cmd = f"nim c --gc:arc --cpu=amd64 -d:mingw"
        output_path = ""

        if self.get_parameter('output_type') == "DLL":
            command = f"{base_cmd} --app=lib --nomain -o:kronos.dll {flags} mainLib.nim"
            output_path = "{}/kronos.dll".format(build_path)
            file_extension = "dll"
        elif self.get_parameter('output_type') == "WinExe":
            command = f"{base_cmd} --app=console -o:kronos.exe {flags} main.nim"
            output_path = "{}/kronos.exe".format(build_path)
            file_extension = "exe"


        proc = await asyncio.create_subprocess_shell(command, stdout=asyncio.subprocess.PIPE, stderr= asyncio.subprocess.PIPE, cwd=build_path)
        stdout, stderr = await proc.communicate()
        stdout_err = ""
        if stdout:
            stdout_err += f'[stdout]\n{stdout.decode()}\n'
        if stderr:
            stdout_err += f'[stderr]\n{stderr.decode()}' + "\n" + command


        params = self.c2info[0].get_parameters_dict()
        stdout_err += str(params)
        step_success = False

        if os.path.exists(output_path):
            # If a shellcode is required, generate it with donut 
            resp.payload = open(output_path, "rb").read()
            resp.status = BuildStatus.Success
            resp.message = "[+] Payload build successfully"
            resp.build_stderr = stdout_err
            step_success = True
        else:
            resp.status = BuildStatus.Error
            resp.build_message += "\nUnknown error while building payload. Check the stderr for this build."
            resp.build_stderr = stdout_err


        await SendMythicRPCPayloadUpdatebuildStep(MythicRPCPayloadUpdateBuildStepMessage(
                PayloadUUID=self.uuid,
                StepName="Compilation",
                StepStdout="Compiled Kronos",
                StepSuccess=step_success
            ))

        return resp

