# make_trailer.ps1 - cuts a short trailer out of a gameplay recording with ffmpeg.
#
# Usage (from the seedshot folder):
#   .\tools\make_trailer.ps1
#   .\tools\make_trailer.ps1 -Source "playthrough recording\other.mp4" -Out "trailer\other.mp4"
#
# WHAT IT DOES
#   1. Cuts each entry of $shots (start second, length, caption) out of the
#      recording, fades it in and out, and writes its caption across the bottom
#      in the game's own marker font.
#   2. Makes an end card from one still frame of the title screen, with the
#      "play it here" line.
#   3. Joins the pieces and lays one of the game's own songs under them. The
#      recording's own sound is dropped: cut-up game audio sounds choppy.
#
# The recording is only READ. Everything is written to the output folder.
# To change the trailer, edit the $shots list: the times are seconds into the
# recording (open it in a video player to find them).

param(
    [string]$Source = "playthrough recording\normal-mode-playthrough.mp4",
    [string]$Out = "trailer\seedshot_trailer.mp4",
    [string]$Music = "audio\music\lofi.mp3",
    [string]$Url = "kingriot.itch.io/seedshot"
)

$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $PSScriptRoot
Set-Location $project

# Each shot: where it starts in the recording, how long it runs, and its caption.
# An empty caption means "no words over this shot".
$shots = @(
    @{ Start = 2.2;   Length = 9.3; Text = "" },                              # the intro clip
    @{ Start = 15.0;  Length = 4.5; Text = "SHOOT THE MACHINES" },
    @{ Start = 40.5;  Length = 4.5; Text = "EVERY ONE GROWS INTO A TREE" },
    @{ Start = 62.5;  Length = 5.0; Text = "ZIP THROUGH YOUR FOREST" },
    @{ Start = 90.0;  Length = 4.5; Text = "GUARD THE HEART TREE" },
    @{ Start = 146.5; Length = 3.0; Text = "PICK YOUR UPGRADES" },
    @{ Start = 150.5; Length = 5.0; Text = "LIGHT UP THE BLOCK" },
    @{ Start = 157.0; Length = 6.5; Text = "SURVIVE THE HEAVIES" }
)
# The end card: a still taken at this second (the title screen), held this long.
$endCardAt = 12.8
$endCardSeconds = 4.5
$fade = 0.25  # seconds each shot takes to fade in and to fade out

$outFolder = Split-Path -Parent (Join-Path $project $Out)
$work = Join-Path $outFolder "_parts"
New-Item -ItemType Directory -Force $work | Out-Null
# ffmpeg's text filter trips over the ":" in "C:\...", so the font is copied
# next to the parts and named without a path. ffmpeg is then run from there.
Copy-Item (Join-Path $project "art\fonts\PermanentMarker-Regular.ttf") (Join-Path $work "font.ttf") -Force
$sourcePath = (Resolve-Path $Source).Path
$musicPath = (Resolve-Path $Music).Path
Push-Location $work

# The caption: big pale-amber letters with a black edge, centred near the bottom,
# on a dark see-through band (box=1) so it covers any game text underneath it.
function Get-Caption([string]$text, [int]$size, [string]$y) {
    if ($text -eq "") { return "" }
    return ",drawtext=fontfile=font.ttf:text='$text':fontsize=${size}:fontcolor=0xFFD180:borderw=6:bordercolor=black:box=1:boxcolor=black@0.72:boxborderw=26:x=(w-text_w)/2:y=$y"
}

$list = @()
for ($i = 0; $i -lt $shots.Count; $i++) {
    $shot = $shots[$i]
    $fadeOutAt = $shot.Length - $fade
    # scale + fps make every piece the same shape, so they can be joined.
    $filter = "scale=1920:1080,fps=60,fade=t=in:st=0:d=$fade,fade=t=out:st=${fadeOutAt}:d=$fade" + (Get-Caption $shot.Text 92 "h-190")
    $part = "part_$i.mp4"
    ffmpeg -v error -y -ss $shot.Start -t $shot.Length -i $sourcePath -an -vf $filter -c:v libx264 -crf 17 -preset fast -pix_fmt yuv420p $part
    if ($LASTEXITCODE -ne 0) { Pop-Location; throw "ffmpeg failed on shot $i" }
    $list += "file '$part'"
}

# The end card: one frame, held, darkened a little so the words stand out.
ffmpeg -v error -y -ss $endCardAt -i $sourcePath -frames:v 1 endcard.png
$endFadeOutAt = $endCardSeconds - 0.6
$endFilter = "scale=1920:1080,fps=60,eq=brightness=-0.12,fade=t=in:st=0:d=$fade,fade=t=out:st=${endFadeOutAt}:d=0.6" +
    (Get-Caption "PLAY FREE IN YOUR BROWSER" 84 "h-300") + (Get-Caption $Url 64 "h-180")
ffmpeg -v error -y -loop 1 -t $endCardSeconds -i endcard.png -vf $endFilter -c:v libx264 -crf 17 -preset fast -pix_fmt yuv420p -r 60 part_end.mp4
if ($LASTEXITCODE -ne 0) { Pop-Location; throw "ffmpeg failed on the end card" }
$list += "file 'part_end.mp4'"
Set-Content -Path "parts.txt" -Value $list -Encoding ascii

# Join the pieces (no re-encode: they are all the same shape), then add the song,
# faded in at the start and out over the last two seconds.
ffmpeg -v error -y -f concat -safe 0 -i parts.txt -c copy joined.mp4
$total = [double](ffprobe -v error -show_entries format=duration -of csv=p=0 joined.mp4)
$musicFadeAt = $total - 2.0
$final = Join-Path $project $Out
ffmpeg -v error -y -i joined.mp4 -i $musicPath -filter_complex "[1:a]atrim=0:$total,afade=t=in:st=0:d=0.5,afade=t=out:st=${musicFadeAt}:d=2,loudnorm=I=-16:TP=-1.5[a]" -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 192k -movflags +faststart -shortest $final
Pop-Location
if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed on the final join" }
Write-Host ("Trailer written: {0}  ({1:N1} s)" -f $final, $total)
