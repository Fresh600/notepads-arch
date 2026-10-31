QT += core gui qml quick quickcontrols2 dbus svg

CONFIG += c++17 release
TARGET = notepads
TEMPLATE = app

HEADERS += \
    src/backend.h \
    src/filepicker.h \
    src/iconprovider.h \
    src/portalfilepicker.h \
    src/textcodec.h \
    src/theme.h \
    src/translator.h

SOURCES += \
    src/main.cpp \
    src/backend.cpp \
    src/iconprovider.cpp \
    src/portalfilepicker.cpp \
    src/textcodec.cpp \
    src/theme.cpp \
    src/translator.cpp

RESOURCES += src/resources.qrc
