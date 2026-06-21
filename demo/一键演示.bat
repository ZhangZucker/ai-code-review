@echo off
chcp 65001 >nul
set "SCRIPT_DIR=%~dp0"

echo ============================================================
echo AI Code Review - Windows 一键答辩演示
echo ============================================================
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%run-demo.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
    echo 演示流程已结束。
) else (
    echo 演示未成功，请根据上方提示检查配置或网络。
)
echo.
pause
exit /b %EXIT_CODE%
