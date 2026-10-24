param([Parameter(Mandatory=$true)][string]$OutputPath,[string]$RuntimeDirectory)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot
$zipPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
if (Test-Path -LiteralPath $zipPath) { throw 'Package already exists; choose a new output filename.' }
if (-not $RuntimeDirectory) {
    $RuntimeDirectory = Join-Path $repoRoot '.cache\realesrgan-windows'
    if (-not (Test-Path -LiteralPath (Join-Path $RuntimeDirectory 'realesrgan-ncnn-vulkan.exe'))) {
        $archive = Join-Path $repoRoot '.cache\realesrgan-official.zip'
        New-Item -ItemType Directory -Force -Path (Split-Path $archive) | Out-Null
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri 'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-windows.zip' -OutFile $archive -UseBasicParsing
        if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne 'ABC02804E17982A3BE33675E4D471E91EA374E65B70167ABC09E31ACB412802D') { throw 'Official runtime archive hash mismatch.' }
        Expand-Archive -LiteralPath $archive -DestinationPath $RuntimeDirectory
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $RuntimeDirectory 'models\realesrgan-x4plus.bin'))) { throw 'Runtime and photo model are required for the complete package.' }
$temporaryRoot = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('personal-skills-build-'+[Guid]::NewGuid().ToString('N'))))
$stage = Join-Path $temporaryRoot 'personal-skills'
try {
    New-Item -ItemType Directory -Force -Path $stage | Out-Null
    foreach ($name in @('README.md','LICENSE','THIRD_PARTY_NOTICES.md','docs','skills')) { Copy-Item -LiteralPath (Join-Path $repoRoot $name) -Destination (Join-Path $stage $name) -Recurse }
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts') -Destination (Join-Path $stage 'scripts') -Recurse
    $runtimeTarget = Join-Path $stage 'skills\real-esrgan-skill\runtime\windows-x64'
    if (Test-Path -LiteralPath $runtimeTarget) {
        if (-not ([IO.Path]::GetFullPath($runtimeTarget)).StartsWith([IO.Path]::GetFullPath($stage)+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Staging runtime path escapes the staging directory.' }
        Remove-Item -LiteralPath $runtimeTarget -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $runtimeTarget | Out-Null
    Get-ChildItem -LiteralPath $RuntimeDirectory -File | Where-Object { $_.Extension -in @('.exe','.dll','.md') -and $_.Name -ne 'vcomp140d.dll' } | Copy-Item -Destination $runtimeTarget
    Copy-Item -LiteralPath (Join-Path $RuntimeDirectory 'models') -Destination (Join-Path $runtimeTarget 'models') -Recurse
    $sums = @(Get-ChildItem -LiteralPath $stage -Recurse -File | Sort-Object FullName | ForEach-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash+'  '+$_.FullName.Substring($stage.Length+1).Replace('\','/') })
    $sums | Set-Content -LiteralPath (Join-Path $stage 'SHA256SUMS.txt') -Encoding UTF8
    New-Item -ItemType Directory -Force -Path (Split-Path $zipPath) | Out-Null
    Compress-Archive -LiteralPath $stage -DestinationPath $zipPath -CompressionLevel Optimal
    [PSCustomObject]@{Package=$zipPath;Bytes=(Get-Item -LiteralPath $zipPath).Length;Files=$sums.Count+1;SHA256=(Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash} | ConvertTo-Json
} finally {
    $expectedParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
    if ($temporaryRoot.StartsWith($expectedParent,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $temporaryRoot -Leaf).StartsWith('personal-skills-build-')) { Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
