$Version = '1.0.0'
$Repo = 'Trincass/deep'
$Branch = 'main'
$Raw = "https://raw.githubusercontent.com/$Repo/$Branch/setup.ps1"

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    if ($PSCommandPath) {
        Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`""
    }
    else {
        Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', "irm $Raw | iex"
    }
    return
}

if ($Repo -notlike 'YOUR_USER*') {
    try {
        $remote = (Invoke-WebRequest "$Raw`?t=$([DateTime]::UtcNow.Ticks)" -UseBasicParsing -TimeoutSec 8).Content
        if ($remote -match "\`$Version\s*=\s*'([\d\.]+)'") {
            if ([version]$Matches[1] -gt [version]$Version) {
                if ($PSCommandPath) {
                    Set-Content -Path $PSCommandPath -Value $remote -Encoding UTF8
                    Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`""
                }
                else {
                    Invoke-Expression $remote
                }
                return
            }
        }
    }
    catch { }
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

$fxSource = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

public class FxPanel : Panel
{
    class Particle { public float X, Y, Size, Speed, Phase; }
    List<Particle> list = new List<Particle>();
    Random rnd = new Random();
    Timer timer = new Timer();
    public string Mode = "snow";
    public string Title = "";
    public string Sub = "";
    public Color Accent = Color.FromArgb(110, 170, 255);

    public FxPanel()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        timer.Interval = 33;
        timer.Tick += delegate { Step(); Invalidate(); };
        timer.Start();
    }

    public void SetMode(string m) { Mode = m; list.Clear(); }

    Particle Make(bool anywhere)
    {
        Particle p = new Particle();
        p.X = (float)(rnd.NextDouble() * (Width + 80));
        p.Y = anywhere ? (float)(rnd.NextDouble() * Height) : -12f;
        p.Phase = (float)(rnd.NextDouble() * 100);
        if (Mode == "snow") { p.Size = 1.5f + (float)rnd.NextDouble() * 3f; p.Speed = 0.6f + p.Size * 0.45f; }
        else { p.Size = 8f + (float)rnd.NextDouble() * 10f; p.Speed = 9f + (float)rnd.NextDouble() * 8f; }
        return p;
    }

    void Step()
    {
        if (Width < 10 || Height < 10) return;
        int target = Mode == "snow" ? 120 : (Mode == "rain" ? 160 : 0);
        while (list.Count < target) list.Add(Make(true));
        while (list.Count > target) list.RemoveAt(list.Count - 1);
        foreach (Particle p in list)
        {
            p.Y += p.Speed;
            if (Mode == "snow") p.X += (float)Math.Sin((p.Y + p.Phase) / 28f) * 0.7f;
            else p.X -= p.Speed * 0.15f;
            if (p.Y > Height + 10 || p.X < -20 || p.X > Width + 20)
            {
                Particle q = Make(false);
                p.X = q.X;
                p.Y = q.Y;
            }
        }
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        if (Width < 2 || Height < 2) return;
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        Color c1 = Color.FromArgb(12, 20, 38);
        Color c2 = Color.FromArgb(34, 58, 96);
        if (Mode == "rain") { c1 = Color.FromArgb(10, 16, 22); c2 = Color.FromArgb(24, 44, 56); }
        if (Mode == "off") { c1 = Color.FromArgb(16, 18, 26); c2 = Color.FromArgb(34, 36, 56); }
        using (LinearGradientBrush bg = new LinearGradientBrush(ClientRectangle, c1, c2, 90f))
        {
            g.FillRectangle(bg, ClientRectangle);
        }
        if (Mode == "snow")
        {
            using (SolidBrush b = new SolidBrush(Color.FromArgb(200, 255, 255, 255)))
            {
                foreach (Particle p in list) g.FillEllipse(b, p.X, p.Y, p.Size, p.Size);
            }
        }
        else if (Mode == "rain")
        {
            using (Pen pen = new Pen(Color.FromArgb(120, Accent), 1f))
            {
                foreach (Particle p in list) g.DrawLine(pen, p.X, p.Y, p.X + p.Size * 0.2f, p.Y - p.Size);
            }
        }
        using (Font f1 = new Font("Segoe UI Semibold", 30f))
        using (Font f2 = new Font("Segoe UI", 10.5f))
        using (SolidBrush tb = new SolidBrush(Color.White))
        using (SolidBrush sb = new SolidBrush(Color.FromArgb(190, 200, 220)))
        using (SolidBrush ab = new SolidBrush(Accent))
        {
            g.DrawString(Title, f1, tb, 24, 22);
            g.FillRectangle(ab, 28, 78, 46, 3);
            g.DrawString(Sub, f2, sb, 26, 90);
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) timer.Stop();
        base.Dispose(disposing);
    }
}
'@
if (-not ('FxPanel' -as [type])) {
    Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition $fxSource
}

Add-Type -Namespace W -Name U -MemberDefinition '[DllImport("user32.dll")] public static extern bool SystemParametersInfo(int a, int b, int[] c, int d);'

$Dl = Join-Path (Join-Path $env:USERPROFILE 'Downloads') 'deep'
$Data = Join-Path $env:ProgramData 'deep'
New-Item -ItemType Directory -Force $Dl, $Data | Out-Null
$BackupFile = Join-Path $Data 'backup.json'
$PlanFile = Join-Path $Data 'powerplan.txt'

function C($r, $g, $b) { [Drawing.Color]::FromArgb($r, $g, $b) }
$cBg = C 16 18 24
$cCard = C 24 28 37
$cActive = C 44 50 66
$cText = C 232 235 242
$cMuted = C 142 150 168

$Themes = @{
    'Snowfall' = @{ Mode = 'snow'; Accent = (C 110 170 255) }
    'Rainfall' = @{ Mode = 'rain'; Accent = (C 70 190 180) }
    'Off'      = @{ Mode = 'off'; Accent = (C 120 140 255) }
}

function Wait-Proc($p) {
    $null = $p.Handle
    while (-not $p.HasExited) {
        [Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 40
    }
    $p.ExitCode
}

function Get-File($url, $name) {
    $path = Join-Path $Dl $name
    $wc = New-Object Net.WebClient
    $wc.Headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) deep'
    try {
        $t = $wc.DownloadFileTaskAsync($url, $path)
        while (-not $t.IsCompleted) {
            [Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 30
        }
        if ($t.IsFaulted) { throw $t.Exception.InnerException }
    }
    finally { $wc.Dispose() }
    $path
}

function Get-GhAsset($repo, $patterns) {
    $rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'deep' }
    foreach ($pat in $patterns) {
        $a = $rel.assets | Where-Object { $_.name -match $pat -and $_.name -notmatch 'arm64' } | Select-Object -First 1
        if ($a) { return @{ Url = $a.browser_download_url; File = $a.name } }
    }
    throw "No matching release asset for $repo"
}

function New-Shortcut($target, $name) {
    $ws = New-Object -ComObject WScript.Shell
    foreach ($dir in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs'))) {
        $s = $ws.CreateShortcut((Join-Path $dir "$name.lnk"))
        $s.TargetPath = $target
        $s.WorkingDirectory = Split-Path $target
        $s.Save()
    }
}

function Test-Winget { [bool](Get-Command winget -ErrorAction SilentlyContinue) }

function Install-Winget($id) {
    if (-not (Test-Winget)) { return $false }
    $p = Start-Process winget -ArgumentList "show --id $id -e --accept-source-agreements" -PassThru -WindowStyle Hidden
    if ((Wait-Proc $p) -ne 0) { return $false }
    $p = Start-Process winget -ArgumentList "install --id $id -e --silent --accept-package-agreements --accept-source-agreements" -PassThru -WindowStyle Hidden
    (Wait-Proc $p) -eq 0
}

$AppDefs = [ordered]@{
    fivem      = @{ Name = 'FiveM'; Kind = 'fivem'; Url = 'https://runtime.fivem.net/client/FiveM.exe'; File = 'FiveM.exe' }
    rockstar   = @{ Name = 'Rockstar Games Launcher'; Kind = 'exe'; Url = 'https://gamedownloads.rockstargames.com/public/installer/Rockstar-Games-Launcher.exe'; File = 'Rockstar-Games-Launcher.exe'; Args = '/S' }
    epic       = @{ Name = 'Epic Games Launcher'; Kind = 'msi'; Url = 'https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi'; File = 'EpicGamesLauncherInstaller.msi'; Winget = 'EpicGames.EpicGamesLauncher' }
    steam      = @{ Name = 'Steam'; Kind = 'exe'; Url = 'https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe'; File = 'SteamSetup.exe'; Args = '/S'; Winget = 'Valve.Steam' }
    discord    = @{ Name = 'Discord'; Kind = 'exe'; Url = 'https://discord.com/api/download?platform=win'; File = 'DiscordSetup.exe'; Args = '-s'; Winget = 'Discord.Discord' }
    brave      = @{ Name = 'Brave'; Kind = 'exe'; Url = 'https://laptop-updates.brave.com/latest/winx64'; File = 'BraveBrowserSetup.exe'; Args = '/silent /install'; Winget = 'Brave.Brave' }
    everything = @{ Name = 'Everything'; Kind = 'exe'; Args = '/S'; Winget = 'voidtools.Everything'
        Resolve = {
            $page = Invoke-WebRequest 'https://www.voidtools.com/downloads/' -UseBasicParsing
            $href = $page.Links.href | Where-Object { $_ -match 'Everything-[\d\.]+\.x64-Setup\.exe$' } | Select-Object -First 1
            if (-not $href) { throw 'Everything installer link not found' }
            if ($href -notmatch '^https?://') { $href = 'https://www.voidtools.com/' + $href.TrimStart('/') }
            @{ Url = $href; File = Split-Path $href -Leaf }
        }
    }
    die        = @{ Name = 'Detect It Easy (DIE)'; Kind = 'zip'; Folder = 'Detect It Easy'; Exe = 'die.exe'; Winget = 'horsicq.DIE-engine'
        Resolve = { Get-GhAsset 'horsicq/DIE-engine' @('(?i)win64.*portable.*\.zip$', '(?i)win64.*\.zip$') }
    }
    obs        = @{ Name = 'OBS Studio'; Kind = 'exe'; Args = '/S'; Winget = 'OBSProject.OBSStudio'
        Resolve = { Get-GhAsset 'obsproject/obs-studio' @('Windows.*x64.*Installer\.exe$', 'Windows.*Installer\.exe$') }
    }
}

function Install-App($key) {
    $a = $AppDefs[$key]
    $url = $a.Url
    $file = $a.File
    $done = $false
    try {
        if ($a.Resolve) {
            $r = & $a.Resolve
            $url = $r.Url
            $file = $r.File
        }
        Write-Log "Downloading $($a.Name)..."
        $path = Get-File $url $file
        Write-Log "Installing $($a.Name)..."
        switch ($a.Kind) {
            'exe' {
                $p = Start-Process $path -ArgumentList $a.Args -PassThru
                $code = Wait-Proc $p
                $done = ($code -eq 0 -or $code -eq 3010)
            }
            'msi' {
                $p = Start-Process msiexec.exe -ArgumentList "/i `"$path`" /qn /norestart" -PassThru
                $code = Wait-Proc $p
                $done = ($code -eq 0 -or $code -eq 3010)
            }
            'zip' {
                $dest = Join-Path $env:ProgramFiles $a.Folder
                if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
                Expand-Archive -Path $path -DestinationPath $dest -Force
                $exe = Get-ChildItem $dest -Recurse -Filter $a.Exe | Select-Object -First 1
                if ($exe) {
                    New-Shortcut $exe.FullName $a.Name
                    $done = $true
                }
            }
            'fivem' {
                $dest = Join-Path $env:LOCALAPPDATA 'FiveM'
                New-Item -ItemType Directory -Force $dest | Out-Null
                Copy-Item $path (Join-Path $dest 'FiveM.exe') -Force
                New-Shortcut (Join-Path $dest 'FiveM.exe') 'FiveM'
                $done = $true
            }
        }
    }
    catch { Write-Log "Direct install failed: $($_.Exception.Message)" }
    if (-not $done -and $a.Winget) {
        Write-Log "Trying winget for $($a.Name)..."
        $done = Install-Winget $a.Winget
    }
    if ($done) { Write-Log "OK: $($a.Name)" } else { Write-Log "FAILED: $($a.Name)" }
}

function Open-Page($url) {
    Start-Process $url
    Write-Log "Opened the official download page: $url"
}

function Install-Chipset {
    $cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
    Write-Log "Chipset/CPU drivers for: $cpu"
    if ($cpu -match 'Intel') {
        Write-Log 'Downloading Intel Driver & Support Assistant...'
        if (-not (Install-Winget 'Intel.IntelDriverAndSupportAssistant')) { Open-Page 'https://www.intel.com/content/www/us/en/support/detect.html' }
    }
    elseif ($cpu -match 'AMD') {
        Open-Page 'https://www.amd.com/en/support/download/drivers.html'
    }
    else {
        Write-Log 'Unknown CPU vendor, skipped.'
    }
}

function Install-Gpu {
    $gpus = @(Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name })
    Write-Log "Graphics drivers for: $($gpus -join ', ')"
    if ($gpus -match 'NVIDIA') {
        Write-Log 'Installing NVIDIA App...'
        if (-not (Install-Winget 'Nvidia.NvidiaApp') -and -not (Install-Winget 'Nvidia.GeForceExperience')) {
            Open-Page 'https://www.nvidia.com/en-us/software/nvidia-app/'
        }
    }
    elseif ($gpus -match 'AMD|Radeon') {
        Open-Page 'https://www.amd.com/en/support/download/drivers.html'
    }
    elseif ($gpus -match 'Intel') {
        Write-Log 'Downloading Intel Driver & Support Assistant...'
        if (-not (Install-Winget 'Intel.IntelDriverAndSupportAssistant')) { Open-Page 'https://www.intel.com/content/www/us/en/support/detect.html' }
    }
    else {
        Write-Log 'Unknown GPU vendor, skipped.'
    }
}

function Load-Backup {
    if (Test-Path $BackupFile) { @(Get-Content $BackupFile -Raw | ConvertFrom-Json) } else { @() }
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
        ConvertTo-Json -InputObject @($list) -Depth 3 | Set-Content $BackupFile
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
}

$TweakActions = @{
    dark      = {
        $p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        Set-Reg $p 'AppsUseLightTheme' 0
        Set-Reg $p 'SystemUsesLightTheme' 0
    }
    power     = {
        $cur = (powercfg /getactivescheme) -join ' '
        if ($cur -match '([0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12})' -and -not (Test-Path $PlanFile)) {
            Set-Content $PlanFile $Matches[1]
        }
        $all = (powercfg /list) -join "`n"
        $guid = $null
        if ($all -match '([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})\s+\(Ultimate Performance\)') { $guid = $Matches[1] }
        if (-not $guid) {
            $o = (powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61) -join ' '
            if ($o -match '([0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12})') { $guid = $Matches[1] }
        }
        if ($guid) { powercfg /setactive $guid } else { throw 'Ultimate Performance plan is not available on this PC.' }
    }
    telemetry = {
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
        Set-Reg 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0
        $cd = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        foreach ($n in 'SilentInstalledAppsEnabled', 'SystemPaneSuggestionsEnabled', 'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled', 'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled') {
            Set-Reg $cd $n 0
        }
    }
    mouse     = {
        $m = 'HKCU:\Control Panel\Mouse'
        Set-Reg $m 'MouseSpeed' '0' 'String'
        Set-Reg $m 'MouseThreshold1' '0' 'String'
        Set-Reg $m 'MouseThreshold2' '0' 'String'
        [W.U]::SystemParametersInfo(4, 0, [int[]](0, 0, 0), 3) | Out-Null
    }
    explorer  = {
        $e = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
        Set-Reg $e 'ShowRecent' 0
        Set-Reg $e 'ShowFrequent' 0
    }
}

$BloatList = @(
    'Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.BingSearch', 'Microsoft.GetHelp', 'Microsoft.Getstarted',
    'Microsoft.MicrosoftSolitaireCollection', 'Microsoft.MicrosoftOfficeHub', 'Microsoft.People', 'Microsoft.WindowsFeedbackHub',
    'Microsoft.ZuneMusic', 'Microsoft.ZuneVideo', 'Microsoft.MixedReality.Portal', 'Microsoft.Microsoft3DViewer', 'Microsoft.Print3D',
    'Microsoft.MSPaint', 'Microsoft.SkypeApp', 'Microsoft.549981C3F5F10', 'Clipchamp.Clipchamp', 'MicrosoftTeams', 'MSTeams',
    'Microsoft.PowerAutomateDesktop', 'Microsoft.OneConnect', 'Microsoft.Wallet', 'Microsoft.WindowsMaps',
    'Microsoft.YourPhone', 'MicrosoftWindows.CrossDevice', 'microsoft.windowscommunicationsapps', 'Microsoft.OutlookForWindows',
    'Microsoft.Todos', 'Microsoft.MicrosoftJournal', 'Microsoft.Office.OneNote', 'Microsoft.Copilot', 'Microsoft.Windows.DevHome',
    'MicrosoftCorporationII.MicrosoftFamily',
    'Microsoft.XboxApp', 'Microsoft.GamingApp', 'Microsoft.XboxGamingOverlay', 'Microsoft.XboxGameOverlay',
    'Microsoft.XboxIdentityProvider', 'Microsoft.XboxSpeechToTextOverlay', 'Microsoft.Xbox.TCUI',
    '*CandyCrush*', '*Disney*', '*TikTok*', '*Facebook*', '*Instagram*', '*Netflix*', '*PrimeVideo*', '*LinkedIn*',
    '*Twitter*', '*Duolingo*', '*AdobeExpress*', '*McAfee*'
)

function Remove-Bloat {
    Write-Log 'Scanning installed apps...'
    $prov = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue)
    foreach ($id in $BloatList) {
        foreach ($x in @(Get-AppxPackage -AllUsers -Name $id -ErrorAction SilentlyContinue)) {
            Write-Log "Removing $($x.Name)"
            Remove-AppxPackage -Package $x.PackageFullName -AllUsers -ErrorAction SilentlyContinue
        }
        foreach ($x in @($prov | Where-Object { $_.DisplayName -like $id })) {
            Remove-AppxProvisionedPackage -Online -PackageName $x.PackageName -ErrorAction SilentlyContinue | Out-Null
        }
        [Windows.Forms.Application]::DoEvents()
    }
}

function New-RestorePoint {
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
        Checkpoint-Computer -Description 'deep' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Log 'Restore point created.'
    }
    catch { Write-Log 'Restore point not created (Windows allows one every 24 hours).' }
}

function Undo-Tweaks {
    foreach ($e in @(Load-Backup)) {
        if ($e.Existed) { Set-ItemProperty -Path $e.Path -Name $e.Name -Value $e.Value -Type $e.Type }
        else { Remove-ItemProperty -Path $e.Path -Name $e.Name -ErrorAction SilentlyContinue }
    }
    if (Test-Path $PlanFile) { powercfg /setactive (Get-Content $PlanFile -Raw).Trim() }
    [W.U]::SystemParametersInfo(4, 0, [int[]](6, 10, 1), 3) | Out-Null
    Remove-Item $BackupFile, $PlanFile -ErrorAction SilentlyContinue
    Write-Log 'Tweaks reverted. Removed apps can be reinstalled from the Microsoft Store.'
}

$form = New-Object Windows.Forms.Form
$form.Text = "deep v$Version"
$form.Size = New-Object Drawing.Size(1000, 760)
$form.MinimumSize = New-Object Drawing.Size(900, 660)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $cBg
$form.ForeColor = $cText
$form.Font = New-Object Drawing.Font('Segoe UI', 9.5)

$header = New-Object FxPanel
$header.Dock = 'Top'
$header.Height = 140
$header.Title = 'deep'
$header.Sub = "Windows 10 / 11 post-install setup   |   v$Version"

$nav = New-Object Windows.Forms.Panel
$nav.Dock = 'Left'
$nav.Width = 170
$nav.BackColor = $cCard

$content = New-Object Windows.Forms.Panel
$content.Dock = 'Fill'
$content.BackColor = $cBg

$bottom = New-Object Windows.Forms.Panel
$bottom.Dock = 'Bottom'
$bottom.Height = 200
$bottom.BackColor = $cCard

$Checks = @{}
$TabKeys = @{ Apps = @(); Drivers = @(); Tweaks = @(); Debloat = @() }
$Flows = @{}
$NavBtns = @{}

$i = 0
foreach ($n in 'Apps', 'Drivers', 'Tweaks', 'Debloat') {
    $f = New-Object Windows.Forms.FlowLayoutPanel
    $f.Dock = 'Fill'
    $f.FlowDirection = 'TopDown'
    $f.WrapContents = $false
    $f.AutoScroll = $true
    $f.Padding = New-Object Windows.Forms.Padding(10, 8, 10, 8)
    $f.BackColor = $cBg
    $f.Visible = $false
    $content.Controls.Add($f)
    $Flows[$n] = $f

    $b = New-Object Windows.Forms.Button
    $b.Text = "   $n"
    $b.TextAlign = 'MiddleLeft'
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 0
    $b.BackColor = $cCard
    $b.ForeColor = $cText
    $b.Font = New-Object Drawing.Font('Segoe UI Semibold', 11)
    $b.Size = New-Object Drawing.Size(170, 48)
    $b.Location = New-Object Drawing.Point(0, (14 + $i * 52))
    $b.Cursor = 'Hand'
    $name = $n
    $b.Add_Click({ Show-Tab $name }.GetNewClosure())
    $nav.Controls.Add($b)
    $NavBtns[$n] = $b
    $i++
}

function Add-Row($tab, $key, $title, $desc, $on, $height = 66) {
    $row = New-Object Windows.Forms.Panel
    $row.Size = New-Object Drawing.Size(700, $height)
    $row.BackColor = $cCard
    $row.Margin = New-Object Windows.Forms.Padding(4, 4, 4, 4)

    $cb = New-Object Windows.Forms.CheckBox
    $cb.Text = $title
    $cb.Font = New-Object Drawing.Font('Segoe UI Semibold', 10.5)
    $cb.AutoSize = $true
    $cb.Checked = $on
    $cb.ForeColor = $cText
    $cb.Location = New-Object Drawing.Point(12, 8)

    $lb = New-Object Windows.Forms.Label
    $lb.Text = $desc
    $lb.ForeColor = $cMuted
    $lb.Location = New-Object Drawing.Point(34, 34)
    $lb.Size = New-Object Drawing.Size(650, ($height - 38))
    $lb.Add_Click({ $cb.Checked = -not $cb.Checked }.GetNewClosure())

    $row.Controls.AddRange(@($cb, $lb))
    $Flows[$tab].Controls.Add($row)
    $Checks[$key] = $cb
    $TabKeys[$tab] += $key
}

Add-Row 'Apps' 'app:fivem' 'FiveM' 'GTA V multiplayer client. Placed in %LocalAppData%\FiveM with shortcuts; the first launch finishes its own setup.' $false
Add-Row 'Apps' 'app:rockstar' 'Rockstar Games Launcher' 'Official launcher for GTA V and Red Dead Redemption 2. Silent install.' $false
Add-Row 'Apps' 'app:epic' 'Epic Games Launcher' 'Epic store and launcher, installed from Epic''s official MSI.' $false
Add-Row 'Apps' 'app:steam' 'Steam' 'Valve''s game store and launcher, installed from the official Steam CDN.' $false
Add-Row 'Apps' 'app:discord' 'Discord' 'Voice and text chat. Installs for your user and starts automatically.' $false
Add-Row 'Apps' 'app:brave' 'Brave' 'Privacy-focused Chromium browser with built-in ad blocking.' $false
Add-Row 'Apps' 'app:everything' 'Everything' 'Instant file search for Windows. Latest version is found on voidtools.com.' $false
Add-Row 'Apps' 'app:die' 'Detect It Easy (DIE)' 'File type, packer and compiler detector for reverse engineering. Latest GitHub release, portable.' $false
Add-Row 'Apps' 'app:obs' 'OBS Studio' 'Free recording and streaming software. Latest release from the official GitHub.' $false

Add-Row 'Drivers' 'drv:chipset' 'CPU / chipset drivers' 'Picks the right package for your processor automatically (Intel or AMD). Falls back to the official vendor page if no silent installer exists.' $false 72
Add-Row 'Drivers' 'drv:gpu' 'Graphics drivers' 'Picks the right package for your graphics card automatically (NVIDIA, AMD or Intel). Falls back to the official vendor page if no silent installer exists.' $false 72

Add-Row 'Tweaks' 'tw:dark' 'Dark theme' 'Switches Windows and apps to dark mode.' $true
Add-Row 'Tweaks' 'tw:power' 'Ultimate Performance power plan' 'Unlocks and activates the hidden plan. Uses more power, best for desktops.' $true
Add-Row 'Tweaks' 'tw:telemetry' 'Reduce telemetry and ads' 'Minimum diagnostic data, advertising ID, tailored experiences, feedback prompts and Start menu suggestions off. No services are disabled.' $true 72
Add-Row 'Tweaks' 'tw:mouse' 'Disable "Enhance pointer precision"' 'Turns off mouse acceleration for consistent aim and cursor movement. Applies instantly.' $true
Add-Row 'Tweaks' 'tw:explorer' 'File Explorer privacy' 'Stops Quick access from showing recent files and frequent folders.' $true

Add-Row 'Debloat' 'bloat' 'Remove bloatware' ('Removes pre-installed apps for all users and stops them returning on new accounts: Xbox apps (Xbox, Game Bar overlay, identity), Phone Link / Cross Device, Mail and Calendar, new Outlook, Maps, Movies and TV, News, Weather, Tips, Get Help, Feedback Hub, People, Skype, Teams (personal), Clipchamp, Copilot, Dev Home, Power Automate, Mixed Reality, 3D Viewer, Paint 3D, To Do, Journal, Family, OneNote, Microsoft 365 hub and sponsored apps (Candy Crush, TikTok, Facebook, Instagram, Netflix, Disney+, Prime Video, LinkedIn, Twitter, Duolingo, Adobe Express, McAfee).' + "`r`n`r`nNever touched: Microsoft Store, Photos, Calculator, Terminal, Notepad, Edge, Windows Security and system components. Removing the Xbox apps can break Xbox sign-in for Store and Game Pass games.") $false 190

$chkRestore = New-Object Windows.Forms.CheckBox
$chkRestore.Text = 'Create a system restore point first'
$chkRestore.Checked = $true
$chkRestore.AutoSize = $true
$chkRestore.Location = New-Object Drawing.Point(16, 14)
$chkRestore.ForeColor = $cText

$lblTheme = New-Object Windows.Forms.Label
$lblTheme.Text = 'Theme'
$lblTheme.AutoSize = $true
$lblTheme.ForeColor = $cMuted
$lblTheme.Location = New-Object Drawing.Point(380, 16)

$cmbTheme = New-Object Windows.Forms.ComboBox
$cmbTheme.DropDownStyle = 'DropDownList'
$cmbTheme.Items.AddRange(@('Snowfall', 'Rainfall', 'Off'))
$cmbTheme.Location = New-Object Drawing.Point(434, 12)
$cmbTheme.Width = 130

function New-FlatButton($text, $x, $w) {
    $b = New-Object Windows.Forms.Button
    $b.Text = $text
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 0
    $b.BackColor = $cActive
    $b.ForeColor = $cText
    $b.Size = New-Object Drawing.Size($w, 34)
    $b.Location = New-Object Drawing.Point($x, 50)
    $b.Cursor = 'Hand'
    $b
}

$btnAll = New-FlatButton 'Select all' 16 110
$btnNone = New-FlatButton 'Select none' 134 110
$btnUndo = New-FlatButton 'Undo tweaks' 252 120
$btnGo = New-FlatButton 'Install / Apply' 0 200
$btnGo.Height = 40
$btnGo.Top = 47
$btnGo.Font = New-Object Drawing.Font('Segoe UI Semibold', 11)
$btnGo.ForeColor = [Drawing.Color]::White

$bar = New-Object Windows.Forms.ProgressBar
$bar.Location = New-Object Drawing.Point(16, 98)
$bar.Height = 8
$bar.Anchor = 'Top,Left,Right'

$txt = New-Object Windows.Forms.TextBox
$txt.Multiline = $true
$txt.ReadOnly = $true
$txt.ScrollBars = 'Vertical'
$txt.BackColor = $cBg
$txt.ForeColor = $cMuted
$txt.BorderStyle = 'None'
$txt.Font = New-Object Drawing.Font('Consolas', 9)
$txt.Location = New-Object Drawing.Point(16, 114)
$txt.Anchor = 'Top,Bottom,Left,Right'

$bottom.Controls.AddRange(@($chkRestore, $lblTheme, $cmbTheme, $btnAll, $btnNone, $btnUndo, $btnGo, $bar, $txt))

function Update-Layout {
    $w = $bottom.ClientSize.Width
    $btnGo.Left = $w - $btnGo.Width - 16
    $bar.Width = $w - 32
    $txt.Width = $w - 32
    $txt.Height = $bottom.ClientSize.Height - 124
}
$bottom.Add_Resize({ Update-Layout })

function Write-Log($m) {
    $txt.AppendText(("[{0}] {1}`r`n" -f (Get-Date -Format 'HH:mm:ss'), $m))
    [Windows.Forms.Application]::DoEvents()
}

function Show-Tab($n) {
    foreach ($k in $Flows.Keys) {
        $Flows[$k].Visible = ($k -eq $n)
        $NavBtns[$k].BackColor = $(if ($k -eq $n) { $cActive } else { $cCard })
    }
    $script:CurrentTab = $n
}

function Apply-Theme($n) {
    $t = $Themes[$n]
    $header.SetMode($t.Mode)
    $header.Accent = $t.Accent
    $btnGo.BackColor = $t.Accent
}

$cmbTheme.Add_SelectedIndexChanged({ Apply-Theme $cmbTheme.SelectedItem })
$btnAll.Add_Click({ foreach ($k in $TabKeys[$script:CurrentTab]) { $Checks[$k].Checked = $true } })
$btnNone.Add_Click({ foreach ($k in $TabKeys[$script:CurrentTab]) { $Checks[$k].Checked = $false } })
$btnUndo.Add_Click({
        $btnUndo.Enabled = $false
        try { Undo-Tweaks } catch { Write-Log "Undo failed: $($_.Exception.Message)" }
        $btnUndo.Enabled = $true
    })

$btnGo.Add_Click({
        $steps = @()
        $selected = @($Checks.Keys | Where-Object { $Checks[$_].Checked })
        if (-not $selected) {
            Write-Log 'Nothing selected.'
            return
        }
        $btnGo.Enabled = $false
        $needsTweaks = [bool]($selected | Where-Object { $_ -like 'tw:*' })
        if ($chkRestore.Checked -and ($needsTweaks -or $selected -contains 'bloat')) {
            $steps += @{ Label = 'Creating restore point'; Action = { New-RestorePoint } }
        }
        foreach ($k in $selected | Where-Object { $_ -like 'tw:*' }) {
            $key = $k.Substring(3)
            $steps += @{ Label = "Applying tweak: $key"; Action = $TweakActions[$key] }
        }
        if ($selected -contains 'bloat') {
            $steps += @{ Label = 'Removing bloatware'; Action = { Remove-Bloat } }
        }
        if ($selected -contains 'drv:chipset') { $steps += @{ Label = 'CPU / chipset drivers'; Action = { Install-Chipset } } }
        if ($selected -contains 'drv:gpu') { $steps += @{ Label = 'Graphics drivers'; Action = { Install-Gpu } } }
        foreach ($k in $selected | Where-Object { $_ -like 'app:*' }) {
            $key = $k.Substring(4)
            $steps += @{ Label = "App: $($AppDefs[$key].Name)"; Action = { Install-App $key }.GetNewClosure() }
        }
        $bar.Minimum = 0
        $bar.Maximum = $steps.Count
        $bar.Value = 0
        foreach ($s in $steps) {
            Write-Log ">> $($s.Label)"
            try { & $s.Action } catch { Write-Log "Error: $($_.Exception.Message)" }
            $bar.Value = [Math]::Min($bar.Value + 1, $bar.Maximum)
        }
        Write-Log "Done. Installers were saved in $Dl"
        $btnGo.Enabled = $true
        if ($selected -contains 'tw:dark' -or $selected -contains 'tw:explorer' -or $selected -contains 'bloat') {
            $ans = [Windows.Forms.MessageBox]::Show('Restart File Explorer now to apply the theme and Explorer changes? (Your taskbar will flicker for a second. Signing out also works.)', 'deep', 'YesNo', 'Question')
            if ($ans -eq 'Yes') { Stop-Process -Name explorer -Force }
        }
    })

$form.Controls.AddRange(@($content, $nav, $bottom, $header))
$form.Add_Shown({
        $cmbTheme.SelectedItem = 'Snowfall'
        Show-Tab 'Apps'
        Update-Layout
        Write-Log "deep v$Version ready. Installers are saved in $Dl"
    })

[void]$form.ShowDialog()
