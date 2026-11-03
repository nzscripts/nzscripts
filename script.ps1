<#
.SYNOPSIS
    Minecraft Forge 1.12.2 dedicated server deployment script for Nazzy story modes.

.DESCRIPTION
    Installs, configures, and prepares a dedicated Minecraft Forge 1.12.2 server
    for Nazzy story modes and multiplayer sessions via Radmin VPN or local network.
    Adheres to the PowerShell Practice and Style Guide (PoshCode/PowerShellPracticeAndStyle).

.PARAMETER Mode
    The story mode to install. Valid values:
    'Interactive', 'None', 'Infected', 'Blizzard', 'Phasmophobia',
    'Slasher', 'Laboratory', 'Crossbattle', 'Scavenger'.
    Default: 'Interactive'.

.PARAMETER ServerPath
    The target directory where the server will be installed.
    Default: Current working directory (or Desktop\NazzyServer if invoked from a system directory or Win+R).

.PARAMETER MaxRamGB
    Maximum RAM allocation for the JVM in gigabytes.
    Default: 4.

.PARAMETER MinRamGB
    Minimum RAM allocation for the JVM in gigabytes.
    Default: 2.

.PARAMETER Force
    Suppresses interactive confirmation prompts during automated deployment.

.PARAMETER GitHubRepo
    The GitHub repository (Owner/Repository) hosting the release assets.
    Default: 'nzscripts/nzscripts'.

.PARAMETER ReleaseTag
    The GitHub Release tag containing the story mode build archives.
    Default: 'v1.0.0'.

.EXAMPLE
    .\script.ps1

.EXAMPLE
    powershell -NoExit -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/nzscripts/nzscripts/refs/heads/main/script.ps1 | iex"

.EXAMPLE
    .\script.ps1 -Mode Blizzard -MaxRamGB 6 -MinRamGB 2 -Force

.OUTPUTS
    None. Outputs status messages and creates server runtime files.

.NOTES
    Repository: https://github.com/nzscripts/nzscripts
    Guidelines: https://github.com/PoshCode/PowerShellPracticeAndStyle
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [ValidateSet('Interactive', 'None', 'Infected', 'Blizzard', 'Phasmophobia', 'Slasher', 'Laboratory', 'Crossbattle', 'Scavenger')]
    [string]$Mode = 'Interactive',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ServerPath = $PWD.Path,

    [Parameter()]
    [ValidateRange(1, 64)]
    [int]$MaxRamGB = 4,

    [Parameter()]
    [ValidateRange(1, 32)]
    [int]$MinRamGB = 2,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$GitHubRepo = 'nzscripts/nzscripts',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ReleaseTag = 'v1.0.0'
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Script:AvailableModes = @{
    'Infected'     = @{ Name = 'INFECTED v1.1';          File = 'INFECTED_v1.1_DISCORD.zip';  Desc = "Выживание с мутациями";    MaxPlayers = 10 }
    'Blizzard'     = @{ Name = 'OPERATION BLIZZARD';     File = 'OPERATION_BLIZZARD.zip';     Desc = "Арктика и военная база";   MaxPlayers = 8 }
    'Phasmophobia' = @{ Name = 'PHASMOPHOBIA HALLOWEEN'; File = 'PHASMOPHOBIA_HALLOWEEN.rar'; Desc = "Хоррор-расследование";     MaxPlayers = 5 }
    'Slasher'      = @{ Name = 'SLASHER (Redwood)';      File = 'SLASHER_Redwood_.rar';       Desc = "Маньяк в лагере";          MaxPlayers = 5 }
    'Laboratory'   = @{ Name = 'LABORATORY NZ';          File = 'LABORATORY_NZ.zip';          Desc = "Секретная лаборатория D7"; MaxPlayers = 8 }
    'Crossbattle'  = @{ Name = 'CROSSBATTLE';            File = 'CROSSBATTLE.rar';            Desc = "PvP арена и перестрелки";  MaxPlayers = 10; Id = '1WcpiUfzsTZni503RDH_bquKiEYRg2pqj' }
    'Scavenger'    = @{ Name = 'SCAVENGER';              File = 'SCAVENGER.rar';              Desc = "Охота на монстра";         MaxPlayers = 8;  Id = '1NRzPSr0bxGgOuKVxj-aPFAMwvQk4sUle' }
}

function Find-PrismJavaInstallation {
    <#
    .SYNOPSIS
        Scans the host system for Java runtime installations.

    .DESCRIPTION
        Scans system PATH, JAVA_HOME, Windows Registry, and launcher directories.
        Tests each executable and extracts version and architecture details.

    .OUTPUTS
        [System.Collections.Generic.List[PSCustomObject]]
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[PSCustomObject]])]
    param()

    $candidates = [System.Collections.Generic.List[string]]::new()

    # 1. System PATH
    $pathCommand = Get-Command -Name 'java.exe' -ErrorAction SilentlyContinue
    if ($null -ne $pathCommand) {
        $candidates.Add($pathCommand.Source)
    }

    # 2. JAVA_HOME environment variable
    if ($env:JAVA_HOME) {
        $candidatePath = Join-Path -Path $env:JAVA_HOME -ChildPath 'bin\java.exe'
        if (Test-Path -LiteralPath $candidatePath) {
            $candidates.Add($candidatePath)
        }
    }

    # 3. Windows Registry keys
    $registryKeys = @(
        'HKLM:\SOFTWARE\JavaSoft\Java Runtime Environment',
        'HKLM:\SOFTWARE\JavaSoft\Java Development Kit',
        'HKLM:\SOFTWARE\JavaSoft\JRE',
        'HKLM:\SOFTWARE\JavaSoft\JDK',
        'HKLM:\SOFTWARE\WOW6432Node\JavaSoft\Java Runtime Environment',
        'HKLM:\SOFTWARE\WOW6432Node\JavaSoft\Java Development Kit',
        'HKLM:\SOFTWARE\Eclipse Adoptium\JRE',
        'HKLM:\SOFTWARE\Eclipse Adoptium\JDK',
        'HKLM:\SOFTWARE\AdoptOpenJDK\JRE',
        'HKLM:\SOFTWARE\AdoptOpenJDK\JDK',
        'HKLM:\SOFTWARE\Microsoft\JDK'
    )

    foreach ($regPath in $registryKeys) {
        if (Test-Path -Path $regPath) {
            Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue | ForEach-Object {
                $subKey = $_.PSPath
                $properties = Get-ItemProperty -Path $subKey -ErrorAction SilentlyContinue
                $javaHome = if ($properties.JavaHome) { $properties.JavaHome } elseif ($properties.Path) { $properties.Path } else { $null }
                if ($null -ne $javaHome) {
                    $exe = Join-Path -Path $javaHome -ChildPath 'bin\java.exe'
                    if (Test-Path -LiteralPath $exe) {
                        $candidates.Add($exe)
                    }
                }
            }
        }
    }

    # 4. Standard installation directories
    $scanFolders = @(
        "${env:ProgramFiles}\Java",
        "${env:ProgramFiles(x86)}\Java",
        "${env:ProgramFiles}\Eclipse Adoptium",
        "${env:ProgramFiles}\AdoptOpenJDK",
        "${env:ProgramFiles}\Microsoft",
        "${env:ProgramFiles}\BellSoft",
        "${env:ProgramFiles}\Zulu",
        "${env:ProgramFiles(x86)}\Common Files\Oracle\Java\java8path",
        "${env:ProgramFiles}\Common Files\Oracle\Java\javapath",
        "${env:LOCALAPPDATA}\Programs\PrismLauncher\java",
        "${env:APPDATA}\PrismLauncher\java",
        "${env:APPDATA}\.minecraft\runtime\jre-legacy\windows-x64\jre-legacy\bin",
        "${env:APPDATA}\.minecraft\runtime\jre-legacy\windows-x86\jre-legacy\bin",
        "${env:APPDATA}\.minecraft\runtime\java-runtime-alpha\windows-x64\java-runtime-alpha\bin"
    )

    foreach ($folder in $scanFolders) {
        if (Test-Path -Path $folder) {
            Get-ChildItem -Path $folder -Filter 'java.exe' -Recurse -Depth 3 -ErrorAction SilentlyContinue | ForEach-Object {
                $candidates.Add($_.FullName)
            }
        }
    }

    # Path normalization and deduplication
    $uniquePaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($cand in $candidates) {
        try {
            $norm = [System.IO.Path]::GetFullPath($cand)
            if (Test-Path -LiteralPath $norm) {
                [void]$uniquePaths.Add($norm)
            }
        }
        catch {
            Write-Verbose "Could not normalize path ${cand}: $_"
        }
    }

    # Test each java.exe using ProcessStartInfo
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($exePath in $uniquePaths) {
        try {
            $psi = [System.Diagnostics.ProcessStartInfo]::new()
            $psi.FileName = $exePath
            $psi.Arguments = '-version'
            $psi.RedirectStandardError = $true
            $psi.RedirectStandardOutput = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true

            $process = [System.Diagnostics.Process]::Start($psi)
            $stderrOutput = $process.StandardError.ReadToEnd()
            [void]$process.WaitForExit(4000)

            $firstLine = ($stderrOutput -split "`r?`n" | Where-Object { $_ -match 'version' } | Select-Object -First 1)
            $is64Bit = ($stderrOutput -match '64-Bit|x64|amd64')
            $isJava8 = ($firstLine -match '1\.8\.0' -or $firstLine -match 'version "1\.8')

            $versionString = if ($firstLine -match 'version "([^"]+)"') { $Matches[1] } else { 'Unknown' }

            $results.Add([PSCustomObject]@{
                Path       = $exePath
                Version    = $versionString
                IsJava8    = [bool]$isJava8
                Is64Bit    = [bool]$is64Bit
                RawDetails = $firstLine
            })
        }
        catch {
            Write-Verbose "Error inspecting Java executable at ${exePath}: $_"
        }
    }

    return $results
}

function Initialize-ForgeBase {
    <#
    .SYNOPSIS
        Downloads and prepares Minecraft Forge 1.12.2 server files and libraries.

    .PARAMETER CacheDirectory
        Directory where Forge runtime files are cached.

    .PARAMETER ForgeVersion
        The Forge version string (e.g. '1.12.2-14.23.5.2860').

    .PARAMETER JavaExecutable
        The full path to the Java 8 executable.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CacheDirectory,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ForgeVersion,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$JavaExecutable
    )

    $installerName = "forge-$ForgeVersion-installer.jar"
    $universalName = "forge-$ForgeVersion-universal.jar"
    $serverJarName = "forge-$ForgeVersion.jar"
    $vanillaServerJar = 'minecraft_server.1.12.2.jar'

    $serverJarPath = Join-Path -Path $CacheDirectory -ChildPath $serverJarName
    $librariesPath = Join-Path -Path $CacheDirectory -ChildPath 'libraries'

    if ((Test-Path -LiteralPath $serverJarPath) -and (Test-Path -LiteralPath $librariesPath)) {
        Write-Verbose "Base Forge 1.12.2 is already initialized in: $CacheDirectory"
        return
    }

    if (-not (Test-Path -LiteralPath $CacheDirectory)) {
        $null = New-Item -ItemType Directory -Path $CacheDirectory -Force
    }

    $installerPath = Join-Path -Path $CacheDirectory -ChildPath $installerName
    if (-not (Test-Path -LiteralPath $installerPath)) {
        $forgeUrl = "https://maven.minecraftforge.net/net/minecraftforge/forge/$ForgeVersion/$installerName"
        Write-Host "Загрузка установщика Forge $ForgeVersion..."
        Invoke-WebRequest -Uri $forgeUrl -OutFile $installerPath -UseBasicParsing
    }

    # Patch for 404 Forge Maven bug on asm-debug-all:5.2 library
    $asmDir = Join-Path -Path $CacheDirectory -ChildPath 'libraries\org\ow2\asm\asm-debug-all\5.2'
    $asmJar = Join-Path -Path $asmDir -ChildPath 'asm-debug-all-5.2.jar'
    if (-not (Test-Path -LiteralPath $asmJar)) {
        if (-not (Test-Path -LiteralPath $asmDir)) {
            $null = New-Item -ItemType Directory -Path $asmDir -Force
        }
        $asmUrl = 'https://repo1.maven.org/maven2/org/ow2/asm/asm-debug-all/5.2/asm-debug-all-5.2.jar'
        Invoke-WebRequest -Uri $asmUrl -OutFile $asmJar -UseBasicParsing
    }

    Write-Host "Развертывание ядра и библиотек Forge..."
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $JavaExecutable
    $psi.Arguments = "-jar `"$installerPath`" --installServer"
    $psi.WorkingDirectory = $CacheDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $installerProcess = [System.Diagnostics.Process]::Start($psi)
    $null = $installerProcess.StandardOutput.ReadToEnd()
    [void]$installerProcess.WaitForExit(180000)

    if ($installerProcess.ExitCode -ne 0) {
        throw "Сбой установки Forge Installer (код завершения: $($installerProcess.ExitCode))."
    }

    $universalPath = Join-Path -Path $CacheDirectory -ChildPath $universalName
    if ((Test-Path -LiteralPath $universalPath) -and (-not (Test-Path -LiteralPath $serverJarPath))) {
        Rename-Item -LiteralPath $universalPath -NewName $serverJarName -Force
    }

    # Verify launchwrapper-1.12.jar presence
    $launchWrapperPath = Join-Path -Path $CacheDirectory -ChildPath 'libraries\net\minecraft\launchwrapper\1.12\launchwrapper-1.12.jar'
    if (-not (Test-Path -LiteralPath $launchWrapperPath)) {
        $lwDir = Split-Path -Path $launchWrapperPath
        if (-not (Test-Path -LiteralPath $lwDir)) {
            $null = New-Item -ItemType Directory -Path $lwDir -Force
        }
        Invoke-WebRequest -Uri 'https://libraries.minecraft.net/net/minecraft/launchwrapper/1.12/launchwrapper-1.12.jar' -OutFile $launchWrapperPath -UseBasicParsing
    }
}

function Expand-ArchivePackage {
    <#
    .SYNOPSIS
        Extracts ZIP, RAR, or TAR archives.

    .PARAMETER ArchiveFilePath
        Path to the archive file to extract.

    .PARAMETER DestinationPath
        Directory to extract archive contents into.

    .OUTPUTS
        [bool]
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ArchiveFilePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationPath
    )

    if ($ArchiveFilePath.EndsWith('.zip', [System.StringComparison]::OrdinalIgnoreCase)) {
        Expand-Archive -LiteralPath $ArchiveFilePath -DestinationPath $DestinationPath -Force
        return $true
    }

    $sevenZipCmd = Get-Command -Name '7z.exe' -ErrorAction SilentlyContinue
    $sevenZip = if ($null -ne $sevenZipCmd) { $sevenZipCmd.Source } else { $null }

    if ($null -eq $sevenZip) {
        $commonPaths = @("${env:ProgramFiles}\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe")
        foreach ($cp in $commonPaths) {
            if (Test-Path -LiteralPath $cp) {
                $sevenZip = $cp
                break
            }
        }
    }

    if ($null -ne $sevenZip) {
        $null = & $sevenZip x "$ArchiveFilePath" "-o$DestinationPath" -y
        return ($LASTEXITCODE -eq 0)
    }

    $winrar = "${env:ProgramFiles}\WinRAR\WinRAR.exe"
    if (Test-Path -LiteralPath $winrar) {
        $null = & $winrar x -ibck "$ArchiveFilePath" "$DestinationPath\"
        return ($LASTEXITCODE -eq 0)
    }

    $tarCmd = Get-Command -Name 'tar.exe' -ErrorAction SilentlyContinue
    if ($null -ne $tarCmd) {
        $null = & tar.exe -xf "$ArchiveFilePath" -C "$DestinationPath" 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
    }

    # Fallback: portable standalone 7za.exe
    $portable7zDir = Join-Path -Path $env:USERPROFILE -ChildPath '.mc_forge_base_1.12.2'
    $portable7z = Join-Path -Path $portable7zDir -ChildPath '7za.exe'
    if (-not (Test-Path -LiteralPath $portable7z)) {
        try {
            Write-Host "Загрузка 7za.exe для распаковки .rar..."
            $sevenZipUrl = 'https://www.7-zip.org/a/7za920.zip'
            $tempZip = Join-Path -Path $env:TEMP -ChildPath '7za920.zip'
            if (-not (Test-Path -LiteralPath $portable7zDir)) {
                $null = New-Item -ItemType Directory -Path $portable7zDir -Force
            }
            Invoke-WebRequest -Uri $sevenZipUrl -OutFile $tempZip -UseBasicParsing
            Expand-Archive -LiteralPath $tempZip -DestinationPath $portable7zDir -Force
            Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue
        }
        catch {
            Write-Verbose "Failed to download portable 7za: $_"
        }
    }

    if (Test-Path -LiteralPath $portable7z) {
        $null = & $portable7z x "$ArchiveFilePath" "-o$DestinationPath" -y
        return ($LASTEXITCODE -eq 0)
    }

    return $false
}

function Set-ServerConfiguration {
    <#
    .SYNOPSIS
        Configures eula.txt and server.properties.

    .PARAMETER TargetDirectory
        The server directory.

    .PARAMETER LevelName
        The world name (default: 'world').

    .PARAMETER MaxPlayers
        Maximum player slots (default: 10).
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetDirectory,

        [Parameter()]
        [string]$LevelName = 'world',

        [Parameter()]
        [int]$MaxPlayers = 10
    )

    $eulaPath = Join-Path -Path $TargetDirectory -ChildPath 'eula.txt'
    $serverPropertiesPath = Join-Path -Path $TargetDirectory -ChildPath 'server.properties'

    if ($PSCmdlet.ShouldProcess($eulaPath, 'Accept EULA')) {
        Set-Content -LiteralPath $eulaPath -Value 'eula=true' -Encoding ascii
    }

    $requiredSettings = @{
        'online-mode'          = 'false'
        'enable-command-block' = 'true'
        'allow-flight'         = 'true'
        'spawn-protection'     = '0'
        'gamemode'             = '2'
        'max-players'          = [string]$MaxPlayers
        'level-name'           = $LevelName
    }

    $currentSettings = @{}
    if (Test-Path -LiteralPath $serverPropertiesPath) {
        Get-Content -LiteralPath $serverPropertiesPath | ForEach-Object {
            $trimmed = $_.Trim()
            if ($trimmed -and -not $trimmed.StartsWith('#') -and $trimmed.Contains('=')) {
                $key, $val = $trimmed -split '=', 2
                $currentSettings[$key.Trim()] = $val.Trim()
            }
        }
    }

    foreach ($key in $requiredSettings.Keys) {
        $currentSettings[$key] = $requiredSettings[$key]
    }

    if ($PSCmdlet.ShouldProcess($serverPropertiesPath, 'Update server.properties')) {
        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add('# Minecraft Server Properties')
        foreach ($key in $currentSettings.Keys) {
            $lines.Add("$key=$($currentSettings[$key])")
        }
        [System.IO.File]::WriteAllLines($serverPropertiesPath, $lines, [System.Text.UTF8Encoding]::new($false))
    }
}

function Install-StoryMode {
    <#
    .SYNOPSIS
        Downloads, extracts, and installs a mode package into the server directory.

    .PARAMETER ModeConfig
        Hashtable containing mode metadata.

    .PARAMETER TargetDirectory
        Target server directory.

    .PARAMETER GitHubRepo
        GitHub repository holding the release assets.

    .PARAMETER ReleaseTag
        GitHub release tag.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$ModeConfig,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetDirectory,

        [Parameter()]
        [string]$GitHubRepo = 'nzscripts/nzscripts',

        [Parameter()]
        [string]$ReleaseTag = 'v1.0.0'
    )

    $archiveName = $ModeConfig.File

    # Check for existing valid archive in cache candidates
    $searchCandidates = [System.Collections.Generic.List[string]]::new()
    if ($TargetDirectory) {
        $searchCandidates.Add((Join-Path -Path $TargetDirectory -ChildPath $archiveName))
        $searchCandidates.Add((Join-Path -Path $TargetDirectory -ChildPath "builds_cache\$archiveName"))
    }
    if ($PSScriptRoot) {
        $searchCandidates.Add((Join-Path -Path $PSScriptRoot -ChildPath "builds_cache\$archiveName"))
        $searchCandidates.Add((Join-Path -Path $PSScriptRoot -ChildPath $archiveName))
    }

    $desktopNazzyCache = Join-Path -Path ([Environment]::GetFolderPath('Desktop')) -ChildPath "NazzyServer\builds_cache\$archiveName"
    if (Test-Path -LiteralPath $desktopNazzyCache) {
        $searchCandidates.Add($desktopNazzyCache)
    }

    # Only pick a candidate if it actually exists AND is larger than 100 KB
    $archiveFullPath = $searchCandidates |
        Where-Object { (Test-Path -LiteralPath $_) -and ((Get-Item -LiteralPath $_).Length -gt 100000) } |
        Select-Object -First 1

    if ($null -eq $archiveFullPath) {
        $archiveFullPath = Join-Path -Path $TargetDirectory -ChildPath $archiveName

        # Remove any corrupted or partial leftover
        if (Test-Path -LiteralPath $archiveFullPath) {
            Remove-Item -LiteralPath $archiveFullPath -Force -ErrorAction SilentlyContinue
        }

        Write-Host "Загрузка архива $($ModeConfig.Name)..."
        $hasCurl = [bool](Get-Command -Name 'curl.exe' -ErrorAction SilentlyContinue)

        $downloadSuccess = $false
        $githubReleaseUrl = "https://github.com/$GitHubRepo/releases/download/$ReleaseTag/$archiveName"

        if ($hasCurl) {
            & curl.exe -f -L --progress-bar -o $archiveFullPath $githubReleaseUrl
            if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $archiveFullPath) -and ((Get-Item -LiteralPath $archiveFullPath).Length -gt 100000)) {
                $downloadSuccess = $true
            }
        }

        if (-not $downloadSuccess) {
            try {
                Invoke-WebRequest -Uri $githubReleaseUrl -OutFile $archiveFullPath -UseBasicParsing -ErrorAction Stop
                if ((Test-Path -LiteralPath $archiveFullPath) -and ((Get-Item -LiteralPath $archiveFullPath).Length -gt 100000)) {
                    $downloadSuccess = $true
                }
            }
            catch {
                Write-Verbose "GitHub Release download failed: $_"
            }
        }

        # Secondary fallback for GDrive archives
        if ((-not $downloadSuccess) -and $ModeConfig.Id) {
            $gdriveUrl = "https://drive.usercontent.google.com/download?id=$($ModeConfig.Id)&export=download&confirm=t"
            if ($hasCurl) {
                & curl.exe -f -L --progress-bar -o $archiveFullPath $gdriveUrl
            }
            else {
                Invoke-WebRequest -Uri $gdriveUrl -OutFile $archiveFullPath -UseBasicParsing
            }
            if ((Test-Path -LiteralPath $archiveFullPath) -and ((Get-Item -LiteralPath $archiveFullPath).Length -gt 100000)) {
                $downloadSuccess = $true
            }
        }

        if (-not $downloadSuccess) {
            throw "Не удалось загрузить архив $archiveName (файл поврежден или недоступен)."
        }
    }

    $tempExtractPath = Join-Path -Path $TargetDirectory -ChildPath 'temp_mode_extract'
    if (Test-Path -LiteralPath $tempExtractPath) {
        Remove-Item -LiteralPath $tempExtractPath -Recurse -Force
    }
    $null = New-Item -ItemType Directory -Path $tempExtractPath -Force

    try {
        Write-Host "Распаковка архива..."
        $isExtracted = Expand-ArchivePackage -ArchiveFilePath $archiveFullPath -DestinationPath $tempExtractPath
        if (-not $isExtracted) {
            throw "Не удалось распаковать архив $archiveName."
        }

        $configuredMaxPlayers = if ($ModeConfig.MaxPlayers) { [int]$ModeConfig.MaxPlayers } else { 10 }

        # 1. World map detection
        $levelDatFile = Get-ChildItem -LiteralPath $tempExtractPath -Recurse -Filter 'level.dat' -ErrorAction SilentlyContinue | Select-Object -First 1
        $worldSourceDir = $null

        if ($null -ne $levelDatFile) {
            $worldSourceDir = $levelDatFile.Directory
            $worldFolderName = $worldSourceDir.Name

            if ($worldFolderName -ieq 'saves' -or $worldFolderName -ieq 'temp_mode_extract') {
                $worldFolderName = 'world'
            }

            $worldTarget = Join-Path -Path $TargetDirectory -ChildPath $worldFolderName
            if (Test-Path -LiteralPath $worldTarget) {
                Remove-Item -LiteralPath $worldTarget -Recurse -Force
            }
            Copy-Item -LiteralPath $worldSourceDir.FullName -Destination $worldTarget -Recurse -Force

            Set-ServerConfiguration -TargetDirectory $TargetDirectory -LevelName $worldFolderName -MaxPlayers $configuredMaxPlayers
            Write-Host "Установлена карта: $worldFolderName"
        }
        else {
            Set-ServerConfiguration -TargetDirectory $TargetDirectory -LevelName 'world' -MaxPlayers $configuredMaxPlayers
        }

        # 2. Mods deployment with client-only filtering
        $modsTarget = Join-Path -Path $TargetDirectory -ChildPath 'mods'
        if (Test-Path -LiteralPath $modsTarget) {
            Get-ChildItem -LiteralPath $modsTarget -Filter '*.jar' -ErrorAction SilentlyContinue | Remove-Item -Force
        }
        else {
            $null = New-Item -ItemType Directory -Path $modsTarget
        }

        $modsSource = Get-ChildItem -LiteralPath $tempExtractPath -Recurse -Directory -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -ieq 'mods' -and
                ($null -eq $worldSourceDir -or -not $_.FullName.StartsWith($worldSourceDir.FullName, [System.StringComparison]::OrdinalIgnoreCase))
            } |
            Select-Object -First 1

        $clientOnlyFilters = @('*OptiFine*', '*BetterFoliage*', '*tlskincape*', '*tlskin*')
        $allJarFiles = if ($null -ne $modsSource) {
            Get-ChildItem -LiteralPath $modsSource.FullName -Filter '*.jar' -ErrorAction SilentlyContinue
        }
        else {
            Get-ChildItem -LiteralPath $tempExtractPath -Recurse -Filter '*.jar' -ErrorAction SilentlyContinue |
                Where-Object { $null -eq $worldSourceDir -or -not $_.FullName.StartsWith($worldSourceDir.FullName, [System.StringComparison]::OrdinalIgnoreCase) }
        }

        $copiedModsCount = 0
        foreach ($jar in $allJarFiles) {
            $isClientOnly = $false
            foreach ($pattern in $clientOnlyFilters) {
                if ($jar.Name -like $pattern) {
                    $isClientOnly = $true
                    break
                }
            }
            if (-not $isClientOnly) {
                Copy-Item -LiteralPath $jar.FullName -Destination $modsTarget -Force
                $copiedModsCount++
            }
        }
        Write-Host "Установлено модов: $copiedModsCount"

        # 3. Weapon content packs (ModularWarfare, Flan, CustomNPCs)
        $contentPackNames = @('ModularWarfare', 'Flan', 'customnpcs')
        foreach ($folderName in $contentPackNames) {
            $foundPack = Get-ChildItem -LiteralPath $tempExtractPath -Recurse -Directory -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.Name -ieq $folderName -and
                    ($null -eq $worldSourceDir -or -not $_.FullName.StartsWith($worldSourceDir.FullName, [System.StringComparison]::OrdinalIgnoreCase))
                } |
                Select-Object -First 1

            if ($null -ne $foundPack) {
                $destFolder = Join-Path -Path $TargetDirectory -ChildPath $folderName
                if (Test-Path -LiteralPath $destFolder) {
                    Remove-Item -LiteralPath $destFolder -Recurse -Force
                }
                Copy-Item -LiteralPath $foundPack.FullName -Destination $destFolder -Recurse -Force
                Write-Host "Установлен контент-пак: $folderName"
            }
        }

        # 4. Configurations
        $configTarget = Join-Path -Path $TargetDirectory -ChildPath 'config'
        $configSource = Get-ChildItem -LiteralPath $tempExtractPath -Recurse -Directory -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -ieq 'config' -and
                ($null -eq $worldSourceDir -or -not $_.FullName.StartsWith($worldSourceDir.FullName, [System.StringComparison]::OrdinalIgnoreCase))
            } |
            Select-Object -First 1

        if ($null -ne $configSource) {
            if (-not (Test-Path -LiteralPath $configTarget)) {
                $null = New-Item -ItemType Directory -Path $configTarget
            }
            Get-ChildItem -LiteralPath $configSource.FullName -ErrorAction SilentlyContinue | ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination $configTarget -Recurse -Force
            }
            Write-Host "Скопированы конфигурации модов"
        }

        # 5. Resource packs
        $rpSource = Get-ChildItem -LiteralPath $tempExtractPath -Recurse -Directory -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -ieq 'resourcepacks' -and
                ($null -eq $worldSourceDir -or -not $_.FullName.StartsWith($worldSourceDir.FullName, [System.StringComparison]::OrdinalIgnoreCase))
            } |
            Select-Object -First 1

        if ($null -ne $rpSource) {
            $rpTarget = Join-Path -Path $TargetDirectory -ChildPath 'resourcepacks'
            if (-not (Test-Path -LiteralPath $rpTarget)) {
                $null = New-Item -ItemType Directory -Path $rpTarget
            }
            Get-ChildItem -LiteralPath $rpSource.FullName -ErrorAction SilentlyContinue | ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination $rpTarget -Recurse -Force
            }
            Write-Host "Ресурспак сохранен в: $rpTarget"
        }
    }
    finally {
        Remove-Item -LiteralPath $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ====================================================================
# Main Script Execution
# ====================================================================

try {
    Clear-Host
    Write-Host '========================================================================'
    Write-Host '  Minecraft Forge 1.12.2 Server Installer (Nazzy Modes)'
    Write-Host '========================================================================'

    # [1/5] Java Scanning
    Write-Host "`n[1/5] Поиск Java 8 (64-bit)..."
    $foundJavas = Find-PrismJavaInstallation

    $selectedJava = $foundJavas |
        Where-Object { $_.IsJava8 -and $_.Is64Bit } |
        Select-Object -First 1

    if ($null -eq $selectedJava) {
        $selectedJava = $foundJavas | Where-Object { $_.IsJava8 } | Select-Object -First 1
    }

    if ($null -eq $selectedJava) {
        Write-Host "Ошибка: Java 8 (64-bit) не найдена в системе." -ForegroundColor Red
        if ($foundJavas.Count -gt 0) {
            Write-Host "Найденные версии Java:"
            foreach ($j in $foundJavas) {
                Write-Host "  - $($j.Path) ($($j.Version), 64-bit: $($j.Is64Bit))"
            }
        }
        Write-Host "`nДля запуска Forge 1.12.2 требуется Java 8 (64-bit)."
        Write-Host "Скачать: https://www.java.com/en/download/manual.jsp"
        Write-Host "`nНажмите любую клавишу для выхода..."
        [void][Console]::ReadKey($true)
        exit 1
    }

    Write-Host "Найдена Java: $($selectedJava.Path) ($($selectedJava.Version), 64-bit: $($selectedJava.Is64Bit))"

    # [2/5] Server Directory Validation
    Write-Host "`n[2/5] Директория сервера..."
    $isSystemOrProtected = (
        $ServerPath.StartsWith($env:SystemRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        $ServerPath.StartsWith("${env:ProgramFiles}", [System.StringComparison]::OrdinalIgnoreCase) -or
        (${env:ProgramFiles(x86)} -and $ServerPath.StartsWith("${env:ProgramFiles(x86)}", [System.StringComparison]::OrdinalIgnoreCase)) -or
        $ServerPath -ieq $env:USERPROFILE
    )

    if ($isSystemOrProtected) {
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        $defaultServerDir = Join-Path -Path $desktopPath -ChildPath 'NazzyServer'

        Write-Host "Запуск из системной папки. По умолчанию выбрана: $defaultServerDir"
        $customInput = Read-Host "Нажмите Enter для продолжения (или введите другой путь)"
        if ($customInput -and $customInput.Trim()) {
            $ServerPath = $customInput.Trim().Replace('"', '')
        }
        else {
            $ServerPath = $defaultServerDir
        }
    }

    try {
        if (-not (Test-Path -LiteralPath $ServerPath)) {
            $null = New-Item -ItemType Directory -Path $ServerPath -Force
        }
        $testFile = Join-Path -Path $ServerPath -ChildPath '.write_perm_test'
        [System.IO.File]::WriteAllText($testFile, 'test')
        Remove-Item -LiteralPath $testFile -Force -ErrorAction SilentlyContinue
    }
    catch {
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        $ServerPath = Join-Path -Path $desktopPath -ChildPath 'NazzyServer'
        if (-not (Test-Path -LiteralPath $ServerPath)) {
            $null = New-Item -ItemType Directory -Path $ServerPath -Force
        }
        Write-Host "Запись в исходную папку ограничена. Сервер перенаправлен в: $ServerPath"
    }

    Write-Host "Папка сервера: $ServerPath"

    # [3/5] Mode Selection
    $chosenModeConfig = $null
    if ($Mode -eq 'Interactive') {
        Write-Host "`n[3/5] Выберите режим для установки:"
        Write-Host "  [1] INFECTED v1.1          - Выживание с мутациями"
        Write-Host "  [2] OPERATION BLIZZARD     - Арктика и военная база"
        Write-Host "  [3] PHASMOPHOBIA HALLOWEEN - Хоррор-расследование"
        Write-Host "  [4] SLASHER (Redwood)      - Маньяк в лагере"
        Write-Host "  [5] LABORATORY NZ          - Секретная лаборатория D7"
        Write-Host "  [6] CROSSBATTLE            - PvP арена и перестрелки"
        Write-Host "  [7] SCAVENGER              - Охота на монстра"
        Write-Host "  [0] Чистый сервер          - Forge 1.12.2 без модов"

        $userInput = Read-Host "`nНомер режима [0-7] (по умолчанию: 0)"
        $modeKeys = @('Infected', 'Blizzard', 'Phasmophobia', 'Slasher', 'Laboratory', 'Crossbattle', 'Scavenger')
        if ($userInput -match '^[1-7]$') {
            $selectedKey = $modeKeys[[int]$userInput - 1]
            $chosenModeConfig = $Script:AvailableModes[$selectedKey]
            Write-Host "Выбран режим: $($chosenModeConfig.Name)"
        }
        else {
            Write-Host "Выбран чистый сервер Forge 1.12.2."
        }
    }
    elseif ($Mode -ne 'None') {
        $chosenModeConfig = $Script:AvailableModes[$Mode]
        Write-Host "`nВыбран режим: $($chosenModeConfig.Name)"
    }

    # [4/5] Forge 1.12.2 Deployment
    Write-Host "`n[4/5] Развертывание ядра Forge 1.12.2..."
    $centralCache = Join-Path -Path $env:USERPROFILE -ChildPath '.mc_forge_base_1.12.2'
    $forgeVersionString = '1.12.2-14.23.5.2860'
    $forgeJarName = "forge-$forgeVersionString.jar"

    Initialize-ForgeBase -CacheDirectory $centralCache -ForgeVersion $forgeVersionString -JavaExecutable $selectedJava.Path

    if (-not (Test-Path -LiteralPath $ServerPath)) {
        $null = New-Item -ItemType Directory -Path $ServerPath -Force
    }

    Copy-Item -LiteralPath (Join-Path -Path $centralCache -ChildPath $forgeJarName) -Destination $ServerPath -Force
    Copy-Item -LiteralPath (Join-Path -Path $centralCache -ChildPath 'minecraft_server.1.12.2.jar') -Destination $ServerPath -Force

    $targetLibraries = Join-Path -Path $ServerPath -ChildPath 'libraries'
    if (-not (Test-Path -LiteralPath $targetLibraries)) {
        $null = New-Item -ItemType Directory -Path $targetLibraries -Force
    }
    Copy-Item -LiteralPath (Get-ChildItem -LiteralPath (Join-Path -Path $centralCache -ChildPath 'libraries')).FullName -Destination $targetLibraries -Recurse -Force
    Write-Host "Ядро и библиотеки Forge скопированы"

    $baseMaxPlayers = if ($null -ne $chosenModeConfig) { [int]$chosenModeConfig.MaxPlayers } else { 10 }
    Set-ServerConfiguration -TargetDirectory $ServerPath -MaxPlayers $baseMaxPlayers

    # [5/5] Story Mode Deployment
    $modeTitle = if ($null -ne $chosenModeConfig) { $chosenModeConfig.Name } else { 'Чистый сервер' }
    Write-Host "`n[5/5] Установка режима ($modeTitle)..."
    if ($null -ne $chosenModeConfig) {
        Install-StoryMode -ModeConfig $chosenModeConfig -TargetDirectory $ServerPath -GitHubRepo $GitHubRepo -ReleaseTag $ReleaseTag
    }
    else {
        $modsFolder = Join-Path -Path $ServerPath -ChildPath 'mods'
        if (-not (Test-Path -LiteralPath $modsFolder)) {
            $null = New-Item -ItemType Directory -Path $modsFolder
        }
    }

    # Generate start.bat using strict CRLF and ASCII
    $batPath = Join-Path -Path $ServerPath -ChildPath 'start.bat'
    $escapedJavaPath = $selectedJava.Path.Replace('"', '')

    $batLines = @(
        '@echo off',
        'chcp 65001 >nul',
        'title Minecraft Server 1.12.2',
        "set `"JAVA_BIN=$escapedJavaPath`"",
        'echo ========================================================',
        'echo   Minecraft Forge 1.12.2 Server',
        'echo ========================================================',
        "`"%JAVA_BIN%`" -Xms${MinRamGB}G -Xmx${MaxRamGB}G -Dfml.queryResult=confirm -jar $forgeJarName nogui",
        'if %ERRORLEVEL% NEQ 0 (',
        '    echo.',
        '    echo [!] Direct Java failed. Trying system java fallback...',
        "    java -Xms${MinRamGB}G -Xmx${MaxRamGB}G -Dfml.queryResult=confirm -jar $forgeJarName nogui",
        ')',
        'pause'
    )
    $batContent = ($batLines -join "`r`n") + "`r`n"
    [System.IO.File]::WriteAllText($batPath, $batContent, [System.Text.Encoding]::ASCII)

    # Completion
    Write-Host "`n========================================================================"
    Write-Host "  Сервер успешно установлен"
    Write-Host '========================================================================'
    Write-Host "  Режим:       $modeTitle"
    Write-Host "  Директория:  $ServerPath"
    Write-Host '  Запуск:      start.bat'
    Write-Host '  Сеть:        Radmin VPN (IP:25565)'
    Write-Host '========================================================================'

    if ($Mode -eq 'Interactive') {
        Write-Host "`n[Enter] Запустить сервер сейчас"
        Write-Host "[Q]     Выйти (запуск позже через start.bat)"
        $action = Read-Host "Выбор"
        if ($action -notmatch '^[qQйЙ]$') {
            Write-Host "`nЗапуск сервера в отдельном окне..."
            Start-Process -FilePath 'cmd.exe' -ArgumentList "/c `"$batPath`"" -WorkingDirectory $ServerPath
        }
        else {
            Write-Host "`nГотово. Файлы сохранены в: $ServerPath"
        }
    }
}
catch {
    $lastError = $_
    Write-Host "`n========================================================================" -ForegroundColor Red
    Write-Host "  Ошибка установки" -ForegroundColor Red
    Write-Host '========================================================================' -ForegroundColor Red
    Write-Host "Сообщение: $($lastError.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Строка:    $($lastError.InvocationInfo.ScriptLineNumber)" -ForegroundColor Gray
    Write-Host "`nНажмите любую клавишу для закрытия окна..."
    [void][Console]::ReadKey($true)
    exit 1
}
