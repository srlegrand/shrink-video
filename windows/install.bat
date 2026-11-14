@echo off
rem Double-click to install. Run "install.bat -Uninstall" to remove.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
pause
