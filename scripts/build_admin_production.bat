@echo off
echo 🏗️  Building Goat Goat Admin Panel for Production
echo.

REM Check if Flutter is installed
flutter --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Flutter is not installed or not in PATH
    pause
    exit /b 1
)

REM Clean previous builds
echo 🧹 Cleaning previous builds...
if exist "build\web" rmdir /s /q "build\web"

REM Enable Flutter web
echo 📱 Enabling Flutter Web...
flutter config --enable-web

REM Get dependencies
echo 📦 Getting Flutter dependencies...
flutter pub get

REM Build for production
echo 🚀 Building admin panel for production...
echo    Target: lib/main_admin.dart
echo    Renderer: HTML (for better compatibility)
echo    Mode: Release
echo.

flutter build web ^
  --target=lib/main_admin.dart ^
  --release ^
  --web-renderer html ^
  --dart-define=FLUTTER_WEB_USE_SKIA=false ^
  --dart-define=FLUTTER_WEB_AUTO_DETECT=false

if %errorlevel% neq 0 (
    echo ❌ Build failed!
    pause
    exit /b 1
)

echo.
echo ✅ Admin panel build completed successfully!
echo 📁 Output directory: build\web
echo 🌐 Ready for deployment to Netlify
echo.

REM Show build info
echo 📊 Build Information:
dir "build\web" /b
echo.

REM Check if Netlify CLI is available
netlify --version >nul 2>&1
if %errorlevel% equ 0 (
    echo 🚀 Netlify CLI detected. You can now deploy with:
    echo    netlify deploy --prod --dir=build/web
    echo.
    echo 📋 Your Netlify Project Details:
    echo    Project ID: 3e82efaf-d46b-4f18-a464-1b11bff4d568
    echo    Site Name: benevolent-toffee-58a972
    echo    Admin URL: https://admin.goatgoat.info
    echo.
) else (
    echo 💡 To deploy, you can:
    echo    1. Install Netlify CLI: npm install -g netlify-cli
    echo    2. Login: netlify login
    echo    3. Link project: netlify link --id=3e82efaf-d46b-4f18-a464-1b11bff4d568
    echo    4. Deploy: netlify deploy --prod --dir=build/web
    echo    5. Or push to Git for automatic deployment
    echo.
)

pause
