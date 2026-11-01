// Notepads — a clean, translucent, tabbed text editor for Omarchy, after the
// Windows app of the same name.

#include <QCommandLineParser>
#include <QDir>
#include <QFileInfo>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QUrl>

#include "backend.h"
#include "globalshortcut.h"
#include "iconprovider.h"
#include "linenumbergutter.h"
#include "portalfilepicker.h"
#include "theme.h"
#include "translator.h"
#include "spellchecker.h"
#include "spellunderline.h"
#include "wheelzoom.h"

int main(int argc, char *argv[]) {
    // The window paints its own translucent background so Hyprland's blur
    // shows through, which needs an alpha channel on the surface.
    QQuickWindow::setDefaultAlphaBuffer(true);

    QGuiApplication app(argc, argv);
    app.setApplicationName("notepads");
    app.setOrganizationName("notepads");
    app.setApplicationVersion("0.5.0");

    // Matches the window to notepads.desktop, so the compositor (Wayland
    // app_id) and the launcher pick up the installed icon.
    app.setDesktopFileName("notepads");
    app.setWindowIcon(QIcon::fromTheme("notepads"));

    QCommandLineParser parser;
    parser.setApplicationDescription("A clean, lightweight text editor.");
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addPositionalArgument("files", "Files to open.", "[files...]");
    parser.process(app);

    QStringList files;
    for (const QString &argument : parser.positionalArguments()) {
        const QUrl url(argument);
        files.append(QFileInfo(url.isLocalFile() ? url.toLocalFile() : argument).absoluteFilePath());
    }

    QQuickStyle::setStyle("Material");

    // Hebrew letters only (a subset of Noto Sans Hebrew), so Hebrew can use a
    // proportional face while spaces, digits, and Latin keep the editor font.
    QFontDatabase::addApplicationFont(":/fonts/NotepadsHebrew-Regular.ttf");

    // Installed before anything is translated, and every qsTr() binding is
    // re-evaluated when the Omarchy language changes.
    Translator translator;
    app.installTranslator(&translator);

    Theme theme;
    PortalFilePicker picker;
    Backend backend(&picker);
    backend.setStartupFiles(files);
    GlobalShortcut shortcut;
    // Before the engine, so they outlive the QML that uses them.
    SpellChecker spellChecker;
    WheelZoom wheelZoom;
    app.installEventFilter(&wheelZoom);

    qmlRegisterType<LineNumberGutter>("Notepads", 1, 0, "LineNumberGutter");
    qmlRegisterType<SpellUnderline>("Notepads", 1, 0, "SpellUnderline");

    QQmlApplicationEngine engine;
    engine.addImageProvider("icon", new IconProvider);
    QObject::connect(&translator, &Translator::changed, &engine, &QQmlEngine::retranslate);
    engine.rootContext()->setContextProperty("translator", &translator);
    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("backend", &backend);
    engine.rootContext()->setContextProperty("spellChecker", &spellChecker);
    engine.rootContext()->setContextProperty("wheelZoom", &wheelZoom);
    engine.rootContext()->setContextProperty("globalShortcut", &shortcut);
    engine.rootContext()->setContextProperty("appVersion", app.applicationVersion());
    engine.load(QUrl("qrc:/Main.qml"));
    if (engine.rootObjects().isEmpty())
        return 1;

    return app.exec();
}
