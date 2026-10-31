QT += core gui qml quick quickcontrols2 testlib dbus svg
CONFIG += c++17 testcase
TARGET = notepads_tests
TEMPLATE = app

INCLUDEPATH += ../src

HEADERS += ../src/backend.h ../src/filepicker.h ../src/textcodec.h ../src/theme.h ../src/translator.h
SOURCES += notepads_tests.cpp ../src/backend.cpp ../src/textcodec.cpp ../src/theme.cpp ../src/translator.cpp
