param([string]$SkillsRoot,[switch]$Update)
$ErrorActionPreference = 'Stop'
if (-not $SkillsRoot) {
    $codexRoot = $env:CODEX_HOME
    if (-not $codexRoot) { $codexRoot = Join-Path $env:USERPROFILE '.codex' }
    $SkillsRoot = Join-Path $codexRoot 'skills'
}
$skillsDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SkillsRoot).TrimEnd('\')
$sourceDirectory = Join-Path (Split-Path $PSScriptRoot) 'skills'
New-Item -ItemType Directory -Force -Path $skillsDirectory | Out-Null
$result = @(foreach ($name in @('imagegen','real-esrgan-skill','change-wallpaper')) {
    $source = Join-Path $sourceDirectory $name
    if (-not (Test-Path -LiteralPath (Join-Path $source 'SKILL.md'))) { throw "Incomplete package: $name" }
    $target = [IO.Path]::GetFullPath((Join-Path $skillsDirectory $name))
    if ($name -eq 'imagegen' -and (Test-Path -LiteralPath (Join-Path $skillsDirectory '.system\imagegen\SKILL.md'))) {
        [PSCustomObject]@{Skill=$name;Status='Using existing built-in imagegen';Path=(Join-Path $skillsDirectory '.system\imagegen')};continue
    }
    if (Test-Path -LiteralPath $target) {
        if (-not $Update) { [PSCustomObject]@{Skill=$name;Status='Already exists; use -Update to back up and replace';Path=$target};continue }
        if ((Get-Item -LiteralPath $target).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Refusing to replace a skill directory that is a link.' }
        if (-not $target.StartsWith($skillsDirectory+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Skill target escapes the requested directory.' }
        $backup = Join-Path (Split-Path $skillsDirectory) ('skill-backups\'+[Guid]::NewGuid().ToString('N')+'\'+$name)
        New-Item -ItemType Directory -Force -Path (Split-Path $backup) | Out-Null
        Copy-Item -LiteralPath $target -Destination $backup -Recurse
        Remove-Item -LiteralPath $target -Recurse -Force
    }
    Copy-Item -LiteralPath $source -Destination $target -Recurse
    [PSCustomObject]@{Skill=$name;Status='Installed';Path=$target}
})
$result | ConvertTo-Json -Depth 4
Write-Host 'Installed skills are available in the next Codex turn. Installing files does not enable imagegen service access.'
