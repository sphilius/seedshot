# floor_tiles.ps1 - build the game's floor tiles from the concept floor sheet.
#
# WHY: the concept sheet (art/concept/02_floor_sheet/02_floor_sheet_final.png) is a 2048 x 2048
# picture of 16 floor slabs, each 512 px. The game needs each slab at 48 x 48 (one grid cell),
# in the game's own 12-colour palette. Klad's `pixelize` does exactly that: it shrinks a
# picture (each new pixel is the average of the area it covers) and snaps every pixel to the
# nearest palette colour, so the tiles match the sprites already in the game.
#
# USE:   .\tools\floor_tiles.ps1
#
# OUT:   art/sprites/floor_tiles.png              one row of 48 x 48 tiles, the file the game loads
#        art/source/klad/floor_tiles@8x.png       the same row at 8x, only for looking at
#
# ORDER MATTERS: the game treats the first `floor_plain_count` tiles (see game_config.gd) as
# plain slabs that fill most of the floor, and the rest as rarer "detail" slabs.
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$klad  = "C:\Users\sphil\dev\klad-dist\klad-windows\klad.exe"
$root  = Split-Path $PSScriptRoot -Parent
$sheet = Join-Path $root "art\concept\02_floor_sheet\02_floor_sheet_final.png"
$work  = Join-Path $env:TEMP "seedshot_floor_tiles"     # throwaway crops and bundles
$palette = Join-Path $root "art\source\klad\palette.ops.jsonl"
$floorPalette = Join-Path $root "art\source\klad\floor_palette.ops.jsonl"
New-Item -ItemType Directory -Force $work | Out-Null

# Which slabs to take, as [column, row] on the 4 x 4 concept sheet (0 = first).
# The yellow line, the cable and the lit row are left out: they only make sense when they
# line up with their neighbours. The soil patch is kept back for the tap points.
$picks = @(
	@{ name = "plain_1"; col = 0; row = 0 },
	@{ name = "plain_2"; col = 1; row = 0 },
	@{ name = "plain_3"; col = 2; row = 0 },
	@{ name = "crater";  col = 3; row = 0 },   # starburst crack: too eye-catching to be plain
	@{ name = "moss";    col = 0; row = 1 },
	@{ name = "puddle";  col = 1; row = 1 },
	@{ name = "oil";     col = 2; row = 1 },
	@{ name = "grate";   col = 0; row = 2 },
	@{ name = "hatch";   col = 1; row = 2 }
)
$TILE = 48          # game size of one slab
$SLAB = 512         # concept size of one slab. (the dark gap is split between neighbours)
# NOTE: PowerShell variable names ignore case, so $TILE and $tile would be the SAME variable.

$sheetImg = [System.Drawing.Bitmap]::FromFile($sheet)
$strip = [System.Drawing.Bitmap]::new($TILE * $picks.Count, $TILE)
$g = [System.Drawing.Graphics]::FromImage($strip)

for ($i = 0; $i -lt $picks.Count; $i++) {
	$p = $picks[$i]
	# 1. Cut one slab out of the concept sheet.
	$crop = $sheetImg.Clone([System.Drawing.Rectangle]::new($p.col * $SLAB, $p.row * $SLAB, $SLAB, $SLAB), $sheetImg.PixelFormat)
	$cropPath = Join-Path $work "$($p.name).png"
	$crop.Save($cropPath, [System.Drawing.Imaging.ImageFormat]::Png); $crop.Dispose()

	# 2. New 48 x 48 Klad drawing with the shared palette, then shrink the slab onto it.
	$bundle = Join-Path $work "$($p.name).klad"
	if (Test-Path $bundle) { Remove-Item $bundle -Recurse -Force }
	& $klad new $bundle --pixel "$($TILE)x$($TILE)" --wrap | Out-Null
	Get-Content $palette | & $klad apply $bundle | Out-Null
	# Two extra steel steps for the floor only (a lighter edge and a darker stain). Without
	# them the slab's light bevel snaps to teal, the nearest of the 12 shared colours.
	Get-Content $floorPalette | & $klad apply $bundle | Out-Null
	& $klad pixelize $bundle --image $cropPath --to l1 --size $TILE | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "klad pixelize failed for $($p.name)" }
	$tilePath = Join-Path $work "$($p.name)_48.png"
	& $klad export $bundle --scale 1 -o $tilePath | Out-Null

	# 3. Paste it into its place in the row.
	$tileImg = [System.Drawing.Image]::FromFile($tilePath)
	$g.DrawImage($tileImg, ($i * $TILE), 0, $TILE, $TILE); $tileImg.Dispose()
}
$sheetImg.Dispose(); $g.Dispose()
$strip.Save((Join-Path $root "art\sprites\floor_tiles.png"), [System.Drawing.Imaging.ImageFormat]::Png)

# An 8x copy with hard pixel edges, for checking by eye.
$big = [System.Drawing.Bitmap]::new($strip.Width * 8, $strip.Height * 8)
$bg = [System.Drawing.Graphics]::FromImage($big)
$bg.InterpolationMode = "NearestNeighbor"; $bg.PixelOffsetMode = "Half"
$bg.DrawImage($strip, 0, 0, $big.Width, $big.Height)
$big.Save((Join-Path $root "art\source\klad\floor_tiles@8x.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$bg.Dispose(); $big.Dispose(); $strip.Dispose()
Write-Host "floor_tiles.png: $($picks.Count) tiles"
