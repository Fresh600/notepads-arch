#pragma once

#include <QLockFile>
#include <QObject>
#include <QStringList>
#include <QTextCursor>
#include <QVariantMap>
#include <memory>

class FilePicker;
class QQuickTextDocument;
class QTextDocument;

// Everything the window can't do itself: reading and writing files in their
// own encoding and line ending, searching and replacing inside a tab's
// document, dialogs, and the session snapshot that brings tabs back.
class Backend : public QObject {
    Q_OBJECT

public:
    // Files larger than this are refused rather than freezing the editor.
    static constexpr qint64 MaxFileSize = 64LL * 1024 * 1024;

    explicit Backend(FilePicker *picker = nullptr, const QString &stateDirectory = {}, QObject *parent = nullptr);
    ~Backend() override;

    void setStartupFiles(const QStringList &files) { m_startupFiles = files; }
    Q_INVOKABLE QStringList startupFiles() const { return m_startupFiles; }

    // {ok, error, missing, text, encoding, lineEnding}. lineEnding is empty
    // when the file has no line breaks.
    Q_INVOKABLE QVariantMap readFile(const QString &path, const QString &encoding = {}) const;
    // Writes atomically beside the target, then renames. Returns an error
    // message, or an empty string on success.
    Q_INVOKABLE QString writeFile(QQuickTextDocument *document, const QString &path,
                                  const QString &encoding, const QString &lineEnding) const;
    Q_INVOKABLE QString documentText(QQuickTextDocument *document) const;
    Q_INVOKABLE void setModified(QQuickTextDocument *document, bool modified) const;
    Q_INVOKABLE QVariantMap lineColumn(QQuickTextDocument *document, int position) const;

    // options: {matchCase, wholeWord, regex}. Returns {start, end, wrapped}
    // with start -1 when nothing matches, plus {error} for a bad pattern.
    Q_INVOKABLE QVariantMap find(QQuickTextDocument *document, const QString &query, int from,
                                 bool backward, const QVariantMap &options) const;
    // Replaces the match at [start, end) if it still matches, as one undo
    // step. Returns {start, end} of the replacement, or start -1.
    Q_INVOKABLE QVariantMap replaceMatch(QQuickTextDocument *document, int start, int end, const QString &query,
                                         const QString &replacement, const QVariantMap &options) const;
    Q_INVOKABLE int replaceAll(QQuickTextDocument *document, const QString &query, const QString &replacement,
                               const QVariantMap &options) const;

    Q_INVOKABLE QString fileName(const QString &path) const;
    Q_INVOKABLE QString folderOf(const QString &path) const;
    Q_INVOKABLE QString urlToPath(const QUrl &url) const;
    Q_INVOKABLE QString suggestedPath(const QString &name) const;
    Q_INVOKABLE void copyToClipboard(const QString &text) const;

    // Only one window keeps the session, so two windows never overwrite each
    // other's unsaved tabs; the rest ask before closing like any editor.
    Q_INVOKABLE bool claimSession();
    Q_INVOKABLE QVariantMap loadSession() const;
    Q_INVOKABLE QString saveSession(const QVariantMap &session) const;

    Q_INVOKABLE void openDialog(const QString &folder = {});
    Q_INVOKABLE void saveDialog(const QString &suggestedPath, int tag);

    // The document-level halves of the above, testable without a window.
    static QString plainText(const QTextDocument *document);
    static QTextCursor findIn(QTextDocument *document, const QString &query, int from, bool backward,
                              const QVariantMap &options, bool wrap, bool *wrapped = nullptr,
                              QString *error = nullptr);
    static int replaceAllIn(QTextDocument *document, const QString &query, const QString &replacement,
                            const QVariantMap &options);
    static QString replacementFor(const QString &matched, const QString &query, const QString &replacement,
                                  const QVariantMap &options);
    static QString writeAtomically(const QString &path, const QByteArray &data);

signals:
    void filesChosen(const QStringList &paths);
    void saveChosen(const QString &path, int tag);
    void failed(const QString &message);

private:
    FilePicker *m_picker = nullptr;
    QString m_stateDirectory;
    QStringList m_startupFiles;
    std::unique_ptr<QLockFile> m_sessionLock;
};
