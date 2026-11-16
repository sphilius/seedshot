# gen_sfx.ps1 - generate the game's sound effects with ElevenLabs Sound Effects.
#
# WHY: audio/SOUNDS.md is the single list of sounds (file name, duration, prompt).
# This script reads that table and asks ElevenLabs for each sound, so the list and
# the generated files can never drift apart.
#
# USE:   .\tools\gen_sfx.ps1                    (every sound, 2 takes each)
#        .\tools\gen_sfx.ps1 -Names fire,cat    (only these)
#        .\tools\gen_sfx.ps1 -Takes 3           (more takes to choose from)
#
# OUT:   audio/sfx/candidates/<name>_take1.mp3, <name>_take2.mp3, ...
#        Candidates are NOT loaded by the game. Copy the chosen take to
#        audio/sfx/<name>.mp3 to put it in the game.
#
# KEY:   reads the ELEVENLABS_API_KEY user environment variable. The key is never
#        printed or written to a file. Each request spends ElevenLabs credits.
param(
	[string[]]$Names,
	[int]$Takes = 2,
	[switch]$Force    # regenerate takes that already exist
)

$ErrorActionPreference = "Stop"

if (-not $env:ELEVENLABS_API_KEY) { throw "ELEVENLABS_API_KEY is not set." }

$root = Split-Path $PSScriptRoot -Parent
$list = Join-Path $root "audio\SOUNDS.md"
$out  = Join-Path $root "audio\sfx\candidates"
New-Item -ItemType Directory -Force $out | Out-Null

# Read the table rows of SOUNDS.md. A row looks like:
# | 1 | `fire.mp3` | Plays when | 0.5 s | `the prompt` |
# The regex captures: file name (no extension), duration in seconds, prompt text.
$rowPattern = '^\|\s*\d+\s*\|\s*`([a-z_]+)\.mp3`\s*\|[^|]*\|\s*([\d.]+)\s*s\s*\|\s*`([^`]+)`\s*\|'
$sounds = foreach ($line in Get-Content $list) {
	if ($line -match $rowPattern) {
		[pscustomobject]@{ Name = $Matches[1]; Seconds = [double]$Matches[2]; Prompt = $Matches[3] }
	}
}
if ($Names) { $sounds = $sounds | Where-Object { $Names -contains $_.Name } }
if (-not $sounds) { throw "No matching sounds found in $list." }

$headers = @{ "xi-api-key" = $env:ELEVENLABS_API_KEY }

foreach ($sound in $sounds) {
	for ($take = 1; $take -le $Takes; $take++) {
		$file = Join-Path $out ("{0}_take{1}.mp3" -f $sound.Name, $take)
		if ((Test-Path $file) -and -not $Force) { Write-Host "skip  $($sound.Name) take $take (exists)"; continue }

		# The request body. prompt_influence 0.7 = stick closely to the words.
		$body = @{
			text             = $sound.Prompt
			duration_seconds = $sound.Seconds
			prompt_influence = 0.7
		} | ConvertTo-Json

		# The reply is the MP3 itself, so it is saved straight to the file.
		Invoke-WebRequest -Uri "https://api.elevenlabs.io/v1/sound-generation" -Method Post `
			-Headers $headers -ContentType "application/json" -Body $body -OutFile $file -TimeoutSec 120
		Write-Host ("made  {0} take {1}  ({2:N0} KB)" -f $sound.Name, $take, ((Get-Item $file).Length / 1KB))
	}
}
