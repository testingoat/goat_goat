@echo off
echo 🚀 Starting Goat Goat Admin Panel - Local Development
echo.

REM Check if Flutter is installed
flutter --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Flutter is not installed or not in PATH
    pause
    exit /b 1
)

REM Enable Flutter web
echo 📱 Enabling Flutter Web...
flutter config --enable-web

REM Get dependencies
echo 📦 Getting Flutter dependencies...
flutter pub get

REM Check if Chrome is available
echo 🌐 Checking Chrome availability...
flutter devices | findstr "Chrome" >nul
if %errorlevel% neq 0 (
    echo ⚠️  Chrome not detected. Admin panel requires Chrome for development.
    echo    Please ensure Chrome is installed and try again.
    pause
    exit /b 1
)

REM Start the admin panel
echo 🎯 Starting Admin Panel on http://localhost:8080
echo.
echo 📋 Admin Panel Development Server:
echo    URL: http://localhost:8080
echo    Target: lib/main_admin.dart
echo    Environment: Development
echo.
echo 🔧 Available Commands:
echo    r - Hot reload
echo    R - Hot restart
echo    h - Help
echo    q - Quit
echo.

flutter run -d chrome --target=lib/main_admin.dart --web-port=8080 --web-hostname=localhost

echo.
echo 👋 Admin Panel development server stopped.
pause
