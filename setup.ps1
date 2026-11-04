$Version = '1.1.0'
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
using System.Runtime.InteropServices;
using System.Windows.Forms;

public static class FxUtil
{
    public static Font TitleFont = new Font("Segoe UI Semibold", 11.5f);
    public static Font DescFont = new Font("Segoe UI", 9.5f);
    public static Font BtnFont = new Font("Segoe UI Semibold", 10f);
    public static Font BigFont = new Font("Segoe UI Light", 34f);
    public static Font SubFont = new Font("Segoe UI", 10f);
    public static SolidBrush Gray = new SolidBrush(Color.FromArgb(150, 156, 168));

    public static GraphicsPath Round(Rectangle r, int rad)
    {
        int d = rad * 2;
        if (d > r.Height) d = r.Height;
        if (d > r.Width) d = r.Width;
        if (d < 1) d = 1;
        GraphicsPath p = new GraphicsPath();
        p.AddArc(r.X, r.Y, d, d, 180, 90);
        p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }
}

public class FxForm : Form
{
    class Particle { public float X, Y, Size, Speed, Phase; public int Level; }
    static int[] levels = new int[] { 70, 110, 150, 190, 230 };
    SolidBrush[] brushes = new SolidBrush[5];
    Pen[] pens = new Pen[5];
    Pen line = new Pen(Color.FromArgb(40, 255, 255, 255), 1f);
    List<Particle> list = new List<Particle>();
    Random rnd = new Random();
    Timer timer = new Timer();
    public string Mode = "snow";
    public string Title = "";
    public string Sub = "";

    [DllImport("dwmapi.dll")]
    static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int val, int size);

    public FxForm()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        BackColor = Color.Black;
        ForeColor = Color.White;
        for (int i = 0; i < 5; i++)
        {
            brushes[i] = new SolidBrush(Color.FromArgb(levels[i], 255, 255, 255));
            pens[i] = new Pen(Color.FromArgb(levels[i] - 20, 255, 255, 255), 1f);
        }
        timer.Interval = 40;
        timer.Tick += delegate
        {
            Step();
            if (Mode != "off" && WindowState != FormWindowState.Minimized) Invalidate(true);
        };
        timer.Start();
    }

    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= 0x02000000;
            return cp;
        }
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        int dark = 1;
        DwmSetWindowAttribute(Handle, 20, ref dark, 4);
        DwmSetWindowAttribute(Handle, 19, ref dark, 4);
    }

    public void SetMode(string m)
    {
        Mode = m;
        list.Clear();
        Invalidate(true);
    }

    Particle Make(bool anywhere)
    {
        Particle p = new Particle();
        p.X = (float)(rnd.NextDouble() * (ClientSize.Width + 60));
        p.Y = anywhere ? (float)(rnd.NextDouble() * ClientSize.Height) : -20f;
        p.Phase = (float)(rnd.NextDouble() * 100);
        if (Mode == "snow")
        {
            p.Size = 1.3f + (float)rnd.NextDouble() * 3.4f;
            p.Speed = 0.5f + p.Size * 0.5f;
            p.Level = Math.Min(4, (int)((p.Size - 1.3f) / 0.85f));
        }
        else
        {
            p.Size = 10f + (float)rnd.NextDouble() * 18f;
            p.Speed = 9f + p.Size * 0.5f;
            p.Level = Math.Min(4, (int)((p.Size - 10f) / 5.6f));
        }
        return p;
    }

    void Step()
    {
        if (ClientSize.Width < 10 || ClientSize.Height < 10) return;
        int target = Mode == "snow" ? 140 : (Mode == "rain" ? 180 : 0);
        while (list.Count < target) list.Add(Make(true));
        while (list.Count > target) list.RemoveAt(list.Count - 1);
        foreach (Particle p in list)
        {
            p.Y += p.Speed;
            if (Mode == "snow") p.X += (float)Math.Sin((p.Y + p.Phase) / 30f) * 0.6f;
            else p.X -= p.Speed * 0.1f;
            if (p.Y > ClientSize.Height + 20 || p.X < -30 || p.X > ClientSize.Width + 30)
            {
                Particle q = Make(false);
                p.X = q.X;
                p.Y = q.Y;
            }
        }
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
        if (Mode == "snow")
        {
            foreach (Particle p in list) g.FillEllipse(brushes[p.Level], p.X, p.Y, p.Size, p.Size);
        }
        else if (Mode == "rain")
        {
            foreach (Particle p in list) g.DrawLine(pens[p.Level], p.X, p.Y, p.X + p.Size * 0.1f, p.Y - p.Size);
        }
        g.DrawString(Title, FxUtil.BigFont, Brushes.White, 30, 14);
        g.DrawString(Sub, FxUtil.SubFont, FxUtil.Gray, 36, 72);
        g.DrawLine(line, 36, 104, ClientSize.Width - 36, 104);
        g.DrawLine(line, 36, ClientSize.Height - 172, ClientSize.Width - 36, ClientSize.Height - 172);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) timer.Stop();
        base.Dispose(disposing);
    }
}

public class FxRow : Control
{
    public string Title = "";
    public string Desc = "";
    bool hover = false;
    bool chk = false;

    public bool Checked
    {
        get { return chk; }
        set { chk = value; Invalidate(); }
    }

    public FxRow()
    {
        SetStyle(ControlStyles.SupportsTransparentBackColor | ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        BackColor = Color.Transparent;
        Cursor = Cursors.Hand;
    }

    protected override void OnMouseEnter(EventArgs e)
    {
        hover = true;
        Invalidate();
        if (Parent != null) Parent.Focus();
        base.OnMouseEnter(e);
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        hover = false;
        Invalidate();
        base.OnMouseLeave(e);
    }

    protected override void OnClick(EventArgs e)
    {
        Checked = !Checked;
        base.OnClick(e);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
        Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
        using (GraphicsPath p = FxUtil.Round(r, 12))
        {
            if (hover)
            {
                using (SolidBrush b = new SolidBrush(Color.FromArgb(18, 255, 255, 255))) g.FillPath(b, p);
            }
            using (Pen pen = new Pen(Color.FromArgb(chk ? 160 : 45, 255, 255, 255), 1f)) g.DrawPath(pen, p);
        }
        g.DrawString(Title, FxUtil.TitleFont, Brushes.White, 20, 12);
        g.DrawString(Desc, FxUtil.DescFont, FxUtil.Gray, new RectangleF(20, 38, Width - 120, Height - 42));

        Rectangle t = new Rectangle(Width - 20 - 44, 14, 44, 22);
        using (GraphicsPath tp = FxUtil.Round(t, 11))
        {
            if (chk)
            {
                g.FillPath(Brushes.White, tp);
                g.FillEllipse(Brushes.Black, t.Right - 19, t.Y + 3, 16, 16);
            }
            else
            {
                using (Pen pen = new Pen(Color.FromArgb(110, 255, 255, 255), 1f)) g.DrawPath(pen, tp);
                using (SolidBrush kb = new SolidBrush(Color.FromArgb(150, 255, 255, 255))) g.FillEllipse(kb, t.X + 3, t.Y + 3, 16, 16);
            }
        }
    }
}

public class FxButton : Control
{
    public string Style = "ghost";
    bool hover = false;
    bool active = false;

    public bool Active
    {
        get { return active; }
        set { active = value; Invalidate(); }
    }

    public FxButton()
    {
        SetStyle(ControlStyles.SupportsTransparentBackColor | ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.StandardClick, true);
        BackColor = Color.Transparent;
        Cursor = Cursors.Hand;
    }

    protected override void OnTextChanged(EventArgs e) { Invalidate(); base.OnTextChanged(e); }
    protected override void OnEnabledChanged(EventArgs e) { Invalidate(); base.OnEnabledChanged(e); }

    protected override void OnMouseEnter(EventArgs e)
    {
        hover = true;
        Invalidate();
        base.OnMouseEnter(e);
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        hover = false;
        Invalidate();
        base.OnMouseLeave(e);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
        int a = Enabled ? 255 : 80;
        Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
        Color txt = Color.FromArgb(a, 255, 255, 255);
        StringFormat sf = new StringFormat();
        sf.LineAlignment = StringAlignment.Center;
        sf.Alignment = StringAlignment.Center;
        RectangleF tr = new RectangleF(0, 0, Width, Height);

        if (Style == "primary")
        {
            int v = hover ? 232 : 255;
            using (GraphicsPath p = FxUtil.Round(r, Height / 2))
            using (SolidBrush b = new SolidBrush(Color.FromArgb(a, v, v, v))) g.FillPath(b, p);
            txt = Color.FromArgb(a, 0, 0, 0);
        }
        else if (Style == "nav")
        {
            sf.Alignment = StringAlignment.Near;
            tr = new RectangleF(24, 0, Width - 24, Height);
            if (active || hover)
            {
                using (GraphicsPath p = FxUtil.Round(r, 10))
                using (SolidBrush b = new SolidBrush(Color.FromArgb(active ? 26 : 12, 255, 255, 255))) g.FillPath(b, p);
            }
            if (active) g.FillRectangle(Brushes.White, 0, 10, 3, Height - 20);
            if (!active) txt = Color.FromArgb(a, 160, 165, 175);
        }
        else
        {
            bool filled = Style == "chip" && active;
            using (GraphicsPath p = FxUtil.Round(r, Height / 2))
            {
                if (filled)
                {
                    g.FillPath(Brushes.White, p);
                    txt = Color.FromArgb(a, 0, 0, 0);
                }
                else
                {
                    if (hover)
                    {
                        using (SolidBrush b = new SolidBrush(Color.FromArgb(24, 255, 255, 255))) g.FillPath(b, p);
                    }
                    using (Pen pen = new Pen(Color.FromArgb(Enabled ? 90 : 40, 255, 255, 255), 1f)) g.DrawPath(pen, p);
                }
            }
        }
        using (SolidBrush tb = new SolidBrush(txt)) g.DrawString(Text, FxUtil.BtnFont, tb, tr, sf);
        sf.Dispose();
    }
}

public class FxProgress : Control
{
    int val = 0;
    int max = 1;

    public int Value
    {
        get { return val; }
        set { val = value; Invalidate(); }
    }

    public int Maximum
    {
        get { return max; }
        set { max = value < 1 ? 1 : value; Invalidate(); }
    }

    public FxProgress()
    {
        SetStyle(ControlStyles.SupportsTransparentBackColor | ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        BackColor = Color.Transparent;
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        using (SolidBrush track = new SolidBrush(Color.FromArgb(40, 255, 255, 255))) e.Graphics.FillRectangle(track, 0, 0, Width, Height);
        int w = (int)((long)Width * val / max);
        e.Graphics.FillRectangle(Brushes.White, 0, 0, w, Height);
    }
}
'@
if (-not ('FxForm' -as [type])) {
    Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition $fxSource
}

Add-Type -Namespace W -Name U -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SystemParametersInfo(int a, int b, int[] c, int d);
[DllImport("uxtheme.dll", CharSet = CharSet.Unicode)] public static extern int SetWindowTheme(IntPtr h, string a, string b);
'@

$Dl = Join-Path (Join-Path $env:USERPROFILE 'Downloads') 'deep'
$Data = Join-Path $env:ProgramData 'deep'
New-Item -ItemType Directory -Force $Dl, $Data | Out-Null
$BackupFile = Join-Path $Data 'backup.json'
$PlanFile = Join-Path $Data 'powerplan.txt'

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

$Themes = @{ 'Snow' = 'snow'; 'Rain' = 'rain'; 'Off' = 'off' }
$PrimaryText = @{ Apps = 'Install selected'; Drivers = 'Install drivers'; Tweaks = 'Apply tweaks'; Debloat = 'Remove bloatware' }
$H = 780

$form = New-Object FxForm
$form.Text = 'deep'
$form.ClientSize = New-Object Drawing.Size(1040, $H)
$form.MinimumSize = $form.Size
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Segoe UI', 9.5)
$form.Title = 'deep'
$form.Sub = "Windows 10 / 11 post-install setup   |   v$Version"

$Checks = @{}
$TabKeys = @{ Apps = @(); Drivers = @(); Tweaks = @(); Debloat = @() }
$Flows = @{}
$NavBtns = @{}
$ChipBtns = @{}
$script:CurrentTab = 'Apps'
$script:Busy = $false

function New-Btn($text, $style, $x, $y, $w, $h, $anchor = 'Top,Left') {
    $b = New-Object FxButton
    $b.Text = $text
    $b.Style = $style
    $b.Location = New-Object Drawing.Point($x, $y)
    $b.Size = New-Object Drawing.Size($w, $h)
    $b.Anchor = $anchor
    $form.Controls.Add($b)
    $b
}

function Write-Log($m) {
    $txt.AppendText(("[{0}] {1}`r`n" -f (Get-Date -Format 'HH:mm:ss'), $m))
    [Windows.Forms.Application]::DoEvents()
}

function Show-Tab($n) {
    $script:CurrentTab = $n
    foreach ($k in $Flows.Keys) {
        $Flows[$k].Visible = ($k -eq $n)
        $NavBtns[$k].Active = ($k -eq $n)
    }
    $btnGo.Text = $PrimaryText[$n]
    $btnUndo.Visible = ($n -eq 'Tweaks')
    $btnAll.Visible = ($n -ne 'Debloat')
    $btnNone.Visible = ($n -ne 'Debloat')
    $null = $Flows[$n].Focus()
}

function Apply-Theme($n) {
    $form.SetMode($Themes[$n])
    foreach ($k in $ChipBtns.Keys) { $ChipBtns[$k].Active = ($k -eq $n) }
}

$i = 0
foreach ($n in 'Apps', 'Drivers', 'Tweaks', 'Debloat') {
    $f = New-Object Windows.Forms.FlowLayoutPanel
    $f.Location = New-Object Drawing.Point(236, 118)
    $f.Size = New-Object Drawing.Size(790, 482)
    $f.Anchor = 'Top,Bottom,Left,Right'
    $f.FlowDirection = 'TopDown'
    $f.WrapContents = $false
    $f.AutoScroll = $true
    $f.BackColor = [Drawing.Color]::Transparent
    $f.Visible = $false
    $form.Controls.Add($f)
    try { [W.U]::SetWindowTheme($f.Handle, 'DarkMode_Explorer', $null) | Out-Null } catch { }
    $Flows[$n] = $f

    $b = New-Btn $n 'nav' 24 (126 + $i * 46) 190 42
    $name = $n
    $b.Add_Click({ Show-Tab $name }.GetNewClosure())
    $NavBtns[$n] = $b
    $i++
}

$cx = 760
foreach ($t in @(@('Snow', 88), @('Rain', 88), @('Off', 64))) {
    $c = New-Btn $t[0] 'chip' $cx 34 $t[1] 32 'Top,Right'
    $name = $t[0]
    $c.Add_Click({ Apply-Theme $name }.GetNewClosure())
    $ChipBtns[$name] = $c
    $cx += $t[1] + 8
}

function Add-Row($tab, $key, $title, $desc, $on, $height = 78) {
    $r = New-Object FxRow
    $r.Title = $title
    $r.Desc = $desc
    $r.Checked = $on
    $r.Size = New-Object Drawing.Size(752, $height)
    $r.Margin = New-Object Windows.Forms.Padding(2, 0, 2, 10)
    $Flows[$tab].Controls.Add($r)
    $Checks[$key] = $r
    $TabKeys[$tab] += $key
}

Add-Row 'Apps' 'app:fivem' 'FiveM' 'GTA V multiplayer client. Placed in %LocalAppData%\FiveM with shortcuts; the first launch finishes its own setup.' $false
Add-Row 'Apps' 'app:rockstar' 'Rockstar Games Launcher' 'Official launcher for GTA V and Red Dead Redemption 2. Silent install.' $false
Add-Row 'Apps' 'app:epic' 'Epic Games Launcher' 'Epic store and launcher, installed from the official Epic MSI.' $false
Add-Row 'Apps' 'app:steam' 'Steam' 'Valve game store and launcher, installed from the official Steam CDN.' $false
Add-Row 'Apps' 'app:discord' 'Discord' 'Voice and text chat. Installs for your user and starts automatically.' $false
Add-Row 'Apps' 'app:brave' 'Brave' 'Privacy-focused Chromium browser with built-in ad blocking.' $false
Add-Row 'Apps' 'app:everything' 'Everything' 'Instant file search for Windows. The latest version is found on voidtools.com.' $false
Add-Row 'Apps' 'app:die' 'Detect It Easy (DIE)' 'File type, packer and compiler detector for reverse engineering. Latest GitHub release, portable.' $false
Add-Row 'Apps' 'app:obs' 'OBS Studio' 'Free recording and streaming software. Latest release from the official GitHub.' $false

Add-Row 'Drivers' 'drv:chipset' 'CPU / chipset drivers' 'Picks the right package for your processor automatically (Intel or AMD). Falls back to the official vendor page if there is no silent installer.' $false 84
Add-Row 'Drivers' 'drv:gpu' 'Graphics drivers' 'Picks the right package for your graphics card automatically (NVIDIA, AMD or Intel). Falls back to the official vendor page if there is no silent installer.' $false 84

Add-Row 'Tweaks' 'tw:dark' 'Dark theme' 'Switches Windows and apps to dark mode.' $true
Add-Row 'Tweaks' 'tw:power' 'Ultimate Performance power plan' 'Unlocks and activates the hidden plan. Uses more power, best for desktops.' $true
Add-Row 'Tweaks' 'tw:telemetry' 'Reduce telemetry and ads' 'Minimum diagnostic data. Turns off advertising ID, tailored experiences, feedback prompts and Start menu suggestions. No services are disabled.' $true 84
Add-Row 'Tweaks' 'tw:mouse' 'Disable "Enhance pointer precision"' 'Turns off mouse acceleration for consistent aim and cursor movement. Applies instantly.' $true
Add-Row 'Tweaks' 'tw:explorer' 'File Explorer privacy' 'Stops Quick access from showing recent files and frequent folders.' $true

Add-Row 'Debloat' 'bloat' 'Remove bloatware' ('Removes pre-installed apps for all users and stops them returning on new accounts: Xbox apps (Xbox, Game Bar overlay, identity), Phone Link / Cross Device, Mail and Calendar, new Outlook, Maps, Movies and TV, News, Weather, Tips, Get Help, Feedback Hub, People, Skype, Teams (personal), Clipchamp, Copilot, Dev Home, Power Automate, Mixed Reality, 3D Viewer, Paint 3D, To Do, Journal, Family, OneNote, Microsoft 365 hub and sponsored apps (Candy Crush, TikTok, Facebook, Instagram, Netflix, Disney+, Prime Video, LinkedIn, Twitter, Duolingo, Adobe Express, McAfee).' + "`r`n`r`nNever touched: Microsoft Store, Photos, Calculator, Terminal, Notepad, Edge, Windows Security and system components. Removing the Xbox apps can break Xbox sign-in for Store and Game Pass games.") $false 270

$restore = New-Object FxRow
$restore.Title = 'Create a restore point first'
$restore.Desc = 'Made before anything is applied, on any page.'
$restore.Checked = $true
$restore.Location = New-Object Drawing.Point(24, ($H - 162))
$restore.Size = New-Object Drawing.Size(420, 62)
$restore.Anchor = 'Bottom,Left'
$form.Controls.Add($restore)

$btnAll = New-Btn 'Select all' 'ghost' 460 ($H - 149) 104 36 'Bottom,Left'
$btnNone = New-Btn 'Select none' 'ghost' 572 ($H - 149) 104 36 'Bottom,Left'
$btnUndo = New-Btn 'Undo tweaks' 'ghost' 684 ($H - 149) 112 36 'Bottom,Left'
$btnGo = New-Btn 'Install selected' 'primary' 816 ($H - 153) 200 44 'Bottom,Right'

$bar = New-Object FxProgress
$bar.Location = New-Object Drawing.Point(24, ($H - 86))
$bar.Size = New-Object Drawing.Size(992, 3)
$bar.Anchor = 'Bottom,Left,Right'
$form.Controls.Add($bar)

$txt = New-Object Windows.Forms.TextBox
$txt.Multiline = $true
$txt.ReadOnly = $true
$txt.ScrollBars = 'Vertical'
$txt.BackColor = [Drawing.Color]::Black
$txt.ForeColor = [Drawing.Color]::FromArgb(150, 156, 168)
$txt.BorderStyle = 'None'
$txt.Font = New-Object Drawing.Font('Consolas', 9)
$txt.Location = New-Object Drawing.Point(24, ($H - 76))
$txt.Size = New-Object Drawing.Size(992, 66)
$txt.Anchor = 'Bottom,Left,Right'
$form.Controls.Add($txt)
try { [W.U]::SetWindowTheme($txt.Handle, 'DarkMode_Explorer', $null) | Out-Null } catch { }

$btnAll.Add_Click({ foreach ($k in $TabKeys[$script:CurrentTab]) { $Checks[$k].Checked = $true } })
$btnNone.Add_Click({ foreach ($k in $TabKeys[$script:CurrentTab]) { $Checks[$k].Checked = $false } })
$btnUndo.Add_Click({
        if ($script:Busy) { return }
        try { Undo-Tweaks } catch { Write-Log "Undo failed: $($_.Exception.Message)" }
    })

$btnGo.Add_Click({
        if ($script:Busy) { return }
        $tab = $script:CurrentTab
        $selected = @($TabKeys[$tab] | Where-Object { $Checks[$_].Checked })
        if (-not $selected) {
            Write-Log "Nothing selected on the $tab page."
            return
        }
        $script:Busy = $true
        $btnGo.Enabled = $false

        $steps = @()
        if ($restore.Checked) {
            $steps += @{ Label = 'Creating restore point'; Action = { New-RestorePoint } }
        }
        switch ($tab) {
            'Apps' {
                foreach ($k in $selected) {
                    $key = $k.Substring(4)
                    $steps += @{ Label = "App: $($AppDefs[$key].Name)"; Action = { Install-App $key }.GetNewClosure() }
                }
            }
            'Drivers' {
                if ($selected -contains 'drv:chipset') { $steps += @{ Label = 'CPU / chipset drivers'; Action = { Install-Chipset } } }
                if ($selected -contains 'drv:gpu') { $steps += @{ Label = 'Graphics drivers'; Action = { Install-Gpu } } }
            }
            'Tweaks' {
                foreach ($k in $selected) {
                    $key = $k.Substring(3)
                    $steps += @{ Label = "Tweak: $key"; Action = $TweakActions[$key] }
                }
            }
            'Debloat' {
                $steps += @{ Label = 'Removing bloatware'; Action = { Remove-Bloat } }
            }
        }

        $bar.Maximum = $steps.Count
        $bar.Value = 0
        foreach ($s in $steps) {
            Write-Log ">> $($s.Label)"
            try { & $s.Action } catch { Write-Log "Error: $($_.Exception.Message)" }
            $bar.Value = [Math]::Min($bar.Value + 1, $bar.Maximum)
        }
        Write-Log 'Finished.'
        if ($tab -eq 'Apps') { Write-Log "Installers were saved in $Dl" }
        $script:Busy = $false
        $btnGo.Enabled = $true

        if ($selected -contains 'tw:dark' -or $selected -contains 'tw:explorer' -or $tab -eq 'Debloat') {
            $ans = [Windows.Forms.MessageBox]::Show('Restart File Explorer now to apply the changes? Your taskbar will flicker for a second. Signing out also works.', 'deep', 'YesNo', 'Question')
            if ($ans -eq 'Yes') { Stop-Process -Name explorer -Force }
        }
    })

$form.Add_Shown({
        Apply-Theme 'Snow'
        Show-Tab 'Apps'
        Write-Log "deep v$Version ready. Only the page you are on is applied."
    })

[void]$form.ShowDialog()
