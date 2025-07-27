#!/usr/bin/env pwsh

# Minimal deployment script for maximum compatibility
# Use this if the main deployment script fails

Write-Host "🚀 Starting MINIMAL Goat Goat Admin Panel Deployment..." -ForegroundColor Green

# Clean build
Write-Host "🧹 Cleaning..." -ForegroundColor Yellow
if (Test-Path "build") { Remove-Item -Recurse -Force "build" }

# Minimal build with maximum compatibility
Write-Host "🔨 Building with minimal settings..." -ForegroundColor Yellow
flutter clean
flutter pub get
flutter build web --release --no-tree-shake-icons

# Copy config files
Write-Host "📋 Copying configuration..." -ForegroundColor Yellow
Copy-Item "_headers" "build/web/_headers" -Force
Copy-Item "_redirects" "build/web/_redirects" -Force

# Deploy
Write-Host "🌐 Deploying..." -ForegroundColor Yellow
netlify deploy --prod --dir=build/web --message="Minimal admin panel deployment"

Write-Host "✅ Minimal deployment complete!" -ForegroundColor Green
Write-Host "🔗 Check: https://goatgoat.info" -ForegroundColor Cyan
