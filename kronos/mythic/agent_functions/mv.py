from mythic_container.MythicCommandBase import *
import json


class MvArguments(TaskArguments):

    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="source",
                cli_name = "Path",
                display_name = "Source File",
                type=ParameterType.String,
                description='Source file to copy.',
                parameter_group_info=[ParameterGroupInfo(required=True, ui_position=0)],
                ),
            CommandParameter(
                name="destination",
                cli_name="Destination",
                display_name="Destination Path",
                type=ParameterType.String,
                description="Where the new file will be created.",
                parameter_group_info=[ParameterGroupInfo(required=True, ui_position=1)],
                )
        ]

    def split_commandline(self):
        if self.command_line[0] == "{":
            raise Exception("split_commandline expected string, but got JSON object: " + self.command_line)
        inQuotes = False
        curCommand = ""
        cmds = []
        for x in range(len(self.command_line)):
            c = self.command_line[x]
            if c == '"' or c == "'":
                inQuotes = not inQuotes
            if (not inQuotes and c == ' '):
                cmds.append(curCommand)
                curCommand = ""
            else:
                curCommand += c
        
        if curCommand != "":
            cmds.append(curCommand)
        
        for x in range(len(cmds)):
            if cmds[x][0] == '"' and cmds[x][-1] == '"':
                cmds[x] = cmds[x][1:-1]
            elif cmds[x][0] == "'" and cmds[x][-1] == "'":
                cmds[x] = cmds[x][1:-1]

        return cmds

    errorMsg = "Missing required argument: {}"
    async def parse_arguments(self):
        if self.command_line[0] == "{":
            self.load_args_from_json_string(self.command_line)
        else:
            cmds = self.split_commandline()
            if len(cmds) != 2:
                raise Exception("Expected two arguments to mv, but got: {}\n\tUsage: {}".format(cmds, MvCommand.help_cmd))
            self.add_arg("source", cmds[0])
            self.add_arg("destination", cmds[1])

class MvCommand(CommandBase):
    cmd = "mv"
    needs_admin = False
    help_cmd = "mv [source] [dest]"
    description = "Move a file from source to destination."
    version = 2
    author = "@djhohnstein"
    argument_class = MvArguments
    attackmapping = ["T1106"]

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        response = PTTaskCreateTaskingMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
        )
        response.DisplayParams = "-Path {} -Destination {}".format(taskData.args.get_arg("source"), taskData.args.get_arg("destination"))
        return response

    async def process_response(self, task: PTTaskMessageAllData, response: any) -> PTTaskProcessResponseMessageResponse:
        resp = PTTaskProcessResponseMessageResponse(TaskID=task.Task.ID, Success=True)
        return resp