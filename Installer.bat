@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title LuaU Obfuscator Installer

set "APPDIR=%~dp0"
set "PROMDIR=%APPDIR%Prometheus"
set "LUADIR=%APPDIR%Lua51"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

cls
echo.
echo  ==================================================
echo                  LUAU OBFUSCATOR SETUP
echo  ==================================================
echo.
echo   Installing what the app needs:
echo.
echo      Python       runs the GUI
echo      PySide6      the app window
echo      Prometheus   obfuscates the Lua script
echo      Lua 5.1      runs Prometheus
echo.
echo   Keep this window open until it says finished.
echo.
echo  ==================================================

call :FindPython

echo.
echo   [ STEP 1 / 4 ]   Python
echo.
if defined PYCMD (
    echo      Already installed, skipping.
) else (
    where winget >nul 2>nul
    if errorlevel 1 goto NoWinget
    echo      Installing Python, please wait...
    winget install --id Python.Python.3.13 --exact --source winget --silent --scope user --accept-source-agreements --accept-package-agreements >nul 2>&1
    call :FindPython
)
if not defined PYCMD goto PythonMissing
echo      Done.

echo.
echo   [ STEP 2 / 4 ]   PySide6
echo.
echo      Installing or updating the GUI components...
%PYCMD% -m pip install --upgrade pip >nul 2>&1
%PYCMD% -m pip install --upgrade PySide6 >nul 2>&1
if errorlevel 1 goto ComponentsFailed
echo      Done.

echo.
echo   [ STEP 3 / 4 ]   Prometheus
echo.
call :SetupPrometheus
if errorlevel 1 goto PrometheusFailed
echo      Done.

echo.
echo   [ STEP 4 / 4 ]   Lua 5.1
echo.
call :SetupLua
if errorlevel 1 goto LuaFailed
echo      Done.

if not exist "%APPDIR%LuaU Obfuscator.pyw" goto AppMissing
if not exist "%PROMDIR%\cli.lua" goto PrometheusFailed
if not exist "%LUADIR%\lua5.1.exe" goto LuaFailed

echo.
echo  ==================================================
echo                ALL SET, YOU ARE READY
echo  ==================================================
echo.
echo   Double-click "LuaU Obfuscator.pyw" to start.
echo.
echo   Prometheus: "%PROMDIR%"
echo   Lua 5.1:    "%LUADIR%\lua5.1.exe"
echo.
pause
exit /b 0

:FindPython
set "PYCMD="
py -3 -V >nul 2>nul && set "PYCMD=py -3"
if not defined PYCMD (
    python -V >nul 2>nul && set "PYCMD=python"
)
if not defined PYCMD (
    for /f "delims=" %%P in ('dir /b /s "%LocalAppData%\Programs\Python\Python3*\python.exe" 2^>nul') do (
        if not defined PYCMD set PYCMD="%%~fP"
    )
)
if not defined PYCMD (
    for /f "delims=" %%P in ('dir /b /s "%ProgramFiles%\Python3*\python.exe" 2^>nul') do (
        if not defined PYCMD set PYCMD="%%~fP"
    )
)
exit /b 0

:SetupPrometheus
if exist "%PROMDIR%\cli.lua" exit /b 0

echo      Looking for an existing Prometheus folder...
for %%D in (
    "%USERPROFILE%\Prometheus"
    "%USERPROFILE%\Downloads\Prometheus"
    "%USERPROFILE%\Documents\Prometheus"
    "%WINDIR%\System32\Prometheus"
) do (
    if exist "%%~D\cli.lua" (
        echo      Found %%~D
        if exist "%PROMDIR%" rmdir /s /q "%PROMDIR%" >nul 2>&1
        xcopy "%%~D\*" "%PROMDIR%\" /E /I /H /Y >nul
        if exist "%PROMDIR%\cli.lua" exit /b 0
    )
)

echo      Downloading the official Prometheus source...
set "DL_URL=https://github.com/prometheus-lua/Prometheus/archive/refs/heads/master.zip"
set "DL_DEST=%PROMDIR%"
call :GetZip
if errorlevel 1 exit /b 1
if not exist "%PROMDIR%\cli.lua" exit /b 1
exit /b 0

:SetupLua
if exist "%LUADIR%\lua5.1.exe" exit /b 0

echo      Looking for your downloaded Lua folder...
for %%D in (
    "%USERPROFILE%\Downloads\lua-5.1.5_Win64_bin"
    "%USERPROFILE%\Downloads\Lua51"
    "%USERPROFILE%\Documents\lua-5.1.5_Win64_bin"
) do (
    if exist "%%~D\lua5.1.exe" (
        echo      Found %%~D
        if exist "%LUADIR%" rmdir /s /q "%LUADIR%" >nul 2>&1
        xcopy "%%~D\*" "%LUADIR%\" /E /I /H /Y >nul
        if exist "%LUADIR%\lua5.1.exe" exit /b 0
    )
)

set "LUAARCH=Win64"
if /I "%PROCESSOR_ARCHITECTURE%"=="x86" if not defined PROCESSOR_ARCHITEW6432 set "LUAARCH=Win32"

echo      Downloading Lua 5.1.5 from LuaBinaries...
set "DL_URL=https://sourceforge.net/projects/luabinaries/files/5.1.5/Tools%%20Executables/lua-5.1.5_%LUAARCH%_bin.zip/download"
set "DL_DEST=%LUADIR%"
call :GetZip
if errorlevel 1 exit /b 1
if not exist "%LUADIR%\lua5.1.exe" exit /b 1
exit /b 0

:GetZip
rem  Downloads DL_URL, verifies it is a real ZIP, and extracts it into DL_DEST.
rem  A curl-style User-Agent is required: SourceForge serves its cookie-consent
rem  HTML page (not the file) to PowerShell's default agent, which used to be
rem  saved as a .zip and then failed to unzip.
set "DL_ZIP=%TEMP%\luaobf-dl-%RANDOM%%RANDOM%.zip"
set "DL_TMP=%TEMP%\luaobf-ex-%RANDOM%%RANDOM%"
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
  "$zip='!DL_ZIP!'; $tmp='!DL_TMP!'; $dest='!DL_DEST!';" ^
  "Invoke-WebRequest -UseBasicParsing -Uri '!DL_URL!' -OutFile $zip -UserAgent 'curl/8.4.0';" ^
  "$fi=Get-Item -LiteralPath $zip;" ^
  "if($fi.Length -lt 1000){ throw ('Download failed - got only ' + $fi.Length + ' bytes. The server likely returned an error page instead of the file.') };" ^
  "$fs=[System.IO.File]::OpenRead($zip); $sig=New-Object byte[] 2; [void]$fs.Read($sig,0,2); $fs.Close();" ^
  "if($sig[0] -ne 80 -or $sig[1] -ne 75){ throw 'Downloaded file is not a ZIP (the server returned an HTML or error page). Check your internet connection, firewall or proxy, then try again.' };" ^
  "Add-Type -AssemblyName System.IO.Compression.FileSystem;" ^
  "if(Test-Path -LiteralPath $tmp){ Remove-Item -LiteralPath $tmp -Recurse -Force };" ^
  "[System.IO.Compression.ZipFile]::ExtractToDirectory($zip,$tmp);" ^
  "$items=@(Get-ChildItem -LiteralPath $tmp);" ^
  "if($items.Count -eq 1 -and $items[0].PSIsContainer){ $root=$items[0].FullName } else { $root=$tmp };" ^
  "if(Test-Path -LiteralPath $dest){ Remove-Item -LiteralPath $dest -Recurse -Force };" ^
  "Move-Item -LiteralPath $root -Destination $dest -Force;"
set "DL_RESULT=%ERRORLEVEL%"
del /q "%DL_ZIP%" >nul 2>&1
rmdir /s /q "%DL_TMP%" >nul 2>&1
exit /b %DL_RESULT%

:PythonMissing
echo.
echo  ==================================================
echo                    SETUP PAUSED
echo  ==================================================
echo.
echo   Python could not be detected after installation.
echo   Restart your PC, then run this installer again.
echo.
pause
exit /b 1

:ComponentsFailed
echo.
echo  ==================================================
echo                   SETUP STOPPED
echo  ==================================================
echo.
echo   PySide6 could not be installed. Check your internet
echo   connection, then run the installer again.
echo.
pause
exit /b 1

:PrometheusFailed
echo.
echo  ==================================================
echo                   SETUP STOPPED
echo  ==================================================
echo.
echo   Prometheus could not be prepared. Check your internet
echo   connection and run the installer again.
echo.
pause
exit /b 1

:LuaFailed
echo.
echo  ==================================================
echo                   SETUP STOPPED
echo  ==================================================
echo.
echo   Lua 5.1 could not be prepared. Check your internet
echo   connection and run the installer again.
echo.
pause
exit /b 1

:AppMissing
echo.
echo  ==================================================
echo                    APP FILE MISSING
echo  ==================================================
echo.
echo   Keep installer.bat and LuaU Obfuscator.pyw in the
echo   same folder, then run the installer again.
echo.
pause
exit /b 1

:NoWinget
echo.
echo  ==================================================
echo                   ONE THING NEEDED
echo  ==================================================
echo.
echo   Python is not installed, and this PC does not have
echo   winget available. Install or update "App Installer"
echo   from the Microsoft Store, then run this again.
echo.
pause
exit /b 1
