param(
    [Parameter(Mandatory=$true)][string]$InputPath,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [string]$EngineDirectory,
    [ValidateRange(32,1024)][int]$TileSize = 128
)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitProcess) { throw 'Use 64-bit Windows PowerShell or PowerShell 7.' }
Add-Type -AssemblyName System.Drawing
$inputFile = (Resolve-Path -LiteralPath $InputPath).Path
$outputFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
if (Test-Path -LiteralPath $outputFile) { throw 'Output already exists; use a new PNG path.' }
if ([IO.Path]::GetExtension($outputFile) -ne '.png') { throw 'Output must be a lossless PNG file.' }
$skillRoot = Split-Path $PSScriptRoot
if (-not $EngineDirectory) { $EngineDirectory = Join-Path $skillRoot 'runtime\windows-x64' }
$exe = Join-Path $EngineDirectory 'realesrgan-ncnn-vulkan.exe'
if (-not (Test-Path -LiteralPath $exe)) {
    $url = 'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-windows.zip'
    $expectedHash = 'ABC02804E17982A3BE33675E4D471E91EA374E65B70167ABC09E31ACB412802D'
    $archive = Join-Path ([IO.Path]::GetTempPath()) ('realesrgan-'+[Guid]::NewGuid().ToString('N')+'.zip')
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing
        if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $expectedHash) { throw 'Official engine archive hash mismatch.' }
        New-Item -ItemType Directory -Force -Path $EngineDirectory | Out-Null
        Expand-Archive -LiteralPath $archive -DestinationPath $EngineDirectory
    } finally { if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive } }
}
$models = Join-Path $EngineDirectory 'models'
if (-not (Test-Path -LiteralPath (Join-Path $models 'realesrgan-x4plus.bin'))) { throw 'Real-ESRGAN photo model is missing.' }
$inputImage = [System.Drawing.Image]::FromFile($inputFile)
try { $width=$inputImage.Width;$height=$inputImage.Height } finally { $inputImage.Dispose() }
New-Item -ItemType Directory -Force -Path (Split-Path $outputFile) | Out-Null
& $exe -i $inputFile -o $outputFile -m $models -n realesrgan-x4plus -s 4 -t $TileSize -f png
if ($LASTEXITCODE -ne 0) { throw "Real-ESRGAN inference failed ($LASTEXITCODE); verify Vulkan GPU support and drivers. Wallpaper was not changed." }
$outputImage = [System.Drawing.Image]::FromFile($outputFile)
try {
    if ($outputImage.Width -ne 4*$width -or $outputImage.Height -ne 4*$height) { throw 'AI output dimensions failed verification.' }
    [PSCustomObject]@{InputWidth=$width;InputHeight=$height;OutputWidth=$outputImage.Width;OutputHeight=$outputImage.Height;OutputPath=$outputFile;Model='realesrgan-x4plus';Scale=4;SHA256=(Get-FileHash -LiteralPath $outputFile -Algorithm SHA256).Hash} | ConvertTo-Json
} finally { $outputImage.Dispose() }
