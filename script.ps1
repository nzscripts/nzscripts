<#
.SYNOPSIS
    Автоматическая установка и настройка сервера Minecraft Forge 1.12.2 с поддержкой сюжетных режимов Nazzy.

.DESCRIPTION
    Использует алгоритмы поиска и валидации Java из Prism Launcher (JavaChecker/JavaUtils):
    сканирует реестр, директории лаунчеров и Program Files, фильтрует Java 8 64-bit,
    развёртывает ядро Forge 1.12.2 и прописывает прямой путь к Java в start.bat.

.PARAMETER Mode
    Название режима: 'Interactive', 'None', 'Infected', 'Blizzard', 'Phasmophobia', 'Slasher', 'Laboratory', 'Crossbattle', 'Scavenger'.

.PARAMETER ServerPath
    Целевая директория сервера. По умолчанию текущая папка (при запуске из Win+R - Desktop\NazzyServer).

.PARAMETER MaxRamGB
    Выделяемая оперативная память (в ГБ). По умолчанию 4.

.PARAMETER MinRamGB
    Минимальная память (в ГБ). По умолчанию 2.
#>

[CmdletBinding(SupportsShouldProcess)]
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
    [string]$GitHubRepo = 'nzscripts/nzscripts',

    [Parameter()]
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

function Find-PrismJavaInstallations {
    <#
    .SYNOPSIS
        Сканирует систему на наличие установок Java по алгоритмам PrismLauncher JavaUtils.
    #>
    [CmdletBinding()]
    param()

    $candidates = [System.Collections.Generic.List[string]]::new()

    # 1. Системный PATH
    $pathCmd = Get-Command -Name "java.exe" -ErrorAction SilentlyContinue
    if ($pathCmd) { $candidates.Add($pathCmd.Source) }

    # 2. JAVA_HOME
    if ($env:JAVA_HOME) {
        $candidate = Join-Path -Path $env:JAVA_HOME -ChildPath "bin\java.exe"
        if (Test-Path -LiteralPath $candidate) { $candidates.Add($candidate) }
    }

    # 3. Реестр Windows (JavaSoft, AdoptOpenJDK, Eclipse Adoptium, Microsoft)
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
                $props = Get-ItemProperty -Path $subKey -ErrorAction SilentlyContinue
                $javaHome = if ($props.JavaHome) { $props.JavaHome } elseif ($props.Path) { $props.Path } else { $null }
                if ($javaHome) {
                    $exe = Join-Path -Path $javaHome -ChildPath "bin\java.exe"
                    if (Test-Path -LiteralPath $exe) { $candidates.Add($exe) }
                }
            }
        }
    }

    # 4. Известные пути (Prism Launcher, Modrinth, CurseForge, Common Files, Program Files)
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
            Get-ChildItem -Path $folder -Filter "java.exe" -Recurse -Depth 3 -ErrorAction SilentlyContinue | ForEach-Object {
                $candidates.Add($_.FullName)
            }
        }
    }

    # Нормализация путей и дедупликация
    $uniquePaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($cand in $candidates) {
        try {
            $norm = [System.IO.Path]::GetFullPath($cand)
            if (Test-Path -LiteralPath $norm) {
                [void]$uniquePaths.Add($norm)
            }
        } catch { }
    }

    # Проверка свойств каждого найденного java.exe (JavaChecker logic)
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($exePath in $uniquePaths) {
        try {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $exePath
            $psi.Arguments = "-version"
            $psi.RedirectStandardError = $true
            $psi.RedirectStandardOutput = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true

            $proc = [System.Diagnostics.Process]::Start($psi)
            $stderrOutput = $proc.StandardError.ReadToEnd()
            $proc.WaitForExit(4000)

            $firstLine = ($stderrOutput -split "`r?`n" | Where-Object { $_ -match 'version' } | Select-Object -First 1)
            $is64Bit = ($stderrOutput -match '64-Bit|x64|amd64')
            $isJava8 = ($firstLine -match '1\.8\.0' -or $firstLine -match 'version "1\.8')

            $verString = if ($firstLine -match 'version "([^"]+)"') { $Matches[1] } else { 'Unknown' }

            $results.Add([PSCustomObject]@{
                Path       = $exePath
                Version    = $verString
                IsJava8    = [bool]$isJava8
                Is64Bit    = [bool]$is64Bit
                RawDetails = $firstLine
            })
        } catch {
            Write-Verbose "Ошибка тестирования пути $($exePath): $_"
        }
    }

    return $results
}

function Initialize-ForgeBase {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$CacheDirectory,

        [Parameter(Mandatory)]
        [string]$ForgeVersion,

        [Parameter(Mandatory)]
        [string]$JavaExecutable
    )

    $installerName = "forge-$ForgeVersion-installer.jar"
    $universalName = "forge-$ForgeVersion-universal.jar"
    $serverJarName = "forge-$ForgeVersion.jar"
    $vanillaServerJar = "minecraft_server.1.12.2.jar"

    $serverJarPath = Join-Path -Path $CacheDirectory -ChildPath $serverJarName
    $librariesPath = Join-Path -Path $CacheDirectory -ChildPath "libraries"

    if ((Test-Path -LiteralPath $serverJarPath) -and (Test-Path -LiteralPath $librariesPath)) {
        Write-Verbose "Базовое ядро Forge 1.12.2 уже развёрнуто в кэше: $CacheDirectory"
        return
    }

    if (-not (Test-Path -LiteralPath $CacheDirectory)) {
        $null = New-Item -ItemType Directory -Path $CacheDirectory -Force
    }

    $installerPath = Join-Path -Path $CacheDirectory -ChildPath $installerName
    if (-not (Test-Path -LiteralPath $installerPath)) {
        $forgeUrl = "https://maven.minecraftforge.net/net/minecraftforge/forge/$ForgeVersion/$installerName"
        Write-Host "    • Загрузка официального инсталлятора Forge 1.12.2..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $forgeUrl -OutFile $installerPath -UseBasicParsing
    }

    # Исправление бага 404 Forge Maven для библиотеки asm-debug-all:5.2
    $asmDir = Join-Path -Path $CacheDirectory -ChildPath "libraries\org\ow2\asm\asm-debug-all\5.2"
    $asmJar = Join-Path -Path $asmDir -ChildPath "asm-debug-all-5.2.jar"
    if (-not (Test-Path -LiteralPath $asmJar)) {
        if (-not (Test-Path -LiteralPath $asmDir)) { $null = New-Item -ItemType Directory -Path $asmDir -Force }
        $asmUrl = "https://repo1.maven.org/maven2/org/ow2/asm/asm-debug-all/5.2/asm-debug-all-5.2.jar"
        Invoke-WebRequest -Uri $asmUrl -OutFile $asmJar -UseBasicParsing
    }

    Write-Host "    • Развёртывание ядра и библиотек Forge (фоновый режим)..." -ForegroundColor Gray
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $JavaExecutable
    $psi.Arguments = "-jar `"$installerPath`" --installServer"
    $psi.WorkingDirectory = $CacheDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::Start($psi)
    $null = $process.StandardOutput.ReadToEnd()
    $process.WaitForExit(180000)

    if ($process.ExitCode -ne 0) {
        throw "Сбой установки Forge Installer (код завершения: $($process.ExitCode))."
    }

    $universalPath = Join-Path -Path $CacheDirectory -ChildPath $universalName
    if ((Test-Path -LiteralPath $universalPath) -and (-not (Test-Path -LiteralPath $serverJarPath))) {
        Rename-Item -Path $universalPath -NewName $serverJarName -Force
    }

    # Проверка launchwrapper-1.12.jar
    $launchWrapperPath = Join-Path -Path $CacheDirectory -ChildPath "libraries\net\minecraft\launchwrapper\1.12\launchwrapper-1.12.jar"
    if (-not (Test-Path -LiteralPath $launchWrapperPath)) {
        $lwDir = Split-Path $launchWrapperPath
        if (-not (Test-Path -LiteralPath $lwDir)) { $null = New-Item -ItemType Directory -Path $lwDir -Force }
        Invoke-WebRequest -Uri "https://libraries.minecraft.net/net/minecraft/launchwrapper/1.12/launchwrapper-1.12.jar" -OutFile $launchWrapperPath -UseBasicParsing
    }
}

function Expand-ArchivePackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ArchiveFilePath,

        [Parameter(Mandatory)]
        [string]$DestinationPath
    )

    if ($ArchiveFilePath.EndsWith('.zip', [System.StringComparison]::OrdinalIgnoreCase)) {
        Expand-Archive -Path $ArchiveFilePath -DestinationPath $DestinationPath -Force
        return $true
    }

    $sevenZip = (Get-Command -Name "7z.exe" -ErrorAction SilentlyContinue).Source
    if (-not $sevenZip) {
        $common = @("${env:ProgramFiles}\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe")
        foreach ($c in $common) { if (Test-Path -LiteralPath $c) { $sevenZip = $c; break } }
    }
    if ($sevenZip) {
        & $sevenZip x "$ArchiveFilePath" "-o$DestinationPath" -y | Out-Null
        return ($LASTEXITCODE -eq 0)
    }

    $winrar = "${env:ProgramFiles}\WinRAR\WinRAR.exe"
    if (Test-Path -LiteralPath $winrar) {
        & $winrar x -ibck "$ArchiveFilePath" "$DestinationPath\"
        return ($LASTEXITCODE -eq 0)
    }

    if (Get-Command -Name "tar.exe" -ErrorAction SilentlyContinue) {
        & tar.exe -xf "$ArchiveFilePath" -C "$DestinationPath" 2>$null
        if ($LASTEXITCODE -eq 0) { return $true }
    }

    # Резервный архиватор: портативный 7za.exe (скачивается автоматически, если на ПК нет 7-Zip)
    $portable7zDir = Join-Path -Path $env:USERPROFILE -ChildPath ".mc_forge_base_1.12.2"
    $portable7z = Join-Path -Path $portable7zDir -ChildPath "7za.exe"
    if (-not (Test-Path -LiteralPath $portable7z)) {
        try {
            Write-Host "    • Загрузка автономного распаковщика .rar архивов..." -ForegroundColor Gray
            $7zZipUrl = "https://www.7-zip.org/a/7za920.zip"
            $temp7zZip = Join-Path -Path $env:TEMP -ChildPath "7za920.zip"
            if (-not (Test-Path -LiteralPath $portable7zDir)) { $null = New-Item -ItemType Directory -Path $portable7zDir -Force }
            Invoke-WebRequest -Uri $7zZipUrl -OutFile $temp7zZip -UseBasicParsing
            Expand-Archive -Path $temp7zZip -DestinationPath $portable7zDir -Force
            Remove-Item -Path $temp7zZip -Force -ErrorAction SilentlyContinue
        } catch { }
    }
    if (Test-Path -LiteralPath $portable7z) {
        & $portable7z x "$ArchiveFilePath" "-o$DestinationPath" -y | Out-Null
        return ($LASTEXITCODE -eq 0)
    }

    return $false
}

function Set-ServerConfiguration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$TargetDirectory,

        [Parameter()]
        [string]$LevelName = 'world'
    )

    $eulaPath = Join-Path -Path $TargetDirectory -ChildPath "eula.txt"
    $serverPropertiesPath = Join-Path -Path $TargetDirectory -ChildPath "server.properties"

    if ($PSCmdlet.ShouldProcess($eulaPath, "Принятие EULA")) {
        Set-Content -Path $eulaPath -Value "eula=true" -Encoding ASCII
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
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith('#') -and $line.Contains('=')) {
                $key, $value = $line -split '=', 2
                $currentSettings[$key.Trim()] = $value.Trim()
            }
        }
    }

    foreach ($key in $requiredSettings.Keys) {
        $currentSettings[$key] = $requiredSettings[$key]
    }

    if ($PSCmdlet.ShouldProcess($serverPropertiesPath, "Обновление параметров server.properties")) {
        $propertiesLines = @("# Minecraft Server Properties (Configured by nzscripts)")
        foreach ($key in $currentSettings.Keys) {
            $propertiesLines += "$key=$($currentSettings[$key])"
        }
        $propertiesLines | Set-Content -LiteralPath $serverPropertiesPath -Encoding UTF8
    }
}

function Invoke-ModeInstallation {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ModeConfig,

        [Parameter(Mandatory)]
        [string]$TargetDirectory
    )

    $archiveName = $ModeConfig.File

    # Безопасный поиск существующего кэша (без ошибок Join-Path при пустом $PSScriptRoot)
    $searchCandidates = [System.Collections.Generic.List[string]]::new()
    if ($TargetDirectory) {
        $searchCandidates.Add((Join-Path -Path $TargetDirectory -ChildPath $archiveName))
        $searchCandidates.Add((Join-Path -Path $TargetDirectory -ChildPath "builds_cache\$archiveName"))
    }
    if ($PSScriptRoot) {
        $searchCandidates.Add((Join-Path -Path $PSScriptRoot -ChildPath "builds_cache\$archiveName"))
        $searchCandidates.Add((Join-Path -Path $PSScriptRoot -ChildPath $archiveName))
    }
    $localDesktopCache = "C:\Users\Seilce\Desktop\ss\builds_cache\$archiveName"
    if (Test-Path -LiteralPath $localDesktopCache) { $searchCandidates.Add($localDesktopCache) }

    $archiveFullPath = $searchCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

    if (-not $archiveFullPath) {
        $archiveFullPath = Join-Path -Path $TargetDirectory -ChildPath $archiveName
        Write-Host "    • Загрузка пакета '$($ModeConfig.Name)'..." -ForegroundColor Yellow
        $hasCurl = [bool](Get-Command -Name "curl.exe" -ErrorAction SilentlyContinue)

        $downloaded = $false
        # 1. Попытка загрузки из GitHub Releases (быстрый CDN, постоянные ссылки)
        if ($GitHubRepo) {
            $githubReleaseUrl = "https://github.com/$GitHubRepo/releases/download/$ReleaseTag/$archiveName"
            try {
                if ($hasCurl) {
                    & curl.exe -# -f -L -o $archiveFullPath $githubReleaseUrl 2>$null
                    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $archiveFullPath) -and (Get-Item $archiveFullPath).Length -gt 100000) {
                        $downloaded = $true
                    }
                } else {
                    Invoke-WebRequest -Uri $githubReleaseUrl -OutFile $archiveFullPath -UseBasicParsing -ErrorAction Stop
                    if ((Get-Item $archiveFullPath).Length -gt 100000) {
                        $downloaded = $true
                    }
                }
            } catch {
                if (Test-Path -LiteralPath $archiveFullPath) { Remove-Item -LiteralPath $archiveFullPath -Force -ErrorAction SilentlyContinue }
            }
        }

        # 2. Резервная загрузка через GDrive / Discord CDN
        if (-not $downloaded) {
            if ($ModeConfig.Type -eq 'GDrive') {
                $gdriveUrl = "https://drive.usercontent.google.com/download?id=$($ModeConfig.Id)&export=download&confirm=t"
                if ($hasCurl) {
                    & curl.exe -# -L -o $archiveFullPath $gdriveUrl
                } else {
                    Invoke-WebRequest -Uri $gdriveUrl -OutFile $archiveFullPath -UseBasicParsing
                }
            } else {
                if ($hasCurl) {
                    & curl.exe -# -L -o $archiveFullPath $ModeConfig.Url
                } else {
                    Invoke-WebRequest -Uri $ModeConfig.Url -OutFile $archiveFullPath -UseBasicParsing
                }
            }
        }
    }

    $tempExtractPath = Join-Path -Path $TargetDirectory -ChildPath "temp_mode_extract"
    if (Test-Path -LiteralPath $tempExtractPath) { Remove-Item -LiteralPath $tempExtractPath -Recurse -Force }
    $null = New-Item -ItemType Directory -Path $tempExtractPath -Force

    try {
        Write-Host "    • Распаковка содержимого режима..." -ForegroundColor Gray
        $isExtracted = Expand-ArchivePackage -ArchiveFilePath $archiveFullPath -DestinationPath $tempExtractPath
        if (-not $isExtracted) {
            Write-Warning "Не удалось распаковать архив режима. Установите 7-Zip или распакуйте архив вручную."
            return
        }

        # 1. Карта (поиск по level.dat, перенос с оригинальным именем и настройка level-name)
        $levelDatFile = Get-ChildItem -LiteralPath $tempExtractPath -Recurse -Filter "level.dat" | Select-Object -First 1
        $worldSourceDir = $null

        if ($levelDatFile) {
            $worldSourceDir = $levelDatFile.Directory
            $worldFolderName = $worldSourceDir.Name

            if ($worldFolderName -ieq 'saves' -or $worldFolderName -ieq 'temp_mode_extract') {
                $worldFolderName = 'world'
            }

            $worldTarget = Join-Path -Path $TargetDirectory -ChildPath $worldFolderName
            if (Test-Path -LiteralPath $worldTarget) { Remove-Item -LiteralPath $worldTarget -Recurse -Force }
            Copy-Item -LiteralPath $worldSourceDir.FullName -Destination $worldTarget -Recurse -Force

            Set-ServerConfiguration -TargetDirectory $TargetDirectory -LevelName $worldFolderName
            Write-Host "    • Карта '$worldFolderName' установлена (server.properties: level-name=$worldFolderName)" -ForegroundColor Green
        }

        # 2. Моды (с автоматической фильтрацией OptiFine, BetterFoliage, tlskincape)
        $modsTarget = Join-Path -Path $TargetDirectory -ChildPath "mods"
        if (Test-Path -LiteralPath $modsTarget) {
            Get-ChildItem -LiteralPath $modsTarget -Filter "*.jar" | Remove-Item -Force
        } else {
            $null = New-Item -ItemType Directory -Path $modsTarget
        }

        $modsSource = Get-ChildItem -LiteralPath $tempExtractPath -Recurse -Directory |
            Where-Object { 
                $_.Name -ieq 'mods' -and 
                (-not $worldSourceDir -or -not $_.FullName.StartsWith($worldSourceDir.FullName, [System.StringComparison]::OrdinalIgnoreCase))
            } |
            Select-Object -First 1

        $clientOnlyFilters = @('*OptiFine*', '*BetterFoliage*', '*tlskincape*', '*tlskin*')
        $allJarFiles = if ($modsSource) {
            Get-ChildItem -LiteralPath $modsSource.FullName -Filter "*.jar"
        } else {
            Get-ChildItem -LiteralPath $tempExtractPath -Recurse -Filter "*.jar" |
                Where-Object { -not $worldSourceDir -or -not $_.FullName.StartsWith($worldSourceDir.FullName, [System.StringComparison]::OrdinalIgnoreCase) }
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

        # 3. Корневые контент-паки оружия (ModularWarfare, Flan, CustomNPCs), строго ВНЕ папки мира
        $contentPackNames = @('ModularWarfare', 'Flan', 'customnpcs')
        foreach ($folderName in $contentPackNames) {
            $foundPack = Get-ChildItem -LiteralPath $tempExtractPath -Recurse -Directory |
                Where-Object { 
                    $_.Name -ieq $folderName -and 
                    (-not $worldSourceDir -or -not $_.FullName.StartsWith($worldSourceDir.FullName, [System.StringComparison]::OrdinalIgnoreCase))
                } |
                Select-Object -First 1

            if ($foundPack) {
                $destFolder = Join-Path -Path $TargetDirectory -ChildPath $folderName
                if (Test-Path -LiteralPath $destFolder) { Remove-Item -LiteralPath $destFolder -Recurse -Force }
                Copy-Item -LiteralPath $foundPack.FullName -Destination $destFolder -Recurse -Force
                Write-Host "    • Контент-пак оружия '$folderName' установлен в корень сервера" -ForegroundColor Green
            }
        }

        # 4. Конфиги (строго вне папки мира)
        $configTarget = Join-Path -Path $TargetDirectory -ChildPath "config"
        $configSource = Get-ChildItem -LiteralPath $tempExtractPath -Recurse -Directory |
            Where-Object { 
                $_.Name -ieq 'config' -and 
                (-not $worldSourceDir -or -not $_.FullName.StartsWith($worldSourceDir.FullName, [System.StringComparison]::OrdinalIgnoreCase))
            } |
            Select-Object -First 1

        if ($configSource) {
            if (-not (Test-Path -LiteralPath $configTarget)) { $null = New-Item -ItemType Directory -Path $configTarget }
            Get-ChildItem -LiteralPath $configSource.FullName | ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination $configTarget -Recurse -Force
            }
            Write-Host "    • Конфигурации модов скопированы в 'config'" -ForegroundColor Green
        }

        # 5. Ресурспаки для игроков (если есть в архиве режима)
        $rpSource = Get-ChildItem -LiteralPath $tempExtractPath -Recurse -Directory |
            Where-Object { 
                $_.Name -ieq 'resourcepacks' -and 
                (-not $worldSourceDir -or -not $_.FullName.StartsWith($worldSourceDir.FullName, [System.StringComparison]::OrdinalIgnoreCase))
            } |
            Select-Object -First 1

        if ($rpSource) {
            $rpTarget = Join-Path -Path $TargetDirectory -ChildPath "resourcepacks"
            if (-not (Test-Path -LiteralPath $rpTarget)) { $null = New-Item -ItemType Directory -Path $rpTarget }
            Get-ChildItem -LiteralPath $rpSource.FullName | ForEach-Object {
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
# Точка входа скрипта (с защитой от внезапного закрытия консоли)
# ====================================================================

try {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              🎮  NAZZY STORY MODES — MINECRAFT FORGE 1.12.2 SERVER                   ║" -ForegroundColor Cyan
    Write-Host "║                Автоматический установщик сервера для Radmin VPN                      ║" -ForegroundColor DarkCyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    # [1/5] Поиск Java
    Write-Host "`n[1/5] 🔍 Сканирование установленных сред Java (алгоритм Prism Launcher)..." -ForegroundColor Yellow
    $foundJavas = Find-PrismJavaInstallations

    # Приоритет: Java 8 (64-bit)
    $selectedJava = $foundJavas |
        Where-Object { $_.IsJava8 -and $_.Is64Bit } |
        Select-Object -First 1

    if (-not $selectedJava) {
        $selectedJava = $foundJavas | Where-Object { $_.IsJava8 } | Select-Object -First 1
    }

    if (-not $selectedJava) {
        Write-Host "`n[!] Java 8 (64-bit) не найдена в системе!" -ForegroundColor Red
        if ($foundJavas.Count -gt 0) {
            Write-Host "Найденные неподходящие версии Java:" -ForegroundColor Yellow
            foreach ($j in $foundJavas) {
                Write-Host "  • $($j.Path) ($($j.Version), 64-bit: $($j.Is64Bit))" -ForegroundColor Gray
            }
        }
        Write-Host "`nДля работы Forge 1.12.2 требуется именно Java 8 (64-bit)." -ForegroundColor Yellow
        Write-Host "Скачайте установщик: https://www.java.com/en/download/manual.jsp" -ForegroundColor Cyan
        Write-Host "`nНажмите любую клавишу для выхода..." -ForegroundColor Gray
        [Console]::ReadKey($true) | Out-Null
        exit 1
    }

    Write-Host "  • Выбрана Java: $($selectedJava.Path)" -ForegroundColor Green
    Write-Host "  • Версия:       $($selectedJava.Version) (64-Bit: $($selectedJava.Is64Bit))" -ForegroundColor Gray

    # [2/5] Проверка папки сервера (защита от записи в системные папки Windows при запуске из Win+R)
    Write-Host "`n[2/5] 📁 Определение директории сервера..." -ForegroundColor Yellow
    $isSystemOrProtected = (
        $ServerPath.StartsWith($env:SystemRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        $ServerPath.StartsWith("${env:ProgramFiles}", [System.StringComparison]::OrdinalIgnoreCase) -or
        (${env:ProgramFiles(x86)} -and $ServerPath.StartsWith("${env:ProgramFiles(x86)}", [System.StringComparison]::OrdinalIgnoreCase)) -or
        $ServerPath -ieq $env:USERPROFILE
    )

    if ($isSystemOrProtected) {
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        $defaultServerDir = Join-Path -Path $desktopPath -ChildPath "NazzyServer"

        Write-Host "  • Обнаружен запуск из системной папки ($ServerPath)." -ForegroundColor DarkYellow
        Write-Host "  • Папка сервера по умолчанию: $defaultServerDir" -ForegroundColor Cyan
        $customInput = Read-Host "`n  Нажмите Enter для установки на Рабочий стол (или введите другой путь)"
        if ($customInput -and $customInput.Trim()) {
            $ServerPath = $customInput.Trim().Replace('"', '')
        } else {
            $ServerPath = $defaultServerDir
        }
    }

    # Проверка прав на запись в $ServerPath
    try {
        if (-not (Test-Path -LiteralPath $ServerPath)) {
            $null = New-Item -ItemType Directory -Path $ServerPath -Force
        }
        $testFile = Join-Path -Path $ServerPath -ChildPath ".write_perm_test"
        [System.IO.File]::WriteAllText($testFile, "test")
        Remove-Item -LiteralPath $testFile -Force -ErrorAction SilentlyContinue
    } catch {
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        $ServerPath = Join-Path -Path $desktopPath -ChildPath "NazzyServer"
        if (-not (Test-Path -LiteralPath $ServerPath)) {
            $null = New-Item -ItemType Directory -Path $ServerPath -Force
        }
        Write-Host "  • Внимание: запись в исходную папку ограничена. Перенаправлено в: $ServerPath" -ForegroundColor DarkYellow
    }

    Write-Host "  • Папка сервера: $ServerPath" -ForegroundColor Green

    # [3/5] Выбор режима
    $chosenModeConfig = $null
    if ($Mode -eq 'Interactive') {
        Write-Host "`n[3/5] 🎮 Выберите сюжетный режим для установки:" -ForegroundColor Yellow
        Write-Host "┌───┬──────────────────────────┬─────────────────────────────┬─────────────────┐" -ForegroundColor DarkGray
        Write-Host "│ № │ РЕЖИМ                    │ ОПИСАНИЕ                    │ ОСОБЕННОСТИ     │" -ForegroundColor Cyan
        Write-Host "├───┼──────────────────────────┼─────────────────────────────┼─────────────────┤" -ForegroundColor DarkGray
        Write-Host "│ 1 │ INFECTED v1.1            │ Выживание и мутации         │ Голосовой чат   │" -ForegroundColor White
        Write-Host "│ 2 │ OPERATION BLIZZARD       │ Арктика, холод и мутанты    │ Мод на оружие   │" -ForegroundColor White
        Write-Host "│ 3 │ PHASMOPHOBIA HALLOWEEN   │ Хоррор-расследование        │ Голосовой чат   │" -ForegroundColor White
        Write-Host "│ 4 │ SLASHER (Redwood)        │ Маньяк в лагере Редвуд      │ Голосовой чат   │" -ForegroundColor White
        Write-Host "│ 5 │ LABORATORY NZ            │ Секретная лаборатория       │ Мод на оружие   │" -ForegroundColor White
        Write-Host "│ 6 │ CROSSBATTLE              │ PvP перестрелки и арена     │ Мод на оружие   │" -ForegroundColor White
        Write-Host "│ 7 │ SCAVENGER                │ Сбор лута и эвакуация       │ Мод на оружие   │" -ForegroundColor White
        Write-Host "│ 0 │ Чистый сервер            │ Forge 1.12.2 без модов      │ Чистый мир      │" -ForegroundColor Gray
        Write-Host "└───┴──────────────────────────┴─────────────────────────────┴─────────────────┘" -ForegroundColor DarkGray

        $userInput = Read-Host "`nВведите номер режима [1-7] (по умолчанию: 0)"
        $modeKeys = @('Infected', 'Blizzard', 'Phasmophobia', 'Slasher', 'Laboratory', 'Crossbattle', 'Scavenger')
        if ($userInput -match '^[1-7]$') {
            $selectedKey = $modeKeys[[int]$userInput - 1]
            $chosenModeConfig = $Script:AvailableModes[$selectedKey]
            Write-Host "`n  • Выбран режим: $($chosenModeConfig.Name) ($($chosenModeConfig.Desc))" -ForegroundColor Green
        } else {
            Write-Host "`n  • Выбран чистый сервер Forge 1.12.2." -ForegroundColor Gray
        }
    } elseif ($Mode -ne 'None') {
        $chosenModeConfig = $Script:AvailableModes[$Mode]
        Write-Host "`n[3/5] 🎮 Режим передан через аргументы: $($chosenModeConfig.Name)" -ForegroundColor Green
    }

    # [4/5] Развёртывание Forge 1.12.2
    Write-Host "`n[4/5] ⚙️ Развёртывание ядра Forge 1.12.2 и библиотек..." -ForegroundColor Yellow
    $centralCache = Join-Path -Path $env:USERPROFILE -ChildPath ".mc_forge_base_1.12.2"
    $forgeVersionString = "1.12.2-14.23.5.2860"
    $forgeJarName = "forge-$forgeVersionString.jar"

    Initialize-ForgeBase -CacheDirectory $centralCache -ForgeVersion $forgeVersionString -JavaExecutable $selectedJava.Path

    if (-not (Test-Path -LiteralPath $ServerPath)) {
        $null = New-Item -ItemType Directory -Path $ServerPath -Force
    }

    Copy-Item -LiteralPath (Join-Path $centralCache $forgeJarName) -Destination $ServerPath -Force
    Copy-Item -LiteralPath (Join-Path $centralCache "minecraft_server.1.12.2.jar") -Destination $ServerPath -Force

    $targetLibraries = Join-Path -Path $ServerPath -ChildPath "libraries"
    if (-not (Test-Path -LiteralPath $targetLibraries)) {
        $null = New-Item -ItemType Directory -Path $targetLibraries -Force
    }
    Copy-Item -LiteralPath (Get-ChildItem -LiteralPath (Join-Path $centralCache "libraries")).FullName -Destination $targetLibraries -Recurse -Force
    Write-Host "  • Ядро Forge 1.12.2 и библиотеки успешно скопированы" -ForegroundColor Green

    Set-ServerConfiguration -TargetDirectory $ServerPath

    # [5/5] Установка режима
    Write-Host "`n[5/5] 📦 Установка модов, карты и файлов конфигурации..." -ForegroundColor Yellow
    if ($chosenModeConfig) {
        Invoke-ModeInstallation -ModeConfig $chosenModeConfig -TargetDirectory $ServerPath
    } else {
        $modsFolder = Join-Path -Path $ServerPath -ChildPath "mods"
        if (-not (Test-Path -LiteralPath $modsFolder)) { $null = New-Item -ItemType Directory -Path $modsFolder }
    }

    # Генерация start.bat с жёстко привязанной Java 8 и флагом автоподтверждения FML
    $batPath = Join-Path -Path $ServerPath -ChildPath "start.bat"
    $escapedJavaPath = $selectedJava.Path.Replace('"', '')

    $startScriptContent = @"
@echo off
chcp 65001 >nul
title Minecraft Server 1.12.2
set "JAVA_BIN=$escapedJavaPath"
echo ========================================================
echo Запуск сервера Forge 1.12.2...
echo (Автоподтверждение FML включено)
echo ========================================================
"%JAVA_BIN%" -Xms${MinRamGB}G -Xmx${MaxRamGB}G -Dfml.queryResult=confirm -jar $forgeJarName nogui
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Попытка запуска через системную java...
    java -Xms${MinRamGB}G -Xmx${MaxRamGB}G -Dfml.queryResult=confirm -jar $forgeJarName nogui
)
pause
"@
    Set-Content -LiteralPath $batPath -Value $startScriptContent -Encoding UTF8

    # Красивая карточка завершения
    $modeTitle = if ($chosenModeConfig) { $chosenModeConfig.Name } else { "Чистый сервер" }
    Write-Host "`n╔══════════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                         СЕРВЕР УСПЕШНО УСТАНОВЛЕН И ГОТОВ!                           ║" -ForegroundColor Green
    Write-Host "╠══════════════════════════════════════════════════════════════════════════════════════╣" -ForegroundColor Green
    Write-Host "║  • Установленный режим: $modeTitle" -ForegroundColor White
    Write-Host "║  • Директория сервера:  $ServerPath" -ForegroundColor White
    Write-Host "║  • Файл для запуска:    start.bat" -ForegroundColor White
    Write-Host "║  • Для игры по сети:    Запустите Radmin VPN и передайте друзьям свой IP:25565       ║" -ForegroundColor DarkCyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green

    if ($Mode -eq 'Interactive') {
        Write-Host "`n  [Enter] Запустить сервер прямо сейчас" -ForegroundColor Cyan
        Write-Host "  [Q]     Выйти (запустите позже через start.bat)" -ForegroundColor Gray
        $action = Read-Host "  Ваш выбор"
        if ($action -notmatch '^[qQйЙ]$') {
            Write-Host "`nЗапуск сервера в отдельном окне..." -ForegroundColor Green
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$batPath`"" -WorkingDirectory $ServerPath
        } else {
            Write-Host "`nСервер сохранён в: $ServerPath" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "`n╔══════════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║                                ОШИБКА УСТАНОВКИ                                      ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host "  • Сообщение: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  • Строка:    $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Gray
    Write-Host "`nНажмите любую клавишу для закрытия окна..." -ForegroundColor Yellow
    [Console]::ReadKey($true) | Out-Null
    exit 1
}
