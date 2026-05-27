' Silent launcher for kanata_wintercept.exe -- invoked by Task Scheduler via
' wscript.exe so no console window flashes. cmd.exe is needed only for stdout
' redirection (kanata has no --log-file flag); wrapping cmd in a WshShell.Run
' with windowStyle=0 keeps it hidden.
Option Explicit
Dim WshShell, exe, cfg, logFile, logDir, fso, cmd
Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

exe     = WshShell.ExpandEnvironmentStrings("%USERPROFILE%\.local\bin\kanata_wintercept.exe")
cfg     = WshShell.ExpandEnvironmentStrings("%USERPROFILE%\.config\kanata\config-windows.kbd")
logDir  = WshShell.ExpandEnvironmentStrings("%LOCALAPPDATA%\Kanata")
logFile = logDir & "\kanata.log"

If Not fso.FolderExists(logDir) Then
    fso.CreateFolder(logDir)
End If

cmd = "cmd /c """"" & exe & """ -c """ & cfg & """ --no-wait >> """ & logFile & """ 2>&1"""
WshShell.Run cmd, 0, False
