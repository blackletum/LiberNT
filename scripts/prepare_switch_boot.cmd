@echo off
rem SPDX-License-Identifier: GPL-3.0-or-later
rem SPDX-FileCopyrightText: 2026 Ahmed ARIF <arif193@gmail.com>

setlocal EnableExtensions EnableDelayedExpansion

set "HEKATE_VERSION=6.5.4"
set "NYX_VERSION=1.9.4"
set "HEKATE_URL=https://github.com/CTCaer/hekate/releases/download/v%HEKATE_VERSION%/hekate_ctcaer_%HEKATE_VERSION%_Nyx_%NYX_VERSION%.zip"
set "HEKATE_SHA256=a5ee4faa956f1ffe49fdd31d795be3fd556c8dffd9cbed69cec7cff92b8b43f6"

set "WINX_RELEASE=2"
set "WINX_URL=https://github.com/steck0714/winx/releases/download/%WINX_RELEASE%/bl33.bin"
set "WINX_SHA256=b68cbcf121415ce7265038306b6a7840cc3cda7316c08f8042c94b88459f1bb6"

set "LAKKA_NAME=Lakka-Switch.aarch64-5.0-devel-20240122151037-5f29696"
set "LAKKA_URL=https://download.switchroot.org/lakka/%LAKKA_NAME%.tar"
set "LAKKA_BOOT_OFFSET=1269749760"
set "LAKKA_BOOT_SHA256=ca894c3ed19a52176d6a5bc7fb8b0fcb2a8bc7857ff82aef4a158c57fbe94a65"
set "BL31_SHA256=77b7f5c688934a4d077cd5f39ffaa57383de422652797fd2cdfad67acf41cda4"

if not "%~1" == "" goto usage

set "CURL=%SystemRoot%\System32\curl.exe"
set "TAR=%SystemRoot%\System32\tar.exe"
if not exist "%CURL%" (echo error: %CURL% is required>&2& exit /b 1)
if not exist "%TAR%" (echo error: %TAR% is required>&2& exit /b 1)

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "SWITCH_DIR=%ROOT%\media\boot\switch"
set "DOWNLOADS=%SWITCH_DIR%\downloads"
set "OPTIONAL=%SWITCH_DIR%\optional"
set "WORK=%DOWNLOADS%\work"
set "BL31=%WORK%\%LAKKA_NAME%\lakka\boot\bl31.bin"

if not exist "%DOWNLOADS%" mkdir "%DOWNLOADS%" || exit /b 1
call :fetch "%HEKATE_URL%" "%DOWNLOADS%\hekate.zip" %HEKATE_SHA256% || exit /b 1
call :fetch "%WINX_URL%" "%DOWNLOADS%\winx-bl33.bin" %WINX_SHA256% || exit /b 1
call :fetch "%LAKKA_URL%" "%DOWNLOADS%\lakka-boot.tar" %LAKKA_BOOT_SHA256% %LAKKA_BOOT_OFFSET%- || exit /b 1

if exist "%WORK%" rmdir /s /q "%WORK%"
if exist "%OPTIONAL%" rmdir /s /q "%OPTIONAL%"
mkdir "%WORK%\hekate" "%OPTIONAL%\switchroot\winx" || exit /b 1
"%TAR%" -xf "%DOWNLOADS%\hekate.zip" -C "%WORK%\hekate" || exit /b 1
"%TAR%" -xf "%DOWNLOADS%\lakka-boot.tar" -C "%WORK%" "%LAKKA_NAME%/lakka/boot/bl31.bin" || exit /b 1
call :sha256 "%BL31%"
if /i not "!HASH!" == "%BL31_SHA256%" (echo error: bl31.bin does not match the pinned SHA-256>&2& exit /b 1)

xcopy /e /i /q /y "%WORK%\hekate\bootloader" "%OPTIONAL%\bootloader" >nul || exit /b 1
copy /y "%WORK%\hekate\hekate_ctcaer_%HEKATE_VERSION%.bin" "%OPTIONAL%\payload.bin" >nul || exit /b 1
copy /y "%DOWNLOADS%\winx-bl33.bin" "%OPTIONAL%\switchroot\winx\bl33.bin" >nul || exit /b 1
copy /y "%BL31%" "%OPTIONAL%\switchroot\winx\bl31.bin" >nul || exit /b 1
rmdir /s /q "%WORK%"

echo Switch boot files are ready in %OPTIONAL%:
dir /s /b /a-d "%OPTIONAL%"
echo Rebuild the liberntimg target of a profile_switch output tree to include them.
exit /b 0

:usage
echo Usage: %~nx0>&2
echo Downloads Hekate, the WinX UEFI firmware (BL33) and the Switchroot BL31 into>&2
echo media\boot\switch\optional, which profile_switch images copy onto the SD card.>&2
exit /b 2

:fetch
set "HASH="
if exist "%~2" call :sha256 "%~2"
if /i "!HASH!" == "%~3" exit /b 0
echo Downloading %~1
if exist "%~2.part" del /f /q "%~2.part"
if "%~4" == "" (
    "%CURL%" -fL --retry 3 -o "%~2.part" "%~1" || exit /b 1
) else (
    "%CURL%" -fL --retry 3 -r %~4 -o "%~2.part" "%~1" || exit /b 1
)
call :sha256 "%~2.part"
if /i not "!HASH!" == "%~3" (
    del /f /q "%~2.part"
    echo error: %~1: SHA-256 !HASH!, expected %~3>&2
    exit /b 1
)
move /y "%~2.part" "%~2" >nul || exit /b 1
exit /b 0

:sha256
set "HASH="
for /f "skip=1 delims=" %%H in ('certutil -hashfile "%~1" SHA256') do if not defined HASH set "HASH=%%H"
if defined HASH set "HASH=!HASH: =!"
exit /b 0
