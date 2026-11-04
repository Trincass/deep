$ErrorActionPreference = 'Continue'

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Executa como administrador.' -ForegroundColor Red
    return
}

$Data = "$env:ProgramData\PCSetup"
New-Item -ItemType Directory -Force $Data | Out-Null
$Backup = "$Data\backup.json"
$PlanFile = "$Data\powerplan.txt"

Add-Type -Namespace W -Name U -MemberDefinition '[DllImport("user32.dll")] public static extern bool SystemParametersInfo(int a, int b, int[] c, int d);'

function Load-Backup {
    if (Test-Path $Backup) { @(Get-Content $Backup -Raw | ConvertFrom-Json) } else { @() }
}

function Set-Reg($Path, $Name, $Value, $Type = 'DWord') {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    $old = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    $list = @(Load-Backup)
    if (-not ($list | Where-Object { $_.Path -eq $Path -and $_.Name -eq $Name })) {
        $list += [pscustomobject]@{
            Path    = $Path
            Name    = $Name
            Existed = ($null -ne $old)
            Value   = $(if ($old) { $old.$Name } else { $null })
            Type    = $Type
        }
        ConvertTo-Json -InputObject @($list) -Depth 3 | Set-Content $Backup
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
}

function Select-Items($Title, $Items) {
    Write-Host "`n$Title" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Items.Count; $i++) {
        Write-Host ('  [{0}] {1}' -f ($i + 1), $Items[$i].Name)
    }
    $r = Read-Host 'Numeros separados por virgula, A = todos, Enter = nenhum'
    if ($r -match '^[Aa]$') { return $Items }
    $idx = $r -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } |
        ForEach-Object { [int]$_ - 1 } | Where-Object { $_ -ge 0 -and $_ -lt $Items.Count }
    return @($idx | ForEach-Object { $Items[$_] })
}

function Install-App($a) {
    Write-Host "`n> $($a.Name)" -ForegroundColor Yellow
    if ($a.Winget -and (Get-Command winget -ErrorAction SilentlyContinue)) {
        foreach ($id in $a.Winget) {
            winget show --id $id --exact --accept-source-agreements *> $null
            if ($LASTEXITCODE -eq 0) {
                winget install --id $id --exact --silent --accept-package-agreements --accept-source-agreements
                return
            }
        }
    }
    if ($a.Url) {
        $f = Join-Path $env:TEMP $a.File
        Invoke-WebRequest $a.Url -OutFile $f -UseBasicParsing
        Start-Process $f -Wait
        return
    }
    if ($a.Page) {
        Write-Host 'Nao foi possivel instalar automaticamente. A abrir a pagina oficial.' -ForegroundColor DarkYellow
        Start-Process $a.Page
    }
}

function Menu-Apps {
    $apps = @(
        @{ Name = 'FiveM'; Url = 'https://runtime.fivem.net/client/FiveM.exe'; File = 'FiveM.exe'; Page = 'https://fivem.net/' },
        @{ Name = 'Rockstar Games Launcher'; Url = 'https://gamedownloads.rockstargames.com/public/installer/Rockstar-Games-Launcher.exe'; File = 'Rockstar-Games-Launcher.exe'; Page = 'https://www.rockstargames.com/downloads' },
        @{ Name = 'Epic Games Launcher'; Winget = @('EpicGames.EpicGamesLauncher'); Page = 'https://store.epicgames.com/download' },
        @{ Name = 'Steam'; Winget = @('Valve.Steam'); Page = 'https://store.steampowered.com/about/' },
        @{ Name = 'Discord'; Winget = @('Discord.Discord'); Page = 'https://discord.com/download' },
        @{ Name = 'Brave'; Winget = @('Brave.Brave'); Page = 'https://brave.com/download/' },
        @{ Name = 'Everything'; Winget = @('voidtools.Everything'); Page = 'https://www.voidtools.com/downloads/' },
        @{ Name = 'Detect It Easy (DIE)'; Winget = @('horsicq.DIE-engine'); Page = 'https://github.com/horsicq/DIE-engine/releases' }
    )
    foreach ($a in (Select-Items 'APPS' $apps)) { Install-App $a }
}

function Menu-Drivers {
    $cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
    $gpus = @(Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name })
    Write-Host "`nCPU: $cpu"
    Write-Host "GPU: $($gpus -join ' | ')"

    $items = @()
    if ($cpu -match 'Intel') {
        $items += @{ Name = 'Intel Driver & Support Assistant (CPU/chipset)'; Winget = @('Intel.IntelDriverAndSupportAssistant'); Page = 'https://www.intel.com/content/www/us/en/support/detect.html' }
    }
    elseif ($cpu -match 'AMD') {
        $items += @{ Name = 'AMD Chipset Drivers (CPU/chipset)'; Winget = @('AMD.AMDChipsetDrivers'); Page = 'https://www.amd.com/en/support/download/drivers.html' }
    }
    $hasNv = [bool]($gpus | Where-Object { $_ -match 'NVIDIA' })
    if ($hasNv) {
        $items += @{ Name = 'NVIDIA App (GPU)'; Winget = @('Nvidia.NvidiaApp', 'Nvidia.GeForceExperience'); Page = 'https://www.nvidia.com/en-us/software/nvidia-app/' }
    }
    if (-not $hasNv -and ($gpus | Where-Object { $_ -match 'AMD|Radeon' })) {
        $items += @{ Name = 'AMD Adrenalin (GPU)'; Winget = @(); Page = 'https://www.amd.com/en/support/download/drivers.html' }
    }
    if ($gpus | Where-Object { $_ -match 'Intel' }) {
        if (-not ($items | Where-Object { $_.Name -like 'Intel*' })) {
            $items += @{ Name = 'Intel Driver & Support Assistant (GPU)'; Winget = @('Intel.IntelDriverAndSupportAssistant'); Page = 'https://www.intel.com/content/www/us/en/support/detect.html' }
        }
    }
    if (-not $items) { Write-Host 'Nenhum driver detetado.'; return }
    foreach ($a in (Select-Items 'DRIVERS' $items)) { Install-App $a }
}

$Tweaks = @(
    @{ Name = 'Tema escuro (apps e sistema)'; Do = {
            $p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
            Set-Reg $p 'AppsUseLightTheme' 0
            Set-Reg $p 'SystemUsesLightTheme' 0
        }
    },
    @{ Name = 'Plano de energia Alto desempenho'; Do = {
            $cur = (powercfg /getactivescheme) -join ' '
            if ($cur -match '([0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12})' -and -not (Test-Path $PlanFile)) {
                Set-Content $PlanFile $Matches[1]
            }
            $hp = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
            powercfg /setactive $hp 2> $null
            if ($LASTEXITCODE -ne 0) {
                $o = (powercfg /duplicatescheme $hp) -join ' '
                if ($o -match '([0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12})') { powercfg /setactive $Matches[1] }
            }
        }
    },
    @{ Name = 'Reduzir telemetria, publicidade e sugestoes'; Do = {
            Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0
            Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
            Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
            Set-Reg 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0
            $cd = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            foreach ($n in 'SilentInstalledAppsEnabled', 'SystemPaneSuggestionsEnabled', 'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled', 'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled') {
                Set-Reg $cd $n 0
            }
        }
    },
    @{ Name = 'Desativar Melhorar precisao do ponteiro'; Do = {
            $m = 'HKCU:\Control Panel\Mouse'
            Set-Reg $m 'MouseSpeed' '0' 'String'
            Set-Reg $m 'MouseThreshold1' '0' 'String'
            Set-Reg $m 'MouseThreshold2' '0' 'String'
            [W.U]::SystemParametersInfo(4, 0, [int[]](0, 0, 0), 3) | Out-Null
        }
    },
    @{ Name = 'Explorador: esconder ficheiros recentes e pastas frequentes'; Do = {
            $e = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
            Set-Reg $e 'ShowRecent' 0
            Set-Reg $e 'ShowFrequent' 0
        }
    }
)

function Menu-Tweaks {
    $sel = Select-Items 'OTIMIZACOES E SETTINGS' $Tweaks
    if (-not $sel) { return }
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
        Checkpoint-Computer -Description 'PCSetup' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Host 'Ponto de restauro criado.' -ForegroundColor Green
    }
    catch { Write-Host 'Ponto de restauro nao criado (Windows limita a 1 por 24h).' -ForegroundColor DarkYellow }
    foreach ($t in $sel) {
        Write-Host "> $($t.Name)" -ForegroundColor Yellow
        & $t.Do
    }
    $r = Read-Host 'Reiniciar o Explorador para aplicar o tema agora? (s/N)'
    if ($r -match '^[sSyY]') { Stop-Process -Name explorer -Force }
}

function Menu-Bloat {
    $list = @(
        @{ Name = 'Noticias (Bing News)'; Id = 'Microsoft.BingNews' },
        @{ Name = 'Meteorologia (Bing Weather)'; Id = 'Microsoft.BingWeather' },
        @{ Name = 'Obter Ajuda'; Id = 'Microsoft.GetHelp' },
        @{ Name = 'Sugestoes (Tips)'; Id = 'Microsoft.Getstarted' },
        @{ Name = 'Solitaire Collection'; Id = 'Microsoft.MicrosoftSolitaireCollection' },
        @{ Name = 'Microsoft 365 (Office Hub)'; Id = 'Microsoft.MicrosoftOfficeHub' },
        @{ Name = 'Pessoas'; Id = 'Microsoft.People' },
        @{ Name = 'Hub de Comentarios'; Id = 'Microsoft.WindowsFeedbackHub' },
        @{ Name = 'Filmes e TV'; Id = 'Microsoft.ZuneVideo' },
        @{ Name = 'Mixed Reality Portal'; Id = 'Microsoft.MixedReality.Portal' },
        @{ Name = '3D Viewer'; Id = 'Microsoft.Microsoft3DViewer' },
        @{ Name = 'Paint 3D / Print 3D'; Id = 'Microsoft.Print3D' },
        @{ Name = 'Skype'; Id = 'Microsoft.SkypeApp' },
        @{ Name = 'Cortana'; Id = 'Microsoft.549981C3F5F10' },
        @{ Name = 'Clipchamp'; Id = 'Clipchamp.Clipchamp' },
        @{ Name = 'Teams (chat pessoal)'; Id = 'MicrosoftTeams' },
        @{ Name = 'Power Automate'; Id = 'Microsoft.PowerAutomateDesktop' },
        @{ Name = 'OneConnect / Mobile Plans'; Id = 'Microsoft.OneConnect' },
        @{ Name = 'Candy Crush e jogos King'; Id = '*CandyCrush*' },
        @{ Name = 'Disney+'; Id = '*Disney*' },
        @{ Name = 'TikTok'; Id = '*TikTok*' },
        @{ Name = 'Facebook'; Id = '*Facebook*' },
        @{ Name = 'Instagram'; Id = '*Instagram*' },
        @{ Name = 'Netflix'; Id = '*Netflix*' },
        @{ Name = 'Prime Video'; Id = '*PrimeVideo*' },
        @{ Name = 'LinkedIn'; Id = '*LinkedIn*' }
    )
    $found = @($list | Where-Object { Get-AppxPackage -Name $_.Id -ErrorAction SilentlyContinue })
    if (-not $found) { Write-Host 'Nao ha bloatware da lista instalado.' -ForegroundColor Green; return }
    foreach ($b in (Select-Items 'BLOATWARE ENCONTRADO' $found)) {
        Write-Host "> A remover $($b.Name)" -ForegroundColor Yellow
        Get-AppxPackage -Name $b.Id | Remove-AppxPackage -ErrorAction SilentlyContinue
    }
}

function Undo-All {
    $list = @(Load-Backup)
    foreach ($e in $list) {
        if ($e.Existed) { Set-ItemProperty -Path $e.Path -Name $e.Name -Value $e.Value -Type $e.Type }
        else { Remove-ItemProperty -Path $e.Path -Name $e.Name -ErrorAction SilentlyContinue }
    }
    if (Test-Path $PlanFile) { powercfg /setactive (Get-Content $PlanFile -Raw).Trim() }
    [W.U]::SystemParametersInfo(4, 0, [int[]](6, 10, 1), 3) | Out-Null
    Remove-Item $Backup, $PlanFile -ErrorAction SilentlyContinue
    Write-Host 'Settings repostas. Bloatware removido reinstala-se pela Microsoft Store.' -ForegroundColor Green
}

while ($true) {
    Clear-Host
    Write-Host '=== PC SETUP ===' -ForegroundColor Cyan
    Write-Host ' [1] Instalar apps'
    Write-Host ' [2] Instalar drivers (CPU/GPU detetados)'
    Write-Host ' [3] Otimizacoes e settings'
    Write-Host ' [4] Remover bloatware'
    Write-Host ' [5] Tudo, passo a passo'
    Write-Host ' [6] Desfazer settings'
    Write-Host ' [0] Sair'
    switch (Read-Host 'Opcao') {
        '1' { Menu-Apps }
        '2' { Menu-Drivers }
        '3' { Menu-Tweaks }
        '4' { Menu-Bloat }
        '5' { Menu-Tweaks; Menu-Bloat; Menu-Drivers; Menu-Apps }
        '6' { Undo-All }
        '0' { return }
    }
    Read-Host "`nEnter para voltar ao menu"
}
