@echo off
echo ====================================================
echo MOZECHAT GOD MODE: SECURE OBFUSCATED BUILD PROCESS
echo ====================================================

echo Temizleniyor...
call flutter clean
call flutter pub get

echo.
echo ====================================================
echo Siber Kalkan Aktif Ediliyor (Obfuscation & R8)
echo ====================================================
echo Dart Kodlari Karistiriliyor...
echo Split Debug Info ile Semboller Gizleniyor...

call flutter build apk --split-per-abi --obfuscate --split-debug-info=build\app\outputs\symbols

echo.
echo ====================================================
echo INSA TAMAMLANDI!
echo ====================================================
echo Uretilen Guvenli APK'lar:
echo - build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk
echo - build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
echo - build\app\outputs\flutter-apk\app-x86_64-release.apk
echo.
echo UYARI: Uygulamaniz su an OS seviyesinde ekran goruntusunu 
echo fiziksel olarak (siyah ekran ile) engellemektedir.
echo Tersine muhendislik yontemlerine karsi Dart kodlari sifrelenmistir.
pause
