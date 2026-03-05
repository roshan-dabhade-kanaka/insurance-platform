@echo off
set PORT=%~1
if "%PORT%"=="" set PORT=3000
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%PORT% "') do (
    taskkill /PID %%a /F 2>nul
    echo Killed PID %%a on port %PORT%
    goto :done
)
echo Nothing listening on port %PORT%
:done
