# Adds a "Shrink video" submenu to the right-click menu of video files
# (current user only, no admin rights needed).
#
#   install.ps1              install
#   install.ps1 -Uninstall   remove everything again
#
# Used by the setup program (windows/setup.iss):
#   -NoPrompt    never ask questions (the setup program offers ffmpeg itself)
#   -KeepFiles   with -Uninstall: only remove the menu, leave the files alone
param([switch]$Uninstall, [switch]$NoPrompt, [switch]$KeepFiles)

$Sizes      = @(20, 10, 50, 100)   # first entry is labelled as the default
$Extensions = @('.mp4', '.m4v', '.mov', '.mkv', '.webm', '.avi', '.wmv', '.flv',
                '.mpg', '.mpeg', '.ts', '.mts', '.m2ts', '.3gp')

$InstallDir = Join-Path $env:LOCALAPPDATA 'ShrinkVideo'
$Script     = Join-Path $InstallDir 'shrink-video.ps1'
$ClassesKey = 'HKCU:\Software\Classes\SystemFileAssociations'

foreach ($ext in $Extensions) {
    $key = "$ClassesKey\$ext\shell\ShrinkVideo"
    if (Test-Path -LiteralPath $key) { Remove-Item -LiteralPath $key -Recurse -Force }
}

if ($Uninstall) {
    if (-not $KeepFiles -and (Test-Path -LiteralPath $InstallDir)) { Remove-Item -LiteralPath $InstallDir -Recurse -Force }
    Write-Host 'Removed.'
    exit 0
}

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
$Source = Join-Path $PSScriptRoot 'shrink-video.ps1'
if ((Resolve-Path -LiteralPath $Source).Path -ne $Script) {   # the setup program installs it in place
    Copy-Item -LiteralPath $Source -Destination $Script -Force
}
Unblock-File -LiteralPath $Script -ErrorAction SilentlyContinue

$launcher = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $Script + '"'

function Add-Entry([string]$parent, [string]$id, [string]$text, [string]$arguments) {
    $key = "$parent\shell\$id"
    New-Item -Path "$key\command" -Force | Out-Null
    Set-ItemProperty -LiteralPath $key -Name 'MUIVerb' -Value $text
    Set-ItemProperty -LiteralPath "$key\command" -Name '(default)' -Value ($launcher + ' ' + $arguments + ' "%1"')
}

foreach ($ext in $Extensions) {
    $root = "$ClassesKey\$ext\shell\ShrinkVideo"
    New-Item -Path $root -Force | Out-Null
    Set-ItemProperty -LiteralPath $root -Name 'MUIVerb' -Value 'Shrink video'
    Set-ItemProperty -LiteralPath $root -Name 'SubCommands' -Value ''
    Set-ItemProperty -LiteralPath $root -Name 'Icon' -Value 'imageres.dll,-23'

    $i = 1
    foreach ($s in $Sizes) {
        $text = "$s MB"
        if ($i -eq 1) { $text += ' (default)' }
        Add-Entry $root ('{0:00}_{1}MB' -f $i, $s) $text "-SizeMB $s"
        $i++
    }
    Add-Entry $root ('{0:00}_custom' -f $i) 'Custom size...' '-Ask'
}

Write-Host "Installed to $InstallDir"

if (-not $NoPrompt -and -not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host ''
    Write-Host 'ffmpeg is not installed yet - it is required.' -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $answer = Read-Host 'Install it now with winget? [Y/n]'
        if ($answer -eq '' -or $answer -match '^[yY]') {
            winget install --id Gyan.FFmpeg -e
        }
    } else {
        Write-Host 'Download it from https://ffmpeg.org/download.html and add its bin folder to PATH.'
    }
}

Write-Host ''
Write-Host 'Done. Right-click a video file and choose "Shrink video".'
Write-Host '(On Windows 11 it is under "Show more options", or Shift + right-click.)'
