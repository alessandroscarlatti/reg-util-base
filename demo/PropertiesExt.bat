@if "%DEBUG%"=="" echo off
setlocal enabledelayedexpansion
pushd "%~dp0"
powershell -file ./RegUtils.ps1 "%~dp0%~n0.properties" "%~n0"
if not "%ERRORLEVEL%"=="0" (
    pause
    exit /b 1
)