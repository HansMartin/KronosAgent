from mythic_container.MythicCommandBase import *
import json
from mythic_container.MythicRPC import *
from os import path
import base64
import asyncio


class PowerScriptArguments(TaskArguments):

    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="script_name",
                cli_name = "Script",
                display_name = "Script",
                type=ParameterType.ChooseOne,
                dynamic_query_function=self.get_files,
                description="PowerShell script to execute (e.g., WinPeas.ps1).",
                parameter_group_info = [
                    ParameterGroupInfo(
                        required=True,
                        group_name="Default",
                        ui_position=1
                    ),
                ]),
            CommandParameter(
                name="script_arguments",
                cli_name="Arguments",
                display_name="Arguments",
                type=ParameterType.String,
                description="Arguments to pass to the script.",
                parameter_group_info = [
                    ParameterGroupInfo(
                        required=False,
                        group_name="Default",
                        ui_position=2
                    ),
                ]),
        ]

    async def parse_arguments(self):
        if len(self.command_line) == 0:
            raise Exception("Require an script to execute.\n\tUsage: {}".format(PowerScriptCommand.help_cmd))
        if self.command_line[0] == "{":
            self.load_args_from_json_string(self.command_line)
        else:
            parts = self.command_line.split(" ", maxsplit=1)
            self.add_arg("script_name", parts[0])
            self.add_arg("script_arguments", "")
            if len(parts) == 2:
                self.add_arg("script_arguments", parts[1])

    async def get_files(self, inputMsg: PTRPCDynamicQueryFunctionMessage) -> PTRPCDynamicQueryFunctionMessageResponse:
        fileResponse = PTRPCDynamicQueryFunctionMessageResponse(Success=False)
        file_resp = await SendMythicRPCFileSearch(MythicRPCFileSearchMessage(
            CallbackID=inputMsg.Callback,
            LimitByCallback=True,
            Filename="",
        ))
        if file_resp.Success:
            file_names = []
            for f in file_resp.Files:
                if f.Filename not in file_names and f.Filename.endswith(".ps1"):
                    file_names.append(f.Filename)
            fileResponse.Success = True
            fileResponse.Choices = file_names
            return fileResponse
        else:
            fileResponse.Error = file_resp.Error
            return fileResponse


class PowerScriptCommand(CommandBase):
    cmd = "powerscript"
    needs_admin = False
    help_cmd = "powerscript [script.ps1] [args]"
    description = "Executes a PowerShell script with the specified arguments. This script must first be known by the agent using the `register_assembly` command."
    version = 3
    author = "@mariusschwarz"
    argument_class = PowerScriptArguments
    attackmapping = ["T1547"]


    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        response = PTTaskCreateTaskingMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
        )
        
        response.DisplayParams = "-Script {} -Arguments {}".format(
            taskData.args.get_arg("script_name"),
            taskData.args.get_arg("script_arguments")
        )

        return response

    async def process_response(self, task: PTTaskMessageAllData, response: any) -> PTTaskProcessResponseMessageResponse:
        resp = PTTaskProcessResponseMessageResponse(TaskID=task.Task.ID, Success=True)
        return resp