# klad_art.ps1 - rebuild the Klad pixel sprites from their recipe files.
#
# WHY: each sprite is stored as a list of drawing steps (art/source/klad/<name>.ops.jsonl),
# not only as a PNG. Running this script replays those steps with the Klad drawing tool,
# so a sprite can be changed by editing one line of its recipe and running this again.
#
# USE:   .\tools\klad_art.ps1                  (rebuild every sprite)
#        .\tools\klad_art.ps1 scrapper sawbot  (rebuild only these)
#
# OUT:   art/sprites/<name>.png         64 x 64, the file the game loads
#        art/source/klad/<name>@8x.png  512 x 512, only for looking at
param([string[]]$Names)

$ErrorActionPreference = "Stop"

# Klad is not on PATH; it lives in the folder the cloud build was downloaded to.
$klad = "C:\Users\sphil\dev\klad-dist\klad-windows\klad.exe"
if (-not (Test-Path $klad)) { throw "klad.exe not found at $klad" }

$root    = Split-Path $PSScriptRoot -Parent           # the repo folder
$recipes = Join-Path $root "art\source\klad"          # recipes and working drawings
$sprites = Join-Path $root "art\sprites"              # what the game loads
New-Item -ItemType Directory -Force $sprites | Out-Null

# No names given: build every recipe except the shared palette file.
if (-not $Names) {
	$Names = Get-ChildItem $recipes -Filter "*.ops.jsonl" |
		Where-Object { $_.Name -ne "palette.ops.jsonl" } |
		ForEach-Object { $_.Name -replace "\.ops\.jsonl$", "" }
}

foreach ($name in $Names) {
	$bundle = Join-Path $recipes "$name.klad"         # Klad's working folder for one drawing
	$ops    = Join-Path $recipes "$name.ops.jsonl"
	# The floor tile is 48 px (one grid cell) and wraps at its edges; sprites are 64 px.
	$isTile = $name -like "floor*"

	# Start from an empty drawing every time, so old pixels never linger.
	if (Test-Path $bundle) { Remove-Item $bundle -Recurse -Force }
	if ($isTile) { & $klad new $bundle --pixel 48x48 --wrap | Out-Null }
	else         { & $klad new $bundle --pixel 64x64 | Out-Null }

	# Step 1: name the 12 shared colours. Step 2: replay the drawing steps.
	Get-Content (Join-Path $recipes "palette.ops.jsonl") | & $klad apply $bundle | Out-Null
	Get-Content $ops | & $klad apply $bundle | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "klad apply failed for $name" }

	# Export at real size for the game and at 8x for human eyes.
	& $klad export $bundle --scale 1 -o (Join-Path $sprites "$name.png") | Out-Null
	& $klad export $bundle --scale 8 -o (Join-Path $recipes "$name@8x.png") | Out-Null

	# klad check lists pixel-art slips (stray pixels, doubled corners). Shown, not fatal.
	Write-Host "== $name"
	& $klad check $bundle
}
