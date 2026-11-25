@echo off
setlocal
pushd "%~dp0" || exit /b 1
runtime\python.exe -I -B packaging\serve.py %*
set "chatbi_exit=%ERRORLEVEL%"
if not "%chatbi_exit%"=="0" pause
popd
exit /b %chatbi_exit%
