<div align="center">

# luau obfuscator

a simple app for obfuscating Roblox LuaU scripts on Windows.

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
- open the output folder from the app

## installation

1. download the latest ZIP from the [releases page](../../releases/latest)
2. extract the folder
3. run `Installer.bat`
4. open `LuaU Obfuscator.pyw`

The installer gets Python, PySide6, Prometheus, and Lua 5.1 from their official sources when they are not already available. It keeps Prometheus and Lua 5.1 inside the app folder. Python and PySide6 may be installed to your user environment.

Run `Installer.bat` again to repair missing components.

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

## responsible use

Only obfuscate code you own or have permission to modify.
