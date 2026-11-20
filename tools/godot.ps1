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
    "test"   {
        # A test scene whose script fails to compile never reaches its quit() call and
        # would hang forever, so run it with a 4-minute safety limit. (The checks
        # themselves take about 100 seconds since s18.)
        $log = Join-Path $env:TEMP "seedshot_test.log"
        $proc = Start-Process -FilePath $console -NoNewWindow -PassThru `
            -ArgumentList "--headless", "--path", "`"$project`"", "res://tests/check.tscn" `
            -RedirectStandardOutput $log -RedirectStandardError "$log.err"
        $null = $proc.Handle  # keeps the handle open so ExitCode is readable afterwards
        if (-not $proc.WaitForExit(240000)) {
            # The console exe is only a launcher; kill it and the Godot process it started.
            Get-CimInstance Win32_Process -Filter "ParentProcessId = $($proc.Id)" |
                ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
            Stop-Process -Id $proc.Id -Force
            Get-Content $log, "$log.err"
            Write-Host "TIMEOUT: tests did not finish in 240 s (usually a script compile error above)."
            exit 2
        }
        Get-Content $log, "$log.err"
        exit $proc.ExitCode
    }
    "export" {
        New-Item -ItemType Directory -Force (Join-Path $project "build\web") | Out-Null
        & $console --headless --path $project --export-release "Web" "build/web/index.html"
        $exportCode = $LASTEXITCODE
        # THE INTRO CLIP: Godot's export only writes its own files, so the clip and
        # the small style and script that play it over the loading screen are
        # copied in afterwards. (The page asks for them through the Web preset's
        # "head include" in export_presets.cfg. If they are missing the game
        # still loads; it just shows the plain loading bar.)
        Copy-Item (Join-Path $project "web\intro.mp4"), (Join-Path $project "web\intro.css"), (Join-Path $project "web\intro.js") -Destination (Join-Path $project "build\web") -Force
        exit $exportCode
    }
    "editor" { & $editor --path $project --editor }
}
# Pass Godot's exit code back to whoever called this script.
exit $LASTEXITCODE
