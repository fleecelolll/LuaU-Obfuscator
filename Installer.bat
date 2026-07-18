@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Lua Obfuscator Installer

set "NO_PAUSE=0"
set "ASSUME_YES=0"

:ParseArguments
if "%~1"=="" goto ArgumentsReady
if /I "%~1"=="--no-pause" set "NO_PAUSE=1"
if /I "%~1"=="--yes" set "ASSUME_YES=1"
shift
goto ParseArguments

:ArgumentsReady

set "ROOT=%~dp0"
set "APP_FILE=%ROOT%Lua Obfuscator.pyw"
set "LOG=%ROOT%setup.log"
set "RUNTIME=%ROOT%.runtime"
set "DOWNLOADS=%RUNTIME%\downloads"
set "VENV=%ROOT%.venv"
set "VENV_PY=%VENV%\Scripts\python.exe"
set "VENV_PYW=%VENV%\Scripts\pythonw.exe"
set "HERCULES_DIR=%RUNTIME%\hercules"
set "HERCULES_CLI=%HERCULES_DIR%\src\hercules.lua"
set "LUA_DIR=%RUNTIME%\lua54"
set "LUA_EXE=%LUA_DIR%\lua54.exe"
set "LUAC_EXE=%LUA_DIR%\luac54.exe"

set "PYSIDE_VERSION=6.11.1"
set "PYPI_INDEX=https://pypi.org/simple"
set "HERCULES_COMMIT=ace084c897369faf584dfa3baeea159d7b205213"
set "HERCULES_URL=https://codeload.github.com/zeusssz/hercules-obfuscator/zip/%HERCULES_COMMIT%"
set "HERCULES_SHA256=8E683C9D49B8298489C12E051ECE8DF55808AC8230914F10814E88DA5408019B"
set "LUA_VERSION=5.4.8"
set "LUA_URL=https://downloads.sourceforge.net/project/luabinaries/5.4.8/Tools%%20Executables/lua-5.4.8_Win64_bin.zip"
set "LUA_SHA256=20321E893509E575D2454DD7BBF05342C1F3CB1B3788C0EC5A55AE4279DDE169"

set "NATIVE_ARCH=%PROCESSOR_ARCHITECTURE%"
if defined PROCESSOR_ARCHITEW6432 set "NATIVE_ARCH=%PROCESSOR_ARCHITEW6432%"
if /I "%NATIVE_ARCH%"=="AMD64" goto ArchitectureReady
if /I "%NATIVE_ARCH%"=="ARM64" goto ArchitectureReady
set "FAIL_MESSAGE=This installer supports 64-bit Windows only."
goto Failed

:ArchitectureReady
if not exist "%RUNTIME%" mkdir "%RUNTIME%" >nul 2>&1
if not exist "%RUNTIME%" (
    set "FAIL_MESSAGE=Could not create the private runtime folder."
    goto Failed
)
if not exist "%DOWNLOADS%" mkdir "%DOWNLOADS%" >nul 2>&1
if not exist "%DOWNLOADS%" (
    set "FAIL_MESSAGE=Could not create the private download folder."
    goto Failed
)

>>"%LOG%" echo.
>>"%LOG%" echo ============================================================
>>"%LOG%" echo Setup started: %DATE% %TIME%
>>"%LOG%" echo Project root: "%ROOT%"
>>"%LOG%" echo Native architecture: %NATIVE_ARCH%
>>"%LOG%" echo ============================================================

cls
echo.
echo  ==================================================
echo                 LUA OBFUSCATOR SETUP
echo  ==================================================
echo.
echo   App-specific components stay inside this folder.
echo   It does not need administrator access.
echo.
echo      Python environment     runs the app
echo      PySide6                the app window
echo      Hercules               obfuscates Lua and Luau
echo      Lua 5.4                runs Hercules
echo.
echo   Keep this window open until every check passes.
echo   The first setup can take a few minutes.
echo.
echo  ==================================================

if not exist "%APP_FILE%" (
    set "FAIL_MESSAGE=Lua Obfuscator.pyw is missing from this folder."
    goto Failed
)

echo.
echo   [ STEP 1 / 5 ]   Private Python environment
echo.
call :ValidateVenv
if not errorlevel 1 (
    echo      Existing environment is valid. Keeping it.
    call :Log "Existing virtual environment passed validation."
    goto PythonEnvironmentReady
)

call :FindBasePython
if defined BASE_PY goto BasePythonReady

echo      No compatible 64-bit CPython was found.
echo.
echo      This app supports Python 3.10 through 3.14.
echo      An older or unsupported version may stop it from working.
echo      Setup can install Python 3.13 for your Windows user
echo      through winget. It does not need administrator access.
echo.
where winget.exe >nul 2>nul
if errorlevel 1 (
    set "FAIL_MESSAGE=Python is missing and winget is unavailable. Install Python 3.10 through 3.14, then run setup again."
    goto Failed
)

if "%ASSUME_YES%"=="1" (
    echo      Install Python 3.13 now? [Y/N]: Y
) else (
    choice /C YN /N /M "      Install Python 3.13 now? [Y/N]: "
    if errorlevel 2 goto Cancelled
)

echo.
echo      Installing Python for the current Windows user...
winget install --id Python.Python.3.13 --exact --source winget --silent --scope user --accept-source-agreements --accept-package-agreements >>"%LOG%" 2>&1
if errorlevel 1 (
    set "FAIL_MESSAGE=Python could not be installed through winget."
    goto Failed
)
call :FindBasePython
if not defined BASE_PY (
    set "FAIL_MESSAGE=Python was installed but could not be detected. Restart Windows, then run setup again."
    goto Failed
)

:BasePythonReady
call :DescribePython "%BASE_PY%"
echo      Creating the app's private environment...
call :CreateVenv
if errorlevel 1 (
    set "FAIL_MESSAGE=The private Python environment could not be created."
    goto Failed
)

:PythonEnvironmentReady
call :ValidateVenv
if errorlevel 1 (
    set "FAIL_MESSAGE=The private Python environment did not pass validation."
    goto Failed
)
echo      Done.

echo.
echo   [ STEP 2 / 5 ]   App components
echo.
echo      Installing or updating trusted packages from PyPI...
echo      Existing components are reused whenever possible.
call :InstallPySide
if errorlevel 1 (
    set "FAIL_MESSAGE=PySide6 could not be installed or verified."
    goto Failed
)
echo      Done.

echo.
echo   [ STEP 3 / 5 ]   Hercules
echo.
call :ValidateHercules
if not errorlevel 1 (
    echo      Current local copy is valid. Keeping it.
    call :Log "Existing Hercules source passed validation."
    goto HerculesReady
)
echo      Downloading the pinned Hercules source...
call :InstallHercules
if errorlevel 1 (
    set "FAIL_MESSAGE=Hercules could not be installed or verified."
    goto Failed
)
:HerculesReady
echo      Done.

echo.
echo   [ STEP 4 / 5 ]   Lua 5.4
echo.
call :ValidateLua
if not errorlevel 1 (
    echo      Current local copy is valid. Keeping it.
    call :Log "Existing Lua runtime passed validation."
    goto LuaReady
)
echo      Downloading the verified Lua 5.4.8 runtime...
call :InstallLua
if errorlevel 1 (
    set "FAIL_MESSAGE=Lua 5.4.8 could not be installed or verified."
    goto Failed
)
:LuaReady
echo      Done.

echo.
echo   [ STEP 5 / 5 ]   Final checks
echo.
echo      Testing every required component...
call :VerifyEverything
if errorlevel 1 (
    set "FAIL_MESSAGE=One or more final component checks failed."
    goto Failed
)
echo      Every check passed.

if exist "%DOWNLOADS%" rmdir /s /q "%DOWNLOADS%" >>"%LOG%" 2>&1
call :Log "Setup completed successfully."

echo.
echo  ==================================================
echo                ALL SET, YOU ARE READY
echo  ==================================================
echo.
echo   Double click "Lua Obfuscator.pyw" to start.
echo.
echo   Run this installer again whenever you want to
echo   repair the app's private components or runtime.
echo.
echo   Setup details were saved to:
echo   "%LOG%"
echo.
call :PauseIfNeeded
exit /b 0

:Cancelled
call :Log "Setup cancelled by the user before Python installation."
echo.
echo  ==================================================
echo                     SETUP CANCELLED
echo  ==================================================
echo.
echo   Nothing was installed outside this project folder.
echo   Run Installer.bat again whenever you are ready.
echo.
call :PauseIfNeeded
exit /b 1

:Failed
if not defined FAIL_MESSAGE set "FAIL_MESSAGE=Setup stopped because an unexpected error occurred."
call :Log "ERROR: %FAIL_MESSAGE%"
echo.
echo  ==================================================
echo                     SETUP STOPPED
echo  ==================================================
echo.
echo   %FAIL_MESSAGE%
echo.
echo   No success was reported because all checks did not pass.
echo   The detailed log is here:
echo.
echo   "%LOG%"
echo.
echo   Fix the listed problem, then run Installer.bat again.
echo.
call :PauseIfNeeded
exit /b 1

:FindBasePython
set "BASE_PY="
for %%V in (3.14 3.13 3.12 3.11 3.10) do call :TryPyTag %%V
if defined BASE_PY exit /b 0
for /f "delims=" %%P in ('where python.exe 2^>nul ^| findstr /V /I /C:"Microsoft\WindowsApps"') do call :TryPythonPath "%%P"
if defined BASE_PY exit /b 0
for %%P in (
    "%LocalAppData%\Programs\Python\Python314\python.exe"
    "%LocalAppData%\Programs\Python\Python313\python.exe"
    "%LocalAppData%\Programs\Python\Python312\python.exe"
    "%LocalAppData%\Programs\Python\Python311\python.exe"
    "%LocalAppData%\Programs\Python\Python310\python.exe"
    "%ProgramFiles%\Python314\python.exe"
    "%ProgramFiles%\Python313\python.exe"
    "%ProgramFiles%\Python312\python.exe"
    "%ProgramFiles%\Python311\python.exe"
    "%ProgramFiles%\Python310\python.exe"
) do call :TryPythonPath "%%~fP"
exit /b 0

:TryPyTag
if defined BASE_PY exit /b 0
set "CANDIDATE_FILE=%RUNTIME%\python-candidate.txt"
py -%~1 -I -c "import sys; print(sys.executable)" >"%CANDIDATE_FILE%" 2>nul
if errorlevel 1 exit /b 1
set "CANDIDATE="
set /p "CANDIDATE="<"%CANDIDATE_FILE%"
del /f /q "%CANDIDATE_FILE%" >nul 2>nul
if not defined CANDIDATE exit /b 1
call :TryPythonPath "%CANDIDATE%"
exit /b %ERRORLEVEL%

:TryPythonPath
if defined BASE_PY exit /b 0
if "%~1"=="" exit /b 1
if not exist "%~1" exit /b 1
call :ValidatePython "%~1"
if errorlevel 1 exit /b 1
set "BASE_PY=%~1"
call :Log "Found compatible base CPython: %~1"
exit /b 0

:ValidatePython
if "%~1"=="" exit /b 1
if not exist "%~1" exit /b 1
"%~1" -I -c "import sys, struct, venv, ensurepip; ok = sys.implementation.name == 'cpython' and (3, 10) <= sys.version_info[:2] < (3, 15) and struct.calcsize('P') == 8; raise SystemExit(0 if ok else 1)" >>"%LOG%" 2>&1
exit /b %ERRORLEVEL%

:DescribePython
"%~1" -I -c "import platform, sys; print('Selected CPython ' + platform.python_version() + ' at ' + sys.executable)" >>"%LOG%" 2>&1
exit /b 0

:CreateVenv
if not defined BASE_PY exit /b 1
call :ValidatePython "%BASE_PY%"
if errorlevel 1 exit /b 1
if exist "%VENV%" rmdir /s /q "%VENV%" >>"%LOG%" 2>&1
if exist "%VENV%" exit /b 1
"%BASE_PY%" -I -m venv --copies "%VENV%" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
call :ValidateVenv
exit /b %ERRORLEVEL%

:ValidateVenv
if not exist "%VENV_PY%" exit /b 1
if not exist "%VENV_PYW%" exit /b 1
"%VENV_PY%" -I -c "import sys, struct; ok = sys.implementation.name == 'cpython' and (3, 10) <= sys.version_info[:2] < (3, 15) and struct.calcsize('P') == 8 and sys.prefix != sys.base_prefix; raise SystemExit(0 if ok else 1)" >>"%LOG%" 2>&1
exit /b %ERRORLEVEL%

:InstallPySide
call :ValidateVenv
if errorlevel 1 exit /b 1
"%VENV_PY%" -I -m pip --isolated --disable-pip-version-check install --upgrade --no-cache-dir --only-binary=:all: --index-url "%PYPI_INDEX%" pip >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
"%VENV_PY%" -I -m pip --isolated --disable-pip-version-check install --upgrade --no-cache-dir --only-binary=:all: --index-url "%PYPI_INDEX%" "PySide6==%PYSIDE_VERSION%" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
call :VerifyPySide
exit /b %ERRORLEVEL%

:VerifyPySide
if not exist "%VENV_PY%" exit /b 1
"%VENV_PY%" -I -c "import PySide6; from importlib.metadata import version; assert version('PySide6') == '%PYSIDE_VERSION%'; print('PySide6=' + version('PySide6'))" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
"%VENV_PY%" -I -m pip --isolated --disable-pip-version-check check >>"%LOG%" 2>&1
exit /b %ERRORLEVEL%

:ValidateHercules
if not exist "%HERCULES_CLI%" exit /b 1
if not exist "%HERCULES_DIR%\src\pipeline.lua" exit /b 1
if not exist "%HERCULES_DIR%\src\manifest.lua" exit /b 1
if not exist "%HERCULES_DIR%\LICENSE" exit /b 1
if not exist "%HERCULES_DIR%\.fleece-version" exit /b 1
set "FOUND_HERCULES_VERSION="
set /p "FOUND_HERCULES_VERSION="<"%HERCULES_DIR%\.fleece-version"
if /I not "%FOUND_HERCULES_VERSION%"=="%HERCULES_COMMIT%" exit /b 1
exit /b 0

:InstallHercules
set "HERCULES_ARCHIVE=%DOWNLOADS%\hercules-%HERCULES_COMMIT%.zip"
set "HERCULES_EXTRACT=%RUNTIME%\hercules.extract"
set "HERCULES_NEW=%RUNTIME%\hercules.new"
set "DL_URL=%HERCULES_URL%"
call :DownloadAndVerify "%HERCULES_ARCHIVE%" "%HERCULES_SHA256%"
if errorlevel 1 exit /b 1
if exist "%HERCULES_EXTRACT%" rmdir /s /q "%HERCULES_EXTRACT%" >>"%LOG%" 2>&1
if exist "%HERCULES_NEW%" rmdir /s /q "%HERCULES_NEW%" >>"%LOG%" 2>&1
set "ARCHIVE_FILE=%HERCULES_ARCHIVE%"
set "EXTRACT_DIR=%HERCULES_EXTRACT%"
set "NEW_DIR=%HERCULES_NEW%"
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath $env:ARCHIVE_FILE -DestinationPath $env:EXTRACT_DIR -Force; $root=Get-ChildItem -LiteralPath $env:EXTRACT_DIR -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'src\hercules.lua') } | Select-Object -First 1; if(-not $root){throw 'Hercules archive did not contain the expected source.'}; Move-Item -LiteralPath $root.FullName -Destination $env:NEW_DIR; Set-Content -LiteralPath (Join-Path $env:NEW_DIR '.fleece-version') -Value $env:HERCULES_COMMIT -Encoding ASCII" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
call :ReplaceDirectory "%HERCULES_NEW%" "%HERCULES_DIR%"
if errorlevel 1 exit /b 1
if exist "%HERCULES_EXTRACT%" rmdir /s /q "%HERCULES_EXTRACT%" >>"%LOG%" 2>&1
del /f /q "%HERCULES_ARCHIVE%" >nul 2>nul
call :ValidateHercules
exit /b %ERRORLEVEL%

:ValidateLua
call :ValidateLuaAt "%LUA_DIR%"
exit /b %ERRORLEVEL%

:ValidateLuaAt
if "%~1"=="" exit /b 1
if not exist "%~1\lua54.exe" exit /b 1
if not exist "%~1\luac54.exe" exit /b 1
set "LUA_CHECK=%RUNTIME%\lua-check.txt"
"%~1\lua54.exe" -v >"%LUA_CHECK%" 2>&1
if errorlevel 1 exit /b 1
findstr /I /C:"Lua %LUA_VERSION%" "%LUA_CHECK%" >nul
if errorlevel 1 exit /b 1
type "%LUA_CHECK%" >>"%LOG%"
"%~1\luac54.exe" -v >"%LUA_CHECK%" 2>&1
if errorlevel 1 exit /b 1
findstr /I /C:"Lua %LUA_VERSION%" "%LUA_CHECK%" >nul
if errorlevel 1 exit /b 1
type "%LUA_CHECK%" >>"%LOG%"
del /f /q "%LUA_CHECK%" >nul 2>nul
exit /b 0

:InstallLua
set "LUA_ARCHIVE=%DOWNLOADS%\lua-%LUA_VERSION%-win64.zip"
set "LUA_NEW=%RUNTIME%\lua54.new"
set "DL_URL=%LUA_URL%"
call :DownloadAndVerify "%LUA_ARCHIVE%" "%LUA_SHA256%"
if errorlevel 1 exit /b 1
if exist "%LUA_NEW%" rmdir /s /q "%LUA_NEW%" >>"%LOG%" 2>&1
set "ARCHIVE_FILE=%LUA_ARCHIVE%"
set "NEW_DIR=%LUA_NEW%"
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath $env:ARCHIVE_FILE -DestinationPath $env:NEW_DIR -Force; if(-not (Test-Path -LiteralPath (Join-Path $env:NEW_DIR 'lua54.exe')) -or -not (Test-Path -LiteralPath (Join-Path $env:NEW_DIR 'luac54.exe'))){throw 'Lua archive did not contain the expected tools.'}" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
call :ValidateLuaAt "%LUA_NEW%"
if errorlevel 1 exit /b 1
call :ReplaceDirectory "%LUA_NEW%" "%LUA_DIR%"
if errorlevel 1 exit /b 1
del /f /q "%LUA_ARCHIVE%" >nul 2>nul
call :ValidateLua
exit /b %ERRORLEVEL%

:VerifyEverything
call :ValidateVenv
if errorlevel 1 exit /b 1
call :VerifyPySide
if errorlevel 1 exit /b 1
call :ValidateHercules
if errorlevel 1 exit /b 1
call :ValidateLua
if errorlevel 1 exit /b 1
"%VENV_PY%" -I -c "from pathlib import Path; app=Path(r'%APP_FILE%'); compile(app.read_text(encoding='utf-8'), str(app), 'exec'); print('Application source compiled successfully.')" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
call :RunEngineChecks
exit /b %ERRORLEVEL%

:RunEngineChecks
set "CHECK_DIR=%RUNTIME%\checks"
if exist "%CHECK_DIR%" rmdir /s /q "%CHECK_DIR%" >>"%LOG%" 2>&1
mkdir "%CHECK_DIR%" >>"%LOG%" 2>&1
if not exist "%CHECK_DIR%" exit /b 1
>"%CHECK_DIR%\lua-smoke.lua" echo local message = "lua-ok"
>>"%CHECK_DIR%\lua-smoke.lua" echo print(message)
>"%CHECK_DIR%\luau-smoke.luau" echo local message: string = "luau-ok"
>>"%CHECK_DIR%\luau-smoke.luau" echo print(message)
pushd "%HERCULES_DIR%\src" >nul 2>&1
if errorlevel 1 exit /b 1
"%LUA_EXE%" "hercules.lua" "%CHECK_DIR%\lua-smoke.lua" --target lua --light --no-watermark >>"%LOG%" 2>&1
set "LUA_SMOKE_CODE=%ERRORLEVEL%"
"%LUA_EXE%" "hercules.lua" "%CHECK_DIR%\luau-smoke.luau" --target luau --light --no-watermark >>"%LOG%" 2>&1
set "LUAU_SMOKE_CODE=%ERRORLEVEL%"
popd >nul 2>&1
if not "%LUA_SMOKE_CODE%"=="0" exit /b 1
if not "%LUAU_SMOKE_CODE%"=="0" exit /b 1
if not exist "%CHECK_DIR%\lua-smoke_obfuscated.lua" exit /b 1
if not exist "%CHECK_DIR%\luau-smoke_obfuscated.luau" exit /b 1
"%LUAC_EXE%" -p "%CHECK_DIR%\lua-smoke_obfuscated.lua" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
rmdir /s /q "%CHECK_DIR%" >>"%LOG%" 2>&1
exit /b 0

:ReplaceDirectory
set "REPLACE_NEW=%~1"
set "REPLACE_TARGET=%~2"
set "REPLACE_BACKUP=%~2.old"
if not exist "%REPLACE_NEW%" exit /b 1
if exist "%REPLACE_BACKUP%" rmdir /s /q "%REPLACE_BACKUP%" >>"%LOG%" 2>&1
if exist "%REPLACE_BACKUP%" exit /b 1
if not exist "%REPLACE_TARGET%" goto ReplaceMoveNew
move "%REPLACE_TARGET%" "%REPLACE_BACKUP%" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1

:ReplaceMoveNew
move "%REPLACE_NEW%" "%REPLACE_TARGET%" >>"%LOG%" 2>&1
if errorlevel 1 goto ReplaceRollback
if exist "%REPLACE_BACKUP%" rmdir /s /q "%REPLACE_BACKUP%" >>"%LOG%" 2>&1
exit /b 0

:ReplaceRollback
if exist "%REPLACE_TARGET%" rmdir /s /q "%REPLACE_TARGET%" >>"%LOG%" 2>&1
if exist "%REPLACE_BACKUP%" move "%REPLACE_BACKUP%" "%REPLACE_TARGET%" >>"%LOG%" 2>&1
exit /b 1

:DownloadAndVerify
set "DL_FILE=%~1"
set "DL_HASH=%~2"
if not defined DL_URL exit /b 1
if exist "%DL_FILE%" del /f /q "%DL_FILE%" >nul 2>nul
call :Log "Downloading: %DL_URL%"
where curl.exe >nul 2>nul
if errorlevel 1 goto DownloadWithPowerShell
curl.exe --fail --location --silent --show-error --retry 3 --retry-delay 2 --connect-timeout 30 --proto "=https" --proto-redir "=https" -o "%DL_FILE%" "%DL_URL%" >>"%LOG%" 2>&1
if not errorlevel 1 goto VerifyDownload
call :Log "curl failed; retrying with PowerShell."

:DownloadWithPowerShell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri $env:DL_URL -OutFile $env:DL_FILE -UserAgent 'curl/8.4.0'" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1

:VerifyDownload
if not exist "%DL_FILE%" exit /b 1
call :VerifyFileHash "%DL_FILE%" "%DL_HASH%"
exit /b %ERRORLEVEL%

:VerifyFileHash
set "VERIFY_FILE=%~1"
set "VERIFY_HASH=%~2"
if not exist "%VERIFY_FILE%" exit /b 1
if not defined VERIFY_HASH exit /b 1
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $stream=[IO.File]::OpenRead($env:VERIFY_FILE); try{$sha=[Security.Cryptography.SHA256]::Create(); try{$actual=([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','')} finally{$sha.Dispose()}} finally{$stream.Dispose()}; if($actual -ne $env:VERIFY_HASH){throw ('SHA-256 mismatch. Expected {0}, got {1}' -f $env:VERIFY_HASH,$actual)}; Write-Output ('Verified SHA-256: ' + $actual)" >>"%LOG%" 2>&1
exit /b %ERRORLEVEL%

:Log
>>"%LOG%" echo [%DATE% %TIME%] %~1
exit /b 0

:PauseIfNeeded
if "%NO_PAUSE%"=="1" exit /b 0
pause
exit /b 0
