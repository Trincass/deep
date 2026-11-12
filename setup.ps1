$Version = '1.9.0'
$Repo = 'Trincass/deep'
$Branch = 'main'
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
    public static Font BtnFont = new Font("Segoe UI Semibold", 9.5f);
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
        }
        timer.Interval = 50;
        timer.Tick += delegate
        {
            if (Mode == "off" || WindowState == FormWindowState.Minimized) return;
            Step();
            Invalidate();
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
        if (m != "snow" && m != "off") throw new ArgumentException("Unsupported theme mode.", "m");
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
            p.Speed = (0.5f + p.Size * 0.5f) * 0.8333f;
            p.Level = Math.Min(4, (int)((p.Size - 1.3f) / 0.85f));
        }
        return p;
    }

    void Step()
    {
        if (ClientSize.Width < 10 || ClientSize.Height < 10) return;
        int target = Math.Min(85, Math.Max(30, (ClientSize.Width * ClientSize.Height) / 18000));
        while (list.Count < target) list.Add(Make(true));
        while (list.Count > target) list.RemoveAt(list.Count - 1);
        foreach (Particle p in list)
        {
            p.Y += p.Speed;
            p.X += (float)Math.Sin((p.Y + p.Phase) / 30f) * 0.6f;
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
        g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
        if (Mode == "snow")
        {
            foreach (Particle p in list) g.FillEllipse(brushes[p.Level], p.X, p.Y, p.Size, p.Size);
        }
        g.DrawString(Title, FxUtil.BigFont, Brushes.White, 30, 14);
        g.DrawString(Sub, FxUtil.SubFont, FxUtil.Gray, 36, 72);
        g.DrawLine(line, 36, 104, ClientSize.Width - 36, 104);
        g.DrawLine(line, 36, ClientSize.Height - 172, ClientSize.Width - 36, ClientSize.Height - 172);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            timer.Stop();
            timer.Dispose();
            line.Dispose();
            foreach (SolidBrush brush in brushes) brush.Dispose();
        }
        base.Dispose(disposing);
    }
}

public class FxRow : Control
{
    public string Title = "";
    public string Desc = "";
    public bool Compact = false;
    public event EventHandler CheckedChanged;
    bool hover = false;
    bool chk = false;

    public bool Checked
    {
        get { return chk; }
        set
        {
            if (chk == value) return;
            chk = value;
            Invalidate();
            if (CheckedChanged != null) CheckedChanged(this, EventArgs.Empty);
        }
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
            if (Compact)
            {
                using (SolidBrush b = new SolidBrush(Color.FromArgb(hover ? 24 : 10, 255, 255, 255))) g.FillPath(b, p);
                using (Pen pen = new Pen(Color.FromArgb(chk ? 105 : 38, 255, 255, 255), 1f)) g.DrawPath(pen, p);

                RectangleF titleBounds = new RectangleF(16, 10, Math.Max(0, Width - 88), 19);
                RectangleF descriptionBounds = new RectangleF(16, 34, Math.Max(0, Width - 32), Math.Max(0, Height - 40));
                using (Font titleFont = new Font("Segoe UI Semibold", 9.5f))
                using (Font descriptionFont = new Font("Segoe UI", 8.25f))
                using (StringFormat titleFormat = new StringFormat())
                using (StringFormat descriptionFormat = new StringFormat())
                using (SolidBrush titleBrush = new SolidBrush(Color.FromArgb(226, 230, 238)))
                {
                    titleFormat.Trimming = StringTrimming.EllipsisCharacter;
                    titleFormat.FormatFlags = StringFormatFlags.NoWrap;
                    descriptionFormat.Trimming = StringTrimming.EllipsisCharacter;
                    g.DrawString(Title, titleFont, titleBrush, titleBounds, titleFormat);
                    g.DrawString(Desc, descriptionFont, FxUtil.Gray, descriptionBounds, descriptionFormat);
                }

                Rectangle toggle = new Rectangle(Width - 54, 10, 36, 18);
                using (GraphicsPath togglePath = FxUtil.Round(toggle, 9))
                using (SolidBrush trackBrush = new SolidBrush(chk ? Color.FromArgb(205, 214, 230) : Color.FromArgb(35, 38, 44)))
                using (Pen trackPen = new Pen(Color.FromArgb(chk ? 150 : 78, 190, 198, 210), 1f))
                using (SolidBrush knobBrush = new SolidBrush(chk ? Color.FromArgb(24, 26, 30) : Color.FromArgb(145, 151, 162)))
                {
                    g.FillPath(trackBrush, togglePath);
                    g.DrawPath(trackPen, togglePath);
                    int knobX = chk ? toggle.Right - 15 : toggle.X + 3;
                    g.FillEllipse(knobBrush, knobX, toggle.Y + 3, 12, 12);
                }
                return;
            }

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
$DeletedRegistryKeysFile = Join-Path $Data 'deleted-registry-keys.json'
$OptionalFeatureBackupFile = Join-Path $Data 'optional-features.json'
$StartMenuBackupFile = Join-Path $Data 'start-menu-backup.json'
$StartMenuBackupDir = Join-Path $Data 'start-menu-backups'

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

function Install-ZipApp($ArchivePath, $Destination, $ExeName, $AppName) {
    $parent = Split-Path -Parent $Destination
    $stage = Join-Path $parent ('.deep-stage-' + [guid]::NewGuid().ToString('N'))
    $backup = "$Destination.deep-backup-$([guid]::NewGuid().ToString('N'))"
    $oldMoved = $false
    try {
        Expand-Archive -Path $ArchivePath -DestinationPath $stage -Force -ErrorAction Stop
        $stagedExe = Get-ChildItem $stage -Recurse -Filter $ExeName -File -ErrorAction Stop | Select-Object -First 1
        if (-not $stagedExe) { throw "$AppName archive does not contain $ExeName." }

        if (Test-Path -LiteralPath $Destination) {
            Move-Item -LiteralPath $Destination -Destination $backup -ErrorAction Stop
            $oldMoved = $true
        }
        try {
            Move-Item -LiteralPath $stage -Destination $Destination -ErrorAction Stop
            $exe = Get-ChildItem $Destination -Recurse -Filter $ExeName -File -ErrorAction Stop | Select-Object -First 1
            if (-not $exe) { throw "$AppName executable was missing after installation." }
            New-Shortcut $exe.FullName $AppName
        }
        catch {
            if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Recurse -Force -ErrorAction Stop }
            if ($oldMoved -and (Test-Path -LiteralPath $backup)) {
                Move-Item -LiteralPath $backup -Destination $Destination -ErrorAction Stop
                $oldMoved = $false
            }
            throw
        }
        if ($oldMoved) {
            try { Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction Stop }
            catch { Write-Log "Installed $AppName, but could not remove its temporary backup: $($_.Exception.Message)" }
            $oldMoved = $false
        }
        return $true
    }
    finally {
        if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
        if ($oldMoved -and -not (Test-Path -LiteralPath $Destination) -and (Test-Path -LiteralPath $backup)) {
            Move-Item -LiteralPath $backup -Destination $Destination -ErrorAction SilentlyContinue
        }
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
                $done = Install-ZipApp $path $dest $a.Exe $a.Name
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

function Load-Backup {
    if (Test-Path $BackupFile) {
        $entries = Get-Content $BackupFile -Raw | ConvertFrom-Json
        foreach ($entry in $entries) { $entry }
    }
}

function Resolve-RegPath($Path) {
    if ($Path -match '^(?<hive>HKCU|HKLM|HKCR|HKU|HKCC):\\(?<subkey>.*)$') {
        $hive = $Matches.hive.ToUpperInvariant()
        $subkey = $Matches.subkey
    }
    elseif ($Path -match '^(?<hive>HKEY_CURRENT_USER|HKEY_LOCAL_MACHINE|HKEY_CLASSES_ROOT|HKEY_USERS|HKEY_CURRENT_CONFIG)\\(?<subkey>.*)$') {
        $hive = switch ($Matches.hive.ToUpperInvariant()) {
            'HKEY_CURRENT_USER' { 'HKCU' }
            'HKEY_LOCAL_MACHINE' { 'HKLM' }
            'HKEY_CLASSES_ROOT' { 'HKCR' }
            'HKEY_USERS' { 'HKU' }
            'HKEY_CURRENT_CONFIG' { 'HKCC' }
        }
        $subkey = $Matches.subkey
    }
    else { throw "Unsupported registry path: $Path" }

    $root = switch ($hive) {
        'HKCU' { [Microsoft.Win32.Registry]::CurrentUser }
        'HKLM' { [Microsoft.Win32.Registry]::LocalMachine }
        'HKCR' { [Microsoft.Win32.Registry]::ClassesRoot }
        'HKU'  { [Microsoft.Win32.Registry]::Users }
        'HKCC' { [Microsoft.Win32.Registry]::CurrentConfig }
        default { throw "Unsupported registry hive: $hive" }
    }
    [pscustomobject]@{ Hive = $hive; SubKey = $subkey; Root = $root }
}

function Write-RegRaw($Path, $Name, $Value, $Type) {
    $resolved = Resolve-RegPath $Path
    $key = $resolved.Root.CreateSubKey($resolved.SubKey)
    if (-not $key) { throw "Could not open registry key: $Path" }
    try {
        $valueName = if ($Name -eq '(default)') { '' } else { $Name }
        $kind = [Microsoft.Win32.RegistryValueKind]::Parse([Microsoft.Win32.RegistryValueKind], $Type, $true)
        switch ($kind) {
            'DWord' {
                $number = [UInt64]$Value
                $Value = if ($number -gt [Int32]::MaxValue) { [UInt32]$number } else { [Int32]$number }
            }
            'QWord' { $Value = [Int64]$Value }
            'Binary' { $Value = [byte[]]@($Value | ForEach-Object { [byte]$_ }) }
            'MultiString' { $Value = [string[]]@($Value) }
        }
        $key.SetValue($valueName, $Value, $kind)
    }
    finally { $key.Dispose() }
}

function Remove-RegValueRaw($Path, $Name) {
    $resolved = Resolve-RegPath $Path
    $key = $resolved.Root.OpenSubKey($resolved.SubKey, $true)
    if (-not $key) { return }
    try {
        $valueName = if ($Name -eq '(default)') { '' } else { $Name }
        $key.DeleteValue($valueName, $false)
    }
    finally { $key.Dispose() }
}

function Save-RegValueBackup($Path, $Name, $DefaultType = 'DWord') {
    $resolved = Resolve-RegPath $Path
    $valueExisted = $false
    $oldValue = $null
    $oldType = $DefaultType
    $keyExisted = $false
    $key = $resolved.Root.OpenSubKey($resolved.SubKey)
    if ($key) {
        $keyExisted = $true
        try {
        $valueName = if ($Name -eq '(default)') { '' } else { $Name }
        $valueExisted = $key.GetValueNames() -contains $valueName
        if ($valueExisted) {
            $oldValue = $key.GetValue($valueName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $oldType = $key.GetValueKind($valueName).ToString()
        }
        }
        finally { $key.Dispose() }
    }
    $list = @(Load-Backup)
    if (-not ($list | Where-Object { $_.Path -eq $Path -and $_.Name -eq $Name })) {
        $list += [pscustomobject]@{
            Path       = $Path
            Name       = $Name
            KeyExisted = $keyExisted
            Existed    = $valueExisted
            Value      = $oldValue
            Type       = $oldType
        }
        ConvertTo-Json -InputObject @($list) -Depth 10 | Set-Content -LiteralPath $BackupFile -Encoding UTF8
    }
}

function Set-Reg($Path, $Name, $Value, $Type = 'DWord') {
    Save-RegValueBackup $Path $Name $Type
    Write-RegRaw $Path $Name $Value $Type
}

function Remove-RegValue($Path, $Name) {
    Save-RegValueBackup $Path $Name
    Remove-RegValueRaw $Path $Name
}

function Get-RegKeySnapshot($Key) {
    $values = @()
    foreach ($valueName in $Key.GetValueNames()) {
        $displayName = if ($valueName -eq '') { '(default)' } else { $valueName }
        $value = $Key.GetValue($valueName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $values += [pscustomobject]@{
            Name = $displayName
            Type = $Key.GetValueKind($valueName).ToString()
            Value = $value
        }
    }
    $subKeys = @()
    foreach ($name in $Key.GetSubKeyNames()) {
        $child = $Key.OpenSubKey($name)
        if ($child) {
            try { $subKeys += [pscustomobject]@{ Name = $name; Snapshot = (Get-RegKeySnapshot $child) } }
            finally { $child.Dispose() }
        }
    }
    [pscustomobject]@{ Values = $values; SubKeys = $subKeys }
}

function Save-DeletedRegistryKeyBackup($Hive, $Path, $Snapshot) {
    $entries = @()
    if (Test-Path -LiteralPath $DeletedRegistryKeysFile) {
        $entries = @(Get-Content -LiteralPath $DeletedRegistryKeysFile -Raw | ConvertFrom-Json)
    }
    if (-not ($entries | Where-Object { $_.Hive -eq $Hive -and $_.Path -eq $Path })) {
        $entries += [pscustomobject]@{ Hive = $Hive; Path = $Path; Snapshot = $Snapshot }
        ConvertTo-Json -InputObject @($entries) -Depth 30 | Set-Content -LiteralPath $DeletedRegistryKeysFile -Encoding UTF8
    }
}

function Remove-RegKey($Hive, $Path) {
    $registryPath = "$Hive\$Path"
    $resolved = Resolve-RegPath $registryPath
    $key = $resolved.Root.OpenSubKey($resolved.SubKey)
    if (-not $key) { return }
    try { $snapshot = Get-RegKeySnapshot $key }
    finally { $key.Dispose() }
    Save-DeletedRegistryKeyBackup $resolved.Hive $resolved.SubKey $snapshot

    $parentPath = Split-Path -Path $resolved.SubKey -Parent
    $leaf = Split-Path -Path $resolved.SubKey -Leaf
    $parent = $resolved.Root.OpenSubKey($parentPath, $true)
    if (-not $parent) { throw "Could not open parent registry key for $registryPath" }
    try { $parent.DeleteSubKeyTree($leaf) }
    finally { $parent.Dispose() }
}

function Restore-RegKeySnapshot($Hive, $Path, $Snapshot) {
    $registryPath = "$Hive`:\$Path"
    foreach ($value in $Snapshot.Values) {
        Write-RegRaw $registryPath $value.Name $value.Value $value.Type
    }
    foreach ($child in $Snapshot.SubKeys) {
        Restore-RegKeySnapshot $Hive (Join-Path $Path $child.Name) $child.Snapshot
    }
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

# Additional registry presets and labels adapted from Raphire/Win11Debloat (MIT):
# https://github.com/Raphire/Win11Debloat
$Win11FeatureBundleBase64 = @'
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
'@
$featureStream = [IO.MemoryStream]::new([Convert]::FromBase64String(($Win11FeatureBundleBase64 -replace '\s', '')))
$featureGzip = [IO.Compression.GZipStream]::new($featureStream, [IO.Compression.CompressionMode]::Decompress)
$featureReader = [IO.StreamReader]::new($featureGzip, [Text.Encoding]::UTF8)
try { $script:Win11DebloatFeatures = ConvertFrom-Json -InputObject $featureReader.ReadToEnd() }
finally {
    $featureReader.Dispose()
    $featureGzip.Dispose()
    $featureStream.Dispose()
}
$overlappingDebloatFeatureIds = @('DisableCopilot', 'DisableSettings365Ads', 'DisablePaintAI', 'DisableNotepadAI', 'DisableStartPhoneLink')
$script:Win11DebloatFeatures = @($script:Win11DebloatFeatures | Where-Object { $_.Id -notin $overlappingDebloatFeatureIds })
$script:Win11DebloatFeatureById = @{}
foreach ($feature in $script:Win11DebloatFeatures) { $script:Win11DebloatFeatureById[$feature.Id] = $feature }

$script:StartMenuTemplateBase64 = '4nrhSwH8TRucAIEL3m5RhU5aX0cAW7FJilySr5CE+V6aoBj7A+HZAaADAABc9u55LN8F4borYyXEGl8Q5+RZ+qERszeqUhhZXDvcjTF6rgdprauITLqPgMVMbSZbRsLN/O5uMjSLEr6nWYIwsMJkZMnZyZrhR3PugUhUKOYDqwySCY6/CPkL/Ooz/5j2R2hwWRGqc7ZsJxDFM1DWofjUiGjDUny+Y8UjowknQVaPYao0PC4bygKEbeZqCqRvSgPalSc53OFqCh2FHydzl09fChaos385QvF40EDEgSO8U9/dntAeNULwuuZBi7BkWSIOmWN1l4e+TZbtSJXwn+EINAJhRHyCSNeku21dsw+cMoLorMKnRmhJMLvE+CCdgNKIaPo/Krizva1+bMsI8bSkV/CxaCTLXodb/NuBYCsIHY1sTvbwSBRNMPvccw43RJCUKZRkBLkCVfW24ANbLfHXofHDMLxxFNUpBPSgzGHnueHknECcf6J4HCFBqzvSH1TjQ3S6J8tq2yaQ+jFNkxGRMushdXNNiTNjDFYMJNvgRL2lu63NPE+Cxy+IKC1NdKLweFdOGZr2mvKAw7t/fxmCTieUgLkegDomZbHL6anjy4SkjSCnfTBUNtxc0X3VJiha4wq/ArRrTtVnzcUcX+CI4BNTicx+X2eXugI+EHKjgaQS7fXHqQGEUMUeHMCXlgWUZ5kE3LFTjVifyVIGqYNDuqt7T9l7DWByiuRariySa7tiN1gA2ALKYlRsjsQL7xpxHnT1hi/9b+UuyC46cYQaDUcKDc4BGReJP2gDIyZfudLpgUPc7YfH9doiMcWimSylbKFtsI3Mfo0HONxet5XjzjDoziduYk2dFoFfz19uaRcOHtASKzaGdtk6RC+Tm4BbU/7PlbvHEKJZ720AxOQkzU9U8RWAHHsPUVfWzYoQc2dN8OQ/JlUAqe8+PI05ST4m3LoUpBKB+oU0H84aet5etGpIi4CthvazGencFObWJWNRzxk9BXIX2YoAdXB8b7JFwlxVdhgzZK0zkkrzSSmX9iJcNoi6Tp+RtnljzLTAv6xh8gwytIW5F2e5sVh7aiqo4sji0aE+ToqyNPV7eE9Idi2ZNeEbnJ9LX127uOl5jB280hs0caXLUrYiR15+Y31wtlD8JVeTDxDDac6v+e3C4VX+28mg9bYQ7NGYXZc7yZANC/nWTn+/hkTZUvR0gi+PUz4o/DSdKzbvVCAlqdjArcKkWW4r/WKUSLskoOKRPxdNLPVBl2S6blje4LvBzulpeHWubXWfCW4ILuOI'

function Invoke-Win11RegistryFeature($FeatureId) {
    $feature = $script:Win11DebloatFeatureById[$FeatureId]
    if (-not $feature) { throw "Unknown Windows feature preset: $FeatureId" }
    $build = [int]$script:WindowsBuild
    if ($feature.MinVersion -and $build -lt [int]$feature.MinVersion) {
        Write-Log "Skipped $($feature.Label): requires Windows build $($feature.MinVersion) or newer."
        return $false
    }
    if ($feature.MaxVersion -and $build -gt [int]$feature.MaxVersion) {
        Write-Log "Skipped $($feature.Label): supported only through Windows build $($feature.MaxVersion)."
        return $false
    }
    foreach ($operation in $feature.Operations) {
        $hive = switch ($operation.Hive) {
            'HKEY_CURRENT_USER' { 'HKCU' }
            'HKEY_LOCAL_MACHINE' { 'HKLM' }
            'HKEY_CLASSES_ROOT' { 'HKCR' }
            'HKEY_USERS' { 'HKU' }
            'HKEY_CURRENT_CONFIG' { 'HKCC' }
            default { throw "Unsupported registry hive in $FeatureId`: $($operation.Hive)" }
        }
        if ($operation.DeleteKey) {
            Remove-RegKey $hive $operation.Path
            continue
        }
        $path = "$hive`:\$($operation.Path)"
        if ($operation.Delete) { Remove-RegValue $path $operation.Name }
        else { Set-Reg $path $operation.Name $operation.Value $operation.Type }
    }
    if ($feature.RequiresReboot) {
        $script:RebootRequired = $true
        Write-Log "$($feature.Label) may require a Windows restart."
    }
}

function Get-Win11ExclusiveGroup($FeatureId) {
    switch ($FeatureId) {
        { $_ -in 'DisableDesktopSpotlight', 'EnableDesktopSpotlight' } { return 'spotlight-mode' }
        { $_ -in 'DisableStartAllApps', 'StartAllAppsCategory', 'StartAllAppsGrid', 'StartAllAppsList' } { return 'start-all-apps' }
        { $_ -in 'HideSearchTb', 'ShowSearchIconTb', 'ShowSearchLabelTb', 'ShowSearchBoxTb' } { return 'taskbar-search' }
        { $_ -in 'HideTabsInAltTab', 'Show3TabsInAltTab', 'Show5TabsInAltTab', 'Show20TabsInAltTab' } { return 'alt-tab' }
        { $_ -in 'CombineTaskbarAlways', 'CombineTaskbarWhenFull', 'CombineTaskbarNever' } { return 'taskbar-combine' }
        { $_ -in 'CombineMMTaskbarAlways', 'CombineMMTaskbarWhenFull', 'CombineMMTaskbarNever' } { return 'taskbar-combine-multimonitor' }
        { $_ -in 'MMTaskbarModeAll', 'MMTaskbarModeMainActive', 'MMTaskbarModeActive' } { return 'taskbar-multimonitor-mode' }
        { $_ -in 'ExplorerToHome', 'ExplorerToThisPC', 'ExplorerToDownloads', 'ExplorerToOneDrive' } { return 'explorer-start-location' }
        { $_ -in 'ShowDriveLettersFirst', 'ShowDriveLettersLast', 'HideDriveLetters' } { return 'drive-letter-display' }
        default { return $null }
    }
}

function Save-OptionalWindowsFeatureState($FeatureName) {
    $entries = @()
    if (Test-Path -LiteralPath $OptionalFeatureBackupFile) {
        $entries = @(Get-Content -LiteralPath $OptionalFeatureBackupFile -Raw | ConvertFrom-Json)
    }
    if ($entries | Where-Object { $_.Name -eq $FeatureName }) { return }
    $state = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop
    $entries += [pscustomobject]@{ Name = $FeatureName; State = $state.State.ToString() }
    ConvertTo-Json -InputObject @($entries) -Depth 4 | Set-Content -LiteralPath $OptionalFeatureBackupFile -Encoding UTF8
}

function Enable-TrackedWindowsFeature($FeatureName) {
    $state = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop
    if ($state.State -eq 'Enabled') {
        Write-Log "$FeatureName is already enabled."
        return
    }
    Save-OptionalWindowsFeatureState $FeatureName
    $result = Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -All -NoRestart -ErrorAction Stop
    if ($result.RestartNeeded) { $script:RebootRequired = $true }
    Write-Log "Enabled Windows feature: $FeatureName"
}

function Enable-WindowsSandbox {
    Enable-TrackedWindowsFeature 'Containers-DisposableClientVM'
}

function Enable-WSL {
    Enable-TrackedWindowsFeature 'Microsoft-Windows-Subsystem-Linux'
    Enable-TrackedWindowsFeature 'VirtualMachinePlatform'
}

function Get-StartMenuTargets($AllUsers) {
    $packagePath = 'AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState'
    if (-not $AllUsers) {
        return @([pscustomobject]@{
            Directory = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState'
        })
    }
    $profiles = @(Get-CimInstance Win32_UserProfile -ErrorAction Stop |
        Where-Object { -not $_.Special -and $_.LocalPath -and (Test-Path -LiteralPath $_.LocalPath) } |
        ForEach-Object { Join-Path $_.LocalPath $packagePath })
    $profiles += Join-Path $env:SystemDrive "Users\Default\$packagePath"
    @($profiles | Select-Object -Unique | ForEach-Object { [pscustomobject]@{ Directory = $_ } })
}

function Save-StartMenuFileBackup($Path, $DirectoryExisted) {
    $entries = @()
    if (Test-Path -LiteralPath $StartMenuBackupFile) {
        $entries = @(Get-Content -LiteralPath $StartMenuBackupFile -Raw | ConvertFrom-Json)
    }
    if ($entries | Where-Object { $_.Path -eq $Path }) { return }
    New-Item -ItemType Directory -Force -Path $StartMenuBackupDir | Out-Null
    $existed = Test-Path -LiteralPath $Path
    $backup = $null
    if ($existed) {
        $backup = Join-Path $StartMenuBackupDir ([guid]::NewGuid().ToString('N') + '.bin')
        Copy-Item -LiteralPath $Path -Destination $backup -ErrorAction Stop
    }
    $entries += [pscustomobject]@{
        Path = $Path
        Directory = Split-Path -Parent $Path
        DirectoryExisted = $DirectoryExisted
        Existed = $existed
        Backup = $backup
    }
    ConvertTo-Json -InputObject @($entries) -Depth 5 | Set-Content -LiteralPath $StartMenuBackupFile -Encoding UTF8
}

function Apply-StartMenuLayout($AllUsers, $TemplatePath) {
    if ([int]$script:WindowsBuild -lt 22621) { throw 'Start menu layout files require Windows 11 build 22621 or newer.' }
    if ($TemplatePath) {
        if ([IO.Path]::GetExtension($TemplatePath) -ne '.bin') { throw 'Choose a Start menu .bin layout file.' }
        $template = [IO.File]::ReadAllBytes($TemplatePath)
    }
    else { $template = [Convert]::FromBase64String($script:StartMenuTemplateBase64) }
    $targets = @(Get-StartMenuTargets $AllUsers)
    if (-not $targets.Count) { throw 'No Start menu profiles were found.' }
    foreach ($target in $targets) {
        $directory = $target.Directory
        $directoryExisted = Test-Path -LiteralPath $directory
        if (-not $directoryExisted) { New-Item -ItemType Directory -Force -Path $directory -ErrorAction Stop | Out-Null }
        $path = Join-Path $directory 'start2.bin'
        Save-StartMenuFileBackup $path $directoryExisted
        [IO.File]::WriteAllBytes($path, $template)
        Write-Log "Updated Start menu layout: $path"
    }
}

function Select-StartMenuLayout($AllUsers) {
    $dialog = New-Object Windows.Forms.OpenFileDialog
    $dialog.Title = 'Select a Windows 11 Start menu .bin layout'
    $dialog.Filter = 'Start menu layout (*.bin)|*.bin'
    try {
        if ($dialog.ShowDialog($form) -ne [Windows.Forms.DialogResult]::OK) {
            Write-Log 'Start menu layout selection cancelled.'
            return
        }
        Apply-StartMenuLayout $AllUsers $dialog.FileName
    }
    finally { $dialog.Dispose() }
}

# App IDs and recommendation labels are read from Win11Debloat's MIT-licensed catalog.
$DebloatCatalogUrl = 'https://raw.githubusercontent.com/Raphire/Win11Debloat/master/Config/Apps.json'
$DebloatNamesUrl = 'https://raw.githubusercontent.com/Raphire/Win11Debloat/master/Config/Languages/en-US/Apps.json'
$script:DebloatCatalog = @()
$script:DebloatGrid = $null
$script:DebloatSearch = $null
$script:DebloatOnlyInstalled = $null
$script:DebloatStatus = $null
$script:DebloatBatchUpdate = $false
$script:DebloatSearchTimer = $null
$script:DebloatJob = $null
$script:DebloatPollTimer = $null
$script:DebloatLoaded = $false
$script:DebloatLoading = $false

function Test-ProtectedDebloatApp($app) {
    # Never offer Windows runtimes or common development tools for removal.
    if (@($app.AppIds | Where-Object { $_ -in @('Microsoft.Edge', 'XPFFTQ037JWMHS') }).Count -gt 0) { return $true }
    if (@($app.AppIds | Where-Object { $_ -in @('XP9CXNGPPJ97XX', 'Microsoft.MicrosoftOfficeHub') }).Count -gt 0) { return $false }
    $identity = "$(if ($app.Name) { $app.Name }) $($app.Description) $($app.AppIds -join ' ')"
    return $identity -match '(?i)(visual\s*studio|vs\s*code|vscode|c\+\+|vcredist|vc\.?redist|microsoft\.vclibs|microsoft\.ui\.xaml|microsoft\.net\.native|windowsappruntime|\.net\s*(desktop\s*)?runtime|developer\s*mode|dev\s*home|windows\s*terminal|powershell|\bgit\b|\bpython\b|\bnode(js)?\b|programming|development\s*tools)'
}

function Get-DebloatCatalog($CatalogUrl, $NamesUrl, $DataPath) {
    $appFile = Join-Path $DataPath 'win11debloat-apps.json'
    $nameFile = Join-Path $DataPath 'win11debloat-app-names.json'
    $messages = @()
    try {
        $appText = (Invoke-WebRequest $CatalogUrl -UseBasicParsing -TimeoutSec 8).Content
        $nameText = (Invoke-WebRequest $NamesUrl -UseBasicParsing -TimeoutSec 8).Content
        Set-Content -LiteralPath $appFile -Value $appText -Encoding UTF8
        Set-Content -LiteralPath $nameFile -Value $nameText -Encoding UTF8
    }
    catch {
        if (-not (Test-Path $appFile) -or -not (Test-Path $nameFile)) {
            return [pscustomobject]@{
                Apps = @()
                Messages = @("Could not load the app catalog: $($_.Exception.Message)")
            }
        }
        $appText = Get-Content -LiteralPath $appFile -Raw
        $nameText = Get-Content -LiteralPath $nameFile -Raw
        $messages += 'Using the saved Win11Debloat app catalog.'
    }

    try {
        $appText = $appText.TrimStart([char]0xFEFF)
        $nameText = $nameText.TrimStart([char]0xFEFF)
        $appData = $appText | ConvertFrom-Json
        $nameData = $nameText | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            Apps = @()
            Messages = @($messages + "Could not read the app catalog: $($_.Exception.Message)")
        }
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
        if ($app.Recommendation -notin @('safe', 'optional', 'unsafe')) { continue }
        $ids = @($app.AppId)
        if ($ids -contains 'Microsoft.Edge' -or $ids -contains 'XPFFTQ037JWMHS') { continue }
        $meta = $null
        foreach ($id in $ids) {
            $property = $nameData.PSObject.Properties[$id]
            if ($property) { $meta = $property.Value; break }
        }
        $name = if ($meta -and $meta.FriendlyName) { $meta.FriendlyName } else { $ids[0] }
        $description = if ($meta -and $meta.Description) { $meta.Description } else { 'Optional Windows or preinstalled app.' }
        $candidate = [pscustomobject]@{ Name = $name; Description = $description; AppIds = $ids }
        if (Test-ProtectedDebloatApp $candidate) { continue }
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
            Recommendation = switch ($app.Recommendation) {
                'safe' { 'Recommended' }
                'optional' { 'Optional' }
                'unsafe' { 'Not Recommended' }
            }
            RemovalMethod = $app.RemovalMethod
            Installed = $isInstalled
            Selected = [bool]($app.Recommendation -ne 'unsafe' -and $app.SelectedByDefault -and $ids -notcontains 'XP9CXNGPPJ97XX' -and $ids -notcontains 'Microsoft.MicrosoftOfficeHub')
        }
    }
    $sortedItems = @($items | Sort-Object @{ Expression = { switch ($_.Recommendation) { 'Recommended' { 0 } 'Optional' { 1 } default { 2 } } } }, Name)
    [pscustomobject]@{
        Apps = $sortedItems
        Messages = @($messages)
    }
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
    if ($script:DebloatBatchUpdate -or -not $script:DebloatStatus -or -not $script:DebloatGrid) { return }
    $selectedCount = 0
    $shownCount = 0
    foreach ($row in $script:DebloatGrid.Rows) {
        if ($row.Visible) { $shownCount++ }
        if ([bool]$row.Cells[0].Value) { $selectedCount++ }
    }
    $script:DebloatStatus.Text = "$selectedCount selected   |   $shownCount apps shown   |   Recommended + Optional + Not Recommended"
}

function Toggle-DebloatGroup($recommendation) {
    $rows = @($script:DebloatGrid.Rows | Where-Object { $_.Tag.Recommendation -eq $recommendation })
    if (-not $rows.Count) { return }
    $allSelected = @($rows | Where-Object { -not [bool]$_.Cells[0].Value }).Count -eq 0
    $script:DebloatBatchUpdate = $true
    $script:DebloatGrid.SuspendLayout()
    try { foreach ($row in $rows) { $row.Cells[0].Value = -not $allSelected } }
    finally {
        $script:DebloatGrid.ResumeLayout()
        $script:DebloatBatchUpdate = $false
        Update-DebloatStatus
    }
}

function Test-DebloatAppInstalled($app, $appxPackages, $provisionedPackages, $wingetList) {
    $ids = @($app.AppIds)
    if (@($appxPackages | Where-Object { $ids -contains $_.Name }).Count -gt 0) { return $true }
    if (@($provisionedPackages | Where-Object { $ids -contains $_.DisplayName }).Count -gt 0) { return $true }
    if ($app.RemovalMethod -eq 'WinGet' -and $wingetList) {
        foreach ($id in $ids) {
            if ($wingetList -match "(?im)(^|\s)$([Regex]::Escape($id))(\s|$)") { return $true }
        }
    }
    return $false
}

function Remove-DebloatApp($app, $appxPackages, $provisionedPackages) {
    if (Test-ProtectedDebloatApp $app) {
        Write-Log "Protected from removal: $($app.Name)"
        return $false
    }
    $ids = @($app.AppIds)
    $removed = $false
    $failed = $false
    if ($app.RemovalMethod -eq 'WinGet' -and (Test-Winget)) {
        foreach ($id in $ids) {
            try {
                $p = Start-Process winget -ArgumentList "uninstall --id `"$id`" --exact --silent --accept-source-agreements --disable-interactivity" -PassThru -WindowStyle Hidden -ErrorAction Stop
                $exitCode = Wait-Proc $p
                if ($exitCode -eq 0) { $removed = $true }
                else {
                    $failed = $true
                    Write-Log "winget could not remove $($app.Name) (exit code $exitCode)."
                }
            }
            catch {
                $failed = $true
                Write-Log "winget failed to remove $($app.Name): $($_.Exception.Message)"
            }
        }
    }
    if (-not $removed) {
        $failed = $false
        foreach ($pkg in @($appxPackages | Where-Object { $ids -contains $_.Name })) {
            Write-Log "Removing $($app.Name)"
            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                $removed = $true
            }
            catch {
                $failed = $true
                Write-Log "Could not remove $($app.Name): $($_.Exception.Message)"
            }
        }
        foreach ($pkg in @($provisionedPackages | Where-Object { $ids -contains $_.DisplayName })) {
            Write-Log "Removing $($app.Name) for new user accounts"
            try {
                Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null
                $removed = $true
            }
            catch {
                $failed = $true
                Write-Log "Could not remove $($app.Name) for new user accounts: $($_.Exception.Message)"
            }
        }
    }
    if ($removed -and -not $failed) {
        Write-Log "Removal command succeeded for $($app.Name)."
        return $true
    }
    else { Write-Log "FAILED: Could not remove $($app.Name)." }
    return $false
}

function New-RestorePoint {
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
        Checkpoint-Computer -Description 'deep' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Log 'Restore point created.'
    }
    catch { Write-Log 'Restore point not created (Windows allows one every 24 hours).' }
}

function Restore-OptionalWindowsFeatures {
    if (-not (Test-Path -LiteralPath $OptionalFeatureBackupFile)) { return }
    $entries = @(Get-Content -LiteralPath $OptionalFeatureBackupFile -Raw | ConvertFrom-Json)
    foreach ($entry in $entries) {
        if ($entry.State -eq 'Enabled') {
            Enable-WindowsOptionalFeature -Online -FeatureName $entry.Name -All -NoRestart -ErrorAction Stop | Out-Null
        }
        else {
            Disable-WindowsOptionalFeature -Online -FeatureName $entry.Name -NoRestart -ErrorAction Stop | Out-Null
        }
        Write-Log "Restored optional Windows feature state: $($entry.Name) ($($entry.State))."
    }
    Remove-Item -LiteralPath $OptionalFeatureBackupFile -ErrorAction Stop
}

function Restore-StartMenuFiles {
    if (-not (Test-Path -LiteralPath $StartMenuBackupFile)) { return }
    $entries = @(Get-Content -LiteralPath $StartMenuBackupFile -Raw | ConvertFrom-Json)
    foreach ($entry in $entries) {
        if ($entry.Existed) {
            Copy-Item -LiteralPath $entry.Backup -Destination $entry.Path -Force -ErrorAction Stop
        }
        elseif (Test-Path -LiteralPath $entry.Path) {
            Remove-Item -LiteralPath $entry.Path -Force -ErrorAction Stop
        }
        if (-not $entry.DirectoryExisted -and (Test-Path -LiteralPath $entry.Directory)) {
            $directory = Get-Item -LiteralPath $entry.Directory -ErrorAction Stop
            if (-not (Get-ChildItem -LiteralPath $entry.Directory -Force -ErrorAction Stop | Select-Object -First 1)) {
                Remove-Item -LiteralPath $entry.Directory -Force -ErrorAction Stop
            }
        }
        Write-Log "Restored Start menu file: $($entry.Path)"
    }
    Remove-Item -LiteralPath $StartMenuBackupFile -ErrorAction Stop
    if (Test-Path -LiteralPath $StartMenuBackupDir) {
        Remove-Item -LiteralPath $StartMenuBackupDir -Recurse -Force -ErrorAction Stop
    }
}

function Undo-Tweaks {
    if (Test-Path -LiteralPath $DeletedRegistryKeysFile) {
        foreach ($entry in @(Get-Content -LiteralPath $DeletedRegistryKeysFile -Raw | ConvertFrom-Json)) {
            Restore-RegKeySnapshot $entry.Hive $entry.Path $entry.Snapshot
        }
    }
    foreach ($e in @(Load-Backup)) {
        if ($e.Existed) {
            Write-RegRaw $e.Path $e.Name $e.Value $e.Type
        }
        else { Remove-RegValueRaw $e.Path $e.Name }
    }
    foreach ($path in @((Load-Backup | Where-Object { $_.PSObject.Properties['KeyExisted'] -and -not $_.KeyExisted } | Select-Object -ExpandProperty Path -Unique))) {
        if (Test-Path -LiteralPath $path) {
            $key = Get-Item -LiteralPath $path -ErrorAction Stop
            if ($key.SubKeyCount -eq 0 -and $key.ValueCount -eq 0) {
                Remove-Item -LiteralPath $path -ErrorAction Stop
            }
        }
    }
    Restore-OptionalWindowsFeatures
    Restore-StartMenuFiles
    if (Test-Path $PlanFile) { powercfg /setactive (Get-Content $PlanFile -Raw).Trim() }
    [W.U]::SystemParametersInfo(4, 0, [int[]](6, 10, 1), 3) | Out-Null
    Remove-Item $BackupFile, $DeletedRegistryKeysFile, $PlanFile -ErrorAction SilentlyContinue
    Write-Log 'Tweaks reverted. Removed apps can be reinstalled from the Microsoft Store.'
}

$Themes = @{ 'Snow' = 'snow'; 'Off' = 'off' }
$PrimaryText = @{ Apps = 'Install selected'; Drivers = 'Install drivers'; Tweaks = 'Apply tweaks'; Debloat = 'Remove selected apps' }
$H = 900

$form = New-Object FxForm
$form.Text = 'deep'
$form.ClientSize = New-Object Drawing.Size(1240, $H)
$form.MinimumSize = $form.Size
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Segoe UI', 9.5)
$form.Title = 'deep'
$os = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$script:WindowsBuild = [int]$os.CurrentBuildNumber
$script:RebootRequired = $false
$osName = if ($os.ProductName) { $os.ProductName } else { 'Windows 10 / 11' }
$osRelease = if ($os.DisplayVersion) { " ($($os.DisplayVersion))" } elseif ($os.ReleaseId) { " ($($os.ReleaseId))" } else { '' }
$osArch = if ([Environment]::Is64BitOperatingSystem) { '64-bit' } else { '32-bit' }
$form.Sub = "$osName$osRelease   |   $osArch   |   v$Version"

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
    $btnGo.Enabled = -not ($n -eq 'Debloat' -and $script:DebloatLoading)
    $null = $Flows[$n].Focus()
}

function Apply-Theme($n) {
    $form.SetMode($Themes[$n])
    foreach ($k in $ChipBtns.Keys) { $ChipBtns[$k].Active = ($k -eq $n) }
}

$i = 0
foreach ($n in 'Apps', 'Drivers', 'Tweaks', 'Debloat') {
    if ($n -eq 'Debloat') {
        $f = New-Object Windows.Forms.Panel
        $f.Location = New-Object Drawing.Point(24, 166)
        $f.Size = New-Object Drawing.Size(1192, 548)
        $f.Anchor = 'Top,Bottom,Left,Right'
        $f.BackColor = [Drawing.Color]::Transparent
        $f.Visible = $false
        $form.Controls.Add($f)
        $Flows[$n] = $f
        $b = New-Btn $n 'nav' (24 + $i * 160) 112 152 36
        $name = $n
        $b.Add_Click({ Show-Tab $name }.GetNewClosure())
        $NavBtns[$n] = $b
        $i++
        continue
    }
    if ($n -eq 'Tweaks') {
        $f = New-Object Windows.Forms.Panel
        $f.AutoScroll = $true
    }
    else {
        $f = New-Object Windows.Forms.FlowLayoutPanel
        $f.FlowDirection = 'TopDown'
        $f.WrapContents = $false
        $f.AutoScroll = $true
    }
    $f.Location = New-Object Drawing.Point(24, 166)
    $f.Size = New-Object Drawing.Size(1192, 548)
    $f.Anchor = 'Top,Bottom,Left,Right'
    $f.BackColor = [Drawing.Color]::Transparent
    $f.Visible = $false
    $form.Controls.Add($f)
    try { [W.U]::SetWindowTheme($f.Handle, 'DarkMode_Explorer', $null) | Out-Null } catch { }
    $Flows[$n] = $f

    $b = New-Btn $n 'nav' (24 + $i * 160) 112 152 36
    $name = $n
    $b.Add_Click({ Show-Tab $name }.GetNewClosure())
    $NavBtns[$n] = $b
    $i++
}

$cx = $form.ClientSize.Width - 24 - (64 + 8 + 48)
foreach ($t in @(@('Snow', 64), @('Off', 48))) {
    $c = New-Btn $t[0] 'chip' $cx 36 $t[1] 28 'Top,Right'
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
    if ($tab -eq 'Tweaks') {
        $r.Compact = $true
        $height = [Math]::Min($height, 72)
        $r.Margin = New-Object Windows.Forms.Padding(2, 0, 2, 6)
    }
    else {
        $r.Margin = New-Object Windows.Forms.Padding(2, 0, 2, 10)
    }
    $r.Size = New-Object Drawing.Size($rowWidth, $height)
    $Flows[$tab].Controls.Add($r)
    $Checks[$key] = $r
    $TabKeys[$tab] += $key
    if ($key -like 'tw:w11:*') {
        $featureId = $key.Substring(7)
        $exclusiveGroup = Get-Win11ExclusiveGroup $featureId
        if ($exclusiveGroup) {
            $r.Add_CheckedChanged({
                    if (-not $r.Checked) { return }
                    foreach ($otherKey in @($TabKeys['Tweaks'])) {
                        if ($otherKey -eq $key) { continue }
                        if ($otherKey -notlike 'tw:w11:*') { continue }
                        if ((Get-Win11ExclusiveGroup $otherKey.Substring(7)) -eq $exclusiveGroup) {
                            $Checks[$otherKey].Checked = $false
                        }
                    }
                }.GetNewClosure())
        }
    }
}

function Add-TweakSection($title) {
    $label = New-Object Windows.Forms.Label
    $label.Text = $title.ToUpperInvariant()
    $label.ForeColor = [Drawing.Color]::FromArgb(190, 198, 210)
    $label.Font = New-Object Drawing.Font('Segoe UI Semibold', 9.5)
    $label.Size = New-Object Drawing.Size([Math]::Max(320, $Flows['Tweaks'].ClientSize.Width - 28), 24)
    $label.Margin = New-Object Windows.Forms.Padding(2, 8, 2, 0)
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

Add-TweakSection 'Win11Debloat: additional features'
foreach ($category in @($script:Win11DebloatFeatures | Select-Object -ExpandProperty Category -Unique | Sort-Object)) {
    Add-TweakSection $category
    foreach ($feature in @($script:Win11DebloatFeatures | Where-Object { $_.Category -eq $category })) {
        Add-Row 'Tweaks' "tw:w11:$($feature.Id)" $feature.Label $feature.Description $false 84
    }
}
Add-TweakSection 'Optional Windows features & Start menu'
Add-Row 'Tweaks' 'tw:w11:EnableWSL' 'Enable Windows Subsystem for Linux' 'Enables WSL and Virtual Machine Platform. Windows may request a restart; Undo Tweaks restores their previous states.' $false 84
Add-Row 'Tweaks' 'tw:w11:EnableSandbox' 'Enable Windows Sandbox' 'Enables Windows Sandbox (available on supported Windows editions). Windows may request a restart; Undo Tweaks restores its previous state.' $false 84
Add-Row 'Tweaks' 'tw:w11:ResetStartMenu' 'Apply clean Start menu layout' 'Replaces the current Start menu layout with a clean default. Existing layout files are backed up for Undo Tweaks.' $false 84
Add-Row 'Tweaks' 'tw:w11:CustomStartMenu' 'Choose Start menu layout file' 'Choose a .bin layout file to apply to the current user. Existing layout files are backed up for Undo Tweaks.' $false 84

# Lay out tweak cards explicitly so maximize/restore cannot leave horizontal
# overflow or stale FlowLayoutPanel positions behind.
$script:LayoutTweakCards = {
        if (-not $Flows['Tweaks']) { return }
        $tweaks = $Flows['Tweaks']
        $scrollTop = -$tweaks.AutoScrollPosition.Y
        $available = [Math]::Max(320, $tweaks.ClientSize.Width - [Windows.Forms.SystemInformation]::VerticalScrollBarWidth - 32)
        $gap = 12
        $columns = [Math]::Min(3, [Math]::Max(1, [Math]::Floor(($available + $gap) / 340)))
        $cardWidth = [Math]::Max(280, [Math]::Floor(($available - (($columns - 1) * $gap)) / $columns))
        $x = 12
        $y = 12
        $column = 0
        $rowHeight = 0
        $tweaks.SuspendLayout()
        try {
            foreach ($control in $tweaks.Controls) {
                if ($control -is [Windows.Forms.Label]) {
                    if ($column -gt 0) {
                        $y += $rowHeight + $gap
                        $column = 0
                        $rowHeight = 0
                    }
                    $control.Location = New-Object Drawing.Point($x, $y)
                    $control.Size = New-Object Drawing.Size($available, $control.Height)
                    $y += $control.Height + $gap
                }
                elseif ($control -is [FxRow]) {
                    $control.Location = New-Object Drawing.Point(($x + $column * ($cardWidth + $gap)), $y)
                    $control.Size = New-Object Drawing.Size($cardWidth, $control.Height)
                    $rowHeight = [Math]::Max($rowHeight, $control.Height)
                    $column++
                    if ($column -ge $columns) {
                        $y += $rowHeight + $gap
                        $column = 0
                        $rowHeight = 0
                    }
                }
            }
            if ($column -gt 0) { $y += $rowHeight + $gap }
            $tweaks.AutoScrollMinSize = New-Object Drawing.Size(0, ($y + 12))
            $maxScroll = [Math]::Max(0, $tweaks.AutoScrollMinSize.Height - $tweaks.ClientSize.Height)
            $tweaks.AutoScrollPosition = New-Object Drawing.Point(0, [Math]::Min($scrollTop, $maxScroll))
        }
        finally {
            $tweaks.ResumeLayout($true)
        }
    }
$Flows['Tweaks'].Add_Resize($script:LayoutTweakCards)

$restore = New-Object FxRow
$restore.Title = 'Create a restore point first'
$restore.Desc = 'Made before anything is applied, on any page.'
$restore.Checked = $true
$restore.Location = New-Object Drawing.Point(24, ($H - 158))
$restore.Size = New-Object Drawing.Size(284, 58)
$restore.Anchor = 'Bottom,Left'
$form.Controls.Add($restore)

$btnAll = New-Btn 'Select all' 'ghost' 320 ($H - 146) 84 30 'Bottom,Left'
$btnNone = New-Btn 'Select none' 'ghost' 412 ($H - 146) 88 30 'Bottom,Left'
$btnUndo = New-Btn 'Undo tweaks' 'ghost' 508 ($H - 146) 96 30 'Bottom,Left'
$btnGo = New-Btn 'Install selected' 'primary' 1048 ($H - 142) 168 36 'Bottom,Right'

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
$debloatSelectRecommended.Size = New-Object Drawing.Size(172, 30)
$debloatPanel.Controls.Add($debloatSelectRecommended)
$debloatSelectOptional = New-Object FxButton
$debloatSelectOptional.Text = 'Select optional'
$debloatSelectOptional.Style = 'ghost'
$debloatSelectOptional.Location = New-Object Drawing.Point(180, 4)
$debloatSelectOptional.Size = New-Object Drawing.Size(148, 30)
$debloatPanel.Controls.Add($debloatSelectOptional)
$debloatSelectNotRecommended = New-Object FxButton
$debloatSelectNotRecommended.Text = 'Select not recommended'
$debloatSelectNotRecommended.Style = 'ghost'
$debloatSelectNotRecommended.Location = New-Object Drawing.Point(336, 4)
$debloatSelectNotRecommended.Size = New-Object Drawing.Size(184, 30)
$debloatPanel.Controls.Add($debloatSelectNotRecommended)
$debloatClear = New-Object FxButton
$debloatClear.Text = 'Clear selection'
$debloatClear.Style = 'ghost'
$debloatClear.Location = New-Object Drawing.Point(528, 4)
$debloatClear.Size = New-Object Drawing.Size(112, 30)
$debloatPanel.Controls.Add($debloatClear)
$script:DebloatOnlyInstalled = New-Object Windows.Forms.CheckBox
$script:DebloatOnlyInstalled.Text = 'Only show installed apps'
$script:DebloatOnlyInstalled.Location = New-Object Drawing.Point(648, 6)
$script:DebloatOnlyInstalled.Size = New-Object Drawing.Size(210, 28)
$script:DebloatOnlyInstalled.Anchor = 'Top,Right'
$script:DebloatOnlyInstalled.ForeColor = [Drawing.Color]::White
$script:DebloatOnlyInstalled.BackColor = [Drawing.Color]::Black
$debloatPanel.Controls.Add($script:DebloatOnlyInstalled)
$script:DebloatSearch = New-Object Windows.Forms.TextBox
$script:DebloatSearch.Text = 'Search apps...'
$script:DebloatSearch.Location = New-Object Drawing.Point(906, 5)
$script:DebloatSearch.Size = New-Object Drawing.Size(270, 30)
$script:DebloatSearch.Anchor = 'Top,Right'
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
$script:DebloatStatus.Text = 'Loading Recommended, Optional, and Not Recommended apps...'
$debloatPanel.Controls.Add($script:DebloatStatus)

$script:DebloatOnlyInstalled.Add_CheckedChanged({ Update-DebloatRows })
$script:DebloatSearch.Add_Enter({ if ($script:DebloatSearch.Text -eq 'Search apps...') { $script:DebloatSearch.Text = '' } })
$script:DebloatSearch.Add_Leave({ if (-not $script:DebloatSearch.Text.Trim()) { $script:DebloatSearch.Text = 'Search apps...' } })
$script:DebloatSearchTimer = New-Object Windows.Forms.Timer
$script:DebloatSearchTimer.Interval = 250
$script:DebloatSearchTimer.Add_Tick({ $script:DebloatSearchTimer.Stop(); Update-DebloatRows })
$script:DebloatSearch.Add_TextChanged({ $script:DebloatSearchTimer.Stop(); $script:DebloatSearchTimer.Start() })
$script:DebloatGrid.Add_CurrentCellDirtyStateChanged({
        if ($script:DebloatGrid.IsCurrentCellDirty) { $script:DebloatGrid.CommitEdit([Windows.Forms.DataGridViewDataErrorContexts]::Commit) }
    })
$script:DebloatGrid.Add_CellValueChanged({ Update-DebloatStatus })
$debloatSelectRecommended.Add_Click({ Toggle-DebloatGroup 'Recommended' })
$debloatSelectOptional.Add_Click({ Toggle-DebloatGroup 'Optional' })
$debloatSelectNotRecommended.Add_Click({ Toggle-DebloatGroup 'Not Recommended' })
$debloatClear.Add_Click({
        $script:DebloatBatchUpdate = $true
        $script:DebloatGrid.SuspendLayout()
        try { foreach ($r in $script:DebloatGrid.Rows) { $r.Cells[0].Value = $false } }
        finally {
            $script:DebloatGrid.ResumeLayout()
            $script:DebloatBatchUpdate = $false
            Update-DebloatStatus
        }
    })

function Load-DebloatUi($result) {
    $script:DebloatCatalog = @($result.Apps)
    foreach ($message in $result.Messages) { Write-Log $message }
    $script:DebloatGrid.Rows.Clear()
    foreach ($app in $script:DebloatCatalog) {
        $idx = $script:DebloatGrid.Rows.Add($app.Selected, $app.Name, $app.Description, ($app.AppIds -join ', '), $app.Recommendation, $(if ($app.Installed) { 'Yes' } else { 'No' }))
        $script:DebloatGrid.Rows[$idx].Tag = $app
        switch ($app.Recommendation) {
            'Recommended' {
                $script:DebloatGrid.Rows[$idx].Cells[4].Style.ForeColor = [Drawing.Color]::FromArgb(104, 194, 126)
            }
            'Optional' {
                $script:DebloatGrid.Rows[$idx].Cells[4].Style.ForeColor = [Drawing.Color]::FromArgb(246, 190, 62)
            }
            default {
                $script:DebloatGrid.Rows[$idx].Cells[4].Style.ForeColor = [Drawing.Color]::FromArgb(230, 120, 120)
            }
        }
    }
    Update-DebloatRows
    if (-not $script:DebloatCatalog.Count) { $script:DebloatStatus.Text = 'App catalog unavailable. Connect to the internet and reopen deep.' }
    elseif ($result.Messages -contains 'Using the saved Win11Debloat app catalog.') { $script:DebloatStatus.Text += ' (cached catalog)' }
}

function Complete-DebloatCatalogLoad {
    if (-not $script:DebloatJob -or $script:DebloatJob.State -in @('NotStarted', 'Running')) { return }
    $script:DebloatPollTimer.Stop()
    try {
        if ($script:DebloatJob.State -ne 'Completed') {
            $reason = $script:DebloatJob.ChildJobs | ForEach-Object { $_.JobStateInfo.Reason } | Where-Object { $_ } | Select-Object -First 1
            if ($reason) { throw $reason }
            throw "Catalog worker ended with state $($script:DebloatJob.State)."
        }
        $results = @(Receive-Job -Job $script:DebloatJob -ErrorAction Stop)
        if (-not $results.Count -or -not $results[-1].PSObject.Properties['Apps']) {
            throw 'Catalog worker returned no valid result.'
        }
        Load-DebloatUi $results[-1]
    }
    catch {
        Write-Log "Could not load the app catalog: $($_.Exception.Message)"
        $script:DebloatStatus.Text = 'App catalog unavailable. Connect to the internet and reopen deep.'
    }
    finally {
        Remove-Job -Job $script:DebloatJob -Force -ErrorAction SilentlyContinue
        $script:DebloatJob = $null
        $script:DebloatLoading = $false
        $script:DebloatLoaded = $true
        $script:DebloatPollTimer.Stop()
        $script:DebloatPollTimer.Dispose()
        $script:DebloatPollTimer = $null
        $script:DebloatSearch.Enabled = $true
        $script:DebloatOnlyInstalled.Enabled = $true
        $debloatSelectRecommended.Enabled = $true
        $debloatSelectOptional.Enabled = $true
        $debloatSelectNotRecommended.Enabled = $true
        $debloatClear.Enabled = $true
        if ($script:CurrentTab -eq 'Debloat') { $btnGo.Enabled = $true }
    }
}

function Start-DebloatCatalogLoad {
    if ($script:DebloatLoaded -or $script:DebloatLoading) { return }
    $script:DebloatLoading = $true
    $script:DebloatStatus.Text = 'Loading app catalog in the background...'
    $script:DebloatSearch.Enabled = $false
    $script:DebloatOnlyInstalled.Enabled = $false
    $debloatSelectRecommended.Enabled = $false
    $debloatSelectOptional.Enabled = $false
    $debloatSelectNotRecommended.Enabled = $false
    $debloatClear.Enabled = $false
    if ($script:CurrentTab -eq 'Debloat') { $btnGo.Enabled = $false }
    try {
        $catalogDefinition = (Get-Command Get-DebloatCatalog).Definition
        $protectedAppDefinition = (Get-Command Test-ProtectedDebloatApp).Definition
        $script:DebloatJob = Start-Job -ScriptBlock {
            param($catalogBody, $protectedAppBody, $catalogUrl, $namesUrl, $dataPath)
            function Test-Winget { [bool](Get-Command winget -ErrorAction SilentlyContinue) }
            . ([scriptblock]::Create("function Test-ProtectedDebloatApp {`n$protectedAppBody`n}"))
            . ([scriptblock]::Create("function Get-DebloatCatalog {`n$catalogBody`n}"))
            Get-DebloatCatalog -CatalogUrl $catalogUrl -NamesUrl $namesUrl -DataPath $dataPath
        } -ArgumentList $catalogDefinition, $protectedAppDefinition, $DebloatCatalogUrl, $DebloatNamesUrl, $Data -ErrorAction Stop
        $script:DebloatPollTimer = New-Object Windows.Forms.Timer
        $script:DebloatPollTimer.Interval = 250
        $script:DebloatPollTimer.Add_Tick({ Complete-DebloatCatalogLoad })
        $script:DebloatPollTimer.Start()
    }
    catch {
        $script:DebloatLoading = $false
        $script:DebloatLoaded = $true
        $script:DebloatStatus.Text = 'App catalog unavailable. Connect to the internet and reopen deep.'
        Write-Log "Could not start the app catalog worker: $($_.Exception.Message)"
        $script:DebloatSearch.Enabled = $true
        $script:DebloatOnlyInstalled.Enabled = $true
        $debloatSelectRecommended.Enabled = $true
        $debloatSelectOptional.Enabled = $true
        $debloatSelectNotRecommended.Enabled = $true
        $debloatClear.Enabled = $true
        if ($script:CurrentTab -eq 'Debloat') { $btnGo.Enabled = $true }
    }
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
        $appxSnapshot = @()
        $provisionedSnapshot = @()
        $wingetSnapshot = ''
        if ($tab -eq 'Debloat') {
            Write-Log 'Scanning installed app packages once...'
            $appxSnapshot = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue)
            $provisionedSnapshot = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue)
            if (($selectedDebloat | Where-Object { $_.RemovalMethod -eq 'WinGet' }).Count -gt 0 -and (Test-Winget)) {
                try { $wingetSnapshot = (& winget list --accept-source-agreements --disable-interactivity 2>$null | Out-String) } catch { }
            }
            $requestedCount = $selectedDebloat.Count
            $selectedDebloat = @($selectedDebloat | Where-Object { Test-DebloatAppInstalled $_ $appxSnapshot $provisionedSnapshot $wingetSnapshot })
            $skippedCount = $requestedCount - $selectedDebloat.Count
            if ($skippedCount -gt 0) { Write-Log "Skipped $skippedCount selected apps because they are not installed." }
            if (-not $selectedDebloat.Count) {
                Write-Log 'None of the selected apps are installed; nothing to remove.'
                return
            }
        }
        $script:Busy = $true
        $script:RebootRequired = $false
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
                    if ($key -eq 'w11:EnableWSL') {
                        $steps += @{ Label = 'Enable Windows Subsystem for Linux'; Action = { Enable-WSL } }
                    }
                    elseif ($key -eq 'w11:EnableSandbox') {
                        $steps += @{ Label = 'Enable Windows Sandbox'; Action = { Enable-WindowsSandbox } }
                    }
                    elseif ($key -eq 'w11:ResetStartMenu') {
                        $steps += @{ Label = 'Apply clean Start menu layout'; Action = { Apply-StartMenuLayout $false $null } }
                    }
                    elseif ($key -eq 'w11:CustomStartMenu') {
                        $steps += @{ Label = 'Choose Start menu layout file'; Action = { Select-StartMenuLayout $false } }
                    }
                    elseif ($key -like 'w11:*') {
                        $featureId = $key.Substring(4)
                        $steps += @{ Label = "Win11Debloat: $featureId"; Action = { Invoke-Win11RegistryFeature $featureId }.GetNewClosure() }
                    }
                    else {
                        $steps += @{ Label = "Tweak: $key"; Action = $TweakActions[$key] }
                    }
                }
            }
            'Debloat' {
                foreach ($app in $selectedDebloat) {
                    $app | Add-Member -NotePropertyName RemovalSucceeded -NotePropertyValue $false -Force
                    $steps += @{
                        Label = "Removing app: $($app.Name)"
                        DebloatApp = $app
                        Action = { Remove-DebloatApp $app $appxSnapshot $provisionedSnapshot }.GetNewClosure()
                    }
                }
            }
        }

        $bar.Maximum = $steps.Count
        $bar.Value = 0
        foreach ($s in $steps) {
            Write-Log ">> $($s.Label)"
            try {
                $stepResult = & $s.Action
                if ($s.ContainsKey('DebloatApp')) { $s.DebloatApp.RemovalSucceeded = [bool]$stepResult }
            }
            catch {
                if ($s.ContainsKey('DebloatApp')) { $s.DebloatApp.RemovalSucceeded = $false }
                Write-Log "Error: $($_.Exception.Message)"
            }
            $bar.Value = [Math]::Min($bar.Value + 1, $bar.Maximum)
        }
        Write-Log 'Finished.'
        if ($tab -eq 'Apps') { Write-Log "Installers were saved in $Dl" }
        if ($tab -eq 'Debloat') {
            foreach ($app in $selectedDebloat) {
                if ($app.RemovalSucceeded) {
                    $app.Installed = $false
                    foreach ($r in $script:DebloatGrid.Rows) {
                        if ($r.Tag -eq $app) { $r.Cells[0].Value = $false; $r.Cells[5].Value = 'No' }
                    }
                }
                else { Write-Log "Removal was not confirmed for $($app.Name); it remains selected." }
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
        if ($script:RebootRequired) {
            Write-Log 'A Windows restart is required to complete some selected changes.'
            [Windows.Forms.MessageBox]::Show('A Windows restart is required to complete some selected changes. Save your work and restart when convenient.', 'deep', 'OK', 'Information') | Out-Null
        }
    })

$form.Add_Shown({
        & $script:LayoutTweakCards
        Apply-Theme 'Snow'
        Show-Tab 'Apps'
        Write-Log "deep v$Version ready. Only the page you are on is applied."
        Start-DebloatCatalogLoad
    })

$form.Add_FormClosed({
        if ($script:DebloatPollTimer) {
            $script:DebloatPollTimer.Stop()
            $script:DebloatPollTimer.Dispose()
            $script:DebloatPollTimer = $null
        }
        if ($script:DebloatJob) {
            Stop-Job -Job $script:DebloatJob -ErrorAction SilentlyContinue
            Remove-Job -Job $script:DebloatJob -Force -ErrorAction SilentlyContinue
            $script:DebloatJob = $null
        }
    })

[void]$form.ShowDialog()
