param([Parameter(Mandatory=$true)][string]$OutputPath,[ValidateSet('windows','macos')][string]$Platform='windows',[string]$RuntimeDirectory,[string]$MacToolPath)
$ErrorActionPreference = 'Stop'
$Platform = $Platform.ToLowerInvariant()
$repoRoot = Split-Path $PSScriptRoot
$zipPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
if (Test-Path -LiteralPath $zipPath) { throw 'Package already exists; choose a new output filename.' }
if ($Platform -eq 'windows') {
    $runtimeName = 'windows-x64'; $engineName = 'realesrgan-ncnn-vulkan.exe'
    $officialHash = 'ABC02804E17982A3BE33675E4D471E91EA374E65B70167ABC09E31ACB412802D'
} else {
    $runtimeName = 'macos-universal'; $engineName = 'realesrgan-ncnn-vulkan'
    $officialHash = 'E0AD05580ABFEB25F8D8FB55AAF7BEDF552C375B5B4D9BD3C8D59764D2CC333A'
    if (-not $MacToolPath -or -not (Test-Path -LiteralPath $MacToolPath -PathType Leaf)) { throw 'macOS package requires the CI-built universal wallpaper helper (-MacToolPath).' }
    $sourceHashPath = Join-Path (Split-Path (Resolve-Path -LiteralPath $MacToolPath).Path) 'source.sha256'
    if (-not (Test-Path -LiteralPath $sourceHashPath)) { throw 'Mac CI artifact must include source.sha256.' }
    $expectedSourceHash = (Get-Content -LiteralPath $sourceHashPath -Raw).Trim()
    if ((Get-FileHash -LiteralPath (Join-Path $repoRoot 'skills\change-wallpaper\scripts\wallpaper-macos.swift') -Algorithm SHA256).Hash -ne $expectedSourceHash) { throw 'Mac helper was built from a different Swift source.' }
    $header = [IO.File]::OpenRead((Resolve-Path -LiteralPath $MacToolPath).Path)
    try { $magic = [byte[]]::new(4);[void]$header.Read($magic,0,4); if ([BitConverter]::ToString($magic) -ne 'CA-FE-BA-BE') { throw 'Expected a universal Mach-O wallpaper helper.' } } finally { $header.Dispose() }
}
if (-not $RuntimeDirectory) {
    $RuntimeDirectory = Join-Path $repoRoot ('.cache\realesrgan-'+$Platform)
    if (-not (Test-Path -LiteralPath (Join-Path $RuntimeDirectory $engineName))) {
        $archive = Join-Path $repoRoot ('.cache\realesrgan-'+$Platform+'.zip')
        New-Item -ItemType Directory -Force -Path (Split-Path $archive) | Out-Null
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri ('https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-'+$Platform+'.zip') -OutFile $archive -UseBasicParsing
        if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $officialHash) { throw 'Official runtime archive hash mismatch.' }
        Expand-Archive -LiteralPath $archive -DestinationPath $RuntimeDirectory
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $RuntimeDirectory 'models\realesrgan-x4plus.bin'))) { throw 'Runtime and photo model are required for the complete package.' }
$temporaryRoot = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('personal-skills-build-'+[Guid]::NewGuid().ToString('N'))))
$stage = Join-Path $temporaryRoot 'personal-skills'
try {
    New-Item -ItemType Directory -Force -Path $stage | Out-Null
    foreach ($name in @('README.md','LICENSE','THIRD_PARTY_NOTICES.md','VERSION','docs','skills')) { Copy-Item -LiteralPath (Join-Path $repoRoot $name) -Destination (Join-Path $stage $name) -Recurse }
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts') -Destination (Join-Path $stage 'scripts') -Recurse
    foreach ($skillName in @('change-wallpaper','real-esrgan-skill')) {
        $oldRuntime = Join-Path $stage ('skills\'+$skillName+'\runtime')
        if (Test-Path -LiteralPath $oldRuntime) {
            if (-not ([IO.Path]::GetFullPath($oldRuntime)).StartsWith([IO.Path]::GetFullPath($stage)+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Staging runtime path escapes the staging directory.' }
            Remove-Item -LiteralPath $oldRuntime -Recurse -Force
        }
    }
    $runtimeTarget = Join-Path $stage ('skills\real-esrgan-skill\runtime\'+$runtimeName)
    New-Item -ItemType Directory -Force -Path $runtimeTarget | Out-Null
    Get-ChildItem -LiteralPath $RuntimeDirectory -File | Where-Object { ($_.Name -eq $engineName -or $_.Extension -in @('.dll','.md')) -and $_.Name -ne 'vcomp140d.dll' } | Copy-Item -Destination $runtimeTarget
    Copy-Item -LiteralPath (Join-Path $RuntimeDirectory 'models') -Destination (Join-Path $runtimeTarget 'models') -Recurse
    if ($Platform -eq 'macos') {
        $helperTarget = Join-Path $stage 'skills\change-wallpaper\runtime\macos-universal'
        New-Item -ItemType Directory -Force -Path $helperTarget | Out-Null
        Copy-Item -LiteralPath $MacToolPath -Destination (Join-Path $helperTarget 'wallpaper-macos')
    }
    [PSCustomObject]@{Version='V1.1';Platform=$Platform;OfficialRuntime='Real-ESRGAN v0.2.5.0 / 20220424';OfficialArchiveSHA256=$officialHash} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stage 'BUILD_INFO.json') -Encoding UTF8
    $sums = @(Get-ChildItem -LiteralPath $stage -Recurse -File | Sort-Object FullName | ForEach-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash+'  '+$_.FullName.Substring($stage.Length+1).Replace('\','/') })
    [IO.File]::WriteAllText((Join-Path $stage 'SHA256SUMS.txt'),(($sums -join "`n")+"`n"),[Text.UTF8Encoding]::new($false))
    New-Item -ItemType Directory -Force -Path (Split-Path $zipPath) | Out-Null
    Compress-Archive -LiteralPath $stage -DestinationPath $zipPath -CompressionLevel Optimal
    [PSCustomObject]@{Package=$zipPath;Bytes=(Get-Item -LiteralPath $zipPath).Length;Files=$sums.Count+1;SHA256=(Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash} | ConvertTo-Json
} finally {
    $expectedParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
    if ($temporaryRoot.StartsWith($expectedParent,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $temporaryRoot -Leaf).StartsWith('personal-skills-build-')) { Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
