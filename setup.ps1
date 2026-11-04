$Version = '1.3.0'
$Repo = 'Trincass/deep'
$Branch = 'main'
$FiveMBranch = 'fivem'
$Raw = "https://raw.githubusercontent.com/$Repo/$Branch/setup.ps1"

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host ''
    Write-Host 'deep needs administrator rights and was not started.' -ForegroundColor Red
    Write-Host 'Close this window, open PowerShell with right click > Run as administrator, and paste the command again.' -ForegroundColor Yellow
    return
}

if ($Repo -notlike 'YOUR_USER*') {
    try {
        $remote = (Invoke-WebRequest "$Raw`?t=$([DateTime]::UtcNow.Ticks)" -UseBasicParsing -TimeoutSec 8).Content
        if ($remote -match "\`$Version\s*=\s*'([\d\.]+)'" -and [version]$Matches[1] -gt [version]$Version) {
            Write-Host "A newer version of deep ($($Matches[1])) is available. Run the command from the README again to use it." -ForegroundColor Yellow
            return
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

function Get-GpuName {
    $names = @(Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name } | Where-Object { $_ -and $_ -notmatch 'Microsoft|Remote|Virtual|Parsec|Citrix|Basic' })
    $pick = $names | Where-Object { $_ -match 'NVIDIA' } | Select-Object -First 1
    if (-not $pick) { $pick = $names | Where-Object { $_ -match 'Radeon (RX|PRO|VII)' } | Select-Object -First 1 }
    if (-not $pick) { $pick = $names | Select-Object -First 1 }
    $pick
}

function Install-FiveMConfig {
    $dest = Join-Path $env:APPDATA 'CitizenFX'
    New-Item -ItemType Directory -Force $dest | Out-Null
    if (Get-Process -Name 'FiveM*' -ErrorAction SilentlyContinue) {
        Write-Log 'FiveM is running. Close it first, or it may overwrite these files when it exits.'
    }
    $base = "https://raw.githubusercontent.com/$Repo/$FiveMBranch/fivem"
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    foreach ($name in 'gta5_settings.xml', 'fivem.cfg') {
        $src = $null
        if ($PSScriptRoot) {
            $local = Join-Path $PSScriptRoot "fivem\$name"
            if (Test-Path $local) { $src = $local }
        }
        if (-not $src) {
            if ($Repo -like 'YOUR_USER*') { throw 'The repository name is not set in setup.ps1 (line 2).' }
            $src = Get-File "$base/$name" $name
        }
        $text = [IO.File]::ReadAllText($src)
        if ($name -eq 'gta5_settings.xml') {
            $gpu = Get-GpuName
            if ($gpu) {
                $text = $text -replace '(<VideoCardDescription>).*?(</VideoCardDescription>)', ('${1}' + $gpu + '${2}')
                Write-Log "Graphics card set to: $gpu"
            }
        }
        else {
            $text = $text -replace '(?m)^seta "cl_nickname".*\r?\n', ''
        }
        $target = Join-Path $dest $name
        if (Test-Path $target) { Copy-Item $target "$target.bak-$stamp" -Force }
        [IO.File]::WriteAllText($target, $text, (New-Object Text.UTF8Encoding($false)))
        Write-Log "Placed $name in $dest"
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
    suggestions = {
        $cd = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        foreach ($n in 'ContentDeliveryAllowed', 'OemPreInstalledAppsEnabled', 'PreInstalledAppsEnabled', 'PreInstalledAppsEverEnabled', 'SilentInstalledAppsEnabled', 'SystemPaneSuggestionsEnabled', 'SubscribedContent-310093Enabled', 'SubscribedContent-338387Enabled', 'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled', 'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled', 'SubscribedContent-353698Enabled', 'SubscribedContent-353699Enabled') { Set-Reg $cd $n 0 }
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSyncProviderNotifications' 0
    }
    notifications = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications' 'ToastEnabled' 0 }
    location = {
        $p = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors'
        Set-Reg $p 'DisableLocation' 1
        Set-Reg $p 'DisableWindowsLocationProvider' 1
    }
    finddevice = { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice' 'AllowFindMyDevice' 0 }
    edgebloat = {
        $p = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
        Set-Reg $p 'AdsSettingForIntrusiveAdsSites' 2
        Set-Reg $p 'HubsSidebarEnabled' 0
        Set-Reg $p 'ShowRecommendationsEnabled' 0
        Set-Reg $p 'SpotlightExperiencesAndRecommendationsEnabled' 0
    }
    updateasap = { Set-Reg 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'IsContinuousInnovationOptedIn' 0 }
    noreboot = { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAutoRebootWithLoggedOnUsers' 1 }
    driverupdates = { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'ExcludeWUDriversInQualityUpdate' 1 }
    deliveryopt = { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0 }
    deviceapps = { Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata' 'PreventDeviceMetadataFromNetwork' 1 }
    faststartup = { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0 }
    widgets = {
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa' 0
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0
    }
    chat = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarMn' 0 }
    taskview = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowTaskViewButton' 0 }
    dvr = {
        Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0
    }
    gamebar = {
        Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'UseNexusForGameBarEnabled' 0
        Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'ShowStartupPanel' 0
        Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'GamePanelStartupTipIndex' 3
    }
    bing = {
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableWebSearch' 1
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'CortanaConsent' 0
    }
    transparency = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0 }
    animations = {
        Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String'
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 2
    }
    spotlight = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowDesktopSpotlightIcon' 0 }
    snap = {
        $p = 'HKCU:\Control Panel\Desktop'
        Set-Reg $p 'WindowArrangementActive' '0' 'String'
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'EnableSnapAssistFlyout' 0
    }
    extensions = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt' 0 }
    hiddenfiles = {
        $p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        Set-Reg $p 'Hidden' 1
        Set-Reg $p 'ShowSuperHidden' 1
    }
    bravebloat = {
        $p = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave'
        Set-Reg $p 'BraveAIChatEnabled' 0
        foreach ($n in 'BraveWalletDisabled', 'BraveRewardsDisabled', 'BraveTalkDisabled', 'BraveVPNDisabled', 'BraveNewsDisabled') { Set-Reg $p $n 1 }
    }
    notifsound = {
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings' 'NOC_GLOBAL_SETTING_ALLOW_NOTIFICATION_SOUND' 0
        foreach ($ev in 'Notification.Default', 'Notification.IM', 'Notification.Mail', 'Notification.Reminder', 'Notification.SMS') {
            $p = "HKCU:\AppEvents\Schemes\Apps\.Default\$ev\.Current"
            if (Test-Path $p) { Set-Reg $p '(default)' '' 'String' }
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

# App IDs and recommendation labels are read from Win11Debloat's MIT-licensed catalog.
$DebloatCatalogUrl = 'https://raw.githubusercontent.com/Raphire/Win11Debloat/master/Config/Apps.json'
$DebloatNamesUrl = 'https://raw.githubusercontent.com/Raphire/Win11Debloat/master/Config/Languages/en-US/Apps.json'
$script:DebloatCatalog = @()
$script:DebloatGrid = $null
$script:DebloatSearch = $null
$script:DebloatOnlyInstalled = $null
$script:DebloatStatus = $null

function Get-DebloatCatalog {
    $appFile = Join-Path $Data 'win11debloat-apps.json'
    $nameFile = Join-Path $Data 'win11debloat-app-names.json'
    try {
        $appText = (Invoke-WebRequest $DebloatCatalogUrl -UseBasicParsing -TimeoutSec 8).Content
        $nameText = (Invoke-WebRequest $DebloatNamesUrl -UseBasicParsing -TimeoutSec 8).Content
        Set-Content -LiteralPath $appFile -Value $appText -Encoding UTF8
        Set-Content -LiteralPath $nameFile -Value $nameText -Encoding UTF8
    }
    catch {
        if (-not (Test-Path $appFile) -or -not (Test-Path $nameFile)) {
            Write-Log "Could not load the app catalog: $($_.Exception.Message)"
            return @()
        }
        $appText = Get-Content -LiteralPath $appFile -Raw
        $nameText = Get-Content -LiteralPath $nameFile -Raw
        Write-Log 'Using the saved Win11Debloat app catalog.'
    }

    try {
        $appData = $appText | ConvertFrom-Json
        $nameData = $nameText | ConvertFrom-Json
    }
    catch {
        Write-Log "Could not read the app catalog: $($_.Exception.Message)"
        return @()
    }
    $installedIds = @(
        @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }) +
        @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | ForEach-Object { $_.DisplayName })
    )
    $wingetList = ''
    if (Test-Winget) {
        try { $wingetList = (& winget list --accept-source-agreements --disable-interactivity 2>$null | Out-String) } catch { }
    }
    $items = @()
    foreach ($app in $appData.Apps) {
        if ($app.Recommendation -notin @('safe', 'optional')) { continue }
        $ids = @($app.AppId)
        $meta = $null
        foreach ($id in $ids) {
            $property = $nameData.PSObject.Properties[$id]
            if ($property) { $meta = $property.Value; break }
        }
        $name = if ($meta -and $meta.FriendlyName) { $meta.FriendlyName } else { $ids[0] }
        $description = if ($meta -and $meta.Description) { $meta.Description } else { 'Optional Windows or preinstalled app.' }
        $isInstalled = [bool](@($ids | Where-Object { $installedIds -contains $_ }).Count)
        if (-not $isInstalled -and $app.RemovalMethod -eq 'WinGet' -and $wingetList) {
            foreach ($id in $ids) {
                if ($wingetList -match "(?im)(^|\s)$([Regex]::Escape($id))(\s|$)") { $isInstalled = $true; break }
            }
        }
        $items += [pscustomobject]@{
            AppIds = $ids
            Name = $name
            Description = $description
            Recommendation = if ($app.Recommendation -eq 'safe') { 'Recommended' } else { 'Optional' }
            RemovalMethod = $app.RemovalMethod
            Installed = $isInstalled
            Selected = [bool]$app.SelectedByDefault
        }
    }
    $items | Sort-Object @{ Expression = { if ($_.Recommendation -eq 'Recommended') { 0 } else { 1 } } }, Name
}

function Update-DebloatRows {
    if (-not $script:DebloatGrid) { return }
    $search = if ($script:DebloatSearch -and $script:DebloatSearch.Text -ne 'Search apps...') { $script:DebloatSearch.Text.Trim() } else { '' }
    foreach ($row in $script:DebloatGrid.Rows) {
        $app = $row.Tag
        $query = "$($app.Name) $($app.Description) $($app.AppIds -join ' ')"
        $matchesSearch = (-not $search) -or ($query -like "*$search*")
        $matchesInstalled = (-not $script:DebloatOnlyInstalled.Checked) -or $app.Installed
        $row.Visible = $matchesSearch -and $matchesInstalled
    }
    Update-DebloatStatus
}

function Update-DebloatStatus {
    if (-not $script:DebloatStatus -or -not $script:DebloatGrid) { return }
    $selectedCount = 0
    $shownCount = 0
    foreach ($row in $script:DebloatGrid.Rows) {
        if ($row.Visible) { $shownCount++ }
        if ([bool]$row.Cells[0].Value) { $selectedCount++ }
    }
    $script:DebloatStatus.Text = "$selectedCount selected   |   $shownCount apps shown   |   Recommended + Optional"
}

function Remove-DebloatApp($app) {
    $ids = @($app.AppIds)
    $removed = $false
    if ($app.RemovalMethod -eq 'WinGet' -and (Test-Winget)) {
        foreach ($id in $ids) {
            $p = Start-Process winget -ArgumentList "uninstall --id `"$id`" --exact --silent --accept-source-agreements --disable-interactivity" -PassThru -WindowStyle Hidden
            if ((Wait-Proc $p) -eq 0) { $removed = $true }
        }
    }
    if (-not $removed) {
        foreach ($pkg in @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $ids -contains $_.Name })) {
            Write-Log "Removing $($app.Name)"
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
            $removed = $true
        }
        foreach ($pkg in @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $ids -contains $_.DisplayName })) {
            Write-Log "Removing $($app.Name) for new user accounts"
            Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction SilentlyContinue | Out-Null
            $removed = $true
        }
    }
    if (-not $removed) { Write-Log "$($app.Name) was not found as an installed app." }
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
$PrimaryText = @{ Apps = 'Install selected'; Drivers = 'Install drivers'; Tweaks = 'Apply tweaks'; FiveM = 'Apply FiveM setup'; Debloat = 'Remove selected apps' }
$H = 900

$form = New-Object FxForm
$form.Text = 'deep'
$form.ClientSize = New-Object Drawing.Size(1240, $H)
$form.MinimumSize = $form.Size
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Segoe UI', 9.5)
$form.Title = 'deep'
$os = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$osName = if ($os.ProductName) { $os.ProductName } else { 'Windows 10 / 11' }
$osRelease = if ($os.DisplayVersion) { " ($($os.DisplayVersion))" } elseif ($os.ReleaseId) { " ($($os.ReleaseId))" } else { '' }
$osArch = if ([Environment]::Is64BitOperatingSystem) { '64-bit' } else { '32-bit' }
$form.Sub = "$osName$osRelease   |   $osArch   |   v$Version"

$Checks = @{}
$TabKeys = @{ Apps = @(); Drivers = @(); Tweaks = @(); FiveM = @(); Debloat = @() }
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
foreach ($n in 'Apps', 'Drivers', 'Tweaks', 'FiveM', 'Debloat') {
    if ($n -eq 'Debloat') {
        $f = New-Object Windows.Forms.Panel
        $f.Location = New-Object Drawing.Point(24, 166)
        $f.Size = New-Object Drawing.Size(1192, 548)
        $f.Anchor = 'Top,Bottom,Left,Right'
        $f.BackColor = [Drawing.Color]::Transparent
        $f.Visible = $false
        $form.Controls.Add($f)
        $Flows[$n] = $f
        $b = New-Btn $n 'nav' (24 + $i * 236) 112 228 42
        $name = $n
        $b.Add_Click({ Show-Tab $name }.GetNewClosure())
        $NavBtns[$n] = $b
        $i++
        continue
    }
    $f = New-Object Windows.Forms.FlowLayoutPanel
    $f.Location = New-Object Drawing.Point(24, 166)
    $f.Size = New-Object Drawing.Size(1192, 548)
    $f.Anchor = 'Top,Bottom,Left,Right'
    $f.FlowDirection = 'TopDown'
    $f.WrapContents = $false
    if ($n -eq 'Tweaks') {
        $f.FlowDirection = 'LeftToRight'
        $f.WrapContents = $true
    }
    $f.AutoScroll = $true
    $f.BackColor = [Drawing.Color]::Transparent
    $f.Visible = $false
    $form.Controls.Add($f)
    try { [W.U]::SetWindowTheme($f.Handle, 'DarkMode_Explorer', $null) | Out-Null } catch { }
    $Flows[$n] = $f

    $b = New-Btn $n 'nav' (24 + $i * 236) 112 228 42
    $name = $n
    $b.Add_Click({ Show-Tab $name }.GetNewClosure())
    $NavBtns[$n] = $b
    $i++
}

$cx = 960
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
    $rowWidth = if ($tab -eq 'Tweaks') { 352 } else { 1148 }
    $r.Size = New-Object Drawing.Size($rowWidth, $height)
    $r.Margin = New-Object Windows.Forms.Padding(2, 0, 2, 10)
    $Flows[$tab].Controls.Add($r)
    $Checks[$key] = $r
    $TabKeys[$tab] += $key
}

function Add-TweakSection($title) {
    $label = New-Object Windows.Forms.Label
    $label.Text = $title.ToUpperInvariant()
    $label.ForeColor = [Drawing.Color]::FromArgb(190, 198, 210)
    $label.Font = New-Object Drawing.Font('Segoe UI Semibold', 9.5)
    $label.Size = New-Object Drawing.Size(1150, 30)
    $label.Margin = New-Object Windows.Forms.Padding(2, 10, 2, 0)
    $Flows['Tweaks'].Controls.Add($label)
}

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

Add-TweakSection 'Privacy & suggested content'
Add-Row 'Tweaks' 'tw:telemetry' 'Reduce telemetry and ads' 'Limits diagnostic data, advertising ID, feedback prompts and tailored experiences.' $true 84
Add-Row 'Tweaks' 'tw:suggestions' 'Disable tips and suggested content' 'Turns off Windows tips, app suggestions and sync-provider ads.' $false 84
Add-Row 'Tweaks' 'tw:location' 'Disable location services' 'Blocks Windows location services and location access for apps.' $false 84
Add-Row 'Tweaks' 'tw:finddevice' 'Disable Find My Device' 'Stops Windows from using device location for Find My Device.' $false 84
Add-Row 'Tweaks' 'tw:edgebloat' 'Reduce Edge ads and suggestions' 'Turns off Edge ads, recommendations, sidebar and news suggestions.' $false 84

Add-TweakSection 'System'
Add-Row 'Tweaks' 'tw:notifications' 'Disable Windows notifications' 'Turns off notifications from Windows and apps. App notifications will stop appearing.' $false 84
Add-Row 'Tweaks' 'tw:mouse' 'Disable mouse acceleration' 'Turns off Enhance pointer precision for consistent cursor movement.' $true
Add-Row 'Tweaks' 'tw:faststartup' 'Disable fast start-up' 'Uses a full shutdown; the next boot may take slightly longer.' $false 84
Add-Row 'Tweaks' 'tw:power' 'Ultimate Performance power plan' 'Unlocks and activates the high-performance plan; it uses more power.' $true 84
Add-Row 'Tweaks' 'tw:notifsound' 'Mute notification sounds' 'Mutes Windows notification sounds. Apps with their own audio must be muted inside the app.' $true 84

Add-TweakSection 'Windows Update'
Add-Row 'Tweaks' 'tw:updateasap' 'Delay early feature updates' 'You still receive updates, but Windows will not place this PC in the earliest rollout group.' $false 84
Add-Row 'Tweaks' 'tw:noreboot' 'Prevent automatic restart while signed in' 'Prevents Windows Update restarting automatically while a user is signed in.' $false 84
Add-Row 'Tweaks' 'tw:driverupdates' 'Exclude drivers from Windows Update' 'Keeps driver updates out of regular Windows quality updates.' $false 84
Add-Row 'Tweaks' 'tw:deliveryopt' 'Stop sharing updates with other PCs' 'Disables Delivery Optimization sharing and peer downloads.' $false 84
Add-Row 'Tweaks' 'tw:deviceapps' 'Stop automatic device companion apps' 'Stops Windows automatically downloading companion apps for connected devices.' $false 84

Add-TweakSection 'Taskbar & gaming'
Add-Row 'Tweaks' 'tw:widgets' 'Disable taskbar widgets' 'Hides Widgets from the taskbar and lock screen.' $false 84
Add-Row 'Tweaks' 'tw:chat' 'Hide Chat from the taskbar' 'Hides the Chat / Meet Now taskbar button.' $false
Add-Row 'Tweaks' 'tw:taskview' 'Hide Task View from the taskbar' 'Hides the Task View button.' $false
Add-Row 'Tweaks' 'tw:dvr' 'Disable game and screen recording' 'Turns off Xbox Game Bar background capture and recording.' $false 84
Add-Row 'Tweaks' 'tw:gamebar' 'Disable Game Bar integration' 'Stops Game Bar popups for games and controllers.' $false 84

Add-TweakSection 'Start & search'
Add-Row 'Tweaks' 'tw:bing' 'Disable Bing and Copilot in search' 'Removes web results and Copilot integration from Windows Search.' $false 84

Add-TweakSection 'Appearance'
Add-Row 'Tweaks' 'tw:dark' 'Dark theme' 'Switches Windows and apps to dark mode.' $true
Add-Row 'Tweaks' 'tw:transparency' 'Disable transparency effects' 'Turns off Windows transparency effects.' $false
Add-Row 'Tweaks' 'tw:animations' 'Reduce animations and visual effects' 'Turns off window animations and some visual effects.' $false 84
Add-Row 'Tweaks' 'tw:spotlight' 'Hide Spotlight desktop shortcut' 'Hides the “Learn about this picture” icon on the desktop.' $false 84

Add-TweakSection 'Multi-tasking'
Add-Row 'Tweaks' 'tw:snap' 'Disable window snapping' 'Turns off snapping windows to screen edges and Snap Assist suggestions.' $false 84

Add-TweakSection 'File Explorer'
Add-Row 'Tweaks' 'tw:explorer' 'File Explorer privacy' 'Stops Quick access from showing recent files and frequent folders.' $true
Add-Row 'Tweaks' 'tw:extensions' 'Show file extensions' 'Shows extensions such as .txt and .jpg in File Explorer.' $false
Add-Row 'Tweaks' 'tw:hiddenfiles' 'Show hidden files' 'Shows hidden files and protected system files in File Explorer.' $false 84

Add-TweakSection 'Other'
Add-Row 'Tweaks' 'tw:bravebloat' 'Disable Brave browser extras' 'Turns off Brave AI, Wallet, Rewards, Talk, VPN and News features.' $false 84

Add-Row 'FiveM' 'fv:install' 'Install FiveM' 'Downloads FiveM from the official site, places it in %LocalAppData%\FiveM and creates shortcuts. The first launch finishes its own setup.' $true 84
Add-Row 'FiveM' 'fv:config' 'Apply my FiveM settings' 'Copies gta5_settings.xml and fivem.cfg into %AppData%\CitizenFX and writes your graphics card into the settings file automatically. Existing files are backed up first.' $true 84

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
$btnGo = New-Btn 'Install selected' 'primary' 1016 ($H - 153) 200 44 'Bottom,Right'

$bar = New-Object FxProgress
$bar.Location = New-Object Drawing.Point(24, ($H - 86))
$bar.Size = New-Object Drawing.Size(1192, 3)
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
$txt.Size = New-Object Drawing.Size(1192, 66)
$txt.Anchor = 'Bottom,Left,Right'
$form.Controls.Add($txt)
try { [W.U]::SetWindowTheme($txt.Handle, 'DarkMode_Explorer', $null) | Out-Null } catch { }

$debloatPanel = $Flows['Debloat']
$debloatSelectRecommended = New-Object FxButton
$debloatSelectRecommended.Text = 'Select recommended'
$debloatSelectRecommended.Style = 'ghost'
$debloatSelectRecommended.Location = New-Object Drawing.Point(0, 4)
$debloatSelectRecommended.Size = New-Object Drawing.Size(190, 36)
$debloatPanel.Controls.Add($debloatSelectRecommended)
$debloatSelectOptional = New-Object FxButton
$debloatSelectOptional.Text = 'Select optional'
$debloatSelectOptional.Style = 'ghost'
$debloatSelectOptional.Location = New-Object Drawing.Point(198, 4)
$debloatSelectOptional.Size = New-Object Drawing.Size(164, 36)
$debloatPanel.Controls.Add($debloatSelectOptional)
$debloatClear = New-Object FxButton
$debloatClear.Text = 'Clear selection'
$debloatClear.Style = 'ghost'
$debloatClear.Location = New-Object Drawing.Point(370, 4)
$debloatClear.Size = New-Object Drawing.Size(170, 36)
$debloatPanel.Controls.Add($debloatClear)
$script:DebloatOnlyInstalled = New-Object Windows.Forms.CheckBox
$script:DebloatOnlyInstalled.Text = 'Only show installed apps'
$script:DebloatOnlyInstalled.Location = New-Object Drawing.Point(554, 10)
$script:DebloatOnlyInstalled.Size = New-Object Drawing.Size(205, 28)
$script:DebloatOnlyInstalled.ForeColor = [Drawing.Color]::White
$script:DebloatOnlyInstalled.BackColor = [Drawing.Color]::Black
$debloatPanel.Controls.Add($script:DebloatOnlyInstalled)
$script:DebloatSearch = New-Object Windows.Forms.TextBox
$script:DebloatSearch.Text = 'Search apps...'
$script:DebloatSearch.Location = New-Object Drawing.Point(875, 5)
$script:DebloatSearch.Size = New-Object Drawing.Size(300, 32)
$script:DebloatSearch.BackColor = [Drawing.Color]::FromArgb(42, 42, 42)
$script:DebloatSearch.ForeColor = [Drawing.Color]::White
$script:DebloatSearch.BorderStyle = 'FixedSingle'
$debloatPanel.Controls.Add($script:DebloatSearch)
$script:DebloatGrid = New-Object Windows.Forms.DataGridView
$script:DebloatGrid.Location = New-Object Drawing.Point(0, 52)
$script:DebloatGrid.Size = New-Object Drawing.Size(1184, 448)
$script:DebloatGrid.Anchor = 'Top,Bottom,Left,Right'
$script:DebloatGrid.AllowUserToAddRows = $false
$script:DebloatGrid.AllowUserToDeleteRows = $false
$script:DebloatGrid.AllowUserToResizeRows = $false
$script:DebloatGrid.AutoGenerateColumns = $false
$script:DebloatGrid.MultiSelect = $false
$script:DebloatGrid.RowHeadersVisible = $false
$script:DebloatGrid.SelectionMode = 'FullRowSelect'
$script:DebloatGrid.BackgroundColor = [Drawing.Color]::FromArgb(12, 12, 12)
$script:DebloatGrid.GridColor = [Drawing.Color]::FromArgb(58, 58, 58)
$script:DebloatGrid.BorderStyle = 'FixedSingle'
$script:DebloatGrid.EnableHeadersVisualStyles = $false
$script:DebloatGrid.ColumnHeadersDefaultCellStyle.BackColor = [Drawing.Color]::FromArgb(38, 38, 38)
$script:DebloatGrid.ColumnHeadersDefaultCellStyle.ForeColor = [Drawing.Color]::White
$script:DebloatGrid.ColumnHeadersDefaultCellStyle.SelectionBackColor = [Drawing.Color]::FromArgb(38, 38, 38)
$script:DebloatGrid.ColumnHeadersHeight = 38
$script:DebloatGrid.DefaultCellStyle.BackColor = [Drawing.Color]::FromArgb(24, 24, 24)
$script:DebloatGrid.DefaultCellStyle.ForeColor = [Drawing.Color]::White
$script:DebloatGrid.DefaultCellStyle.SelectionBackColor = [Drawing.Color]::FromArgb(47, 47, 47)
$script:DebloatGrid.DefaultCellStyle.SelectionForeColor = [Drawing.Color]::White
$script:DebloatGrid.AlternatingRowsDefaultCellStyle.BackColor = [Drawing.Color]::FromArgb(29, 29, 29)
$script:DebloatGrid.RowTemplate.Height = 34
$checkColumn = New-Object Windows.Forms.DataGridViewCheckBoxColumn
$checkColumn.HeaderText = ''
$checkColumn.Width = 34
$checkColumn.SortMode = 'NotSortable'
$null = $script:DebloatGrid.Columns.Add($checkColumn)
foreach ($column in @(@('Name', 205), @('Description', 425), @('App ID', 340), @('Type', 104), @('Installed', 76))) {
    $c = New-Object Windows.Forms.DataGridViewTextBoxColumn
    $c.Name = $column[0]
    $c.HeaderText = $column[0]
    $c.Width = $column[1]
    $c.ReadOnly = $true
    $c.SortMode = 'NotSortable'
    $null = $script:DebloatGrid.Columns.Add($c)
}
$debloatPanel.Controls.Add($script:DebloatGrid)
$script:DebloatStatus = New-Object Windows.Forms.Label
$script:DebloatStatus.Location = New-Object Drawing.Point(4, 510)
$script:DebloatStatus.Size = New-Object Drawing.Size(1180, 30)
$script:DebloatStatus.ForeColor = [Drawing.Color]::FromArgb(180, 188, 200)
$script:DebloatStatus.Text = 'Loading Recommended and Optional apps...'
$debloatPanel.Controls.Add($script:DebloatStatus)

$script:DebloatOnlyInstalled.Add_CheckedChanged({ Update-DebloatRows })
$script:DebloatSearch.Add_Enter({ if ($script:DebloatSearch.Text -eq 'Search apps...') { $script:DebloatSearch.Text = '' } })
$script:DebloatSearch.Add_Leave({ if (-not $script:DebloatSearch.Text.Trim()) { $script:DebloatSearch.Text = 'Search apps...' } })
$script:DebloatSearch.Add_TextChanged({ Update-DebloatRows })
$script:DebloatGrid.Add_CurrentCellDirtyStateChanged({
        if ($script:DebloatGrid.IsCurrentCellDirty) { $script:DebloatGrid.CommitEdit([Windows.Forms.DataGridViewDataErrorContexts]::Commit) }
    })
$script:DebloatGrid.Add_CellValueChanged({ Update-DebloatStatus })
$debloatSelectRecommended.Add_Click({ foreach ($r in $script:DebloatGrid.Rows) { $r.Cells[0].Value = ($r.Tag.Recommendation -eq 'Recommended') } })
$debloatSelectOptional.Add_Click({ foreach ($r in $script:DebloatGrid.Rows) { $r.Cells[0].Value = ($r.Tag.Recommendation -eq 'Optional') } })
$debloatClear.Add_Click({ foreach ($r in $script:DebloatGrid.Rows) { $r.Cells[0].Value = $false } })

function Load-DebloatUi {
    $script:DebloatCatalog = @(Get-DebloatCatalog)
    $script:DebloatGrid.Rows.Clear()
    foreach ($app in $script:DebloatCatalog) {
        $idx = $script:DebloatGrid.Rows.Add($app.Selected, $app.Name, $app.Description, ($app.AppIds -join ', '), $app.Recommendation, $(if ($app.Installed) { 'Yes' } else { 'No' }))
        $script:DebloatGrid.Rows[$idx].Tag = $app
        if ($app.Recommendation -eq 'Recommended') {
            $script:DebloatGrid.Rows[$idx].Cells[4].Style.ForeColor = [Drawing.Color]::FromArgb(104, 194, 126)
        }
        else {
            $script:DebloatGrid.Rows[$idx].Cells[4].Style.ForeColor = [Drawing.Color]::FromArgb(246, 190, 62)
        }
    }
    Update-DebloatRows
    if (-not $script:DebloatCatalog.Count) { $script:DebloatStatus.Text = 'App catalog unavailable. Connect to the internet and reopen deep.' }
}

$btnAll.Add_Click({ foreach ($k in $TabKeys[$script:CurrentTab]) { $Checks[$k].Checked = $true } })
$btnNone.Add_Click({ foreach ($k in $TabKeys[$script:CurrentTab]) { $Checks[$k].Checked = $false } })
$btnUndo.Add_Click({
        if ($script:Busy) { return }
        try { Undo-Tweaks } catch { Write-Log "Undo failed: $($_.Exception.Message)" }
    })

$btnGo.Add_Click({
        if ($script:Busy) { return }
        $tab = $script:CurrentTab
        $selectedDebloat = @()
        if ($tab -eq 'Debloat') {
            if ($script:DebloatGrid.IsCurrentCellDirty) { $script:DebloatGrid.CommitEdit([Windows.Forms.DataGridViewDataErrorContexts]::Commit) }
            $selectedDebloat = @($script:DebloatGrid.Rows | Where-Object { [bool]$_.Cells[0].Value } | ForEach-Object { $_.Tag })
            $selected = @('debloat:apps')
        }
        else { $selected = @($TabKeys[$tab] | Where-Object { $Checks[$_].Checked }) }
        if (($tab -eq 'Debloat' -and -not $selectedDebloat.Count) -or ($tab -ne 'Debloat' -and -not $selected.Count)) {
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
            'FiveM' {
                if ($selected -contains 'fv:install') { $steps += @{ Label = 'Installing FiveM'; Action = { Install-App 'fivem' } } }
                if ($selected -contains 'fv:config') { $steps += @{ Label = 'Applying FiveM settings'; Action = { Install-FiveMConfig } } }
            }
            'Debloat' {
                foreach ($app in $selectedDebloat) {
                    $steps += @{ Label = "Removing app: $($app.Name)"; Action = { Remove-DebloatApp $app }.GetNewClosure() }
                }
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
        if ($tab -eq 'Debloat') {
            foreach ($app in $selectedDebloat) {
                $app.Installed = $false
                foreach ($r in $script:DebloatGrid.Rows) {
                    if ($r.Tag -eq $app) { $r.Cells[0].Value = $false; $r.Cells[5].Value = 'No' }
                }
            }
            Update-DebloatRows
        }
        $script:Busy = $false
        $btnGo.Enabled = $true

        $restartKeys = @('tw:dark', 'tw:explorer', 'tw:widgets', 'tw:chat', 'tw:taskview', 'tw:extensions', 'tw:hiddenfiles', 'tw:spotlight', 'tw:transparency', 'tw:animations')
        $needsExplorerRestart = @($restartKeys | Where-Object { $selected -contains $_ }).Count -gt 0
        if ($needsExplorerRestart -or $tab -eq 'Debloat') {
            $ans = [Windows.Forms.MessageBox]::Show('Restart File Explorer now to apply the changes? Your taskbar will flicker for a second. Signing out also works.', 'deep', 'YesNo', 'Question')
            if ($ans -eq 'Yes') { Stop-Process -Name explorer -Force }
        }
    })

$form.Add_Shown({
        Apply-Theme 'Snow'
        Show-Tab 'Apps'
        Write-Log "deep v$Version ready. Only the page you are on is applied."
        Load-DebloatUi
    })

[void]$form.ShowDialog()
