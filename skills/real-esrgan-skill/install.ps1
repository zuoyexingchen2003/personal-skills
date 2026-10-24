# Install real-esrgan-skill into %USERPROFILE%\.claude\skills\ (Claude Code user skills).
$ErrorActionPreference = "Stop"

$Src = $PSScriptRoot
$Dest = Join-Path $HOME ".claude\skills\real-esrgan-skill"

if (-not (Test-Path (Join-Path $Src "SKILL.md"))) {
    Write-Error "SKILL.md not found in $Src - run this from the repo root"
}

New-Item -ItemType Directory -Force -Path (Split-Path $Dest) | Out-Null
if (Test-Path $Dest) { Remove-Item -Recurse -Force $Dest }
New-Item -ItemType Directory -Force -Path (Join-Path $Dest "scripts") | Out-Null
Copy-Item (Join-Path $Src "SKILL.md") $Dest
Copy-Item (Join-Path $Src "scripts\*") (Join-Path $Dest "scripts")

Write-Host "[ok] installed to $Dest"
Write-Host "[next] restart your Claude Code session (or open a new one), then say:"
Write-Host '       帮我把 xxx.mp4 超分到 4 倍'
