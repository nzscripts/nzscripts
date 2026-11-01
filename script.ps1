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
    Целевая директория сервера. По умолчанию текущая папка.

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
    'Infected'     = @{ Name = 'INFECTED v1.1';           File = 'INFECTED_v1.1_DISCORD.zip';         Type = 'Direct'; Url = 'https://cdn.discordapp.com/attachments/989644883390246922/1216449065005486251/INFECTED_v1.1_DISCORD.zip?ex=6ae82a39&is=6ae6d8b9&hm=0b0b93a02e8aeb62e58e80fa885c462226d2a0eab59ab606f2f00545e0bd83f0&' }
    'Blizzard'     = @{ Name = 'OPERATION BLIZZARD';      File = 'OPERATION_BLIZZARD.zip';    Type = 'Direct'; Url = 'https://cdn.discordapp.com/attachments/989644883390246922/1214709450280140880/OPERATION_BLIZZARD.zip?ex=6ae86d95&is=6ae71c15&hm=ecf6b2151bcc6150ef0fc95ce59eb79677698d5469510927b7ad15a03efdafed&' }
    'Phasmophobia' = @{ Name = 'PHASMOPHOBIA HALLOWEEN';  File = 'PHASMOPHOBIA_HALLOWEEN.rar';Type = 'Direct'; Url = 'https://cdn.discordapp.com/attachments/778261521800233022/905517032265617409/PHASMOPHOBIA_HALLOWEEN.rar?ex=6ae82734&is=6ae6d5b4&hm=9377702f3624aea35b6cd8b45e4a4d4b6342c6cb6d25ec256a6c012c44ccc790&' }
    'Slasher'      = @{ Name = 'SLASHER (Redwood)';       File = 'SLASHER_Redwood_.rar';       Type = 'Direct'; Url = 'https://cdn.discordapp.com/attachments/778261521800233022/897470764582830091/SLASHER_Redwood_.rar?ex=6ae88b48&is=6ae739c8&hm=c5356cf49c0a27b73f5632b07480c0366bf32eff190bf7ebd513ea7a3d124eda&' }
    'Laboratory'   = @{ Name = 'LABORATORY NZ';           File = 'LABORATORY_NZ.zip';         Type = 'Direct'; Url = 'https://cdn.discordapp.com/attachments/989644883390246922/1215231119906045973/LABORATORY_NZ.zip?ex=6ae8592c&is=6ae707ac&hm=af2b0c9eff80f5de18ceb15c5970996f36e6597890ede5029324d7e055b9442e&' }
    'Crossbattle'  = @{ Name = 'CROSSBATTLE';             File = 'CROSSBATTLE.rar';           Type = 'GDrive'; Id  = '1WcpiUfzsTZni503RDH_bquKiEYRg2pqj' }
    'Scavenger'    = @{ Name = 'SCAVENGER';               File = 'SCAVENGER.rar';             Type = 'GDrive'; Id  = '1NRzPSr0bxGgOuKVxj-aPFAMwvQk4sUle' }
}

function Find-PrismJavaInstallations {
    <#
    .SYNOPSIS
        Сканирует систему на наличие установок Java по аналогии с PrismLauncher JavaUtils.
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
        if (Test-Path -Path $candidate) { $candidates.Add($candidate) }
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
                    if (Test-Path -Path $exe) { $candidates.Add($exe) }
                }
            }
        }
    }

    # 4. Рантаймы лаунчеров Minecraft (.minecraft\runtime)
    $mcRuntime = Join-Path -Path $env:APPDATA -ChildPath ".minecraft\runtime"
    if (Test-Path -Path $mcRuntime) {
        Get-ChildItem -Path $mcRuntime -Recurse -Filter "java.exe" -ErrorAction SilentlyContinue | ForEach-Object {
            $candidates.Add($_.FullName)
        }
    }

    # 5. Program Files и Oracle javapath
    $programPaths = @(
        "$env:ProgramFiles\Java",
        "${env:ProgramFiles(x86)}\Java",
        "$env:ProgramData\Oracle\Java\javapath",
        "${env:ProgramFiles(x86)}\Common Files\Oracle\Java\java8path"
    )
    foreach ($dir in $programPaths) {
        if (Test-Path -Path $dir) {
            Get-ChildItem -Path $dir -Recurse -Filter "java.exe" -ErrorAction SilentlyContinue | ForEach-Object {
                $candidates.Add($_.FullName)
            }
        }
    }

    # 6. Валидация каждого кандидата через чистый процесс (Prism JavaChecker)
    $validJavas = @()
    $uniquePaths = $candidates | Where-Object { Test-Path -Path $_ } | Select-Object -Unique

    foreach ($exePath in $uniquePaths) {
        try {
            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = $exePath
            $pinfo.Arguments = "-version"
            $pinfo.RedirectStandardError = $true
            $pinfo.UseShellExecute = $false
            $pinfo.CreateNoWindow = $true

            # Очистка окружения от конфликтных флагов
            $pinfo.EnvironmentVariables.Remove("_JAVA_OPTIONS")
            $pinfo.EnvironmentVariables.Remove("JAVA_TOOL_OPTIONS")

            $proc = [System.Diagnostics.Process]::Start($pinfo)
            $output = $proc.StandardError.ReadToEnd()
            $proc.WaitForExit()

            $is64Bit = ($output -match '64-Bit')
            $versionMatch = [regex]::Match($output, 'version "(.*?)"')
            $versionStr = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { "Unknown" }
            $isJava8 = $versionStr.StartsWith("1.8.")

            $validJavas += [PSCustomObject]@{
                Path     = $exePath
                Version  = $versionStr
                Is64Bit  = $is64Bit
                IsJava8  = $isJava8
                RawInfo  = ($output -split "`r?`n")[0]
            }
        }
        catch {
            Write-Verbose "Java check failed for $($exePath)"
        }
    }

    return $validJavas
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

    $forgeJarPath = Join-Path -Path $CacheDirectory -ChildPath "forge-$ForgeVersion.jar"
    $serverJarPath = Join-Path -Path $CacheDirectory -ChildPath "minecraft_server.1.12.2.jar"
    $librariesDirectory = Join-Path -Path $CacheDirectory -ChildPath "libraries"

    $isBaseValid = (Test-Path -Path $forgeJarPath) -and
                   (Test-Path -Path $serverJarPath) -and
                   (Test-Path -Path $librariesDirectory)

    if ($isBaseValid) {
        Write-Verbose "Общее хранилище Forge валидно: $CacheDirectory"
        return
    }

    if ($PSCmdlet.ShouldProcess($CacheDirectory, "Создание базового ядра Forge $ForgeVersion")) {
        Write-Host "Создание центрального хранилища Forge (выполняется один раз на ПК)..." -ForegroundColor Yellow

        if (-not (Test-Path -Path $CacheDirectory)) {
            $null = New-Item -ItemType Directory -Path $CacheDirectory -Force
        }

        # Фикс org.ow2.asm:asm-debug-all:5.2
        $asmDirectory = Join-Path -Path $CacheDirectory -ChildPath "libraries\org\ow2\asm\asm-debug-all\5.2"
        if (-not (Test-Path -Path $asmDirectory)) {
            $null = New-Item -ItemType Directory -Path $asmDirectory -Force
        }
        $asmJar = Join-Path -Path $asmDirectory -ChildPath "asm-debug-all-5.2.jar"
        if (-not (Test-Path -Path $asmJar)) {
            Write-Verbose "Загрузка отсутствующей библиотеки asm-debug-all:5.2 из Maven Central..."
            $downloadParams = @{
                Uri             = "https://repo1.maven.org/maven2/org/ow2/asm/asm-debug-all/5.2/asm-debug-all-5.2.jar"
                OutFile         = $asmJar
                UseBasicParsing = $true
            }
            Invoke-WebRequest @downloadParams
        }

        # Фикс net.minecraft:launchwrapper:1.12
        $launchDir = Join-Path -Path $CacheDirectory -ChildPath "libraries\net\minecraft\launchwrapper\1.12"
        if (-not (Test-Path -Path $launchDir)) {
            $null = New-Item -ItemType Directory -Path $launchDir -Force
        }
        $launchJar = Join-Path -Path $launchDir -ChildPath "launchwrapper-1.12.jar"
        if (-not (Test-Path -Path $launchJar)) {
            Write-Verbose "Загрузка обязательной библиотеки launchwrapper-1.12.jar..."
            $launchParams = @{
                Uri             = "https://libraries.minecraft.net/net/minecraft/launchwrapper/1.12/launchwrapper-1.12.jar"
                OutFile         = $launchJar
                UseBasicParsing = $true
            }
            Invoke-WebRequest @launchParams
        }

        $installerUrl = "https://maven.minecraftforge.net/net/minecraftforge/forge/$ForgeVersion/forge-$ForgeVersion-installer.jar"
        $installerFilePath = Join-Path -Path $CacheDirectory -ChildPath "forge-installer.jar"
        
        Write-Host "Загрузка инсталлера Forge..." -ForegroundColor Yellow
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerFilePath -UseBasicParsing

        Write-Host "Распаковка библиотек ядра..." -ForegroundColor Yellow
        Push-Location -Path $CacheDirectory
        try {
            $processParams = @{
                FilePath     = $JavaExecutable
                ArgumentList = "-jar `"$installerFilePath`" --installServer"
                Wait         = $true
                PassThru     = $true
                NoNewWindow  = $true
            }
            $installProcess = Start-Process @processParams
            if ($installProcess.ExitCode -ne 0) {
                throw [System.InvalidOperationException]::new("Процесс установки Forge завершился с кодом: $($installProcess.ExitCode)")
            }
        }
        finally {
            Pop-Location
            Remove-Item -Path $installerFilePath -Force -ErrorAction SilentlyContinue
        }

        Write-Host "Базовое ядро Forge успешно инициализировано." -ForegroundColor Green
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
        foreach ($c in $common) { if (Test-Path $c) { $sevenZip = $c; break } }
    }
    if ($sevenZip) {
        & $sevenZip x "$ArchiveFilePath" "-o$DestinationPath" -y | Out-Null
        return ($LASTEXITCODE -eq 0)
    }

    $winrar = "${env:ProgramFiles}\WinRAR\WinRAR.exe"
    if (Test-Path $winrar) {
        & $winrar x -ibck "$ArchiveFilePath" "$DestinationPath\"
        return ($LASTEXITCODE -eq 0)
    }

    if (Get-Command -Name "tar.exe" -ErrorAction SilentlyContinue) {
        & tar.exe -xf "$ArchiveFilePath" -C "$DestinationPath" 2>$null
        if ($LASTEXITCODE -eq 0) { return $true }
    }

    # Резервный архиватор: портативный 7za.exe (скачивается автоматически, если на ПК нет архиватора)
    $portable7zDir = Join-Path -Path $env:USERPROFILE -ChildPath ".mc_forge_base_1.12.2"
    $portable7z = Join-Path -Path $portable7zDir -ChildPath "7za.exe"
    if (-not (Test-Path -LiteralPath $portable7z)) {
        try {
            Write-Host "Загрузка автономного модуля распаковки .rar архивов..." -ForegroundColor Yellow
            $7zZipUrl = "https://www.7-zip.org/a/7za920.zip"
            $temp7zZip = Join-Path -Path $env:TEMP -ChildPath "7za920.zip"
            if (-not (Test-Path -LiteralPath $portable7zDir)) { $null = New-Item -ItemType Directory -Path $portable7zDir -Force }
            Invoke-WebRequest -Uri $7zZipUrl -OutFile $temp7zZip -UseBasicParsing
            Expand-Archive -Path $temp7zZip -DestinationPath $portable7zDir -Force
            Remove-Item -Path $temp7zZip -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Verbose "Не удалось скачать 7za.exe: $_"
        }
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
    if (Test-Path -Path $serverPropertiesPath) {
        Get-Content -Path $serverPropertiesPath | ForEach-Object {
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
        $propertiesLines = @("# Minecraft Server Properties (Configured by setup.ps1)")
        foreach ($key in $currentSettings.Keys) {
            $propertiesLines += "$key=$($currentSettings[$key])"
        }
        $propertiesLines | Set-Content -Path $serverPropertiesPath -Encoding UTF8
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
    $searchCandidates = @(
        (Join-Path -Path $TargetDirectory -ChildPath $archiveName),
        (Join-Path -Path $TargetDirectory -ChildPath "builds_cache\$archiveName"),
        (Join-Path -Path $PSScriptRoot -ChildPath "builds_cache\$archiveName"),
        (Join-Path -Path "C:\Users\Seilce\Desktop\ss\builds_cache" -ChildPath $archiveName)
    )
    $archiveFullPath = $searchCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

    if (-not $archiveFullPath) {
        $archiveFullPath = Join-Path -Path $TargetDirectory -ChildPath $archiveName
        Write-Host "Загрузка архива режима '$($ModeConfig.Name)'..." -ForegroundColor Yellow
        $hasCurl = [bool](Get-Command -Name "curl.exe" -ErrorAction SilentlyContinue)

        $downloaded = $false
        # 1. Попытка загрузки из GitHub Releases
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
        Write-Host "Распаковка содержимого режима..." -ForegroundColor Yellow
        $isExtracted = Expand-ArchivePackage -ArchiveFilePath $archiveFullPath -DestinationPath $tempExtractPath
        if (-not $isExtracted) {
            Write-Warning "Не удалось автоматически распаковать архив. Установите 7-Zip или распакуйте вручную."
            return
        }

        # 1. Карта (поиск по level.dat, перенос с оригинальным именем и настройка level-name)
        $levelDatFile = Get-ChildItem -LiteralPath $tempExtractPath -Recurse -Filter "level.dat" | Select-Object -First 1
        $worldSourceDir = $null

        if ($levelDatFile) {
            $worldSourceDir = $levelDatFile.Directory
            $worldFolderName = $worldSourceDir.Name

            # Если имя папки было просто 'saves' или не определено, используем 'world'
            if ($worldFolderName -ieq 'saves' -or $worldFolderName -ieq 'temp_mode_extract') {
                $worldFolderName = 'world'
            }

            $worldTarget = Join-Path -Path $TargetDirectory -ChildPath $worldFolderName
            if (Test-Path -LiteralPath $worldTarget) { Remove-Item -LiteralPath $worldTarget -Recurse -Force }
            Copy-Item -LiteralPath $worldSourceDir.FullName -Destination $worldTarget -Recurse -Force

            # Обновляем server.properties, чтобы сервер загружал именно этот мир
            Set-ServerConfiguration -TargetDirectory $TargetDirectory -LevelName $worldFolderName
            Write-Host "Карта '$worldFolderName' перенесена, в server.properties установлен level-name=$worldFolderName." -ForegroundColor Green
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
            }
        }
        Write-Host "Моды скопированы в 'mods' (клиентские моды отфильтрованы)." -ForegroundColor Green

        # 3. Корневые контент-паки оружия/моделей (ModularWarfare, Flan, CustomNPCs), строго ВНЕ папки мира
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
                Write-Host "Контент-пак '$folderName' скопирован в корень сервера." -ForegroundColor Green
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
            Write-Host "Конфигурации скопированы в папку 'config'." -ForegroundColor Green
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
            Write-Host "Ресурспак режима сохранён в папку 'resourcepacks' (передайте его игрокам)!" -ForegroundColor Cyan
        }
    }
    finally {
        Remove-Item -LiteralPath $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ====================================================================
# Точка входа скрипта
# ====================================================================

Write-Host "Поиск установленных сред Java (алгоритм Prism Launcher)..." -ForegroundColor Yellow
$foundJavas = Find-PrismJavaInstallations

# Приоритет: Java 8 (64-bit)
$selectedJava = $foundJavas |
    Where-Object { $_.IsJava8 -and $_.Is64Bit } |
    Select-Object -First 1

if (-not $selectedJava) {
    # Запасной вариант: любая Java 8
    $selectedJava = $foundJavas | Where-Object { $_.IsJava8 } | Select-Object -First 1
}

if (-not $selectedJava) {
    Write-Host "`n[ОШИБКА] Подходящая Java 8 не найдена!" -ForegroundColor Red
    if ($foundJavas.Count -gt 0) {
        Write-Host "В системе найдены неподходящие версии Java:" -ForegroundColor Yellow
        foreach ($j in $foundJavas) {
            Write-Host "  - $($j.Path) ($($j.Version), 64-bit: $($j.Is64Bit))" -ForegroundColor Gray
        }
        Write-Host "Для сервера Forge 1.12.2 строго требуется Java 8 (64-bit)." -ForegroundColor Yellow
    }
    Write-Host "Скачать Java 8 (Windows Offline 64-bit): https://www.java.com/en/download/manual.jsp" -ForegroundColor Cyan
    Pause
    exit 1
}

Write-Host "Выбрана Java: $($selectedJava.Path)" -ForegroundColor Green
Write-Host "Версия: $($selectedJava.Version) | 64-Bit: $($selectedJava.Is64Bit)" -ForegroundColor Gray

# Выбор режима
# Проверка запуска через Win + R (когда рабочая директория - профиль пользователя или System32)
if ($ServerPath -ieq $env:USERPROFILE -or $ServerPath -ieq "$env:SystemRoot\System32" -or $ServerPath -ieq $env:SystemRoot) {
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $defaultServerDir = Join-Path -Path $desktopPath -ChildPath "NazzyServer"

    Write-Host "`n[Win + R] Обнаружен запуск из диалогового окна 'Выполнить'." -ForegroundColor Yellow
    Write-Host "Папка сервера по умолчанию: $defaultServerDir" -ForegroundColor Cyan
    $customInput = Read-Host "Нажмите Enter для создания сервера в этой папке (или укажите свой путь)"
    if ($customInput -and $customInput.Trim()) {
        $ServerPath = $customInput.Trim().Replace('"', '')
    } else {
        $ServerPath = $defaultServerDir
    }
}

$chosenModeConfig = $null
if ($Mode -eq 'Interactive') {
    Write-Host "`nДоступные режимы для установки:" -ForegroundColor White
    $modeKeys = @('Infected', 'Blizzard', 'Phasmophobia', 'Slasher', 'Laboratory', 'Crossbattle', 'Scavenger')
    for ($i = 0; $i -lt $modeKeys.Count; $i++) {
        $key = $modeKeys[$i]
        Write-Host "  [$($i + 1)] $($Script:AvailableModes[$key].Name)" -ForegroundColor Cyan
    }
    Write-Host "  [0] Чистый сервер (без модов и карты)" -ForegroundColor Gray

    $userInput = Read-Host "`nВведите номер режима (0 по умолчанию)"
    if ($userInput -match '^[1-7]$') {
        $selectedKey = $modeKeys[[int]$userInput - 1]
        $chosenModeConfig = $Script:AvailableModes[$selectedKey]
        Write-Host "`nВыбран режим: $($chosenModeConfig.Name)" -ForegroundColor Green
    } else {
        Write-Host "`nВыбран чистый сервер." -ForegroundColor Gray
    }
} elseif ($Mode -ne 'None') {
    $chosenModeConfig = $Script:AvailableModes[$Mode]
}

# Инициализация центральной базы Forge
$centralCache = Join-Path -Path $env:USERPROFILE -ChildPath ".mc_forge_base_1.12.2"
$forgeVersionString = "1.12.2-14.23.5.2860"
$forgeJarName = "forge-$forgeVersionString.jar"

Initialize-ForgeBase -CacheDirectory $centralCache -ForgeVersion $forgeVersionString -JavaExecutable $selectedJava.Path

# Копирование ядра и библиотек
if (-not (Test-Path -LiteralPath $ServerPath)) {
    $null = New-Item -ItemType Directory -Path $ServerPath -Force
}

Write-Host "`nРазвёртывание ядра Forge в целевую директорию..." -ForegroundColor Yellow
Copy-Item -LiteralPath (Join-Path $centralCache $forgeJarName) -Destination $ServerPath -Force
Copy-Item -LiteralPath (Join-Path $centralCache "minecraft_server.1.12.2.jar") -Destination $ServerPath -Force

$targetLibraries = Join-Path -Path $ServerPath -ChildPath "libraries"
if (-not (Test-Path -LiteralPath $targetLibraries)) {
    $null = New-Item -ItemType Directory -Path $targetLibraries -Force
}
Copy-Item -LiteralPath (Get-ChildItem -LiteralPath (Join-Path $centralCache "libraries")).FullName -Destination $targetLibraries -Recurse -Force
Write-Host "Ядро и библиотеки развёрнуты." -ForegroundColor Green

Set-ServerConfiguration -TargetDirectory $ServerPath

if ($chosenModeConfig) {
    Invoke-ModeInstallation -ModeConfig $chosenModeConfig -TargetDirectory $ServerPath
} else {
    $modsFolder = Join-Path -Path $ServerPath -ChildPath "mods"
    if (-not (Test-Path -Path $modsFolder)) { $null = New-Item -ItemType Directory -Path $modsFolder }
}

# Генерация start.bat с жёстко привязанной Java 8 (как в Prism Launcher)
$batPath = Join-Path -Path $ServerPath -ChildPath "start.bat"
$escapedJavaPath = $selectedJava.Path.Replace('"', '')

$startScriptContent = @"
@echo off
chcp 65001 >nul
title Minecraft Server 1.12.2
set "JAVA_BIN=$escapedJavaPath"
echo Запуск сервера Forge 1.12.2 (автоподтверждение FML включено)...
"%JAVA_BIN%" -Xms${MinRamGB}G -Xmx${MaxRamGB}G -Dfml.queryResult=confirm -jar $forgeJarName nogui
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Попытка запуска через системную java...
    java -Xms${MinRamGB}G -Xmx${MaxRamGB}G -Dfml.queryResult=confirm -jar $forgeJarName nogui
)
pause
"@
Set-Content -Path $batPath -Value $startScriptContent -Encoding UTF8

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "  Сервер готов к запуску! Файл запуска: start.bat" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Cyan

if ($Mode -eq 'Interactive') {
    $runNow = Read-Host "`nЗапустить сервер прямо сейчас? (Y/N, Enter = Y)"
    if ($runNow -eq '' -or $runNow -ieq 'Y' -or $runNow -ieq 'Д') {
        Write-Host "Запуск сервера..." -ForegroundColor Green
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$batPath`"" -WorkingDirectory $ServerPath
    } else {
        Write-Host "Для запуска сервера откройте файл: $batPath" -ForegroundColor Cyan
        Pause
    }
}
