@echo off

@REM Set default configuration as release
set PACKAGE_CONFIG=release

:arg-parse
if not "%1"=="" (
    if "%1"=="--config" (
        set PACKAGE_CONFIG=%2
        shift
    )
    shift
    goto :arg-parse
)

set PACKAGE_NAME=aerosim-isaac-sim-%PACKAGE_CONFIG%.zip
set BUILD_FOLDER=%AEROSIM_ISAAC_SIM_ROOT%\package-%PACKAGE_CONFIG%

pushd %AEROSIM_ISAAC_SIM_ROOT%

@REM Build the kit app
call build.bat --config %PACKAGE_CONFIG% || exit /b %ERRORLEVEL%

@REM Package the kit app
call repo.bat package -c %PACKAGE_CONFIG% -n %PACKAGE_NAME% || exit /b %ERRORLEVEL%

@REM Remove auto-generated part of package name
move /Y _build\packages\%PACKAGE_NAME%*.zip _build\packages\%PACKAGE_NAME%

@REM Extract the package to the target output folder
if not exist %BUILD_FOLDER% mkdir %BUILD_FOLDER%
powershell -Command "Expand-Archive -Path '%AEROSIM_ISAAC_SIM_ROOT%\_build\packages\%PACKAGE_NAME%' -DestinationPath '%BUILD_FOLDER%' -Force"
del "%AEROSIM_ISAAC_SIM_ROOT%\_build\packages\%PACKAGE_NAME%"

echo Package created and output to: %BUILD_FOLDER%

popd
