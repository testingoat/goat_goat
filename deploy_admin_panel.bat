@echo off
echo ========================================
echo   GOAT GOAT ADMIN PANEL DEPLOYMENT
echo ========================================
echo.

echo 📋 Step 1: Building Flutter Web Admin Panel...
flutter config --enable-web
if %errorlevel% neq 0 (
    echo ❌ Failed to enable web support
    pause
    exit /b 1
)

echo 🔨 Building admin panel with development authentication...
flutter build web --target=lib/main_admin.dart --release --dart-define=ADMIN_ENVIRONMENT=development --base-href=/
if %errorlevel% neq 0 (
    echo ❌ Build failed
    pause
    exit /b 1
)

echo ✅ Build completed successfully!
echo.

echo 📋 Step 2: Deployment Options
echo.
echo Choose your deployment method:
echo 1. Deploy via Netlify CLI (recommended)
echo 2. Manual deployment instructions
echo 3. Exit
echo.
set /p choice="Enter your choice (1-3): "

if "%choice%"=="1" goto netlify_cli
if "%choice%"=="2" goto manual_deploy
if "%choice%"=="3" goto end

:netlify_cli
echo.
echo 🚀 Deploying via Netlify CLI...
echo.

:: Check if Netlify CLI is installed
netlify --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Netlify CLI not found. Installing...
    npm install -g netlify-cli
    if %errorlevel% neq 0 (
        echo ❌ Failed to install Netlify CLI
        echo Please install Node.js first: https://nodejs.org/
        pause
        exit /b 1
    )
)

echo 📡 Deploying to Netlify...
netlify deploy --prod --dir=build/web
if %errorlevel% neq 0 (
    echo ❌ Deployment failed
    echo.
    echo Troubleshooting:
    echo 1. Make sure you're logged in: netlify login
    echo 2. Link your site: netlify link
    echo 3. Check your site settings in Netlify dashboard
    pause
    exit /b 1
)

echo ✅ Deployment successful!
echo.
echo 🌐 Your admin panel is now live at:
echo https://admin.goatgoat.info
echo.
goto end

:manual_deploy
echo.
echo 📋 MANUAL DEPLOYMENT INSTRUCTIONS
echo ========================================
echo.
echo 1. 📁 Upload Files:
echo    - Go to your Netlify dashboard: https://app.netlify.com/
echo    - Find your site: benevolent-toffee-58a972
echo    - Go to "Deploys" tab
echo    - Drag and drop the entire "build/web" folder
echo.
echo 2. 🔧 Alternative - Git Deployment:
echo    - Commit your changes: git add . && git commit -m "Update admin panel with Phase 1.2"
echo    - Push to GitHub: git push origin main
echo    - Netlify will auto-deploy from your repository
echo.
echo 3. 🌐 Access Your Admin Panel:
echo    - URL: https://admin.goatgoat.info
echo    - Login with your admin credentials
echo    - Navigate to "Review Moderation" to see the new features
echo.
echo 4. ✅ Verify Deployment:
echo    - Check that the Review Moderation tab works
echo    - Verify database connection
echo    - Test the new product review features
echo.
goto end

:end
echo.
echo 📊 DEPLOYMENT SUMMARY
echo ========================================
echo ✅ Flutter Web build: Complete
echo ✅ Admin panel updated with Phase 1.2 features
echo ✅ Product Review Moderation system integrated
echo ✅ Ready for production deployment
echo.
echo 🎉 PHASE 1.2 ADMIN PANEL READY!
echo.
echo Next steps:
echo 1. Test the admin panel at https://admin.goatgoat.info
echo 2. Verify the Review Moderation features work
echo 3. Proceed with Phase 1.3A (SMS Notifications)
echo.
pause
