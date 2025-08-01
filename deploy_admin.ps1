#!/usr/bin/env pwsh

# Enhanced deployment script for Goat Goat Admin Panel
# Handles CSP issues and ensures proper Flutter web deployment

Write-Host "🚀 Starting Goat Goat Admin Panel Deployment..." -ForegroundColor Green

# Step 1: Clean previous builds
Write-Host "🧹 Cleaning previous builds..." -ForegroundColor Yellow
if (Test-Path "build") {
    Remove-Item -Recurse -Force "build"
    Write-Host "✅ Cleaned build directory" -ForegroundColor Green
}

# Step 2: Build Flutter web with HTML renderer (more compatible)
Write-Host "🔨 Building Flutter web application with HTML renderer..." -ForegroundColor Yellow
$env:FLUTTER_WEB_USE_SKIA = "false"
$buildResult = flutter build web --web-renderer html --dart-define=FLUTTER_WEB_USE_SKIA=false --release --source-maps --base-href="/"
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Flutter build failed! Trying alternative build..." -ForegroundColor Red
    
    # Fallback: Try with auto renderer
    Write-Host "🔄 Attempting fallback build with auto renderer..." -ForegroundColor Yellow
    $buildResult = flutter build web --web-renderer auto --release --base-href="/"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ All build attempts failed!" -ForegroundColor Red
        exit 1
    }
}
Write-Host "✅ Flutter build completed successfully" -ForegroundColor Green

# Step 3: Create/Update Netlify configuration files with MIME type fixes
Write-Host "📋 Creating Netlify configuration with MIME type fixes..." -ForegroundColor Yellow

# Create _headers file with proper MIME types - CRITICAL FOR PREVENTING RECURRING ISSUES
$headersContent = @"
# Netlify Headers Configuration for Flutter Web - PREVENTS MIME TYPE ERRORS
/*.js
  Content-Type: application/javascript; charset=utf-8
  Cache-Control: public, max-age=31536000, immutable

/*.dart.js
  Content-Type: application/javascript; charset=utf-8
  Cache-Control: public, max-age=31536000, immutable

/main.dart.js
  Content-Type: application/javascript; charset=utf-8
  Cache-Control: public, max-age=31536000, immutable

/flutter_service_worker.js
  Content-Type: application/javascript; charset=utf-8
  Cache-Control: public, max-age=0, must-revalidate

/flutter_bootstrap.js
  Content-Type: application/javascript; charset=utf-8
  Cache-Control: public, max-age=31536000, immutable

/*.css
  Content-Type: text/css; charset=utf-8
  Cache-Control: public, max-age=31536000, immutable

/*.html
  Content-Type: text/html; charset=utf-8
  Cache-Control: public, max-age=0, must-revalidate

/*.json
  Content-Type: application/json; charset=utf-8

# Security headers
/*
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  X-XSS-Protection: 1; mode=block
"@

$headersContent | Out-File -FilePath "build/web/_headers" -Encoding UTF8 -Force

# Create _redirects file for SPA routing
$redirectsContent = @"
# Redirect rules for Flutter Web SPA
/*    /index.html   200
"@

$redirectsContent | Out-File -FilePath "build/web/_redirects" -Encoding UTF8 -Force

Write-Host "✅ Netlify configuration created with MIME type fixes" -ForegroundColor Green

# Step 4: Verify build output
Write-Host "🔍 Verifying build output..." -ForegroundColor Yellow
$requiredFiles = @("index.html", "main.dart.js", "flutter_bootstrap.js")
$missingFiles = @()

foreach ($file in $requiredFiles) {
    if (-not (Test-Path "build/web/$file")) {
        $missingFiles += $file
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "❌ Missing required files: $($missingFiles -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host "✅ All required files present" -ForegroundColor Green

# Step 5: Deploy to Netlify
Write-Host "🌐 Deploying to Netlify..." -ForegroundColor Yellow
$deployResult = netlify deploy --prod --dir=build/web --message="Admin panel deployment with CSP fixes and HTML renderer"
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Netlify deployment failed!" -ForegroundColor Red
    exit 1
}

Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
Write-Host "🔗 Admin panel available at: https://goatgoat.info" -ForegroundColor Cyan
Write-Host "" -ForegroundColor White
Write-Host "📝 Testing Checklist:" -ForegroundColor Yellow
Write-Host "   ✓ Page loads without blank screen" -ForegroundColor White
Write-Host "   ✓ No CSP errors in browser console" -ForegroundColor White
Write-Host "   ✓ Login form is visible and functional" -ForegroundColor White
Write-Host "   ✓ Authentication works properly" -ForegroundColor White
Write-Host "   ✓ No 'Refused to connect' errors" -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "🔧 If issues persist, check:" -ForegroundColor Cyan
Write-Host "   - Browser developer console for errors" -ForegroundColor White
Write-Host "   - Network tab for failed requests" -ForegroundColor White
Write-Host "   - Netlify function logs for backend issues" -ForegroundColor White
