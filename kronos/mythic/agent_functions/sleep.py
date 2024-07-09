from mythic_container.MythicCommandBase import *
import json


class SleepArguments(TaskArguments):

    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="interval",
                cli_name = "Sleep",
                display_name = "Sleep Time",
                type=ParameterType.Number,
                description='Time (in seconds) the agent sleeps',
                parameter_group_info=[ParameterGroupInfo(required=True, ui_position=0)],
                ),
            CommandParameter(
                name="jitter",
                cli_name="Jitter",
                display_name="Jitter",
                type=ParameterType.Number,
                description="Jitter in %",
                parameter_group_info=[ParameterGroupInfo(required=False, ui_position=1)],
                )
        ]

    async def parse_arguments(self):
        if len(self.command_line.strip()) == 0:
            raise Exception(
                "sleep requires a sleep time.\n\tUsage: {}".format(
                    RunCommand.help_cmd
                )
            )
        if self.command_line[0] == "{":
            self.load_args_from_json_string(self.command_line)
        else:
            parts = self.command_line.split(" ")
            self.add_arg("interval", int(parts[0]), ParameterType.Number)

            if len(parts) > 1:
                self.add_arg("jitter", int(parts[1]), ParameterType.Number)
            else:
                self.add_arg("jitter", 0, ParameterType.Number)


class SleepCommand(CommandBase):
    cmd = "sleep"
    needs_admin = False
    help_cmd = "sleep [seconds] [jitter]"
    description = "Change the implant's sleep interval."
    version = 2
    author = "@djhohnstein"
    argument_class = SleepArguments
    attackmapping = ["T1029"]

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        response = PTTaskCreateTaskingMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
        )
        return response

    async def process_response(self, task: PTTaskMessageAllData, response: any) -> PTTaskProcessResponseMessageResponse:
        resp = PTTaskProcessResponseMessageResponse(TaskID=task.Task.ID, Success=True)
        return resp
