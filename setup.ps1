<#
.SYNOPSIS
    Automated Minecraft Forge 1.12.2 story modes server deployment tool.

.DESCRIPTION
    Installs, configures, and prepares a dedicated Minecraft Forge 1.12.2 server
    for Nazzy story modes and multiplayer sessions via Radmin VPN or local network.
    Adheres strictly to the PowerShell Practice and Style Guide (PoshCode/PowerShellPracticeAndStyle).

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
    # Interactive installation with mode selection menu:
    .\script.ps1

.EXAMPLE
    # One-liner execution from Win+R or PowerShell terminal:
    powershell -NoExit -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/nzscripts/nzscripts/refs/heads/main/script.ps1 | iex"

.EXAMPLE
    # Automated deployment of Crossbattle with 6 GB RAM:
    .\script.ps1 -Mode Crossbattle -MaxRamGB 6 -MinRamGB 2 -Force

.OUTPUTS
    None. Outputs formatted status messages and generates server runtime files.

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
    'Infected'     = @{ Name = 'INFECTED v1.1';           File = 'INFECTED_v1.1_DISCORD.zip';   Desc = 'Выживание и мутации';          Type = 'Direct'; Url = 'https://cdn.discordapp.com/attachments/989644883390246922/1216449065005486251/INFECTED_v1.1_DISCORD.zip?ex=6ae82a39&is=6ae6d8b9&hm=0b0b93a02e8aeb62e58e80fa885c462226d2a0eab59ab606f2f00545e0bd83f0&' }
    'Blizzard'     = @{ Name = 'OPERATION BLIZZARD';      File = 'OPERATION_BLIZZARD.zip';      Desc = 'Арктика, холод и мутанты';     Type = 'Direct'; Url = 'https://cdn.discordapp.com/attachments/989644883390246922/1214709450280140880/OPERATION_BLIZZARD.zip?ex=6ae86d95&is=6ae71c15&hm=ecf6b2151bcc6150ef0fc95ce59eb79677698d5469510927b7ad15a03efdafed&' }
    'Phasmophobia' = @{ Name = 'PHASMOPHOBIA HALLOWEEN';  File = 'PHASMOPHOBIA_HALLOWEEN.rar';  Desc = 'Хоррор-расследование';         Type = 'Direct'; Url = 'https://cdn.discordapp.com/attachments/778261521800233022/905517032265617409/PHASMOPHOBIA_HALLOWEEN.rar?ex=6ae82734&is=6ae6d5b4&hm=9377702f3624aea35b6cd8b45e4a4d4b6342c6cb6d25ec256a6c012c44ccc790&' }
    'Slasher'      = @{ Name = 'SLASHER (Redwood)';       File = 'SLASHER_Redwood_.rar';        Desc = 'Маньяк в лагере Редвуд';       Type = 'Direct'; Url = 'https://cdn.discordapp.com/attachments/778261521800233022/897470764582830091/SLASHER_Redwood_.rar?ex=6ae88b48&is=6ae739c8&hm=c5356cf49c0a27b73f5632b07480c0366bf32eff190bf7ebd513ea7a3d124eda&' }
    'Laboratory'   = @{ Name = 'LABORATORY NZ';           File = 'LABORATORY_NZ.zip';           Desc = 'Секретная лаборатория';        Type = 'Direct'; Url = 'https://cdn.discordapp.com/attachments/989644883390246922/1215231119906045973/LABORATORY_NZ.zip?ex=6ae8592c&is=6ae707ac&hm=af2b0c9eff80f5de18ceb15c5970996f36e6597890ede5029324d7e055b9442e&' }
    'Crossbattle'  = @{ Name = 'CROSSBATTLE';             File = 'CROSSBATTLE.rar';             Desc = 'PvP перестрелки и арена';      Type = 'GDrive'; Id  = '1WcpiUfzsTZni503RDH_bquKiEYRg2pqj' }
    'Scavenger'    = @{ Name = 'SCAVENGER';               File = 'SCAVENGER.rar';               Desc = 'Сбор лута и эвакуация';        Type = 'GDrive'; Id  = '1NRzPSr0bxGgOuKVxj-aPFAMwvQk4sUle' }
}

function Find-PrismJavaInstallation {
    <#
    .SYNOPSIS
        Scans the host system for Java runtime installations.

    .DESCRIPTION
        Implements Java detection logic modeled after Prism Launcher JavaUtils and JavaChecker.
        Scans the system PATH, JAVA_HOME, Windows Registry entries, and common launcher directories.
        Tests each executable and extracts version and architecture details.

    .OUTPUTS
        [System.Collections.Generic.List[PSCustomObject]]
        Collection of detected Java installations with Path, Version, IsJava8, and Is64Bit properties.
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

    # 3. Windows Registry keys (JavaSoft, AdoptOpenJDK, Eclipse Adoptium, Microsoft)
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

    # 4. Standard launcher and vendor installation folders
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

    # Test each java.exe using ProcessStartInfo (non-blocking stderr capture)
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
        Downloads and prepares the Minecraft Forge 1.12.2 base server files and libraries.

    .DESCRIPTION
        Ensures the Forge 1.12.2 installer, vanilla server jar, asm patch, and launchwrapper
        libraries are deployed and validated in the centralized user cache directory.

    .PARAMETER CacheDirectory
        Directory where Forge runtime files are cached.

    .PARAMETER ForgeVersion
        The Forge version string (e.g. '1.12.2-14.23.5.2860').

    .PARAMETER JavaExecutable
        The full path to the Java 8 executable used to run the Forge installer.
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
        Write-Host '    • Загрузка официального инсталлятора Forge 1.12.2...' -ForegroundColor Gray
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

    Write-Host '    • Развёртывание ядра и библиотек Forge (фоновый режим)...' -ForegroundColor Gray
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
        throw "Forge installer failed with exit code $($installerProcess.ExitCode)."
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
        Extracts ZIP, RAR, or TAR archives using available system utilities.

    .DESCRIPTION
        Extracts .zip archives natively via Expand-Archive.
        For .rar and other formats, attempts 7-Zip, WinRAR, tar, or automatically downloads portable 7za.exe.

    .PARAMETER ArchiveFilePath
        Path to the archive file to extract.

    .PARAMETER DestinationPath
        Directory to extract archive contents into.

    .OUTPUTS
        [bool] True if extraction succeeded, False otherwise.
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
            Write-Host '    • Загрузка автономного распаковщика .rar архивов...' -ForegroundColor Gray
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
        Configures eula.txt and server.properties with recommended multiplayer settings.

    .DESCRIPTION
        Automatically agrees to Minecraft EULA and ensures essential server settings:
        online-mode=false, enable-command-block=true, allow-flight=true,
        spawn-protection=0, gamemode=2, max-players=10, and sets level-name.

    .PARAMETER TargetDirectory
        The server directory containing server.properties and eula.txt.

    .PARAMETER LevelName
        The world name to set in server.properties (default: 'world').
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetDirectory,

        [Parameter()]
        [string]$LevelName = 'world'
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
        'max-players'          = '10'
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
        $lines.Add('# Minecraft Server Properties (Configured by nzscripts)')
        foreach ($key in $currentSettings.Keys) {
            $lines.Add("$key=$($currentSettings[$key])")
        }
        [System.IO.File]::WriteAllLines($serverPropertiesPath, $lines, [System.Text.UTF8Encoding]::new($false))
    }
}

function Install-StoryMode {
    <#
    .SYNOPSIS
        Downloads, extracts, and installs a Nazzy story mode package into the server directory.

    .DESCRIPTION
        Handles archive retrieval from GitHub Releases (primary fast CDN) with GDrive/Discord fallback,
        extracts contents safely, identifies the world map via level.dat, installs mods with client-mod
        filtering (OptiFine, BetterFoliage, tlskincape), deploys root weapon content packs (ModularWarfare, Flan),
        and updates config files.

    .PARAMETER ModeConfig
        Hashtable containing mode details: Name, File, Desc, Type, Url or Id.

    .PARAMETER TargetDirectory
        Target server directory where the mode is installed.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$ModeConfig,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetDirectory
    )

    $archiveName = $ModeConfig.File

    # Safe cache search without empty Join-Path errors
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

    $archiveFullPath = $searchCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

    if ($null -eq $archiveFullPath) {
        $archiveFullPath = Join-Path -Path $TargetDirectory -ChildPath $archiveName
        Write-Host "    • Загрузка пакета '$($ModeConfig.Name)'..." -ForegroundColor Yellow
        $hasCurl = [bool](Get-Command -Name 'curl.exe' -ErrorAction SilentlyContinue)

        $downloaded = $false
        # 1. Primary: GitHub Releases CDN (permanent, high-speed, no quota)
        if ($GitHubRepo) {
            $githubReleaseUrl = "https://github.com/$GitHubRepo/releases/download/$ReleaseTag/$archiveName"
            try {
                if ($hasCurl) {
                    $null = & curl.exe -# -f -L -o $archiveFullPath $githubReleaseUrl 2>$null
                    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $archiveFullPath) -and (Get-Item -LiteralPath $archiveFullPath).Length -gt 100000) {
                        $downloaded = $true
                    }
                }
                else {
                    Invoke-WebRequest -Uri $githubReleaseUrl -OutFile $archiveFullPath -UseBasicParsing -ErrorAction Stop
                    if ((Get-Item -LiteralPath $archiveFullPath).Length -gt 100000) {
                        $downloaded = $true
                    }
                }
            }
            catch {
                if (Test-Path -LiteralPath $archiveFullPath) {
                    Remove-Item -LiteralPath $archiveFullPath -Force -ErrorAction SilentlyContinue
                }
            }
        }

        # 2. Secondary: Google Drive / Discord CDN fallback
        if (-not $downloaded) {
            if ($ModeConfig.Type -eq 'GDrive') {
                $gdriveUrl = "https://drive.usercontent.google.com/download?id=$($ModeConfig.Id)&export=download&confirm=t"
                if ($hasCurl) {
                    $null = & curl.exe -# -L -o $archiveFullPath $gdriveUrl
                }
                else {
                    Invoke-WebRequest -Uri $gdriveUrl -OutFile $archiveFullPath -UseBasicParsing
                }
            }
            else {
                if ($hasCurl) {
                    $null = & curl.exe -# -L -o $archiveFullPath $ModeConfig.Url
                }
                else {
                    Invoke-WebRequest -Uri $ModeConfig.Url -OutFile $archiveFullPath -UseBasicParsing
                }
            }
        }
    }

    $tempExtractPath = Join-Path -Path $TargetDirectory -ChildPath 'temp_mode_extract'
    if (Test-Path -LiteralPath $tempExtractPath) {
        Remove-Item -LiteralPath $tempExtractPath -Recurse -Force
    }
    $null = New-Item -ItemType Directory -Path $tempExtractPath -Force

    try {
        Write-Host '    • Распаковка содержимого режима...' -ForegroundColor Gray
        $isExtracted = Expand-ArchivePackage -ArchiveFilePath $archiveFullPath -DestinationPath $tempExtractPath
        if (-not $isExtracted) {
            Write-Warning 'Не удалось распаковать архив режима. Установите 7-Zip или распакуйте архив вручную.'
            return
        }

        # 1. World map detection via level.dat
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

            Set-ServerConfiguration -TargetDirectory $TargetDirectory -LevelName $worldFolderName
            Write-Host "    • Карта '$worldFolderName' установлена (server.properties: level-name=$worldFolderName)" -ForegroundColor Green
        }

        # 2. Mods deployment with client-only filtering (OptiFine, BetterFoliage, tlskincape)
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
        Write-Host "    • Моды установлены: $copiedModsCount шт. (OptiFine/BetterFoliage отфильтрованы)" -ForegroundColor Green

        # 3. Weapon content packs (ModularWarfare, Flan, CustomNPCs), strictly outside world dir
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
                Write-Host "    • Контент-пак оружия '$folderName' установлен в корень сервера" -ForegroundColor Green
            }
        }

        # 4. Configurations (strictly outside world directory)
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
            Write-Host "    • Конфигурации модов скопированы в 'config'" -ForegroundColor Green
        }

        # 5. Resource packs (if bundled with mode)
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
            Write-Host "    • Ресурспак режима извлечён в папку 'resourcepacks' (передайте его друзьям)" -ForegroundColor Cyan
        }
    }
    finally {
        Remove-Item -LiteralPath $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ====================================================================
# Script Entry Point (with protection against abrupt window closing)
# ====================================================================

try {
    Clear-Host
    Write-Host '╔══════════════════════════════════════════════════════════════════════════════════════╗' -ForegroundColor Cyan
    Write-Host '║              🎮  NAZZY STORY MODES — MINECRAFT FORGE 1.12.2 SERVER                   ║' -ForegroundColor Cyan
    Write-Host '║                Автоматический установщик сервера для Radmin VPN                      ║' -ForegroundColor DarkCyan
    Write-Host '╚══════════════════════════════════════════════════════════════════════════════════════╝' -ForegroundColor Cyan

    # [1/5] Java Scanning
    Write-Host "`n[1/5] 🔍 Сканирование установленных сред Java (алгоритм Prism Launcher)..." -ForegroundColor Yellow
    $foundJavas = Find-PrismJavaInstallation

    # Priority: Java 8 (64-Bit)
    $selectedJava = $foundJavas |
        Where-Object { $_.IsJava8 -and $_.Is64Bit } |
        Select-Object -First 1

    if ($null -eq $selectedJava) {
        $selectedJava = $foundJavas | Where-Object { $_.IsJava8 } | Select-Object -First 1
    }

    if ($null -eq $selectedJava) {
        Write-Host "`n[!] Java 8 (64-bit) не найдена в системе!" -ForegroundColor Red
        if ($foundJavas.Count -gt 0) {
            Write-Host 'Найденные неподходящие версии Java:' -ForegroundColor Yellow
            foreach ($j in $foundJavas) {
                Write-Host "  • $($j.Path) ($($j.Version), 64-bit: $($j.Is64Bit))" -ForegroundColor Gray
            }
        }
        Write-Host "`nДля работы Forge 1.12.2 требуется именно Java 8 (64-bit)." -ForegroundColor Yellow
        Write-Host 'Скачайте установщик: https://www.java.com/en/download/manual.jsp' -ForegroundColor Cyan
        Write-Host "`nНажмите любую клавишу для выхода..." -ForegroundColor Gray
        [void][Console]::ReadKey($true)
        exit 1
    }

    Write-Host "  • Выбрана Java: $($selectedJava.Path)" -ForegroundColor Green
    Write-Host "  • Версия:       $($selectedJava.Version) (64-Bit: $($selectedJava.Is64Bit))" -ForegroundColor Gray

    # [2/5] Server Directory Validation & Win+R protection
    Write-Host "`n[2/5] 📁 Определение директории сервера..." -ForegroundColor Yellow
    $isSystemOrProtected = (
        $ServerPath.StartsWith($env:SystemRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        $ServerPath.StartsWith("${env:ProgramFiles}", [System.StringComparison]::OrdinalIgnoreCase) -or
        (${env:ProgramFiles(x86)} -and $ServerPath.StartsWith("${env:ProgramFiles(x86)}", [System.StringComparison]::OrdinalIgnoreCase)) -or
        $ServerPath -ieq $env:USERPROFILE
    )

    if ($isSystemOrProtected) {
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        $defaultServerDir = Join-Path -Path $desktopPath -ChildPath 'NazzyServer'

        Write-Host "  • Обнаружен запуск из системной папки ($ServerPath)." -ForegroundColor DarkYellow
        Write-Host "  • Папка сервера по умолчанию: $defaultServerDir" -ForegroundColor Cyan
        $customInput = Read-Host "`n  Нажмите Enter для установки на Рабочий стол (или введите другой путь)"
        if ($customInput -and $customInput.Trim()) {
            $ServerPath = $customInput.Trim().Replace('"', '')
        }
        else {
            $ServerPath = $defaultServerDir
        }
    }

    # Verify write access to $ServerPath
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
        Write-Host "  • Внимание: запись в исходную папку ограничена. Перенаправлено в: $ServerPath" -ForegroundColor DarkYellow
    }

    Write-Host "  • Папка сервера: $ServerPath" -ForegroundColor Green

    # [3/5] Mode Selection
    $chosenModeConfig = $null
    if ($Mode -eq 'Interactive') {
        Write-Host "`n[3/5] 🎮 Выберите сюжетный режим для установки:" -ForegroundColor Yellow
        Write-Host '┌───┬──────────────────────────┬─────────────────────────────┬─────────────────┐' -ForegroundColor DarkGray
        Write-Host '│ № │ РЕЖИМ                    │ ОПИСАНИЕ                    │ ОСОБЕННОСТИ     │' -ForegroundColor Cyan
        Write-Host '├───┼──────────────────────────┼─────────────────────────────┼─────────────────┤' -ForegroundColor DarkGray
        Write-Host '│ 1 │ INFECTED v1.1            │ Выживание и мутации         │ Голосовой чат   │' -ForegroundColor White
        Write-Host '│ 2 │ OPERATION BLIZZARD       │ Арктика, холод и мутанты    │ Мод на оружие   │' -ForegroundColor White
        Write-Host '│ 3 │ PHASMOPHOBIA HALLOWEEN   │ Хоррор-расследование        │ Голосовой чат   │' -ForegroundColor White
        Write-Host '│ 4 │ SLASHER (Redwood)        │ Маньяк в лагере Редвуд      │ Голосовой чат   │' -ForegroundColor White
        Write-Host '│ 5 │ LABORATORY NZ            │ Секретная лаборатория       │ Мод на оружие   │' -ForegroundColor White
        Write-Host '│ 6 │ CROSSBATTLE              │ PvP перестрелки и арена     │ Мод на оружие   │' -ForegroundColor White
        Write-Host '│ 7 │ SCAVENGER                │ Сбор лута и эвакуация       │ Мод на оружие   │' -ForegroundColor White
        Write-Host '│ 0 │ Чистый сервер            │ Forge 1.12.2 без модов      │ Чистый мир      │' -ForegroundColor Gray
        Write-Host '└───┴──────────────────────────┴─────────────────────────────┴─────────────────┘' -ForegroundColor DarkGray

        $userInput = Read-Host "`nВведите номер режима [1-7] (по умолчанию: 0)"
        $modeKeys = @('Infected', 'Blizzard', 'Phasmophobia', 'Slasher', 'Laboratory', 'Crossbattle', 'Scavenger')
        if ($userInput -match '^[1-7]$') {
            $selectedKey = $modeKeys[[int]$userInput - 1]
            $chosenModeConfig = $Script:AvailableModes[$selectedKey]
            Write-Host "`n  • Выбран режим: $($chosenModeConfig.Name) ($($chosenModeConfig.Desc))" -ForegroundColor Green
        }
        else {
            Write-Host "`n  • Выбран чистый сервер Forge 1.12.2." -ForegroundColor Gray
        }
    }
    elseif ($Mode -ne 'None') {
        $chosenModeConfig = $Script:AvailableModes[$Mode]
        Write-Host "`n[3/5] 🎮 Режим передан через аргументы: $($chosenModeConfig.Name)" -ForegroundColor Green
    }

    # [4/5] Forge 1.12.2 Deployment
    Write-Host "`n[4/5] ⚙️ Развёртывание ядра Forge 1.12.2 и библиотек..." -ForegroundColor Yellow
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
    Write-Host '  • Ядро Forge 1.12.2 и библиотеки успешно скопированы' -ForegroundColor Green

    Set-ServerConfiguration -TargetDirectory $ServerPath

    # [5/5] Story Mode Deployment
    Write-Host "`n[5/5] 📦 Установка модов, карты и файлов конфигурации..." -ForegroundColor Yellow
    if ($null -ne $chosenModeConfig) {
        Install-StoryMode -ModeConfig $chosenModeConfig -TargetDirectory $ServerPath
    }
    else {
        $modsFolder = Join-Path -Path $ServerPath -ChildPath 'mods'
        if (-not (Test-Path -LiteralPath $modsFolder)) {
            $null = New-Item -ItemType Directory -Path $modsFolder
        }
    }

    # Generate start.bat using strict CRLF and ASCII (no BOM, prevents Windows cmd offset bugs)
    $batPath = Join-Path -Path $ServerPath -ChildPath 'start.bat'
    $escapedJavaPath = $selectedJava.Path.Replace('"', '')

    $batLines = @(
        '@echo off',
        'chcp 65001 >nul',
        'title Minecraft Server 1.12.2',
        "set `"JAVA_BIN=$escapedJavaPath`"",
        'echo ========================================================',
        'echo   Minecraft Forge 1.12.2 Server (Nazzy Story Modes)',
        'echo   Auto-confirm FML: Enabled',
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

    # Completion Card
    $modeTitle = if ($null -ne $chosenModeConfig) { $chosenModeConfig.Name } else { 'Чистый сервер' }
    Write-Host "`n╔══════════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host '║                         СЕРВЕР УСПЕШНО УСТАНОВЛЕН И ГОТОВ!                           ║' -ForegroundColor Green
    Write-Host '╠══════════════════════════════════════════════════════════════════════════════════════╣' -ForegroundColor Green
    Write-Host "║  • Установленный режим: $modeTitle" -ForegroundColor White
    Write-Host "║  • Директория сервера:  $ServerPath" -ForegroundColor White
    Write-Host '║  • Файл для запуска:    start.bat' -ForegroundColor White
    Write-Host '║  • Для игры по сети:    Запустите Radmin VPN и передайте друзьям свой IP:25565       ║' -ForegroundColor DarkCyan
    Write-Host '╚══════════════════════════════════════════════════════════════════════════════════════╝' -ForegroundColor Green

    if ($Mode -eq 'Interactive') {
        Write-Host "`n  [Enter] Запустить сервер прямо сейчас" -ForegroundColor Cyan
        Write-Host '  [Q]     Выйти (запустите позже через start.bat)' -ForegroundColor Gray
        $action = Read-Host '  Ваш выбор'
        if ($action -notmatch '^[qQйЙ]$') {
            Write-Host "`nЗапуск сервера в отдельном окне..." -ForegroundColor Green
            Start-Process -FilePath 'cmd.exe' -ArgumentList "/c `"$batPath`"" -WorkingDirectory $ServerPath
        }
        else {
            Write-Host "`nСервер сохранён в: $ServerPath" -ForegroundColor Gray
        }
    }
}
catch {
    $lastError = $_
    Write-Host "`n╔══════════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host '║                                ОШИБКА УСТАНОВКИ                                      ║' -ForegroundColor Red
    Write-Host '╚══════════════════════════════════════════════════════════════════════════════════════╝' -ForegroundColor Red
    Write-Host "  • Сообщение: $($lastError.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  • Строка:    $($lastError.InvocationInfo.ScriptLineNumber)" -ForegroundColor Gray
    Write-Host "`nНажмите любую клавишу для закрытия окна..." -ForegroundColor Yellow
    [void][Console]::ReadKey($true)
    exit 1
}
