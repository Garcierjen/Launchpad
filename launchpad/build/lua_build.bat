@echo off

rmdir /S /Q lua-build 2>nul
mkdir lua-build

copy ..\*.lua .\lua-build\ /y 2>nul
copy ..\*.dll .\lua-build\ /y 2>nul
if exist ..\dep mkdir .\lua-build\dep && xcopy ..\dep .\lua-build\dep\ /s /e /y /i
if exist ..\requires mkdir .\lua-build\requires && xcopy ..\requires .\lua-build\requires\ /s /e /y /i

glue.exe .\srlua.exe ..\cli.lua .\lua-build\cli.exe
del .\lua-build\cli.lua