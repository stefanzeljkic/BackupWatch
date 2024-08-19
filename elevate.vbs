Set UAC = CreateObject("Shell.Application")
UAC.ShellExecute "cmd.exe", "/c " & WScript.Arguments(0), "", "runas", 1
