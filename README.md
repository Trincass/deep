# deep

Open-source setup tool for Windows 10 and 11. After a fresh install, run one command, pick what you want with the mouse, and apply it page by page.

## Download and run

Choose either option:

### PowerShell

1. Right click the Start button (or search "PowerShell"), then choose **Run as administrator**.
2. Paste:

```
$commit = (irm https://api.github.com/repos/Trincass/deep/commits/main).sha
irm "https://raw.githubusercontent.com/Trincass/deep/$commit/setup.ps1" | iex
```

### Executable

1. [Download optimizer.exe](https://github.com/Trincass/deep/releases/latest/download/optimizer.exe).
2. Open it and approve the required Windows administrator permission prompt. The executable will not start if you cancel.

The executable launches the same setup. Windows requires administrator permission before the executable starts. The PowerShell option must be started from an administrator PowerShell window.

## How it works

Each page applies only its own selection. The button at the bottom right acts on the page you are on, plus a restore point if that option is on.

- **Apps:** Rockstar Games Launcher, Epic Games Launcher, Steam, Discord, Brave and OBS Studio. Downloaded from the official sources and installed silently. Installers are kept in `Downloads\deep`.
- **Drivers:** CPU/chipset and graphics drivers, picked automatically for your hardware.
- **Tweaks:** grouped Windows privacy, update, taskbar, gaming, search, appearance, multitasking and File Explorer options, plus 61 additional Win11Debloat presets. App-specific options for apps listed in Debloat are kept in Debloat to avoid duplicates. Includes other Windows AI controls, WSL, Windows Sandbox and Start menu layout options. All options, including the restore-point toggle and Debloat selections, start off until selected. Registry changes and enabled optional Windows features can be reverted with **Undo tweaks**.
- **Debloat:** searchable app catalog with Recommended, Optional and Not Recommended classifications, descriptions, installed-app filtering and individual selection. Catalog loading runs in the background. Not Recommended apps are unselected by default. Microsoft Edge is excluded and protected from removal.
- **Themes:** snow or off. The snowfall adapts its particle count to the window size.

## Repository layout

```
main branch:
  DeepLauncher.cs
  DeepLauncher.manifest
  optimizer.exe
  setup.ps1
  README.md
```

`DeepLauncher.cs` is the C# source for the executable launcher. It embeds and runs `setup.ps1`; `DeepLauncher.manifest` makes Windows require administrator permission before launch. The launcher uses a process-only PowerShell execution-policy override for the embedded script; it does not change Windows' saved execution-policy settings.

The Debloat page reads the app catalog and English app descriptions from Win11Debloat and saves a local copy for later use.

## Notes

- Review the script before running it. Running remote code with `irm | iex` is only safe if you trust the source. Download the executable only from this repository.
- The executable is not digitally signed. SmartScreen or antivirus tools may warn; review the published source and verify the release checksum rather than disabling protection or adding an exclusion.
- Some vendors (AMD, parts of NVIDIA) do not offer stable silent download links. In that case deep opens the official download page.
- Removing the Xbox apps can break Xbox sign-in for Microsoft Store and Game Pass games.
- The Debloat app catalog and additional presets are based on [Raphire/Win11Debloat](https://github.com/Raphire/Win11Debloat), licensed under MIT. Not Recommended apps are available but start unselected; Microsoft Edge is never offered for removal.
- Microsoft Copilot, Microsoft 365 Copilot, Bing, Paint, Notepad and Phone Link are managed from Debloat without duplicate app-specific entries in Tweaks. Both Copilot apps start unselected. Microsoft Edge is never offered for removal. Apps removed from Debloat can be reinstalled from Microsoft Store; **Undo tweaks** cannot restore removed apps.
- The Debloat catalog needs an internet connection the first time it loads, then keeps a local cached copy.
- Snowfall uses a capped, size-adjusted particle count to reduce rendering work. Choose Off to disable animation entirely.

## Contributing

Issues and pull requests are welcome, especially fixes for download links and silent install switches.

## License

MIT
