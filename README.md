# deep

Open-source setup tool for Windows 10 and 11. After a fresh install, run one command, tick what you want with the mouse, and click **Install / Apply**.

## Run

Open PowerShell and paste:

```
irm https://raw.githubusercontent.com/Trincass/deep/main/setup.ps1 | iex
```

From CMD:

```
powershell -NoProfile -Command "irm https://raw.githubusercontent.com/Trincass/deep/main/setup.ps1 | iex"
```

It asks for administrator rights by itself and always runs the latest version from this repository.

## Features

- **Apps (you choose):** FiveM, Rockstar Games Launcher, Epic Games Launcher, Steam, Discord, Brave, Everything, Detect It Easy (DIE), OBS Studio. Downloaded from the official sources and installed silently. Installers are kept in `Downloads\deep`.
- **Drivers:** CPU/chipset and graphics drivers, picked automatically for your hardware.
- **Tweaks:** dark theme, Ultimate Performance power plan, reduced telemetry and ads, mouse acceleration off, File Explorer privacy.
- **Debloat:** one option that removes pre-installed apps (Xbox apps, Phone Link, Mail, Maps, Copilot, sponsored apps and more). No services are disabled.
- **Safety:** optional restore point, every registry tweak is backed up and can be undone from the app.
- **Themes:** snowfall, rainfall or off.

## Notes

- Review the script before running it. Running remote code with `irm | iex` is only safe if you trust the source.
- Some vendors (AMD, parts of NVIDIA) do not offer stable silent download links. In that case deep opens the official download page.
- Removing the Xbox apps can break Xbox sign-in for Microsoft Store and Game Pass games.

## Contributing

Issues and pull requests are welcome, especially fixes for download links and silent install switches.

## License

MIT
