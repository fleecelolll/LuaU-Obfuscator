<div align="center">

# lua obfuscator

A little tool I made with AI to quickly obfuscate Lua 5.4 and Roblox Luau scripts & code on 64-bit Windows.

</div>

<p align="center">
  <img src="Lua Obfuscator.png" alt="lua obfuscator" width="675">
</p>

## features

- target Lua 5.4 or Roblox Luau
- choose low, medium, or high obfuscation
- select a `.lua` or `.luau` file or drag it into the app
- choose the output folder
- follow progress in the built-in log
- process every script locally without uploads or telemetry

Lua 5.4 uses Hercules's complete protection set. Luau automatically skips the VM and bytecode protections that are not compatible with the Luau runtime.

## installation

1. download the latest ZIP from the [releases page](../../releases/latest)
2. extract the folder
3. run `Installer.bat`
4. open `Lua Obfuscator.pyw`

The download contains only the installer and app. Setup downloads the pinned Hercules source and Lua 5.4.8 runtime into a private `.runtime` folder. It also creates a private `.venv` for PySide6 and does not require administrator access.

If compatible 64-bit Python 3.10 through 3.14 is already installed, setup uses it to create the private environment. If Python is unavailable, setup installs Python 3.13 for the current Windows user through winget.

The Hercules and Lua archives are checked against pinned SHA-256 checksums before they are installed. Run `Installer.bat` again whenever you want to repair the private environment or downloaded components.

## usage

1. choose a `.lua` or `.luau` file
2. select Lua 5.4 or Roblox Luau
3. select low, medium, or high obfuscation
4. choose the output folder
5. click **Obfuscate**

Lua output is saved as `<name>.obfuscated.lua`. Luau output is saved as `<name>.obfuscated.luau`. The original file is never overwritten.

## built with

- [Hercules](https://github.com/zeusssz/hercules-obfuscator)
- [PySide6](https://doc.qt.io/qtforpython-6/)
- [Lua 5.4](https://www.lua.org/)
- [Python](https://www.python.org/)

## privacy and removal

The app has no telemetry, analytics, accounts, or usage tracking. Scripts are processed locally and are never uploaded. To remove everything installed specifically for the app, close it and delete its folder. A Python installation added through winget may remain in your user environment.

## note

This project was made with AI.

Obfuscation makes source harder to read but does not make it impossible to recover. Only obfuscate code you own or have permission to modify.
