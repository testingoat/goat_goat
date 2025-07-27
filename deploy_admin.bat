@echo off
echo Starting Goat Goat Admin Panel Deployment...

echo Cleaning previous builds...
if exist build rmdir /s /q build

echo Building Flutter web application with ADMIN entry point...
echo Target: lib/main_admin.dart (Admin Panel Entry Point)
flutter build web --target=lib/main_admin.dart --dart-define=FLUTTER_WEB_USE_SKIA=false --release
if %errorlevel% neq 0 (
    echo Build failed! Trying clean build with admin target...
    flutter clean
    flutter pub get
    flutter build web --target=lib/main_admin.dart --release
    if %errorlevel% neq 0 (
        echo ERROR: All build attempts failed!
        exit /b 1
    )
)

echo Verifying build output...
if not exist "build\web\index.html" (
    echo ERROR: Build output missing index.html!
    exit /b 1
)
echo ✓ Admin panel build successful

echo Copying Netlify configuration...
copy "_headers" "build\web\_headers"
copy "_redirects" "build\web\_redirects"

echo Deploying to Netlify...
netlify deploy --prod --dir=build/web --message="Admin panel deployment with CSP fixes"

echo Deployment completed!
echo Admin panel available at: https://goatgoat.info
