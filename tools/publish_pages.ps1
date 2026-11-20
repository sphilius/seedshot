# publish_pages.ps1 - put the web build on GitHub Pages, so the game plays from a link.
#
# WHY: GitHub Pages serves the files of one branch as a website. This script copies the
# exported web build (build/web) onto the `gh-pages` branch and pushes it. The game's code
# stays on main; gh-pages only ever holds the built files, one commit per publish.
#
# USE:   .\tools\publish_pages.ps1            (publish the build already in build/web)
#        .\tools\publish_pages.ps1 -Export    (export a fresh build first)
#        .\tools\publish_pages.ps1 -BuildDir C:\path\to\web   (publish a build from elsewhere)
#
# OUT:   https://sphilius.github.io/seedshot/  (a minute or two after the push)
#
# HOW:   gh-pages lives in its own folder next to the repo (..\seedshot-pages), a "git
#        worktree": a second checkout of the same repository, so this never switches the
#        branch of the folder you are working in.
param(
	[switch]$Export,
	[string]$BuildDir
)

$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent                 # the repo folder
if (-not $BuildDir) { $BuildDir = Join-Path $root "build\web" }
$pages = Join-Path (Split-Path $root -Parent) "seedshot-pages"   # the gh-pages checkout

if ($Export) { & (Join-Path $PSScriptRoot "godot.ps1") export }
if (-not (Test-Path (Join-Path $BuildDir "index.html"))) { throw "No web build in $BuildDir. Run with -Export." }

# 1. Make sure the gh-pages checkout exists.
if (-not (Test-Path $pages)) {
	git -C $root fetch origin gh-pages 2>$null
	if ($LASTEXITCODE -eq 0) {
		# The branch is already on GitHub: check it out into its own folder.
		git -C $root worktree add $pages gh-pages
	} else {
		# First publish ever: an "orphan" branch shares no history with main.
		git -C $root worktree add --detach $pages
		git -C $pages switch --orphan gh-pages
	}
}
git -C $pages pull --ff-only origin gh-pages 2>$null   # pick up the last publish, if any

# 2. Replace everything on the branch with the new build. (.git is a file in a
#    worktree; it is kept so the folder stays a checkout.)
Get-ChildItem $pages -Force | Where-Object { $_.Name -ne ".git" } | Remove-Item -Recurse -Force
Copy-Item (Join-Path $BuildDir "*") $pages -Recurse
# .nojekyll tells GitHub to serve the files as they are, without its Jekyll site builder.
New-Item -ItemType File (Join-Path $pages ".nojekyll") | Out-Null

# 3. Commit and push, labelled with the main commit the build came from.
$commit = git -C $root rev-parse --short HEAD
git -C $pages add --all
git -C $pages commit -m "Web build of $commit" | Out-Null
git -C $pages push origin gh-pages
Write-Host "Published build of $commit. Live at https://sphilius.github.io/seedshot/ in a minute or two."
