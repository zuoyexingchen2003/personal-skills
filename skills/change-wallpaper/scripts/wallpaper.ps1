param(
    [ValidateSet('Inspect','Prepare','Apply','Restore')][string]$Mode = 'Inspect',
    [string]$MasterPath,
    [string]$SourceMapPath,
    [string]$OutputDirectory,
    [string]$ManifestPath,
    [ValidateRange(1,4)][double]$PixelScale = 2
)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Wallpaper control requires Windows 10/11.' }
Add-Type -AssemblyName System.Drawing
if (-not ('PersonalSkills.Wallpaper' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace PersonalSkills {
 [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
 [ComImport, Guid("B92B56A9-8B55-4E14-9A89-0199BBB6F93B"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
 public interface IDesktop {
  void SetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitor,[MarshalAs(UnmanagedType.LPWStr)] string image);
  void GetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitor,[MarshalAs(UnmanagedType.LPWStr)] out string image);
  void GetMonitorDevicePathAt(uint index,[MarshalAs(UnmanagedType.LPWStr)] out string monitor);
  void GetMonitorDevicePathCount(out uint count);
  void GetMonitorRECT([MarshalAs(UnmanagedType.LPWStr)] string monitor,out Rect rect);
  void SetBackgroundColor(uint color);
  void GetBackgroundColor(out uint color);
  void SetPosition(uint position);
  void GetPosition(out uint position);
 }
 public class Monitor {
  public int Index, Left, Top, Width, Height;
  public string Id, Image;
 }
 public class State { public uint Position; public Monitor[] Monitors; }
 public static class Wallpaper {
  private static IDesktop Create() { return (IDesktop)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("C2CF3110-460E-4FC1-B9D0-8A1C0C9CC4BD"))); }
  private static State Read(IDesktop desktop) {
   uint count, position;
   desktop.GetMonitorDevicePathCount(out count);
   desktop.GetPosition(out position);
   var monitors = new System.Collections.Generic.List<Monitor>();
   for (uint i=0; i<count; i++) {
    string id, image; Rect rect;
    desktop.GetMonitorDevicePathAt(i,out id);
    desktop.GetMonitorRECT(id,out rect);
    if (rect.Right<=rect.Left || rect.Bottom<=rect.Top) continue;
    desktop.GetWallpaper(id,out image);
    monitors.Add(new Monitor {Index=monitors.Count+1,Id=id,Image=image,Left=rect.Left,Top=rect.Top,Width=rect.Right-rect.Left,Height=rect.Bottom-rect.Top});
   }
   return new State {Position=position,Monitors=monitors.ToArray()};
  }
  public static State Read() { var desktop=Create(); try {return Read(desktop);} finally {Marshal.ReleaseComObject(desktop);} }
  public static State Apply(string[] ids,string[] images,uint position) {
   var desktop=Create(); var before=Read(desktop);
   try {
    desktop.SetPosition(position);
    for (int i=0;i<ids.Length;i++) desktop.SetWallpaper(ids[i],images[i]);
    var after=Read(desktop);
    if (after.Position!=position) throw new Exception("Wallpaper placement read-back failed.");
    foreach(var monitor in after.Monitors) {
     int index=Array.IndexOf(ids,monitor.Id);
     if(index<0 || !String.Equals(monitor.Image,images[index],StringComparison.OrdinalIgnoreCase)) throw new Exception("Wallpaper path read-back failed.");
    }
    return after;
   } catch(Exception failure) {
    try {
     desktop.SetPosition(before.Position);
     foreach(var monitor in before.Monitors) desktop.SetWallpaper(monitor.Id,monitor.Image);
    } catch(Exception recovery) { throw new AggregateException("Applying failed and restoring previous wallpaper also failed.",failure,recovery); }
    throw;
   } finally {Marshal.ReleaseComObject(desktop);}
  }
 }
}
'@
}

function Get-ImageSize([string]$Path) {
    $image = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $Path).Path)
    try { [PSCustomObject]@{Width=$image.Width;Height=$image.Height} } finally { $image.Dispose() }
}
function Restore-ImportQuality($Value) {
    if ($null -eq $Value) { Remove-ItemProperty -LiteralPath 'HKCU:\Control Panel\Desktop' -Name JPEGImportQuality -ErrorAction SilentlyContinue }
    else { New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Desktop' -Name JPEGImportQuality -PropertyType DWord -Value $Value -Force | Out-Null }
}
$state = [PersonalSkills.Wallpaper]::Read()
if ($state.Monitors.Count -eq 0) { throw 'No active display rectangles were detected in this desktop session.' }
if ($Mode -eq 'Inspect') { $state | ConvertTo-Json -Depth 6; return }

if ($Mode -eq 'Prepare') {
    if (-not $OutputDirectory -or (-not $MasterPath -and -not $SourceMapPath)) { throw 'Prepare requires OutputDirectory and MasterPath or SourceMapPath.' }
    $sourceMap = $null
    if ($SourceMapPath) { $sourceMap = Get-Content -LiteralPath $SourceMapPath -Raw | ConvertFrom-Json }
    $targetDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
    $manifestFile = Join-Path $targetDirectory 'wallpaper-manifest.json'
    if (Test-Path -LiteralPath $manifestFile) { throw 'Output directory already contains a manifest; choose a new directory.' }
    $plan = @(foreach ($monitor in $state.Monitors) {
        $selectedSource = $MasterPath
        if ($sourceMap) {
            $property = $sourceMap.PSObject.Properties[$monitor.Id]
            if ($property) { $selectedSource = [string]$property.Value }
        }
        if (-not $selectedSource) { throw "No source supplied for monitor $($monitor.Index)." }
        $selectedSource = (Resolve-Path -LiteralPath $selectedSource).Path
        $size = Get-ImageSize $selectedSource
        $width = [int][Math]::Ceiling($monitor.Width*$PixelScale)
        $height = [int][Math]::Ceiling($monitor.Height*$PixelScale)
        $ratio = [double]$width/$height
        $cropWidth = [Math]::Min([double]$size.Width,[double]($size.Height*$ratio))
        $cropHeight = [Math]::Min([double]$size.Height,[double]($size.Width/$ratio))
        if ($cropWidth -lt $width -or $cropHeight -lt $height) { throw "AI master has insufficient pixels for monitor $($monitor.Index): need a crop of at least ${width}x${height}. Use imagegen / Real-ESRGAN again; ordinary enlargement is rejected." }
        $file = Join-Path $targetDirectory ('wallpaper_{0:D2}_{1}x{2}.png' -f $monitor.Index,$width,$height)
        if (Test-Path -LiteralPath $file) { throw "Refusing to overwrite $file" }
        [PSCustomObject]@{MonitorId=$monitor.Id;Index=$monitor.Index;NativeWidth=$monitor.Width;NativeHeight=$monitor.Height;Width=$width;Height=$height;File=$file;Source=$selectedSource;CropWidth=$cropWidth;CropHeight=$cropHeight;RetainedArea=($cropWidth*$cropHeight/($size.Width*$size.Height));SHA256=$null}
    })
    New-Item -ItemType Directory -Force -Path $targetDirectory | Out-Null
    foreach ($entry in $plan) {
        $master = [System.Drawing.Image]::FromFile($entry.Source)
        $result = [System.Drawing.Bitmap]::new($entry.Width,$entry.Height,[System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        $graphics = [System.Drawing.Graphics]::FromImage($result)
        $attributes = [System.Drawing.Imaging.ImageAttributes]::new()
        try {
            $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $attributes.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
            $left = [single](($master.Width-$entry.CropWidth)/2)
            $top = [single](($master.Height-$entry.CropHeight)/2)
            $graphics.DrawImage($master,[System.Drawing.Rectangle]::new(0,0,$entry.Width,$entry.Height),$left,$top,[single]$entry.CropWidth,[single]$entry.CropHeight,[System.Drawing.GraphicsUnit]::Pixel,$attributes)
            $result.Save($entry.File,[System.Drawing.Imaging.ImageFormat]::Png)
        } finally { $attributes.Dispose();$graphics.Dispose();$result.Dispose();$master.Dispose() }
        $actual = Get-ImageSize $entry.File
        if ($actual.Width -ne $entry.Width -or $actual.Height -ne $entry.Height) { throw 'Saved image dimensions failed verification.' }
        $entry.SHA256 = (Get-FileHash -LiteralPath $entry.File -Algorithm SHA256).Hash
    }
    [PSCustomObject]@{SchemaVersion=1;PixelScale=$PixelScale;Entries=$plan} | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $manifestFile -Encoding UTF8
    [PSCustomObject]@{ManifestPath=$manifestFile;Entries=$plan} | ConvertTo-Json -Depth 7
    return
}

if (-not $ManifestPath) { throw "$Mode requires ManifestPath." }
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
if ($Mode -eq 'Restore') {
    $entries = @($manifest.State.Monitors)
    $ids = [string[]]@($entries | ForEach-Object { $_.Id })
    $images = [string[]]@($entries | ForEach-Object { $_.Image })
    $position = [uint32]$manifest.State.Position
} else {
    if ($manifest.SchemaVersion -ne 1 -or $manifest.PixelScale -lt 1 -or $manifest.PixelScale -gt 4) { throw 'Unsupported wallpaper manifest.' }
    $entries = @($manifest.Entries)
    $ids = [string[]]@($entries | ForEach-Object { $_.MonitorId })
    $images = [string[]]@($entries | ForEach-Object { (Resolve-Path -LiteralPath $_.File).Path })
    $position = [uint32]4
}
if ($ids.Count -ne $state.Monitors.Count -or @($ids | Select-Object -Unique).Count -ne $ids.Count) { throw 'Monitor count or identity changed; prepare a new manifest.' }
for ($index=0;$index -lt $ids.Count;$index++) {
    $monitor = @($state.Monitors | Where-Object { $_.Id -eq $ids[$index] })
    if ($monitor.Count -ne 1) { throw 'Monitor identity changed; prepare again.' }
    if ($images[$index] -and -not (Test-Path -LiteralPath $images[$index] -PathType Leaf)) { throw 'A wallpaper image is missing; no settings were changed.' }
    if ($Mode -eq 'Apply') {
        $entry = $entries[$index]
        $size = Get-ImageSize $images[$index]
        if ($monitor[0].Width -ne $entry.NativeWidth -or $monitor[0].Height -ne $entry.NativeHeight) { throw 'Display resolution or orientation changed; prepare again.' }
        if ($size.Width -ne [Math]::Ceiling($monitor[0].Width*$manifest.PixelScale) -or $size.Height -ne [Math]::Ceiling($monitor[0].Height*$manifest.PixelScale)) { throw 'Wallpaper pixel dimensions do not match the manifest.' }
        if ((Get-FileHash -LiteralPath $images[$index] -Algorithm SHA256).Hash -ne $entry.SHA256) { throw 'Wallpaper file changed after preparation; no settings were changed.' }
    }
}
$qualityBefore = (Get-ItemProperty -LiteralPath 'HKCU:\Control Panel\Desktop' -Name JPEGImportQuality -ErrorAction SilentlyContinue).JPEGImportQuality
if ($Mode -eq 'Apply') {
    $backupPath = Join-Path (Split-Path (Resolve-Path -LiteralPath $ManifestPath).Path) ('wallpaper-backup-'+[Guid]::NewGuid().ToString('N')+'.json')
    [PSCustomObject]@{State=$state;JPEGImportQuality=$qualityBefore} | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $backupPath -Encoding UTF8
    New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Desktop' -Name JPEGImportQuality -PropertyType DWord -Value 100 -Force | Out-Null
}
try { $after = [PersonalSkills.Wallpaper]::Apply($ids,$images,$position) }
catch { Restore-ImportQuality $qualityBefore; throw }
if ($Mode -eq 'Restore') { Restore-ImportQuality $manifest.JPEGImportQuality }
[PSCustomObject]@{Mode=$Mode;BackupPath=$backupPath;VerifiedState=$after} | ConvertTo-Json -Depth 7
