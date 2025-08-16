@echo off
echo ========================================
echo Goat Goat Application Test Suite
echo ========================================
echo.

echo 🚀 Starting Test Execution...
echo.

cd /d "%~dp0.."

echo 📱 Running FCM Test Script...
flutter pub run test/fcm_test_script.dart
echo.

echo 🔑 Running Custom Test Suite...
flutter pub run testsprite_tests/run_all_tests.dart
echo.

echo 🎉 Test Execution Complete!
echo.
echo Check the console output above for detailed results.
echo.
pause
