# deep

Open-source setup tool for Windows 10 and 11. After a fresh install, run one command, pick what you want, and let it handle the rest: apps, drivers, safe tweaks and bloatware removal.

## Features

- **Apps (you choose):** FiveM, Rockstar Games Launcher, Epic Games Launcher, Steam, Discord, Brave, Everything, Detect It Easy (DIE)
- **Drivers:** detects your CPU and GPU and offers the matching drivers (AMD/Intel chipset, NVIDIA, AMD Radeon, Intel)
- **Tweaks:**
  - Dark theme
  - High performance power plan
  - Reduced telemetry, advertising and suggestions
  - "Enhance pointer precision" disabled
  - Explorer: hide recent files and frequent folders in Quick access
- **Bloatware removal:** shows what is installed from a curated list and lets you choose what to remove
- **Safe by design:**
  - No services are disabled
  - A restore point is created before applying tweaks
  - Original values are saved and every tweak can be undone from the menu
  - Removed apps can be reinstalled from the Microsoft Store

## Usage

Open **CMD** and run:

```
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoExit','-NoProfile','-ExecutionPolicy','Bypass','-Command','irm https://raw.githubusercontent.com/Trincass/deep/main/setup.ps1 | iex'"
```

A UAC prompt will appear, then the menu opens in an elevated PowerShell window.

### Run locally

Clone or download the repository and double-click `setup.bat`.

## Menu

```
[1] Install apps
[2] Install drivers (detected CPU/GPU)
[3] Tweaks and settings
[4] Remove bloatware
[5] Everything, step by step
[6] Undo tweaks
[0] Exit
```

## What is removed

Only apps for the current user, from this list: Bing News, Bing Weather, Get Help, Tips, Solitaire Collection, Microsoft 365 (Office Hub), People, Feedback Hub, Movies & TV, Mixed Reality Portal, 3D Viewer, Print 3D, Skype, Cortana, Clipchamp, Teams (personal), Power Automate, OneConnect, and sponsored apps (Candy Crush, Disney+, TikTok, Facebook, Instagram, Netflix, Prime Video, LinkedIn).

Never touched: Microsoft Store, Calculator, Photos, Terminal, Notepad, Paint, Edge, Defender, Xbox apps and Game Bar, system frameworks and Windows Search.

## Notes

- Requires Windows 10 or 11 with administrator rights. Apps are installed through [winget](https://learn.microsoft.com/windows/package-manager/winget/) when available; FiveM and Rockstar are downloaded from their official sites.
- If a package ID is not found, the script opens the official download page instead.
- Telemetry set to 0 on Windows Pro is treated by Windows as the minimum allowed level.
- The mouse tweak applies immediately; the dark theme may need an Explorer restart (the script offers it).
- Review the script before running it. Running remote code with `irm | iex` is only safe if you trust the source.

## Contributing

Issues and pull requests are welcome, especially fixes for winget package IDs and additions to the bloatware list.

## License

MIT
