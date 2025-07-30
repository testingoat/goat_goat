# Goat Goat Admin Panel Deployment Script
# This script ensures the correct admin panel is built and deployed

Write-Host "🚀 Goat Goat Admin Panel Deployment Script" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

# Verify we're in the correct directory
if (-not (Test-Path "lib/main_admin.dart")) {
    Write-Host "❌ Error: lib/main_admin.dart not found!" -ForegroundColor Red
    Write-Host "Please run this script from the project root directory." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Found lib/main_admin.dart - proceeding with admin panel build" -ForegroundColor Green

# Clean previous build
Write-Host "🧹 Cleaning previous build..." -ForegroundColor Yellow
if (Test-Path "build/web") {
    Remove-Item -Recurse -Force "build/web"
    Write-Host "✅ Cleaned build/web directory" -ForegroundColor Green
}

# Build admin panel for web
Write-Host "🔨 Building admin panel for web..." -ForegroundColor Yellow
Write-Host "Command: flutter build web --release --target=lib/main_admin.dart" -ForegroundColor Cyan

$buildResult = flutter build web --release --target=lib/main_admin.dart

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    exit 1
}

# Verify build output
Write-Host "🔍 Verifying build output..." -ForegroundColor Yellow

if (-not (Test-Path "build/web/index.html")) {
    Write-Host "❌ Build verification failed: index.html not found!" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "build/web/main.dart.js")) {
    Write-Host "❌ Build verification failed: main.dart.js not found!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Build verification successful" -ForegroundColor Green

# Check if this is the admin panel build (look for admin-specific content)
$indexContent = Get-Content "build/web/index.html" -Raw
if ($indexContent -match "Goat Goat Admin Panel") {
    Write-Host "✅ Confirmed: Admin panel build detected" -ForegroundColor Green
} else {
    Write-Host "⚠️  Warning: Could not confirm admin panel build" -ForegroundColor Yellow
    Write-Host "Please manually verify the build is correct before deploying" -ForegroundColor Yellow
}

# Prompt for deployment
Write-Host ""
Write-Host "🚀 Ready to deploy admin panel to https://goatgoat.info" -ForegroundColor Green
Write-Host "This will:" -ForegroundColor White
Write-Host "  1. Add build/web to git (forced)" -ForegroundColor White
Write-Host "  2. Commit the changes" -ForegroundColor White
Write-Host "  3. Push to trigger Netlify deployment" -ForegroundColor White
Write-Host ""

$deploy = Read-Host "Do you want to proceed with deployment? (y/N)"

if ($deploy -eq "y" -or $deploy -eq "Y") {
    Write-Host "📦 Adding build files to git..." -ForegroundColor Yellow
    git add -f build/web
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to add build files to git!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "💾 Committing changes..." -ForegroundColor Yellow
    $commitMessage = "Deploy admin panel build - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    git commit -m "$commitMessage

- Built with target: lib/main_admin.dart
- Verified admin panel build output
- Ready for https://goatgoat.info deployment"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to commit changes!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "🚀 Pushing to trigger deployment..." -ForegroundColor Yellow
    git push origin main
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to push changes!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    Write-Host "✅ Deployment initiated successfully!" -ForegroundColor Green
    Write-Host "🌐 Monitor deployment at: https://app.netlify.com/sites/goatgoat/deploys" -ForegroundColor Cyan
    Write-Host "🔗 Verify deployment at: https://goatgoat.info" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📋 Post-deployment checklist:" -ForegroundColor Yellow
    Write-Host "  ✓ Visit https://goatgoat.info" -ForegroundColor White
    Write-Host "  ✓ Verify 'Goat Goat Admin Panel' title" -ForegroundColor White
    Write-Host "  ✓ Check admin login screen appears" -ForegroundColor White
    Write-Host "  ✓ Test admin authentication" -ForegroundColor White
    
} else {
    Write-Host "⏸️  Deployment cancelled by user" -ForegroundColor Yellow
    Write-Host "Build files are ready in build/web when you're ready to deploy" -ForegroundColor White
}

Write-Host ""
Write-Host "🎉 Script completed!" -ForegroundColor Green
