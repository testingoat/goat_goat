# 🚀 GitHub Actions CI/CD Setup for Admin Panel

## 📋 Overview

This document explains how to set up automated deployment for the Goat Goat Admin Panel using GitHub Actions and Netlify.

## 🔧 Required Secrets

To enable automated deployment, you need to add these secrets to your GitHub repository:

### 1. Get Netlify Auth Token
1. Go to [Netlify User Settings](https://app.netlify.com/user/applications)
2. Click "New access token"
3. Give it a name like "GitHub Actions Deploy"
4. Copy the token

### 2. Get Netlify Site ID
1. Go to your [Netlify site dashboard](https://app.netlify.com/sites/goatgoat)
2. Go to "Site settings" → "General"
3. Copy the "Site ID" (should be: `benevolent-toffee-58a972`)

### 3. Add Secrets to GitHub
1. Go to your GitHub repository
2. Click "Settings" → "Secrets and variables" → "Actions"
3. Click "New repository secret"
4. Add these secrets:

```
NETLIFY_AUTH_TOKEN = [Your Netlify auth token]
NETLIFY_SITE_ID = benevolent-toffee-58a972
```

## 🔄 How It Works

### Automatic Deployment Triggers
- **Production Deploy**: Pushes to `main` branch
- **Preview Deploy**: Pull requests to `main` branch

### Build Process
1. **Setup**: Install Flutter 3.16.0
2. **Dependencies**: Run `flutter pub get`
3. **Analysis**: Check code quality with `flutter analyze`
4. **Testing**: Run admin panel tests (if they exist)
5. **Build**: Create optimized web build with `flutter build web --target=lib/main_admin.dart`
6. **Deploy**: Upload to Netlify using official CLI

### File Monitoring
The workflow only triggers when these files change:
- `lib/admin/**` (any admin panel code)
- `lib/main_admin.dart` (main admin entry point)
- `pubspec.yaml` (dependencies)
- `netlify.toml` (deployment config)
- The workflow file itself

## 🎯 Benefits

### ✅ Automated Quality Checks
- Code analysis before deployment
- Build verification
- Automatic rollback on failure

### ✅ Preview Deployments
- Every PR gets a preview URL
- Test changes before merging
- Automatic cleanup after merge

### ✅ Production Safety
- Only deploys from `main` branch
- Requires successful build
- Maintains deployment history

## 🔧 Manual Override

If you need to deploy manually:

```bash
# Build locally
flutter build web --target=lib/main_admin.dart --release

# Deploy with Netlify CLI
netlify deploy --prod --dir=build/web
```

## 🚨 Troubleshooting

### Common Issues

1. **Missing Secrets**: Ensure `NETLIFY_AUTH_TOKEN` and `NETLIFY_SITE_ID` are set
2. **Build Failures**: Check Flutter version compatibility
3. **Deploy Failures**: Verify Netlify site permissions

### Debug Steps

1. Check GitHub Actions logs
2. Verify secrets are correctly set
3. Test build locally first
4. Check Netlify deployment logs

## 📊 Monitoring

- **GitHub Actions**: Monitor builds at `https://github.com/[username]/goat_goat/actions`
- **Netlify**: Monitor deployments at `https://app.netlify.com/sites/goatgoat/deploys`
- **Live Site**: Check admin panel at `https://goatgoat.info`

## 🔄 Migration from Manual Process

Once GitHub Actions is working:

1. **Restore .gitignore**: Remove build/ directory from tracking
2. **Clean Repository**: Remove committed build files
3. **Update Documentation**: Point to automated process
4. **Test Workflow**: Make a small change to verify automation

This ensures a clean, maintainable deployment process going forward.
