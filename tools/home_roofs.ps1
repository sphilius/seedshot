# home_roofs.ps1 - build the roofs of the block's homes from the concept homes strip.
#
# WHY: the concept picture art/concept/03_wall_and_homes/03_wall_and_homes_b.png shows six
# homes seen from above (water tank, satellite dish, potted plants, washing line...). The game
# draws each home as a roof on top and a front wall with windows below it. This script cuts
# the six roofs out of the concept and shrinks each one with Klad's `pixelize`, which also
# snaps every pixel to the game's palette.
#
# Only the ROOFS come from the concept. The front wall and its windows are drawn by the game
# (scripts/block_windows.gd), because each window has to light up on its own.
#
# USE:   .\tools\home_roofs.ps1
#
# OUT:   art/sprites/home_roofs.png          6 roof units side by side, 52 x 32 each
#        art/source/klad/home_roofs@8x.png   the same at 8x, only for looking at
#
# The game packs one roof unit over each of the block's 24 windows, edge to edge along
# the bottom wall (24 x 52 = 1248 px, the arena's width). A home is 2 or 3 units side by
# side. The width here MUST match block_windows.gd; tests/check.gd checks that it does.
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
# NOTE: PowerShell variable names ignore case: $W and $w would be the same variable.

$klad    = "C:\Users\sphil\dev\klad-dist\klad-windows\klad.exe"
$root    = Split-Path $PSScriptRoot -Parent
$concept = Join-Path $root "art\concept\03_wall_and_homes\03_wall_and_homes_b.png"
$work    = Join-Path $env:TEMP "seedshot_home_roofs"
$palette = Join-Path $root "art\source\klad\palette.ops.jsonl"
$floorPalette = Join-Path $root "art\source\klad\floor_palette.ops.jsonl"   # the two extra steel steps
New-Item -ItemType Directory -Force $work | Out-Null

$ROOF_H = 32                                   # roof height in the game, in pixels
$BRIGHTEN = 1.9                                # colour multiplier applied before shrinking (1 = unchanged)
$sizes  = @(@{ label = "units"; width = 52 })   # one roof unit sits over each window
# Left edge of each of the six concept homes (measured), and the concept roof's top and
# bottom rows. The roofs run from y 67 to y 192; below that is the concept's front wall.
$homeLefts = @(156, 272, 396, 504, 619, 736)
$CONCEPT_HOME_W = 115
$ROOF_TOP = 67; $ROOF_BOTTOM = 192
$conceptRight = 851                            # right edge of the last home

$sheetImg = [System.Drawing.Bitmap]::FromFile($concept)
foreach ($size in $sizes) {
	$strip = [System.Drawing.Bitmap]::new($size.width * $homeLefts.Count, $ROOF_H)
	$g = [System.Drawing.Graphics]::FromImage($strip)
	for ($i = 0; $i -lt $homeLefts.Count; $i++) {
		# The cut has the same shape (width : height) as the roof unit in the game,
		# so nothing is squashed.
		$cutW = $CONCEPT_HOME_W
		$cutH = [int][math]::Round($cutW * $ROOF_H / $size.width)
		$left = [math]::Min($homeLefts[$i], $conceptRight - $cutW)
		# Cut from the roof's top edge, so the tanks, dishes and plants up there are kept.
		$top = $ROOF_TOP
		# Copy the cut through a brightening filter. The concept's "dark" roofs are almost
		# black, and would all snap to the outline colour; brighter, they land on the steel
		# greys. The game's night tint darkens them again on screen.
		$cut = [System.Drawing.Bitmap]::new($cutW, $cutH)
		$cg = [System.Drawing.Graphics]::FromImage($cut)
		$matrix = [System.Drawing.Imaging.ColorMatrix]::new()
		$matrix.Matrix00 = $BRIGHTEN; $matrix.Matrix11 = $BRIGHTEN; $matrix.Matrix22 = $BRIGHTEN
		$attrs = [System.Drawing.Imaging.ImageAttributes]::new(); $attrs.SetColorMatrix($matrix)
		$cg.DrawImage($sheetImg, [System.Drawing.Rectangle]::new(0, 0, $cutW, $cutH), $left, $top, $cutW, $cutH, [System.Drawing.GraphicsUnit]::Pixel, $attrs)
		$cg.Dispose()
		$cutPath = Join-Path $work "$($size.label)_$i.png"
		$cut.Save($cutPath, [System.Drawing.Imaging.ImageFormat]::Png); $cut.Dispose()

		$bundle = Join-Path $work "$($size.label)_$i.klad"
		if (Test-Path $bundle) { Remove-Item $bundle -Recurse -Force }
		& $klad new $bundle --pixel "$($size.width)x$($ROOF_H)" | Out-Null
		Get-Content $palette | & $klad apply $bundle | Out-Null
		Get-Content $floorPalette | & $klad apply $bundle | Out-Null
		# --size is the longest side, so the width sets the scale.
		& $klad pixelize $bundle --image $cutPath --to l1 --size $size.width | Out-Null
		if ($LASTEXITCODE -ne 0) { throw "klad pixelize failed for $($size.label) $i" }
		$roofPath = Join-Path $work "$($size.label)_$($i)_out.png"
		& $klad export $bundle --scale 1 -o $roofPath | Out-Null

		$roofImg = [System.Drawing.Image]::FromFile($roofPath)
		$g.DrawImage($roofImg, ($i * $size.width), 0, $size.width, $ROOF_H); $roofImg.Dispose()
	}
	$g.Dispose()
	$strip.Save((Join-Path $root "art\sprites\home_roofs.png"), [System.Drawing.Imaging.ImageFormat]::Png)
	$strip.Dispose()
}
$sheetImg.Dispose()

# Both rows at 8x, one above the other, for checking by eye.
$rows = $sizes | ForEach-Object { [System.Drawing.Bitmap]::FromFile((Join-Path $root "art\sprites\home_roofs.png")) }
$rows = @($rows)
$bigW = [int]$rows[0].Width * 8
$big = [System.Drawing.Bitmap]::new($bigW, $ROOF_H * 8 * $rows.Count + 8)
$bg = [System.Drawing.Graphics]::FromImage($big)
$bg.InterpolationMode = "NearestNeighbor"; $bg.PixelOffsetMode = "Half"
for ($r = 0; $r -lt $rows.Count; $r++) {
	$bg.DrawImage($rows[$r], 0, ($r * ($ROOF_H * 8 + 8)), $rows[$r].Width * 8, $ROOF_H * 8)
	$rows[$r].Dispose()
}
$big.Save((Join-Path $root "art\source\klad\home_roofs@8x.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$bg.Dispose(); $big.Dispose()
Write-Host "home roofs built"
