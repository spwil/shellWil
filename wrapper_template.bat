<# :
@echo off
:: Guardamos la ruta exacta antes de entrar a PowerShell, estos fragmentos son para que que powershell se ejecute en una extension .bat;; Script Híbrido (Polyglot)
set "SCRIPT_PATH=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((Get-Content '%~f0') -join [Environment]::NewLine)"
exit /b
#>
