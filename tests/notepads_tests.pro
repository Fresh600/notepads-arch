QT += core gui qml quick quickcontrols2 testlib dbus svg
CONFIG += c++17 testcase link_pkgconfig
PKGCONFIG += hunspell
TARGET = notepads_tests
TEMPLATE = app

INCLUDEPATH += ../src

HEADERS += ../src/linenumbergutter.h ../src/globalshortcut.h ../src/paragraphdirection.h ../src/backend.h ../src/filepicker.h ../src/textcodec.h ../src/theme.h ../src/translator.h ../src/wheelzoom.h ../src/spellchecker.h ../src/spellunderline.h
SOURCES += notepads_tests.cpp ../src/linenumbergutter.cpp ../src/globalshortcut.cpp ../src/paragraphdirection.cpp ../src/backend.cpp ../src/textcodec.cpp ../src/theme.cpp ../src/translator.cpp ../src/wheelzoom.cpp ../src/spellchecker.cpp ../src/spellunderline.cpp
