@echo off
echo 🚀 Deploying Goat Goat Admin Panel to Netlify
echo.

REM Check if Netlify CLI is installed
netlify --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Netlify CLI is not installed
    echo 💡 Install it with: npm install -g netlify-cli
    echo    Then run: netlify login
    pause
    exit /b 1
)

REM Check if build directory exists
if not exist "build\web" (
    echo ❌ Build directory not found
    echo 💡 Run build_admin_production.bat first
    pause
    exit /b 1
)

REM Check if user is logged in to Netlify
netlify status >nul 2>&1
if %errorlevel% neq 0 (
    echo 🔐 Please login to Netlify first...
    netlify login
    if %errorlevel% neq 0 (
        echo ❌ Netlify login failed
        pause
        exit /b 1
    )
)

echo 📋 Deployment Configuration:
echo    Source: build\web
echo    Target: admin.goatgoat.info
echo    Environment: Production
echo.

REM Ask for confirmation
set /p confirm="Deploy to production? (y/N): "
if /i not "%confirm%"=="y" (
    echo ❌ Deployment cancelled
    pause
    exit /b 0
)

echo.
echo 🚀 Deploying to Netlify...

REM Deploy to production
netlify deploy --prod --dir=build/web --message="Admin panel deployment from local"

if %errorlevel% neq 0 (
    echo ❌ Deployment failed!
    pause
    exit /b 1
)

echo.
echo ✅ Deployment completed successfully!
echo 🌐 Admin panel is now live at: https://admin.goatgoat.info
echo.

REM Show deployment info
echo 📊 Deployment Information:
netlify status

echo.
echo 🎉 Admin panel deployment complete!
echo 💡 Next steps:
echo    1. Test the admin panel at https://admin.goatgoat.info
echo    2. Login with: admin@goatgoat.com / admin123 (development)
echo    3. Verify all features work correctly
echo    4. Set up custom domain if needed
echo.

pause
