QT += core gui qml quick quickcontrols2 dbus svg

CONFIG += c++17 release link_pkgconfig
PKGCONFIG += hunspell
TARGET = notepads
TEMPLATE = app

HEADERS += \
    src/backend.h \
    src/filepicker.h \
    src/globalshortcut.h src/wheelzoom.h src/spellchecker.h src/spellunderline.h \
    src/paragraphdirection.h \
    src/iconprovider.h \
    src/linenumbergutter.h \
    src/portalfilepicker.h \
    src/textcodec.h \
    src/theme.h \
    src/translator.h

SOURCES += \
    src/main.cpp \
    src/backend.cpp \
    src/globalshortcut.cpp src/wheelzoom.cpp src/spellchecker.cpp src/spellunderline.cpp \
    src/paragraphdirection.cpp \
    src/iconprovider.cpp \
    src/linenumbergutter.cpp \
    src/portalfilepicker.cpp \
    src/textcodec.cpp \
    src/theme.cpp \
    src/translator.cpp

RESOURCES += src/resources.qrc
