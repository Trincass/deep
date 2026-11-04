# deep

Open-source setup tool for Windows 10 and 11. After a fresh install, run one command, pick what you want with the mouse, and apply it page by page.

## Run

1. Right click the Start button (or search "PowerShell"), then choose **Run as administrator**.
2. Paste:

```
irm https://raw.githubusercontent.com/Trincass/deep/main/setup.ps1 | iex
```

deep does not elevate itself. If PowerShell is not running as administrator, it stops and tells you why.

## How it works

Each page applies only its own selection. The button at the bottom right acts on the page you are on, plus a restore point if that option is on.

- **Apps:** Rockstar Games Launcher, Epic Games Launcher, Steam, Discord, Brave, Everything, Detect It Easy (DIE), OBS Studio. Downloaded from the official sources and installed silently. Installers are kept in `Downloads\deep`.
- **Drivers:** CPU/chipset and graphics drivers, picked automatically for your hardware.
- **Tweaks:** dark theme, Ultimate Performance power plan, reduced telemetry and ads, muted notification sounds, mouse acceleration off, File Explorer privacy. Can be undone from the app.
- **FiveM:** installs FiveM and places `gta5_settings.xml` and `fivem.cfg` in `%AppData%\CitizenFX`. Your graphics card is detected and written into the settings file. Existing files are backed up with a timestamp.
- **Debloat:** one option that removes pre-installed apps (Xbox apps, Phone Link, Mail, Maps, Copilot, sponsored apps and more). No services are disabled.
- **Themes:** snow, rain or off. Black background with white falling particles.

## Repository layout

```
setup.ps1
fivem/
  gta5_settings.xml
  fivem.cfg
```

The FiveM page downloads the two files from the `fivem` folder of this repository.

## Notes

- Some vendors (AMD, parts of NVIDIA) do not offer stable silent download links. In that case deep opens the official download page.
- Removing the Xbox apps can break Xbox sign-in for Microsoft Store and Game Pass games.
- The FiveM settings file sets a fixed resolution and refresh rate. Change them in `fivem/gta5_settings.xml` if your monitor differs.
- The animated theme redraws the window constantly. On a slow PC, choose Off.

## Contributing

Issues and pull requests are welcome, especially fixes for download links and silent install switches.

## License

MIT
