#!/bin/bash

function copy-dlls()
{
    rsync windows/binaries/* ./release -v -L
    rsync t1wrench.lua ./release -v

    for x in icudt52.dll icuin52.dll icuuc52.dll QT5CORE.DLL QT5GUI.DLL QT5WIDGETS.DLL; do
        rsync $1/bin/$x ./release -av
        chmod 555 ./release/$x
    done

    for x in libEGL.dll libGLESv2.dll libstdc++-6.dll libwinpthread-1.dll libgcc_s_dw2-1.dll; do
        rsync $1/bin/$x ./release -av || continue
        chmod 555 ./release/$x
    done

    mkdir -p ./release/platforms
    rsync $1/plugins/platforms/qwindows.dll ./release/platforms -av
    chmod 555 ./release/platforms/*
    rsync ~/adb_usb_driver_smartisan ./release -av
}

function make-release-tgz()
{
    rm -rf ./release/*.obj
    rm -rf ./release/*.o
    rm -rf ./release/*.cpp
    rsync readme.* ./release/
    rsync -av *.png ./release/
    command rsync -av -d release/ t1wrench-release
    set -x
    tar czfv ${1:-t1wrench-release.tgz} t1wrench-release
}

if test $# = 0; then
    set -- pub
fi
if test $(uname) = Linux; then
    psync $1 .; ssh $1 "cd $PWD; ./$(basename $0)"
    rsync $1:$(up .)/t1wrench-release ../ -av
    rsync $1:$(up .)/t1wrench-windows.tgz ~/today/
    smb-push ~/today/t1wrench-windows.tgz
else
    set -e
    set -o pipefail
    /cygdrive/c/Python2/python.exe "C:\cygwin64\home\bhj\system-config\bin\windows\terminateModule.py" T1Wrench.exe || true

    if test $(basename $0) = build-win-vc.sh; then
        perl -npe "$(grep 's/.*ord' ~/bin/vc-utf8-escape)" -i t1wrenchmainwindow.cpp
        /c/Qt/5.3/msvc2013_64/bin/qmake.exe

        vc2013env nmake | perl -npe 's/\\/\//g'
        copy-dlls /c/Qt/5.3/msvc2013_64/
        rsync ~/vcredist_x64.exe ./release/vcredist-vs2013-x86_64.exe
        make-release-tgz
    else # mingw
        export PATH=/cygdrive/c/Qt-mingw/Qt5.3.1/5.3/mingw482_32/bin:/c/Qt-mingw/Qt5.3.1/Tools/mingw482_32/bin:$PATH
        if test ! -e Makefile; then
            qmake.exe
        fi
        mingw32-make.exe | perl -npe 's/\\/\//g'
        copy-dlls /c/Qt-mingw/./Qt5.3.1/5.3/mingw482_32
        set -x
        (
            myscr bash -c 'cd t1wrench-release; of ./T1Wrench.exe'
        )&
        make-release-tgz t1wrench-windows.tgz
    fi
fi
