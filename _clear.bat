@echo off

chcp 65001 > nul

setlocal enabledelayedexpansion

call del /F /S /q *.local
call del /F /S /q *.identcache 
call del /F /S /q *.stat
call del /F /S /q *.skincfg
call del /F /S /q *.tvsconfig

rem call rmdir /s /q .\bin

set "target_directory=%cd%"
set "directory_list=__history __recovery"

for /f "delims=" %%d in ('dir /b /s /ad "%target_directory%" ^| sort /r') do (
    for %%i in (%directory_list%) do (
        if /i "%%~nxd"=="%%i" (
            rd "%%d" /s /q && echo Удаление каталога: "%%d"
        )
    )
)

echo.
echo Очистка репозитория завершена.
timeout 2