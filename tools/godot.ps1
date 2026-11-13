# godot.ps1 - run the right Godot build against this project from PowerShell.
#
# WHY THIS EXISTS: the `godot` on PATH is the 4.6 mono (.NET) build, which hangs in
# --headless mode. Seedshot is plain GDScript on Godot 4.7, so we call the 4.7.2
# non-mono console build directly.
#
# USAGE (from the seedshot folder):
#   .\tools\godot.ps1 import     # rebuild the import cache (.godot/) - do this first on a fresh clone
#   .\tools\godot.ps1 test       # run the headless checks; exit code 1 on failure
#   .\tools\godot.ps1 export     # export the web build to build\web\index.html
#   .\tools\godot.ps1 editor     # open the project in the Godot editor
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("import", "test", "export", "editor")]
    [string]$Task
)

$packageDir = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
$console = Join-Path $packageDir "Godot_v4.7.2-stable_win64_console.exe"
$editor = Join-Path $packageDir "Godot_v4.7.2-stable_win64.exe"
# $PSScriptRoot is the folder this script lives in (tools\); the project is one level up.
$project = Split-Path $PSScriptRoot -Parent

switch ($Task) {
    "import" { & $console --headless --path $project --import }
    "test"   { & $console --headless --path $project "res://tests/check.tscn" }
    "export" {
        New-Item -ItemType Directory -Force (Join-Path $project "build\web") | Out-Null
        & $console --headless --path $project --export-release "Web" "build/web/index.html"
    }
    "editor" { & $editor --path $project --editor }
}
# Pass Godot's exit code back to whoever called this script.
exit $LASTEXITCODE
