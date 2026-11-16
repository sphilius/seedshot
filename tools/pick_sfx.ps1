# pick_sfx.ps1 - put a chosen take into the game, at an even loudness.
#
# WHY: ElevenLabs returns each take at whatever loudness it likes; some came back
# almost silent, others at full blast. This script copies the chosen take to
# audio/sfx/<name>.mp3 and turns it up or down so its AVERAGE loudness matches a
# target, with a limiter so the loudest instant never clips.
#
# USE:   .\tools\pick_sfx.ps1 fire=1 thunk=3 cat=2     (sound=take, as many as you like)
#
# Needs ffmpeg on PATH (installed with winget).
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Picks)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$candidates = Join-Path $root "audio\sfx\candidates"
$sfx = Join-Path $root "audio\sfx"

# Target average loudness in dB (closer to 0 = louder). Sounds heard many times a
# second sit lower so they do not tire the ear; rare, important ones sit higher.
$targets = @{
	fire = -27; saw = -25; thunk = -25; spit = -23; zip = -23; grow = -23
	windup = -20; hurt = -19; bind = -22; enemy_down = -21; unlock = -24
	player_down = -20; wave_clear = -20; cat = -19
}

foreach ($pick in $Picks) {
	$name, $take = $pick -split "="
	$source = Join-Path $candidates "${name}_take$take.mp3"
	if (-not (Test-Path $source)) { throw "No such take: $source" }

	# Pass 1: measure. volumedetect prints the take's mean (average) volume.
	$report = ffmpeg -hide_banner -i $source -af volumedetect -f null NUL 2>&1
	$mean = [double](($report | Select-String 'mean_volume: (\S+)').Matches.Groups[1].Value)

	# Pass 2: change the volume by the gap to the target, then limit peaks to
	# 0.89 (about -1 dB) so a big boost cannot clip.
	$target = if ($targets.ContainsKey($name)) { $targets[$name] } else { -21 }
	$gain = $target - $mean
	$dest = Join-Path $sfx "$name.mp3"
	ffmpeg -hide_banner -loglevel error -y -i $source -af "volume=${gain}dB,alimiter=limit=0.89" -b:a 128k $dest
	Write-Host ("{0,-12} take {1}  mean {2,6:N1} -> {3} dB  (gain {4:+0.0;-0.0})" -f $name, $take, $mean, $target, $gain)
}
