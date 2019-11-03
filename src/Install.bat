@if "%DEBUG%"=="" echo off
setlocal enabledelayedexpansion
pushd "%~dp0"
@rem create the backup reg file
set "REG_FILE=%~n0.reg.txt"
powershell "ipmo ./RegUtil.psm1; Backup-RegFile \"%REG_FILE%\""
if not "%ERRORLEVEL%"=="0" pause && exit /b 1
regedit "%~dp0%~n0.reg.txt"
@rem powershell "Start-Process reg -ArgumentList @('import', '%~n0.reg') -Wait -verb runas"
if not "%ERRORLEVEL%"=="0" ( pause && exit /b 1 )

exit /b %ERRORLEVEL%