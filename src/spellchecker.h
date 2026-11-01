#pragma once

#include <QHash>
#include <QObject>
#include <QPointer>
#include <QRegularExpression>
#include <QSet>
#include <QStringList>
#include <QVariantMap>
#include <memory>
#include <vector>

class Hunspell;
class QQuickTextDocument;
class QTextDocument;
class SpellHighlighter;

// Spelling, from the Hunspell dictionaries installed on the system
// (hunspell-en_us, hunspell-he, ...), plus the user's own word list.
//
// A word is only judged by dictionaries for its alphabet, so Hebrew isn't
// flagged when only English is installed, and the other way round.
// Misspelled words get a red underline through a highlighter on each tab's
// document; suggestions are only ever asked for by the right-click menu.
class SpellChecker : public QObject {
    Q_OBJECT
    // Whether any dictionary is installed.
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(bool underline READ underline WRITE setUnderline NOTIFY underlineChanged)

public:
    // Underlining a huge file would freeze the window while it's checked.
    static constexpr int MaxUnderlinedCharacters = 2'000'000;

    // Empty arguments mean the system's dictionary folders and
    // ~/.local/share/notepads/dictionary.txt.
    explicit SpellChecker(const QStringList &dictionaryDirectories = {}, const QString &userDictionary = {},
                          QObject *parent = nullptr);
    ~SpellChecker() override;

    bool available() const { return !m_dictionaries.empty(); }
    bool underline() const { return m_underline; }
    void setUnderline(bool value);

    // The dictionaries' languages, like "en_US", for the settings page.
    Q_INVOKABLE QStringList languages() const;

    bool isCorrect(const QString &word) const;
    Q_INVOKABLE QStringList suggestions(const QString &word, int limit = 5) const;
    // The one correction to offer: the first suggestion, or empty if none.
    Q_INVOKABLE QString bestSuggestion(const QString &word) const { return suggestions(word, 1).value(0); }
    // Remembers the word for good and takes its underline away everywhere.
    Q_INVOKABLE void addWord(const QString &word);

    // Underlines this document's mistakes while underline is on.
    Q_INVOKABLE void attach(QQuickTextDocument *document);
    // The word at a position, or the selection when it is a single word:
    // {start, end, word, misspelled}; start -1 when there is no word there.
    Q_INVOKABLE QVariantMap wordAt(QQuickTextDocument *document, int position, int selectionStart = -1,
                                   int selectionEnd = -1) const;
    // Swaps [start, end) for the replacement as one undo step, if the text
    // there is still the word that was checked.
    Q_INVOKABLE bool replace(QQuickTextDocument *document, int start, int end, const QString &expected,
                             const QString &replacement) const;

    // The document-level halves of the above, testable without a window.
    static bool replaceIn(QTextDocument *document, int start, int end, const QString &expected,
                          const QString &replacement);
    // The ranges of a line that are words worth checking: no numbers,
    // identifiers, acronyms, links, or e-mail addresses. Pairs of
    // (start, length).
    static QList<QPair<int, int>> words(const QString &text);
    QVariantMap wordIn(const QTextDocument *document, int position, int selectionStart, int selectionEnd) const;
    void attachTo(QTextDocument *document);
    // The misspelled words found on a line, as (start, length) pairs.
    static QList<QPair<int, int>> misspelled(const class QTextBlock &block);

signals:
    void availableChanged();
    void underlineChanged();

private:
    struct Dictionary {
        QString language;
        QString letters;
        std::unique_ptr<Hunspell> hunspell;
    };

    void load(const QStringList &directories);
    void rehighlightAll();
    std::vector<const Dictionary *> dictionariesFor(const QString &word) const;

    std::vector<Dictionary> m_dictionaries;
    QSet<QString> m_userWords;
    QString m_userDictionary;
    bool m_underline = true;
    QList<QPointer<SpellHighlighter>> m_highlighters;
};
