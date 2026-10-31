#include <QDir>
#include <QFile>
#include <QFontMetricsF>
#include <QTemporaryDir>
#include <QTextBlock>
#include <QTextDocument>
#include <QtTest>

#include "backend.h"
#include "filepicker.h"
#include "globalshortcut.h"
#include "linenumbergutter.h"
#include "paragraphdirection.h"
#include "textcodec.h"
#include "theme.h"
#include "translator.h"

class FakePicker : public FilePicker {
public:
    QString lastSave;
    int lastTag = 0;
    void openFiles(const QString &) override { emit openSelected({QUrl::fromLocalFile("/tmp/a.txt")}); }
    void saveFile(const QString &suggested, int tag) override {
        lastSave = suggested;
        lastTag = tag;
        emit saveSelected(QUrl::fromLocalFile(suggested), tag);
    }
};

class NotepadsTests : public QObject {
    Q_OBJECT

private slots:
    void decodesUtf8AndKeepsLineEnding()
    {
        const auto decoded = TextCodec::decode("one\r\ntwo\r\nthree");
        QCOMPARE(decoded.encoding, QString("utf-8"));
        QCOMPARE(decoded.lineEnding, QString("crlf"));
        QCOMPARE(decoded.text, QString("one\ntwo\nthree"));
    }

    void detectsByteOrderMarks()
    {
        QCOMPARE(TextCodec::decode("\xEF\xBB\xBFhi").encoding, QString("utf-8-bom"));
        QCOMPARE(TextCodec::decode("\xEF\xBB\xBFhi").text, QString("hi"));
        const QByteArray utf16le("\xFF\xFEh\0i\0", 6);
        QCOMPARE(TextCodec::decode(utf16le).encoding, QString("utf-16le"));
        QCOMPARE(TextCodec::decode(utf16le).text, QString("hi"));
    }

    void fallsBackToLatin1()
    {
        const auto decoded = TextCodec::decode("caf\xE9");
        QCOMPARE(decoded.encoding, QString("latin1"));
        QCOMPARE(decoded.text, QString::fromUtf8("café"));
    }

    void refusesBinary()
    {
        QVERIFY(!TextCodec::decode(QByteArray("ab\0cd", 5)).error.isEmpty());
    }

    void lineEndingIsEmptyWithoutBreaks()
    {
        QVERIFY(TextCodec::decode("single line").lineEnding.isEmpty());
        QCOMPARE(TextCodec::detectLineEnding("a\rb\rc\nd"), QString("cr"));
    }

    void roundTripsEveryEncoding()
    {
        const QString text = QString::fromUtf8("héllo\nwörld\n");
        for (const QString encoding : {"utf-8", "utf-8-bom", "utf-16le", "utf-16be", "latin1"}) {
            for (const QString ending : {"lf", "crlf", "cr"}) {
                const QByteArray bytes = TextCodec::encode(text, encoding, ending);
                const auto decoded = TextCodec::decode(bytes, encoding);
                QCOMPARE(decoded.text, text);
                QCOMPARE(decoded.lineEnding, ending);
            }
        }
        QCOMPARE(TextCodec::encode("a\nb", "utf-8", "crlf"), QByteArray("a\r\nb"));
        QVERIFY(TextCodec::encode("x", "utf-8-bom", "lf").startsWith("\xEF\xBB\xBF"));
    }

    void latin1RefusesWhatItCannotStore()
    {
        QVERIFY(TextCodec::canEncode(QString::fromUtf8("café"), "latin1"));
        QVERIFY(!TextCodec::canEncode(QString::fromUtf8("🙂"), "latin1"));
        QVERIFY(TextCodec::canEncode(QString::fromUtf8("🙂"), "utf-8"));
    }

    void readsAndWritesFiles()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath("note.txt");
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write("a\r\nb");
        file.close();
        QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner);

        Backend backend(nullptr, dir.filePath("state"));
        const QVariantMap read = backend.readFile(path);
        QVERIFY(read.value("ok").toBool());
        QCOMPARE(read.value("text").toString(), QString("a\nb"));
        QCOMPARE(read.value("lineEnding").toString(), QString("crlf"));

        QVERIFY(Backend::writeAtomically(path, "new").isEmpty());
        QVERIFY(file.open(QIODevice::ReadOnly));
        QCOMPARE(file.readAll(), QByteArray("new"));
        QCOMPARE(QFile::permissions(path) & 0x0777, QFileDevice::ReadUser | QFileDevice::WriteUser);

        const QVariantMap missing = backend.readFile(dir.filePath("nope.txt"));
        QVERIFY(!missing.value("ok").toBool());
        QVERIFY(missing.value("missing").toBool());
        QVERIFY(!backend.readFile(dir.path()).value("ok").toBool());
    }

    void plainTextKeepsNonBreakingSpaces()
    {
        QTextDocument document;
        document.setPlainText(QString::fromUtf8("a b\nc"));
        QCOMPARE(Backend::plainText(&document), QString::fromUtf8("a b\nc"));
    }

    void findsWithOptions()
    {
        QTextDocument document;
        document.setPlainText("Cat cat concat\ncat");
        QVariantMap options;
        QCOMPARE(Backend::findIn(&document, "cat", 0, false, options, false).selectionStart(), 0);

        options["matchCase"] = true;
        QCOMPARE(Backend::findIn(&document, "cat", 0, false, options, false).selectionStart(), 4);

        options["wholeWord"] = true;
        QTextCursor next = Backend::findIn(&document, "cat", 5, false, options, false);
        QCOMPARE(next.selectionStart(), 15);

        bool wrapped = false;
        next = Backend::findIn(&document, "cat", 16, false, options, true, &wrapped);
        QVERIFY(wrapped);
        QCOMPARE(next.selectionStart(), 4);

        QVariantMap regex{{"regex", true}};
        QCOMPARE(Backend::findIn(&document, "c.n", 0, false, regex, false).selectionStart(), 8);
        QString error;
        QVERIFY(Backend::findIn(&document, "(", 0, false, regex, false, nullptr, &error).isNull());
        QVERIFY(!error.isEmpty());
        QVERIFY(Backend::findIn(&document, "^", 0, false, regex, false).isNull());
    }

    void findsBackward()
    {
        QTextDocument document;
        document.setPlainText("one two one two");
        const QTextCursor cursor = Backend::findIn(&document, "one", 8, true, {}, false);
        QCOMPARE(cursor.selectionStart(), 0);
    }

    void replacesAllAsOneUndoStep()
    {
        QTextDocument document;
        document.setPlainText("a-1 b-2 c-3");
        const int count = Backend::replaceAllIn(&document, "(\\w)-(\\d)", "$2:\\1", {{"regex", true}});
        QCOMPARE(count, 3);
        QCOMPARE(document.toPlainText(), QString("1:a 2:b 3:c"));
        document.undo();
        QCOMPARE(document.toPlainText(), QString("a-1 b-2 c-3"));
    }

    void replaceAllHandlesGrowingReplacement()
    {
        QTextDocument document;
        document.setPlainText("aaa");
        QCOMPARE(Backend::replaceAllIn(&document, "a", "aa", {}), 3);
        QCOMPARE(document.toPlainText(), QString("aaaaaa"));
    }

    void sessionBelongsToOneWindow()
    {
        QTemporaryDir dir;
        Backend first(nullptr, dir.path());
        Backend second(nullptr, dir.path());
        QVERIFY(first.claimSession());
        QVERIFY(!second.claimSession());
        QVERIFY(!second.saveSession({{"current", 0}}).isEmpty());

        QVariantMap tab{{"path", ""}, {"modified", true}, {"text", "unsaved"}};
        QVERIFY(first.saveSession({{"current", 0}, {"tabs", QVariantList{tab}}}).isEmpty());
        QCOMPARE(first.loadSession().value("tabs").toList().value(0).toMap().value("text").toString(), QString("unsaved"));
        QCOMPARE(QFile::permissions(dir.filePath("session.json")) & 0x0777,
                 QFileDevice::ReadUser | QFileDevice::WriteUser);
    }

    void dialogsGoThroughThePicker()
    {
        FakePicker picker;
        QTemporaryDir dir;
        Backend backend(&picker, dir.path());
        QSignalSpy saved(&backend, &Backend::saveChosen);
        QSignalSpy opened(&backend, &Backend::filesChosen);
        backend.saveDialog("/tmp/x.txt", 7);
        backend.openDialog();
        QCOMPARE(saved.count(), 1);
        QCOMPARE(saved.at(0).at(0).toString(), QString("/tmp/x.txt"));
        QCOMPARE(saved.at(0).at(1).toInt(), 7);
        QCOMPARE(opened.count(), 1);
    }

    void eachParagraphGetsItsOwnDirection()
    {
        QTextDocument document;
        document.setPlainText(QString::fromUtf8("שלום עולם\nHello world\n\n123\nמשפט with English"));
        document.setModified(false);
        ParagraphDirection::updateAll(&document);
        auto direction = [&](int block) { return document.findBlockByNumber(block).blockFormat().layoutDirection(); };
        QCOMPARE(direction(0), Qt::RightToLeft);
        QCOMPARE(direction(1), Qt::LeftToRight);
        // Lines with no letters follow the paragraph before them.
        QCOMPARE(direction(2), Qt::LeftToRight);
        QCOMPARE(direction(3), Qt::LeftToRight);
        QCOMPARE(direction(4), Qt::RightToLeft);
        QVERIFY(!document.isModified());
        QVERIFY(!document.isUndoAvailable());
    }

    void directionFollowsEditsAndUndoesWithThem()
    {
        QTextDocument document;
        document.setPlainText("hello");
        ParagraphDirection::updateAll(&document);
        QTextCursor cursor(&document);
        cursor.setPosition(0);
        cursor.select(QTextCursor::BlockUnderCursor);
        cursor.insertText(QString::fromUtf8("שלום"));
        QCOMPARE(ParagraphDirection::update(&document, 0, 4), 1);
        QCOMPARE(document.firstBlock().blockFormat().layoutDirection(), Qt::RightToLeft);
        document.undo();
        QCOMPARE(document.toPlainText(), QString("hello"));
        QCOMPARE(document.firstBlock().blockFormat().layoutDirection(), Qt::LeftToRight);
        QCOMPARE(ParagraphDirection::update(&document, 0, 5), 0);
    }

    void directionDoesNotChangeTheSavedText()
    {
        QTextDocument document;
        document.setPlainText(QString::fromUtf8("שלום\nhi"));
        ParagraphDirection::updateAll(&document);
        QCOMPARE(Backend::plainText(&document), QString::fromUtf8("שלום\nhi"));
    }

    void shortcutsAreNormalized()
    {
        QCOMPARE(GlobalShortcut::normalize("alt+super+n"), QString("SUPER + ALT + N"));
        QCOMPARE(GlobalShortcut::normalize("Meta + Shift + F5"), QString("SUPER + SHIFT + F5"));
        QVERIFY(GlobalShortcut::normalize("N").isEmpty());
        QVERIFY(GlobalShortcut::normalize("SUPER + ALT").isEmpty());
        QCOMPARE(GlobalShortcut::modmask("SUPER + ALT + N"), 72);
        QCOMPARE(GlobalShortcut::displayName("SUPER + ALT + N"), QString("Super+Alt+N"));
    }

    void shortcutGoesInItsOwnFile()
    {
        QTemporaryDir dir;
        write(dir.filePath("hyprland.lua"), "require(\"hypr.bindings\")");
        GlobalShortcut shortcut(dir.path(), "/usr/bin/true");
        QVERIFY(shortcut.apply("SUPER + ALT + N").isEmpty());

        QFile own(dir.filePath("notepads.lua"));
        QVERIFY(own.open(QIODevice::ReadOnly));
        // A new window each time, like the terminal, not a jump to an open one.
        QVERIFY(own.readAll().contains("o.bind(\"SUPER + ALT + N\", \"Notepads\", { launch = \"notepads\" })"));
        own.close();

        // The require is added once, after a backup, and the rest is kept.
        QVERIFY(shortcut.apply("SUPER + ALT + K").isEmpty());
        QFile main(dir.filePath("hyprland.lua"));
        QVERIFY(main.open(QIODevice::ReadOnly));
        const QByteArray text = main.readAll();
        QVERIFY(text.startsWith("require(\"hypr.bindings\")"));
        QCOMPARE(text.count("pcall(require, \"hypr.notepads\")"), 1);
        QCOMPARE(QDir(dir.path()).entryList({"hyprland.lua.bak.*"}).size(), 1);

        // Removing the shortcut leaves the file with no binding.
        QVERIFY(shortcut.apply("").isEmpty());
        QVERIFY(own.open(QIODevice::ReadOnly));
        QVERIFY(!own.readAll().contains("o.bind"));
    }

    void refreshUpdatesAnOlderBinding()
    {
        QTemporaryDir dir;
        write(dir.filePath("hyprland.lua"), "pcall(require, \"hypr.notepads\")\n");
        write(dir.filePath("notepads.lua"), "o.bind(\"SUPER + ALT + N\", \"Notepads\", { launch = \"notepads\", focus = \"^notepads$\" })\n");
        GlobalShortcut shortcut(dir.path(), "/usr/bin/true");
        QVERIFY(shortcut.refresh("SUPER + ALT + N").isEmpty());
        QFile own(dir.filePath("notepads.lua"));
        QVERIFY(own.open(QIODevice::ReadOnly));
        QVERIFY(!own.readAll().contains("focus"));
        // Nothing to do when Notepads never wrote a binding.
        QTemporaryDir empty;
        GlobalShortcut none(empty.path(), "/usr/bin/true");
        QVERIFY(none.refresh("SUPER + ALT + N").isEmpty());
        QVERIFY(!QFile::exists(empty.filePath("notepads.lua")));
    }

    void gutterNumbersEachSide()
    {
        QTextDocument document;
        document.setPlainText(QString::fromUtf8("hello\nשלום"));
        ParagraphDirection::updateAll(&document);
        QVERIFY(!LineNumberGutter::isRightToLeft(document.findBlockByNumber(0)));
        QVERIFY(LineNumberGutter::isRightToLeft(document.findBlockByNumber(1)));

        QFont font("monospace");
        // Three digits' room up to line 999, then it grows.
        QCOMPARE(LineNumberGutter::widthFor(5, font), LineNumberGutter::widthFor(999, font));
        QVERIFY(LineNumberGutter::widthFor(1000, font) > LineNumberGutter::widthFor(999, font));
    }

    void wordSpacingIsAShareOfASpace()
    {
        Backend backend(nullptr, QDir::tempPath());
        const QFont normal = backend.editorFont({"monospace"}, 12, 100);
        const QFont narrow = backend.editorFont({"monospace"}, 12, 50);
        const QFont wide = backend.editorFont({"monospace"}, 12, 200);
        const qreal space = QFontMetricsF(normal).horizontalAdvance(QLatin1Char(' '));
        QCOMPARE(normal.wordSpacing(), 0.0);
        QVERIFY(qAbs(narrow.wordSpacing() + space / 2) < 0.6);
        QVERIFY(qAbs(wide.wordSpacing() - space) < 0.6);
    }

    void shortcutNeedsHyprlandConfigAndAModifier()
    {
        QTemporaryDir dir;
        GlobalShortcut shortcut(dir.path(), "/usr/bin/true");
        QVERIFY(!shortcut.apply("SUPER + N").isEmpty());
        write(dir.filePath("hyprland.lua"), "");
        QVERIFY(!shortcut.apply("N").isEmpty());
    }

    void themeFallsBack()
    {
        QTemporaryDir dir;
        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QString("#FFD60A"));
        QCOMPARE(theme.mode(), QString("dark"));
    }

    void themeReadsPalette()
    {
        QTemporaryDir dir;
        QDir(dir.path()).mkpath("theme");
        write(dir.path() + "/theme/colors.toml",
              "accent = \"#112233\"\nbackground = \"#fafafa\"\nforeground = \"#101010\"\n");
        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QString("#112233"));
        QCOMPARE(theme.accentForeground(), QString("white"));
        QCOMPARE(theme.background(), QString("#fafafa"));
        QCOMPARE(theme.mode(), QString("light"));

        write(dir.path() + "/theme/colors.toml", "background = \"#fafafa\"\nmode = \"dark\"\n");
        QTRY_COMPARE(theme.mode(), QString("dark"));
    }

    void themeFollowsHyprlandRounding()
    {
        QTemporaryDir dir;
        const QString response = dir.filePath("response.json"), command = dir.filePath("hyprctl");
        write(command, "#!/bin/sh\ncat '" + response.toUtf8() + "'\n");
        QVERIFY(QFile::setPermissions(command, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner));
        write(response, "{\"int\":0}");

        Theme theme(dir.path(), nullptr, command);
        QCOMPARE(theme.radius(), 0);
        write(response, "{\"int\":6}");
        QTRY_COMPARE(theme.radius(), 6);
    }

    void translatorFallsBackToEnglish()
    {
        QTemporaryDir dir;
        Translator translator(dir.path() + "/language", dir.path());
        QCOMPARE(translator.language(), QString("en"));
        QVERIFY(translator.translate("Main", "Save").isNull());
    }

    void translatorFollowsTheLanguageFile()
    {
        QTemporaryDir dir;
        write(dir.path() + "/language", "pt-BR\n");
        write(dir.path() + "/pt.json", R"({"Save": "Guardar", "Open": "Abrir"})");
        write(dir.path() + "/pt-BR.json", R"({"Save": "Salvar"})");

        Translator translator(dir.path() + "/language", dir.path());
        QCOMPARE(translator.translate("Main", "Save"), QString("Salvar"));
        QCOMPARE(translator.translate("Main", "Open"), QString("Abrir"));
    }

    void englishCatalogHasPlurals()
    {
        Translator translator(QDir::temp().filePath("notepads-no-language"), QFINDTESTDATA("../src/i18n"));
        QCOMPARE(translator.translate("Main", "%n tab(s) have unsaved changes.", nullptr, 1),
                 QString("%n tab has unsaved changes."));
        QCOMPARE(translator.translate("Main", "%n tab(s) have unsaved changes.", nullptr, 3),
                 QString("%n tabs have unsaved changes."));
    }

private:
    static void write(const QString &path, const QByteArray &contents)
    {
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Truncate));
        file.write(contents);
    }
};

QTEST_MAIN(NotepadsTests)
#include "notepads_tests.moc"
