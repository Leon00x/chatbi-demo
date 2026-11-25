@echo off
setlocal
pushd "%~dp0" || exit /b 1
backend\.venv\Scripts\python.exe -I -B packaging\serve.py %*
set "chatbi_exit=%ERRORLEVEL%"
popd
exit /b %chatbi_exit%
