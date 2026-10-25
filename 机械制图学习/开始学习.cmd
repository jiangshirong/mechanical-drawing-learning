@echo off
cd /d "%~dp0"
if "%~1"=="--qa" (
  start "" "%~dp0runtime\godot.exe" --path "%~dp0." --audio-driver Dummy --position -6000,-6000 --log-file "%~dp0runtime\latest-run.log" -- %*
) else (
  start "" "%~dp0runtime\godot.exe" --path "%~dp0." --log-file "%~dp0runtime\latest-run.log" -- %*
)
