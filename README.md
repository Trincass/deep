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
- **Tweaks:** grouped Windows privacy, update, taskbar, gaming, search, appearance, multitasking and File Explorer options. Existing tweaks can be undone from the app; new options are off until selected.
- **FiveM:** installs FiveM and places `gta5_settings.xml` and `fivem.cfg` in `%AppData%\CitizenFX`. Your graphics card is detected and written into the settings file. Existing files are backed up with a timestamp.
- **Debloat:** searchable app catalog with Recommended and Optional classifications, descriptions, installed-app filtering and individual selection. Recommended apps follow the catalog defaults; Optional apps start unselected. Apps marked Not Recommended by the catalog are excluded.
- **Themes:** snow, rain or off. Black background with white falling particles.

## Repository layout

```
main branch:
  setup.ps1
fivem branch:
  fivem/
    gta5_settings.xml
    fivem.cfg
```

The FiveM page downloads the two files from the `fivem` folder on the `fivem` branch. The Debloat page reads the app catalog and English app descriptions from Win11Debloat and saves a local copy for later use.

## Notes

- Review the script before running it. Running remote code with `irm | iex` is only safe if you trust the source.
- Some vendors (AMD, parts of NVIDIA) do not offer stable silent download links. In that case deep opens the official download page.
- Removing the Xbox apps can break Xbox sign-in for Microsoft Store and Game Pass games.
- The FiveM settings file sets a fixed resolution and refresh rate. Change them in `fivem/gta5_settings.xml` if your monitor differs.
- The Debloat app catalog is based on [Raphire/Win11Debloat](https://github.com/Raphire/Win11Debloat), licensed under MIT. `deep` uses only its Recommended and Optional app entries; it does not include Not Recommended entries.
- The Debloat catalog needs an internet connection the first time it loads, then keeps a local cached copy.
- The animated theme redraws the window constantly. On a slow PC, choose Off.

## Contributing

Issues and pull requests are welcome, especially fixes for download links and silent install switches.

## License

MIT
