@echo off
echo Building Inmobarco App for Android...
echo.

echo 1. Cleaning previous builds...
flutter clean

echo.
echo 2. Getting dependencies...
flutter pub get

echo.
echo 3. Analyzing code...
flutter analyze

echo.
echo 4. Building APK...
flutter build apk --release

echo.
echo 5. Building App Bundle...
flutter build appbundle --release

echo.
echo Build completed!
echo APK location: build\app\outputs\flutter-apk\app-release.apk
echo App Bundle location: build\app\outputs\bundle\release\app-release.aab
echo.
pause
