# gen_music.ps1 - generate the Canopy FM songs with the ElevenLabs music API.
#
# WHY: Canopy FM is the block's pirate radio (STORY.md, story step 4). One song plays at a time,
# muffled at first and opening up as the block gets its light back. Three stations exist; the
# player picks one in New Game + (unlocked by finishing the game once).
#
# USE:   .\tools\gen_music.ps1                 (make every station that has no file yet)
#        .\tools\gen_music.ps1 lofi -Force     (remake one station)
#        .\tools\gen_music.ps1 -Names dub,chip (several: name the -Names parameter, comma between)
#
# NEEDS: the ELEVENLABS_API_KEY environment variable. It is read here and sent only to
#        ElevenLabs; it is never printed or written to a file.
#
# OUT:   audio/music/<station>.mp3
param(
	[string[]]$Names,
	[int]$Seconds = 90,
	[switch]$Force    # remake stations that already have a file
)
$ErrorActionPreference = "Stop"
if (-not $env:ELEVENLABS_API_KEY) { throw "ELEVENLABS_API_KEY is not set." }

$root = Split-Path $PSScriptRoot -Parent
$out  = Join-Path $root "audio\music"
New-Item -ItemType Directory -Force $out | Out-Null

# One prompt per station. "Seamless loop" and "no vocals" matter: the song repeats under play.
$stations = [ordered]@{
	lofi = "Lo-fi hip hop instrumental for a game. Warm dusty vinyl crackle, mellow Rhodes piano chords, " +
	       "soft boom-bap drums at 78 BPM, round warm bass, a little tape wobble. Hopeful and slightly scrappy, " +
	       "like a pirate radio station broadcasting from a rooftop garden at night. Steady energy, no build-up, " +
	       "seamless loop, no vocals."
	dub  = "Roots dub reggae instrumental for a game. Deep round bassline, offbeat skank guitar, spring reverb " +
	       "and tape echo throws, a melodica melody, one-drop drums at 72 BPM. Rebellious but warm, like a pirate " +
	       "radio station in a neighbourhood that powers itself. Steady energy, seamless loop, no vocals."
	chip = "Hopeful chiptune instrumental for a pixel art game. Bright square-wave lead melody, bubbly arpeggios, " +
	       "warm triangle bass, crisp noise drums at 110 BPM, with a soft analog synth pad underneath. " +
	       "Optimistic solarpunk mood, a city switching its lights back on. Steady energy, seamless loop, no vocals."
	trap = "Lo-fi drill trap instrumental for a game. Sliding 808 bass glides, skittering triplet hi-hat rolls, " +
	       "syncopated drill snares at 142 BPM (half-time feel), a dark but warm detuned piano and vinyl-dusted pad " +
	       "loop, a little tape saturation. Gritty and determined, a block standing its ground at night, still mellow " +
	       "enough to sit under gameplay. Steady energy, no drops, seamless loop, no vocals."
}
# @(...) copies the key list first: removing from a list while walking it is an error.
if ($Names) { @($stations.Keys) | Where-Object { $Names -notcontains $_ } | ForEach-Object { $stations.Remove($_) } }

$headers = @{ "xi-api-key" = $env:ELEVENLABS_API_KEY }
foreach ($name in @($stations.Keys)) {
	$file = Join-Path $out "$name.mp3"
	if ((Test-Path $file) -and -not $Force) { Write-Host "skip  $name (exists)"; continue }
	$body = @{ prompt = $stations[$name]; music_length_ms = $Seconds * 1000 } | ConvertTo-Json
	# Songs take a while to make, hence the long timeout.
	Invoke-WebRequest -Uri "https://api.elevenlabs.io/v1/music" -Method Post -Headers $headers `
		-ContentType "application/json" -Body $body -OutFile $file -TimeoutSec 300
	Write-Host ("made  {0}  ({1:N0} KB)" -f $name, ((Get-Item $file).Length / 1KB))
}
