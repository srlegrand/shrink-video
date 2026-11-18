# shrink-video.ps1 - re-encode a video so it fits under a target file size.
#
#   shrink-video.ps1 [-SizeMB 20] [-Methods resize,compress] FILE...
#
# You choose which methods may be used (resize, fps, speed, compress) and the
# script picks the combination that hurts the picture least while still
# fitting in the target size. Without -Methods a dialog asks.
# Writes FILE_<size>MB.mp4 next to each input (H.264 + AAC, two-pass).
# Only FILE is positional. Otherwise the right-click menu's
# `-SizeMB 20 "C:\clip.mp4"` would put the path in -Methods and leave no files.
[CmdletBinding(PositionalBinding = $false)]
param(
    [double]$SizeMB = 20,
    [switch]$Ask,
    [string]$Methods = '',
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Files
)

$DefaultMB = 20
$DefaultMethods = 'resize,compress'
$inv = [Globalization.CultureInfo]::InvariantCulture
$Host.UI.RawUI.WindowTitle = 'Shrink video'

function Stop-WithPause([int]$code) {
    Write-Host ''
    Read-Host 'Press Enter to close' | Out-Null
    exit $code
}

function Format-MB([long]$bytes) {
    return ($bytes / 1000000).ToString('0.0', $inv) + ' MB'
}

function Format-Num([double]$x) {
    return $x.ToString('0.###', $inv)
}

# Explorer keeps the PATH it started with, so an ffmpeg installed since the last
# sign-in would not be found. Add the current PATH from the registry.
foreach ($scope in 'User', 'Machine') {
    $extra = [Environment]::GetEnvironmentVariable('Path', $scope)
    if ($extra) { $env:Path = $env:Path.TrimEnd(';') + ';' + $extra }
}

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue) -or
    -not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
    Write-Host 'ffmpeg was not found on this PC.' -ForegroundColor Red
    Write-Host 'Install it by running this in a terminal, then try again:'
    Write-Host '    winget install --id Gyan.FFmpeg -e'
    Stop-WithPause 1
}

if (-not $Files -or $Files.Count -eq 0) {
    Write-Host 'Usage: shrink-video.ps1 [-SizeMB 20] [-Methods resize,compress] FILE...'
    Stop-WithPause 2
}

# --- Dialog: target size + which methods may be used ------------------------

function Show-OptionsDialog([double]$size, [string]$checked, [string]$what) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Shrink video'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true
    $form.ClientSize = New-Object System.Drawing.Size(400, 270)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = $what
    $title.AutoEllipsis = $true
    $title.Location = New-Object System.Drawing.Point(16, 14)
    $title.Size = New-Object System.Drawing.Size(368, 20)
    $form.Controls.Add($title)

    $sizeLabel = New-Object System.Windows.Forms.Label
    $sizeLabel.Text = 'Target size (MB):'
    $sizeLabel.Location = New-Object System.Drawing.Point(16, 46)
    $sizeLabel.Size = New-Object System.Drawing.Size(110, 20)
    $form.Controls.Add($sizeLabel)

    $sizeBox = New-Object System.Windows.Forms.TextBox
    $sizeBox.Text = Format-Num $size
    $sizeBox.Location = New-Object System.Drawing.Point(130, 43)
    $sizeBox.Size = New-Object System.Drawing.Size(70, 22)
    $form.Controls.Add($sizeBox)

    $byLabel = New-Object System.Windows.Forms.Label
    $byLabel.Text = 'Shrink it by:'
    $byLabel.Location = New-Object System.Drawing.Point(16, 82)
    $byLabel.Size = New-Object System.Drawing.Size(368, 20)
    $form.Controls.Add($byLabel)

    $options = @(
        @('resize',   'Resizing  (lower the resolution)'),
        @('speed',    'Speeding it up  (play faster)'),
        @('fps',      'Dropping the framerate'),
        @('compress', 'Compressing  (lower the picture quality)')
    )
    $boxes = @{}
    $y = 106
    foreach ($o in $options) {
        $cb = New-Object System.Windows.Forms.CheckBox
        $cb.Text = $o[1]
        $cb.Checked = ((',' + $checked + ',') -like ('*,' + $o[0] + ',*'))
        $cb.Location = New-Object System.Drawing.Point(28, $y)
        $cb.Size = New-Object System.Drawing.Size(350, 24)
        $form.Controls.Add($cb)
        $boxes[$o[0]] = $cb
        $y += 26
    }

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'Shrink'
    $ok.Location = New-Object System.Drawing.Point(214, 228)
    $ok.Size = New-Object System.Drawing.Size(80, 28)
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($ok)
    $form.AcceptButton = $ok

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.Location = New-Object System.Drawing.Point(304, 228)
    $cancel.Size = New-Object System.Drawing.Size(80, 28)
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancel)
    $form.CancelButton = $cancel

    while ($true) {
        if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return $null }

        $text = ($sizeBox.Text.Trim() -replace ',', '.') -replace '\s*[mM][bB]$', ''
        $parsed = 0.0
        if (-not [double]::TryParse($text, [Globalization.NumberStyles]::Float, $inv, [ref]$parsed) -or $parsed -le 0) {
            [void][System.Windows.Forms.MessageBox]::Show('Enter the target size as a number of megabytes, e.g. 20.', 'Shrink video')
            continue
        }
        $picked = @()
        foreach ($o in $options) { if ($boxes[$o[0]].Checked) { $picked += $o[0] } }
        if ($picked.Count -eq 0) {
            [void][System.Windows.Forms.MessageBox]::Show('Tick at least one way to shrink the video.', 'Shrink video')
            continue
        }
        return @{ Size = $parsed; Methods = ($picked -join ',') }
    }
}

if ($Methods -eq '') {
    $settingsFile = Join-Path $env:LOCALAPPDATA 'ShrinkVideo\methods.txt'
    $saved = $DefaultMethods
    if (Test-Path -LiteralPath $settingsFile) {
        $line = Get-Content -LiteralPath $settingsFile -TotalCount 1
        if ($line) { $saved = ([string]$line).Trim() }
    }
    if ($Files.Count -eq 1) { $what = Split-Path -Leaf $Files[0] } else { $what = "$($Files.Count) videos" }
    if ($Ask) { $SizeMB = $DefaultMB }

    if ($env:SHRINK_VIDEO_NO_DIALOG) {   # for the automated test: accept the dialog's defaults
        $choice = @{ Size = $SizeMB; Methods = $saved }
    } else {
        $choice = Show-OptionsDialog $SizeMB $saved $what
    }
    if ($null -eq $choice) { exit 0 }
    $SizeMB = $choice.Size
    $Methods = $choice.Methods
    try {
        New-Item -ItemType Directory -Path (Split-Path -Parent $settingsFile) -Force | Out-Null
        Set-Content -LiteralPath $settingsFile -Value $Methods -Encoding ASCII
    } catch { }
}

if ($SizeMB -le 0) {
    Write-Host "Invalid size: $SizeMB" -ForegroundColor Red
    Stop-WithPause 2
}

$useResize = $false; $useFps = $false; $useSpeed = $false; $useCompress = $false
foreach ($m in ($Methods -split '[,\s]+')) {
    switch ($m.ToLowerInvariant()) {
        ''          { }
        'resize'    { $useResize = $true }
        'fps'       { $useFps = $true }
        'framerate' { $useFps = $true }
        'speed'     { $useSpeed = $true }
        'compress'  { $useCompress = $true }
        default {
            Write-Host "Unknown method '$m'. Use: resize, fps, speed, compress." -ForegroundColor Red
            Stop-WithPause 2
        }
    }
}
if (-not ($useResize -or $useFps -or $useSpeed -or $useCompress)) {
    Write-Host 'Select at least one way to shrink the video.' -ForegroundColor Red
    Stop-WithPause 2
}

$label = Format-Num $SizeMB
$limit = [long]($SizeMB * 1000000)

# --- Planner -----------------------------------------------------------------
# Model: a "good looking" encode needs about 4000 kb/s at 1080p30, scaling
# with pixels^0.75 and fps^0.5. Quality x is the bitrate we can afford divided
# by that (never aiming higher than the source's own quality). Every allowed
# method has a cost; the candidate with the best overall score wins. Without
# "compress", x must stay near 1 and the other methods have to do the work -
# if they cannot, compression is forced.

function Get-Needed([double]$short, [double]$fps, [double]$aspect) {
    return 4000.0 * [Math]::Pow($short * $short * $aspect / 2073600.0, 0.75) * [Math]::Sqrt($fps / 30.0)
}

function Get-FpsWeight([double]$x) { return $x / ($x + 8.0) }

function Get-Plan([double]$factor, [double]$dur, [int]$sw, [int]$sh, [double]$sfps, [double]$srcv, [bool]$audio) {
    $sshort = [Math]::Min($sw, $sh)
    $aspect = [Math]::Max($sw, $sh) / [double]$sshort
    $qt = [Math]::Min(1.0, $srcv / (Get-Needed $sshort $sfps $aspect))

    $shorts = @([double]$sshort)
    if ($useResize) { foreach ($c in 2160, 1440, 1080, 720, 540, 480, 360, 240) { if ($c -lt $sshort) { $shorts += [double]$c } } }
    $fpss = @($sfps)
    if ($useFps) { foreach ($d in 2, 3, 4) { if ($sfps / $d -ge 10) { $fpss += ($sfps / $d) } } }
    $speeds = @(1.0)
    if ($useSpeed) { $speeds += 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 4.0 }

    $best = $null; $bestScore = -1.0
    $bestOk = $null; $bestOkScore = -1.0
    foreach ($short in $shorts) {
        foreach ($fps in $fpss) {
            foreach ($s in $speeds) {
                $total = $limit * 8.0 / ($dur / $s) / 1000.0 * $factor
                $ak = 0
                if ($audio) {
                    if     ($total -ge 1500) { $ak = 128 }
                    elseif ($total -ge 700)  { $ak = 96 }
                    elseif ($total -ge 300)  { $ak = 64 }
                    else                     { $ak = 32 }
                }
                $v = $total - $ak
                if ($v -lt 40) { continue }
                $x = [Math]::Min(1.0, $v / (Get-Needed $short $fps $aspect) / $qt)
                $cost = [Math]::Sqrt($short / $sshort) * ((Get-FpsWeight $fps) / (Get-FpsWeight $sfps)) / [Math]::Sqrt($s)
                $score = $cost * 1.3 * $x / ($x + 0.3)
                $cand = @{ Short = [int]$short; Fps = $fps; Speed = $s
                           VKbps = [int][Math]::Floor([Math]::Min($v, $srcv)); AKbps = $ak; Forced = $false }
                if ($score -gt $bestScore) { $bestScore = $score; $best = $cand }
                if ($x -ge 0.85 -and ($cost + $x / 1000.0) -gt $bestOkScore) { $bestOkScore = $cost + $x / 1000.0; $bestOk = $cand }
            }
        }
    }
    if ($null -eq $best) { return $null }
    if ($useCompress) { return $best }
    if ($null -ne $bestOk) { return $bestOk }
    $best.Forced = $true
    return $best
}

# --- Encoding ----------------------------------------------------------------

function Invoke-Shrink([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Write-Host "Not a file: $path" -ForegroundColor Red
        return $false
    }
    $item = Get-Item -LiteralPath $path
    $in = $item.FullName
    $name = $item.Name
    Write-Host ''
    Write-Host "$name  ->  $label MB" -ForegroundColor Cyan

    if ($item.Length -le $limit) {
        Write-Host "Already under $label MB ($(Format-MB $item.Length)) - nothing to do." -ForegroundColor Green
        return $true
    }

    $durText = (& ffprobe -v error -show_entries format=duration -of csv=p=0 $in | Select-Object -First 1)
    $dur = 0.0
    if (-not [double]::TryParse([string]$durText, [Globalization.NumberStyles]::Float, $inv, [ref]$dur) -or $dur -le 0) {
        Write-Host 'Could not read the video duration (is this a video file?)' -ForegroundColor Red
        return $false
    }

    # Source picture properties.
    $props = @{}
    $info = & ffprobe -v error -select_streams v:0 -show_entries stream=width,height,avg_frame_rate,bit_rate -of default=nw=1 $in
    foreach ($line in $info) {
        if ([string]$line -match '^(\w+)=(.*)$') {
            if (-not $props.ContainsKey($matches[1])) { $props[$matches[1]] = $matches[2].Trim() }
        }
    }
    $sw = 0; $sh = 0
    if (-not [int]::TryParse([string]$props['width'], [ref]$sw) -or
        -not [int]::TryParse([string]$props['height'], [ref]$sh) -or $sw -lt 16 -or $sh -lt 16) {
        Write-Host 'No video stream found.' -ForegroundColor Red
        return $false
    }
    $sfps = 30.0
    $fr = ([string]$props['avg_frame_rate']) -split '/'
    $num = 0.0; $den = 1.0
    if ([double]::TryParse($fr[0], [Globalization.NumberStyles]::Float, $inv, [ref]$num)) {
        if ($fr.Count -gt 1) { [void][double]::TryParse($fr[1], [Globalization.NumberStyles]::Float, $inv, [ref]$den) }
        if ($den -gt 0 -and ($num / $den) -ge 1 -and ($num / $den) -le 240) { $sfps = $num / $den }
    }
    # Video bitrate: from the stream if known, otherwise the whole file's.
    $srcBits = 0.0
    if ([double]::TryParse([string]$props['bit_rate'], [Globalization.NumberStyles]::Float, $inv, [ref]$srcBits) -and $srcBits -gt 0) {
        $srcv = $srcBits / 1000.0
    } else {
        $srcv = $item.Length * 8.0 / $dur / 1000.0
    }

    $hasAudio = [bool](& ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 $in | Select-Object -First 1)

    $dir = $item.DirectoryName
    $stem = $item.BaseName
    $out = Join-Path $dir ($stem + '_' + $label + 'MB.mp4')
    $n = 2
    while (Test-Path -LiteralPath $out) {
        $out = Join-Path $dir ($stem + '_' + $label + 'MB_' + $n + '.mp4')
        $n++
    }
    $part = $out + '.part'
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('shrink-video-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    $passlog = Join-Path $tmp 'pass'
    $srcShort = [Math]::Min($sw, $sh)

    try {
        $factor = 0.97
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            $plan = Get-Plan $factor $dur $sw $sh $sfps $srcv $hasAudio
            if ($null -eq $plan) {
                Write-Host "This video is too long to fit in $label MB with the selected methods." -ForegroundColor Red
                return $false
            }
            $short = $plan.Short; $fps = $plan.Fps; $speed = $plan.Speed
            $vkbps = $plan.VKbps; $akbps = $plan.AKbps
            $fpsChanged = ($fps -lt $sfps - 0.01)

            $parts = @()
            if ($short -lt $srcShort) { $parts += "${srcShort}p -> ${short}p" }
            if ($fpsChanged) { $parts += "$(Format-Num $sfps) -> $(Format-Num $fps) fps" }
            if ($speed -ne 1) { $parts += "$(Format-Num $speed)x speed" }
            $parts += "video $vkbps kb/s"
            Write-Host ($parts -join ', ')
            if ($plan.Forced) {
                Write-Host 'The selected methods are not enough on their own, so it is also being compressed.' -ForegroundColor Yellow
            }

            # Video filters: speed, then framerate, then size (always forced to even dimensions).
            $vf = ''
            $af = ''
            if ($speed -ne 1) {
                $vf = "setpts=PTS/$(Format-Num $speed),"
                if ($speed -gt 2) { $af = "atempo=2,atempo=$(Format-Num ($speed / 2))" }
                else              { $af = "atempo=$(Format-Num $speed)" }
            }
            if ($speed -ne 1 -or $fpsChanged) { $vf += "fps=$(Format-Num $fps)," }
            $vf += "scale='if(gt(iw,ih),-2,trunc(min(iw,${short})/2)*2)':'if(gt(iw,ih),trunc(min(ih,${short})/2)*2,-2)'"

            $common = @('-hide_banner', '-loglevel', 'error', '-stats', '-nostdin', '-y',
                        '-i', $in, '-map', '0:v:0', '-c:v', 'libx264', '-preset', 'medium',
                        '-b:v', "${vkbps}k", '-pix_fmt', 'yuv420p', '-vf', $vf,
                        '-passlogfile', $passlog, '-sn', '-dn')

            if ($akbps -gt 0) {
                $audio = @('-map', '0:a:0', '-c:a', 'aac', '-b:a', "${akbps}k", '-ac', '2')
                if ($af -ne '') { $audio += @('-af', $af) }
            } else {
                $audio = @('-an')
            }

            # Pass 1 must use the same muxer as pass 2, or the frame counts can differ.
            Write-Host 'Pass 1 of 2 (analysing)'
            $a = $common + @('-pass', '1', '-an', '-f', 'mp4', 'NUL')
            & ffmpeg @a
            if ($LASTEXITCODE -ne 0) { Write-Host 'ffmpeg failed.' -ForegroundColor Red; return $false }

            Write-Host 'Pass 2 of 2 (encoding)'
            $a = $common + @('-pass', '2') + $audio + @('-movflags', '+faststart', '-f', 'mp4', $part)
            & ffmpeg @a
            if ($LASTEXITCODE -ne 0) { Write-Host 'ffmpeg failed.' -ForegroundColor Red; return $false }

            $outSize = (Get-Item -LiteralPath $part).Length
            if ($outSize -le $limit) {
                Move-Item -LiteralPath $part -Destination $out -Force
                Write-Host "Done: $(Format-MB $item.Length) -> $(Format-MB $outSize)" -ForegroundColor Green
                Write-Host "Saved as $(Split-Path -Leaf $out)"
                return $true
            }
            Write-Host "Result was $(Format-MB $outSize), slightly too big - trying again with a lower bitrate." -ForegroundColor Yellow
            $factor = $factor * $limit / $outSize * 0.98
        }
        Write-Host "Could not get under $label MB after 3 attempts." -ForegroundColor Red
        return $false
    }
    finally {
        Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$allOk = $true
foreach ($f in $Files) {
    if (-not (Invoke-Shrink $f)) { $allOk = $false }
}

if ($allOk) {
    Start-Sleep -Seconds 4
    exit 0
}
Stop-WithPause 1
