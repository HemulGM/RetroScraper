#requires -Version 5.1
<#
.SYNOPSIS
Builds Release binaries and packages them into releases/RetroScraper-<platform>.zip.
.EXAMPLE
.\BuildReleases.ps1
.EXAMPLE
.\BuildReleases.ps1 -Platforms win32,win64 -BdsPath 'G:\Program Files (x86)\Embarcadero\Studio\37.0'
.EXAMPLE
.\BuildReleases.ps1 -Platforms macos64,macosarm64
.NOTES
macOS targets are included by default and require the corresponding RAD Studio toolchains
and SDKs. Archives contain a local .app bundle, without Apple signing or
notarization. ARM64 linking may also require a configured Mac/PAServer profile.
#>
[CmdletBinding()]
param(
    [ValidateSet('win32', 'win64', 'linux64', 'macos64', 'macosarm64')]
    [string[]] $Platforms = @('win32', 'win64', 'linux64', 'macos64', 'macosarm64'),
    [string] $BdsPath = $env:BDS
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectDirectory = Join-Path $PSScriptRoot '.'
$projectFile = Join-Path $projectDirectory 'RetroScraper.dproj'
$projectName = [IO.Path]::GetFileNameWithoutExtension($projectFile)
$releaseDirectory = Join-Path $PSScriptRoot 'releases'

# Prefer the active installation; otherwise discover Delphi on PATH or in the registry.
if (-not $BdsPath) {
    $compiler = Get-Command dcc32.exe -ErrorAction SilentlyContinue
    if ($compiler) {
        $BdsPath = Split-Path -Parent (Split-Path -Parent $compiler.Source)
    } else {
        $installations = @(Get-ChildItem 'HKCU:\Software\Embarcadero\BDS' -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -match '^\d+\.\d+$' } |
            Sort-Object { [version]$_.PSChildName } -Descending)
        foreach ($installation in $installations) {
            $candidate = (Get-ItemProperty -LiteralPath $installation.PSPath).RootDir
            if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate 'bin\rsvars.bat'))) {
                $BdsPath = $candidate
                break
            }
        }
    }
}
if (-not $BdsPath) { throw 'RAD Studio was not found. Specify -BdsPath or run from the RAD Studio command prompt.' }
$rsvars = Join-Path $BdsPath 'bin\rsvars.bat'
if (-not (Test-Path -LiteralPath $rsvars -PathType Leaf)) { throw "RAD Studio environment script not found: $rsvars" }

# rsvars.bat configures SDK/compiler/MSBuild paths. Import into this process only.
$environmentLines = & $env:ComSpec /d /c "call `"$rsvars`" >nul && set"
if ($LASTEXITCODE -ne 0) { throw "Could not initialize RAD Studio from $rsvars" }
foreach ($line in $environmentLines) {
    if ($line -match '^([^=]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
    }
}
$msbuild = Join-Path $env:FrameworkDir 'MSBuild.exe'
if (-not (Test-Path -LiteralPath $msbuild -PathType Leaf)) { throw "MSBuild not found: $msbuild" }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
New-Item -ItemType Directory -Force -Path $releaseDirectory | Out-Null

function Set-ZipUnixHost([string] $Path) {
    # .NET on Windows writes a DOS host marker even with Unix ExternalAttributes.
    # Mark central-directory entries as Unix so extractors honor their modes.
    # These locally created archives have no comment and one or three entries.
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite)
    $reader = [IO.BinaryReader]::new($stream)
    try {
        $stream.Position = $stream.Length - 22
        if ($reader.ReadUInt32() -ne 0x06054b50) { throw 'ZIP end record not found.' }
        $stream.Position = $stream.Length - 12
        $count = $reader.ReadUInt16()
        $stream.Position = $stream.Length - 6
        $offset = $reader.ReadUInt32()
        if ($count -notin @(1, 3) -or $offset -eq [uint32]::MaxValue) { throw 'Unexpected ZIP directory format.' }
        for ($index = 0; $index -lt $count; $index++) {
            $stream.Position = $offset
            if ($reader.ReadUInt32() -ne 0x02014b50) { throw 'ZIP central-directory entry not found.' }
            $stream.Position = $offset + 5
            $stream.WriteByte(3) # Unix host system.
            $stream.Position = $offset + 28
            $nameLength = $reader.ReadUInt16()
            $extraLength = $reader.ReadUInt16()
            $commentLength = $reader.ReadUInt16()
            $offset += 46 + $nameLength + $extraLength + $commentLength
        }
    } finally { $reader.Dispose(); $stream.Dispose() }
}

$platformNames = @{ win32 = 'Win32'; win64 = 'Win64'; linux64 = 'Linux64'; macos64 = 'OSX64'; macosarm64 = 'OSXARM64' }
foreach ($prefix in ($Platforms | Select-Object -Unique)) {
    $prefix = $prefix.ToLowerInvariant()
    $platform = $platformNames[$prefix]
    $isMacTarget = $prefix -in @('macos64', 'macosarm64')
    $outputDirectory = Join-Path $projectDirectory "$platform\Release"
    $binaryName = if ($prefix -eq 'linux64' -or $isMacTarget) { 'RetroScraper' } else { 'RetroScraper.exe' }
    $binaryPath = Join-Path $outputDirectory $binaryName
    $archivePath = Join-Path $releaseDirectory "RetroScraper-$prefix.zip"
    $temporaryArchive = Join-Path $releaseDirectory (".RetroScraper-$prefix-" + [guid]::NewGuid().ToString('N') + '.zip')

    if ($isMacTarget) {
        # Resolve the icon from the project's common, platform and Release groups.
        [xml] $projectXml = Get-Content -LiteralPath $projectFile -Raw -Encoding UTF8
        $iconSetting = $null
        foreach ($key in @('Base', "Base_$platform", 'Cfg_2', "Cfg_2_$platform")) {
            $condition = "'`$($key)'!=''"
            foreach ($group in $projectXml.Project.PropertyGroup) {
                if ($group.GetAttribute('Condition') -eq $condition -and $group.SelectSingleNode("*[local-name()='Icns_MainIcns']")) {
                    $iconSetting = [string] $group.Icns_MainIcns
                }
            }
        }
        if (-not $iconSetting) { throw "macOS icon is not configured for $platform in $projectFile" }
        $iconPath = $iconSetting.Replace('$(BDS)', $BdsPath).Replace('$(ProjectName)', $projectName)
        if (-not [IO.Path]::IsPathRooted($iconPath)) { $iconPath = Join-Path $projectDirectory $iconPath }
        if (-not (Test-Path -LiteralPath $iconPath -PathType Leaf)) { throw "macOS icon not found: $iconPath" }
        $plistPath = Join-Path $outputDirectory "$projectName.info.plist"
        # A previous metadata file must not survive a build that failed to generate it.
        if (Test-Path -LiteralPath $plistPath) { Remove-Item -LiteralPath $plistPath -Force }
    }

    # Delete only the expected previous binary so it cannot pass as a fresh build.
    if (Test-Path -LiteralPath $binaryPath) { Remove-Item -LiteralPath $binaryPath -Force }
    $target = if ($isMacTarget) { '/t:Build;BuildInfoPlist' } else { '/t:Build' }
    # Artwork paths in the .dproj use ProjectName before Delphi targets define it.
    # Set it as a global property so it is available during project evaluation.
    $arguments = @($projectFile, '/nologo', '/v:minimal', $target, "/p:ProjectName=$projectName", '/p:Config=Release', "/p:Platform=$platform",
        '/p:DCC_Optimize=true', '/p:DCC_DebugDCUs=false', '/p:DCC_DebugInformation=0', '/p:DCC_LocalDebugSymbols=false')

    Write-Host "Building $platform / Release..."
    Push-Location $projectDirectory
    try {
        & $msbuild @arguments
        if ($LASTEXITCODE -ne 0) { throw "$platform build failed (MSBuild exit code $LASTEXITCODE)." }
    } finally { Pop-Location }
    if (-not (Test-Path -LiteralPath $binaryPath -PathType Leaf) -or (Get-Item -LiteralPath $binaryPath).Length -eq 0) {
        throw "Build did not produce a nonempty executable: $binaryPath"
    }
    if ($isMacTarget -and (-not (Test-Path -LiteralPath $plistPath -PathType Leaf) -or (Get-Item -LiteralPath $plistPath).Length -eq 0)) {
        throw "Build did not produce macOS bundle metadata: $plistPath"
    }

    try {
        $zip = [IO.Compression.ZipFile]::Open($temporaryArchive, [IO.Compression.ZipArchiveMode]::Create)
        try {
            $entryName = if ($isMacTarget) { "$projectName.app/Contents/MacOS/$binaryName" } else { $binaryName }
            $entry = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $binaryPath, $entryName, [IO.Compression.CompressionLevel]::Optimal)
            if ($prefix -eq 'linux64' -or $isMacTarget) {
                # Unix regular file, mode 0755: preserve execute permission on unzip.
                $entry.ExternalAttributes = -2115174400
            }
            if ($isMacTarget) {
                $entry = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $plistPath, "$projectName.app/Contents/Info.plist", [IO.Compression.CompressionLevel]::Optimal)
                $entry.ExternalAttributes = -2119958528 # Unix regular file, mode 0644.
                $entry = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $iconPath, "$projectName.app/Contents/Resources/$projectName.icns", [IO.Compression.CompressionLevel]::Optimal)
                $entry.ExternalAttributes = -2119958528
            }
        } finally { $zip.Dispose() }
        if ($prefix -eq 'linux64' -or $isMacTarget) { Set-ZipUnixHost $temporaryArchive }
        Move-Item -LiteralPath $temporaryArchive -Destination $archivePath -Force
    } finally {
        if (Test-Path -LiteralPath $temporaryArchive) { Remove-Item -LiteralPath $temporaryArchive -Force }
    }
    Write-Host "Created $archivePath"
    if ($isMacTarget) { Write-Host 'The .app bundle has not been signed or notarized by this script.' }
}
