<div align="center">

# luau obfuscator

a simple app for quickly obfuscating Roblox LuaU scripts and code on Windows.

</div>

<p align="center">
  <img src="LuaU Obfuscator.png" alt="luau obfuscator" width="675">
</p>

## features

- obfuscate Roblox LuaU scripts with Prometheus
- choose low, medium, or high obfuscation
- select a file or drag it into the app
- choose the output folder
- follow progress in the built-in log

## installation

1. download the latest ZIP from the [releases page](../../releases/latest)
2. extract the folder
3. run `Installer.bat`
4. open `LuaU Obfuscator.pyw`

The installer gets the required components from their official sources. It keeps Prometheus and Lua 5.1 inside the app folder and does not require administrator access.

If Python is already installed, setup uses it and installs or updates PySide6 in that Python environment. If Python is unavailable, setup installs Python 3.13 for the current Windows user.

Run `Installer.bat` again whenever you want to repair the app's local files or missing components.

## usage

1. choose a `.lua` file or drag one into the app
2. select low, medium, or high obfuscation
3. choose the output folder
4. click **Obfuscate**

The finished file is saved as `<name>.obfuscated.lua`.

## built with

- [Prometheus](https://github.com/prometheus-lua/Prometheus)
- [PySide6](https://doc.qt.io/qtforpython-6/)
- [Lua 5.1](https://www.lua.org/)
- [Python](https://www.python.org/)

## privacy and removal

The app has no telemetry, analytics, accounts, or usage tracking. To remove its local components, close the app and delete its folder. Python or PySide6 installed by setup may remain in your user environment.

## note

This project was made with AI.

Only obfuscate code you own or have permission to modify.
