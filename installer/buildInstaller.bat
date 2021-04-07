@echo off
setlocal
set /a ERROR_FILE_NOT_FOUND = 2
set /a ERROR_DIR_NOT_EMPTY = 145

rem  #### Parse command line parameters ####
if "x%~1" == "x" (
    goto Usage
)
if "%~1" == "/?" (
    goto Usage
)
set "exePath=%~1"
set "exePath=%exePath:/=\%"
if not exist "%exePath%" (
    echo Birdtray executable not found at "%exePath%" 1>&2
    exit /b %ERROR_FILE_NOT_FOUND%
)
for /F "tokens=* USEBACKQ" %%f in (`dir /b "%~2" 2^>nul ^| findstr libcrypto ^| findstr .dll` ) do (
    set "openSSLCryptoPath=%~2\%%f"
)
for /F "tokens=* USEBACKQ" %%f in (`dir /b "%~2" 2^>nul ^| findstr libssl ^| findstr .dll`) do (
    set "openSSLPath=%~2\%%f"
)
if not exist "%openSSLCryptoPath%" (
    echo OpenSSL crypto library not found at "%~2\libcrypto*.dll" 1>&2
    exit /b %ERROR_FILE_NOT_FOUND%
)
if not exist "%openSSLPath%" (
    echo OpenSSL library not found at "%~2\libssl*.dll" 1>&2
    exit /b %ERROR_FILE_NOT_FOUND%
)

if "%~3" == "--install" (
    set "installAfterBuild=1"
)

rem  #### Check if required programs are available ####
for %%x in (windeployqt.exe) do (set winDeployQtExe=%%~$PATH:x)
if not defined winDeployQtExe (
    echo windeployqt.exe is not on the PATH 1>&2
    exit /b %ERROR_FILE_NOT_FOUND%
)
for %%x in (makensis.exe) do (set makeNsisExe=%%~$PATH:x)
if not defined makeNsisExe (
    echo makensis.exe is not on the PATH 1>&2
    exit /b %ERROR_FILE_NOT_FOUND%
)
for %%x in (g++.exe) do (set g++Exe=%%~$PATH:x)
if not defined g++Exe (
    echo g++.exe is not on the PATH 1>&2
    exit /b %ERROR_FILE_NOT_FOUND%
)
for %%x in (git.exe) do (set gitExe=%%~$PATH:x)
if not defined gitExe (
    echo git.exe is not on the PATH 1>&2
    exit /b %ERROR_FILE_NOT_FOUND%
)
for %%x in (curl.exe) do (set curlExe=%%~$PATH:x)
if not defined curlExe (
    echo curl.exe is not on the PATH 1>&2
    exit /b %ERROR_FILE_NOT_FOUND%
)
for %%x in (7z.exe) do (set sevenZExe=%%~$PATH:x)
if not defined sevenZExe (
    echo 7z.exe is not on the PATH 1>&2
    exit /b %ERROR_FILE_NOT_FOUND%
)

rem  #### Create the deployment folder ####
set "deploymentFolder=%~dp0winDeploy"
echo Creating deployment folder at "%deploymentFolder%"...
rem  Clear the old deployment folder.
if exist "%deploymentFolder%" (
    rmdir /s /q "%deploymentFolder%" 1>nul
    if exist "%deploymentFolder%" (
        rmdir /s /q "%deploymentFolder%" 1>nul
        if exist "%deploymentFolder%" (
            echo Failed to delete the old deployment folder at "%deploymentFolder%" 1>&2
            exit /b %ERROR_DIR_NOT_EMPTY%
        )
    )
)
mkdir "%deploymentFolder%"
if errorLevel 1 (
    echo Failed to create deployment folder at "%deploymentFolder%" 1>&2
    exit /b %errorLevel%
)
for /f "delims=" %%i in ("%exePath%") do (
    set "exeFileName=%%~nxi"
    set "translationDir=%%~di%%~pitranslations"
)
xcopy "%exePath%" "%deploymentFolder%" /q /y 1>nul
if errorLevel 1 (
    echo Failed to copy the Birdtray executable from "%exePath%" 1>&2
    echo to the deployment folder at "%deploymentFolder%" 1>&2
    exit /b %errorLevel%
)
if not exist "%deploymentFolder%/%exeFileName%" (
    echo Birdtray executable not found at "%exePath%" 1>&2
    exit /b %ERROR_FILE_NOT_FOUND%
)
xcopy "%openSSLCryptoPath%" "%deploymentFolder%" /q /y 1>nul
if errorLevel 1 (
    echo Failed to copy the OpenSSL crypto library from "%openSSLCryptoPath%" 1>&2
    echo to the deployment folder at "%deploymentFolder%" 1>&2
    exit /b %errorLevel%
)
xcopy "%openSSLPath%" "%deploymentFolder%" /q /y 1>nul
if errorLevel 1 (
    echo Failed to copy the OpenSSL library from "%openSSLPath%" 1>&2
    echo to the deployment folder at "%deploymentFolder%" 1>&2
    exit /b %errorLevel%
)
"%winDeployQtExe%" --release --no-system-d3d-compiler --no-quick-import --no-webkit2 ^
        --no-angle --no-opengl-sw "%deploymentFolder%\%exeFileName%"
if errorLevel 1 (
    echo Failed to create deployment folder: windeployqt.exe failed 1>&2
    exit /b %errorLevel%
)
if exist "%deploymentFolder%\imageformats" (
    for /f %%F in ('dir "%deploymentFolder%\imageformats" /b /a-d ^| findstr /vile "qico.dll"
            ^| findstr /vile "qsvg.dll"') do (
        del "%deploymentFolder%\imageformats\%%F" 1>nul
    )
)
rem  Copy translations
if not exist "%translationDir%" (
    if exist "%translationDir%\..\..\translations" (
        set "translationDir=%translationDir%\..\..\translations"
    )
)
if exist "%translationDir%" (
    xcopy "%translationDir%" "%deploymentFolder%\translations" /q /y 1>nul
    if errorLevel 1 (
        echo Failed to copy the translations from "%translationDir%" 1>&2
        echo to the deployment folder at "%deploymentFolder%\translations" 1>&2
        exit /b %errorLevel%
    )
) else (
    echo Warning: Did not find translations directory at "%translationDir%"
)

rem  #### Download the installer dependencies ####
echo Downloading installer dependencies...
rem  Clear the old dependencies folder.
set "dependencyFolder=%~dp0nsisDependencies"
if exist "%dependencyFolder%" (
    rmdir /s /q "%dependencyFolder%" 1>nul
    if exist "%dependencyFolder%" (
        rmdir /s /q "%dependencyFolder%" 1>nul
        if exist "%dependencyFolder%" (
            echo Failed to delete the old nsis dependency folder at "%dependencyFolder%" 1>&2
            exit /b %ERROR_DIR_NOT_EMPTY%
        )
    )
)

"%gitExe%" clone -q "https://github.com/Drizin/NsisMultiUser.git" "%dependencyFolder%" 1>nul
if errorLevel 1 (
    echo Failed to clone NsisMultiUser 1>&2
    exit /b %errorLevel%
)
rmdir /s /q "%dependencyFolder%\.git" 1>nul
set "nsProcessUrl=https://nsis.sourceforge.io/mediawiki/images/1/18/NsProcess.zip"
"%curlExe%" --silent --output "%TEMP%\NsProcess.zip" "%nsProcessUrl%" 1>nul
if errorLevel 1 (
    echo Failed to download NsProcess 1>&2
    exit /b %errorLevel%
)
"%sevenZExe%" e -y -o"%TEMP%\NsProcess" "%TEMP%\NsProcess.zip" 1>nul
if errorLevel 1 (
    echo Failed to extract NsProcess 1>&2
    exit /b %errorLevel%
)
del "%TEMP%\NsProcess.zip" /F
xcopy "%TEMP%\NsProcess\nsProcess.nsh" "%dependencyFolder%\Include" /q /y 1>nul
if errorLevel 1 (
    echo Failed to copy the NsProcess library from "%TEMP%\NsProcess\nsProcess.nsh" 1>&2
    echo to the deployment folder at "%dependencyFolder%\Include" 1>&2
    exit /b %errorLevel%
)
xcopy "%TEMP%\NsProcess\nsProcessW.dll" "%dependencyFolder%\Plugins\x86-unicode" /q /y 1>nul
if errorLevel 1 (
    echo Failed to copy the NsProcess library from "%TEMP%\NsProcess\nsProcessW.dll" 1>&2
    echo to the deployment folder at "%dependencyFolder%\Plugins\x86-unicode" 1>&2
    exit /b %errorLevel%
)
rmdir /s /q "%TEMP%\NsProcess" 1>nul
rename "%dependencyFolder%\Plugins\x86-unicode\nsProcessW.dll" nsProcess.dll 1>nul
if errorLevel 1 (
    echo Failed to copy the NsProcess library from "%TEMP%\NsProcess\nsProcessW.dll" 1>&2
    echo to the deployment folder at "%dependencyFolder%\Plugins\x86-unicode" 1>&2
    exit /b %errorLevel%
)
set "nsArrayUrl=https://nsis.sourceforge.io/mediawiki/images/9/97/NsArray.zip"
"%curlExe%" --silent --output "%TEMP%\nsArray.zip" "%nsArrayUrl%" 1>nul
if errorLevel 1 (
    echo Failed to download nsArray 1>&2
    exit /b %errorLevel%
)
"%sevenZExe%" x -y -o"%TEMP%\nsArray" "%TEMP%\nsArray.zip" 1>nul
if errorLevel 1 (
    echo Failed to extract nsArray 1>&2
    exit /b %errorLevel%
)
del "%TEMP%\nsArray.zip" /F
xcopy "%TEMP%\nsArray\Include\nsArray.nsh" "%dependencyFolder%\Include" /q /y 1>nul
if errorLevel 1 (
    echo Failed to copy the nsArray library from "%TEMP%\nsArray\Include\nsArray.nsh" 1>&2
    echo to the deployment folder at "%dependencyFolder%\Include" 1>&2
    exit /b %errorLevel%
)
xcopy "%TEMP%\nsArray\Plugins\x86-unicode\nsArray.dll" ^
        "%dependencyFolder%\Plugins\x86-unicode" /q /y 1>nul
if errorLevel 1 (
    echo Failed to copy the nsArray library from 1>&2
    echo "%TEMP%\nsArray\Plugins\x86-unicode\nsArray.dll" 1>&2
    echo to the deployment folder at "%dependencyFolder%\Plugins\x86-unicode" 1>&2
    exit /b %errorLevel%
)
rmdir /s /q "%TEMP%\nsArray" 1>nul
echo xcopy "%~dp0deps\nsisXML.dll" "%dependencyFolder%\Plugins\x86-unicode" /q /y 1>nul
"%sevenZExe%" e "%~dp0deps\nsisXML.zip" -y -o"%dependencyFolder%\Plugins\x86-unicode" ^
        -i!"*.dll" 1>nul
if errorLevel 1 (
    echo Failed to extract the nsisXML library from "%~dp0deps\nsisXML.zip:*.dll" 1>&2
    echo to the deployment folder at "%dependencyFolder%\Plugins\x86-unicode" 1>&2
    exit /b %errorLevel%
)

rem  #### Create the actual installer ####
echo Creating the installer...
"%makeNsisExe%" "%~dp0installer.nsi"
if errorLevel 1 (
    echo Failed to create installer: makensis.exe failed 1>&2
    exit /b %errorLevel%
)
echo Successfully created the installer

rem  #### Run the installer, if called with --install ####
if not defined installAfterBuild (
    goto :eof
)
for /F "tokens=* USEBACKQ" %%f in (`dir /b "%~dp0" 2^>nul ^| findstr Birdtray ^| findstr .exe`) do (
    set "installerExe=%~dp0%%f"
)
if "x%installerExe%" == "x" (
    echo Failed to start the installer: Unable to find the generated installer executable 1>&2
    exit /b %ERROR_FILE_NOT_FOUND%
)
echo Executing installer...
"%installerExe%"
exit /b %errorLevel%

goto :eof

: Usage
echo Creates the Birdtray installer. - Usage:
echo buildInstaller.bat exePath openSSLPath [--install]
echo:
echo exePath:       The path to the birdtray.exe to include in the installer
echo openSSLPath:   The path to the OpenSSL directory containing libcrypto*.dll and libssl*.dll
echo --install:     Optional parameter. If specified, executes the generated installer.
echo:
echo The following programs must be on the PATH: windeployqt, makensis, g++, git, curl and 7z.
echo The script also searches for translations in translations subdirectory
echo of the directory containing the Birdtray executable.
goto :eof
