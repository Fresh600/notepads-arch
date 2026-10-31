#include "backend.h"

#include "filepicker.h"
#include "textcodec.h"

#include <QClipboard>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQuickTextDocument>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTextBlock>
#include <QTextDocument>
#include <QUrl>

namespace {

bool option(const QVariantMap &options, const char *name) {
    return options.value(QString::fromLatin1(name)).toBool();
}

QRegularExpression patternFor(const QString &query, const QVariantMap &options, bool anchored = false) {
    QString pattern = option(options, "regex") ? query : QRegularExpression::escape(query);
    if (option(options, "wholeWord"))
        pattern = QStringLiteral("\\b(?:%1)\\b").arg(pattern);
    if (anchored)
        pattern = QRegularExpression::anchoredPattern(pattern);
    QRegularExpression::PatternOptions flags = QRegularExpression::UseUnicodePropertiesOption;
    if (!option(options, "matchCase"))
        flags |= QRegularExpression::CaseInsensitiveOption;
    return QRegularExpression(pattern, flags);
}

QTextDocument *textDocumentOf(QQuickTextDocument *document) {
    return document ? document->textDocument() : nullptr;
}

}

Backend::Backend(FilePicker *picker, const QString &stateDirectory, QObject *parent)
    : QObject(parent),
      m_picker(picker),
      m_stateDirectory(stateDirectory.isEmpty()
                           ? QStandardPaths::writableLocation(QStandardPaths::GenericStateLocation) + "/notepads"
                           : stateDirectory) {
    if (m_picker) {
        connect(m_picker, &FilePicker::openSelected, this, [this](const QList<QUrl> &urls) {
            QStringList paths;
            for (const QUrl &url : urls)
                if (url.isLocalFile())
                    paths.append(url.toLocalFile());
            if (!paths.isEmpty())
                emit filesChosen(paths);
        });
        connect(m_picker, &FilePicker::saveSelected, this, [this](const QUrl &url, int tag) {
            if (url.isLocalFile())
                emit saveChosen(url.toLocalFile(), tag);
        });
        connect(m_picker, &FilePicker::failed, this, &Backend::failed);
    }
}

Backend::~Backend() = default;

QVariantMap Backend::readFile(const QString &path, const QString &encoding) const {
    QVariantMap result{{"ok", false}, {"missing", false}};
    const QFileInfo info(path);
    if (!info.exists()) {
        result["missing"] = true;
        result["error"] = tr("%1 does not exist.").arg(path);
        return result;
    }
    if (info.isDir()) {
        result["error"] = tr("%1 is a folder, not a file.").arg(path);
        return result;
    }
    if (info.size() > MaxFileSize) {
        result["error"] = tr("%1 is too large to open (more than %2 MB).").arg(info.fileName()).arg(MaxFileSize / 1024 / 1024);
        return result;
    }

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        result["error"] = tr("Could not open %1: %2").arg(info.fileName(), file.errorString());
        return result;
    }

    const auto decoded = TextCodec::decode(file.readAll(),
                                           TextCodec::isKnownEncoding(encoding) ? encoding : QString());
    if (!decoded.error.isEmpty()) {
        result["error"] = decoded.error;
        return result;
    }
    result["ok"] = true;
    result["text"] = decoded.text;
    result["encoding"] = decoded.encoding;
    result["lineEnding"] = decoded.lineEnding;
    return result;
}

QString Backend::writeFile(QQuickTextDocument *document, const QString &path, const QString &encoding,
                           const QString &lineEnding) const {
    QTextDocument *doc = textDocumentOf(document);
    if (!doc)
        return tr("There is no document to save.");
    const QString text = plainText(doc);
    const QString chosenEncoding = TextCodec::isKnownEncoding(encoding) ? encoding : QStringLiteral("utf-8");
    if (!TextCodec::canEncode(text, chosenEncoding))
        return tr("This text has characters ISO-8859-1 cannot store. Pick UTF-8 in the status bar and save again.");
    return writeAtomically(path, TextCodec::encode(text, chosenEncoding,
                                                   TextCodec::isKnownLineEnding(lineEnding) ? lineEnding : "lf"));
}

QString Backend::writeAtomically(const QString &path, const QByteArray &data) {
    const QFileInfo info(path);
    const bool existed = info.exists();
    const auto permissions = existed ? QFile::permissions(path) : QFileDevice::Permissions();

    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return tr("Could not save %1: %2").arg(info.fileName(), file.errorString());
    if (file.write(data) != data.size()) {
        const QString error = file.errorString();
        file.cancelWriting();
        return tr("Could not save %1: %2").arg(info.fileName(), error);
    }
    if (!file.commit())
        return tr("Could not save %1: %2").arg(info.fileName(), file.errorString());

    // The rename replaces the file, so keep the permissions it had.
    if (existed)
        QFile::setPermissions(path, permissions);
    return {};
}

QString Backend::plainText(const QTextDocument *document) {
    if (!document)
        return {};
    // toPlainText() would also turn non-breaking spaces into plain ones,
    // which quietly changes the file; only the paragraph and line separators
    // the document uses internally become line breaks.
    QString text = document->toRawText();
    text.replace(QChar::ParagraphSeparator, u'\n');
    text.replace(QChar::LineSeparator, u'\n');
    return text;
}

QString Backend::documentText(QQuickTextDocument *document) const {
    return plainText(textDocumentOf(document));
}

void Backend::setModified(QQuickTextDocument *document, bool modified) const {
    if (QTextDocument *doc = textDocumentOf(document))
        doc->setModified(modified);
}

QVariantMap Backend::lineColumn(QQuickTextDocument *document, int position) const {
    QTextDocument *doc = textDocumentOf(document);
    if (!doc)
        return {{"line", 1}, {"column", 1}};
    const QTextBlock block = doc->findBlock(position);
    if (!block.isValid())
        return {{"line", doc->blockCount()}, {"column", 1}};
    return {{"line", block.blockNumber() + 1}, {"column", position - block.position() + 1}};
}

QTextCursor Backend::findIn(QTextDocument *document, const QString &query, int from, bool backward,
                            const QVariantMap &options, bool wrap, bool *wrapped, QString *error) {
    if (wrapped)
        *wrapped = false;
    if (!document || query.isEmpty())
        return {};

    const QRegularExpression expression = patternFor(query, options);
    if (!expression.isValid()) {
        if (error)
            *error = tr("Invalid regular expression: %1").arg(expression.errorString());
        return {};
    }

    // find() makes a regular expression case-insensitive unless told
    // otherwise, whatever the expression's own options say.
    QTextDocument::FindFlags flags;
    if (backward)
        flags |= QTextDocument::FindBackward;
    if (option(options, "matchCase"))
        flags |= QTextDocument::FindCaseSensitively;
    auto search = [&](int position) {
        QTextCursor cursor = document->find(expression, position, flags);
        // An empty match ("^", "\b") selects nothing and can't be stepped
        // through, so it doesn't count as found.
        return cursor.hasSelection() ? cursor : QTextCursor();
    };

    QTextCursor cursor = search(from);
    if (cursor.isNull() && wrap) {
        cursor = search(backward ? document->characterCount() - 1 : 0);
        if (wrapped && !cursor.isNull())
            *wrapped = true;
    }
    return cursor;
}

QVariantMap Backend::find(QQuickTextDocument *document, const QString &query, int from, bool backward,
                          const QVariantMap &options) const {
    bool wrapped = false;
    QString error;
    const QTextCursor cursor = findIn(textDocumentOf(document), query, from, backward, options, true, &wrapped, &error);
    if (cursor.isNull())
        return {{"start", -1}, {"end", -1}, {"error", error}};
    return {{"start", cursor.selectionStart()}, {"end", cursor.selectionEnd()}, {"wrapped", wrapped}};
}

QString Backend::replacementFor(const QString &matched, const QString &query, const QString &replacement,
                                const QVariantMap &options) {
    if (!option(options, "regex"))
        return replacement;
    // Both \1 and $1 name a captured group.
    static const QRegularExpression dollar(QStringLiteral("\\$(\\d)"));
    QString after;
    qsizetype last = 0;
    for (auto it = dollar.globalMatch(replacement); it.hasNext();) {
        const auto m = it.next();
        after += replacement.mid(last, m.capturedStart() - last) + u'\\' + m.captured(1);
        last = m.capturedEnd();
    }
    after += replacement.mid(last);
    QString out = matched;
    out.replace(patternFor(query, options, true), after);
    return out;
}

QVariantMap Backend::replaceMatch(QQuickTextDocument *document, int start, int end, const QString &query,
                                  const QString &replacement, const QVariantMap &options) const {
    QTextDocument *doc = textDocumentOf(document);
    const QTextCursor match = findIn(doc, query, start, false, options, false);
    if (match.isNull() || match.selectionStart() != start || match.selectionEnd() != end)
        return {{"start", -1}, {"end", -1}};

    QTextCursor cursor(doc);
    cursor.setPosition(start);
    cursor.setPosition(end, QTextCursor::KeepAnchor);
    const QString text = replacementFor(cursor.selectedText(), query, replacement, options);
    cursor.beginEditBlock();
    cursor.insertText(text);
    cursor.endEditBlock();
    return {{"start", start}, {"end", start + int(text.size())}};
}

int Backend::replaceAllIn(QTextDocument *document, const QString &query, const QString &replacement,
                          const QVariantMap &options) {
    if (!document || query.isEmpty())
        return 0;
    int count = 0;
    int position = 0;
    QTextCursor edit(document);
    edit.beginEditBlock();
    while (true) {
        QTextCursor match = findIn(document, query, position, false, options, false);
        if (match.isNull())
            break;
        const QString text = replacementFor(match.selectedText(), query, replacement, options);
        match.insertText(text);
        position = match.position();
        ++count;
        if (position >= document->characterCount() - 1)
            break;
    }
    edit.endEditBlock();
    return count;
}

int Backend::replaceAll(QQuickTextDocument *document, const QString &query, const QString &replacement,
                        const QVariantMap &options) const {
    return replaceAllIn(textDocumentOf(document), query, replacement, options);
}

QString Backend::fileName(const QString &path) const {
    return QFileInfo(path).fileName();
}

QString Backend::folderOf(const QString &path) const {
    return QFileInfo(path).absolutePath();
}

QString Backend::urlToPath(const QUrl &url) const {
    return url.isLocalFile() ? url.toLocalFile() : QString();
}

QString Backend::suggestedPath(const QString &name) const {
    QString folder = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (!QDir(folder).exists())
        folder = QDir::homePath();
    return folder + "/" + name;
}

void Backend::copyToClipboard(const QString &text) const {
    if (auto *clipboard = QGuiApplication::clipboard())
        clipboard->setText(text);
}

bool Backend::claimSession() {
    if (m_sessionLock && m_sessionLock->isLocked())
        return true;
    if (!QDir().mkpath(m_stateDirectory))
        return false;
    m_sessionLock = std::make_unique<QLockFile>(m_stateDirectory + "/session.lock");
    // A lock left by a crashed instance is detected by its process id.
    m_sessionLock->setStaleLockTime(0);
    return m_sessionLock->tryLock(0);
}

QVariantMap Backend::loadSession() const {
    QFile file(m_stateDirectory + "/session.json");
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(file.readAll()).object().toVariantMap();
}

QString Backend::saveSession(const QVariantMap &session) const {
    if (!m_sessionLock || !m_sessionLock->isLocked())
        return tr("Another Notepads window keeps the session.");
    const QString path = m_stateDirectory + "/session.json";
    const QString error = writeAtomically(path, QJsonDocument(QJsonObject::fromVariantMap(session)).toJson(QJsonDocument::Compact));
    // Unsaved tabs can hold anything, so only the user may read them.
    QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    return error;
}

void Backend::openDialog(const QString &folder) {
    if (!m_picker) {
        emit failed(tr("No file chooser is available."));
        return;
    }
    m_picker->openFiles(folder);
}

void Backend::saveDialog(const QString &suggestedPath, int tag) {
    if (!m_picker) {
        emit failed(tr("No file chooser is available."));
        return;
    }
    m_picker->saveFile(suggestedPath, tag);
}
