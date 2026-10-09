@echo off
cd /d "%~dp0"
dotnet publish -c Release -r win-x64 --self-contained false -o publish
echo.
echo Done. Copy everything inside the "publish" folder to your IIS site folder.
pause
