# Smoke test (Windows): make a test clip, shrink it, check the result fits.
$ErrorActionPreference = 'Stop'
$work = Join-Path ([IO.Path]::GetTempPath()) ('shrink-test-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
$clip = Join-Path $work 'my clip.mp4'
$script = Join-Path $PSScriptRoot '..\windows\shrink-video.ps1'

& ffmpeg -hide_banner -loglevel error -y `
    -f lavfi -i 'testsrc2=size=1280x720:rate=30:duration=12' `
    -f lavfi -i 'sine=frequency=440:duration=12' `
    -c:v libx264 -preset ultrafast -crf 12 -pix_fmt yuv420p -c:a aac -shortest $clip
if ($LASTEXITCODE -ne 0) { throw 'could not create the test clip' }
Write-Host "Test clip: $((Get-Item -LiteralPath $clip).Length) bytes"

function Test-Shrink([string]$size, [string]$methods, [long]$limit) {
    # Same way the right-click menu starts it: Windows PowerShell, -File.
    # stdin is empty so a "Press Enter to close" prompt cannot hang the test.
    '' | powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -SizeMB $size -Methods $methods $clip
    if ($LASTEXITCODE -ne 0) { throw "shrink-video.ps1 exited with $LASTEXITCODE" }
    $out = Join-Path $work "my clip_${size}MB.mp4"
    if (-not (Test-Path -LiteralPath $out)) { throw "$out was not created" }
    $len = (Get-Item -LiteralPath $out).Length
    if ($len -gt $limit) { throw "$len bytes is over the $limit limit" }
    Write-Host "ok ($methods): $len bytes"
}

Test-Shrink '1'   'resize,compress'  1000000
Test-Shrink '0.5' 'resize,fps,speed' 500000

Remove-Item -LiteralPath $work -Recurse -Force
Write-Host 'All good.'
