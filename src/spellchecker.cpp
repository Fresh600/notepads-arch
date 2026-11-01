#include "spellchecker.h"

#include "backend.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QQuickTextDocument>
#include <QStandardPaths>
#include <QStringDecoder>
#include <QStringEncoder>
#include <QSyntaxHighlighter>
#include <QAbstractTextDocumentLayout>
#include <QTextBlock>
#include <QTextCursor>
#include <QTextDocument>

#include <hunspell/hunspell.hxx>

// The misspelled words of one line, kept with the line itself.
class SpellMarks : public QTextBlockUserData {
public:
    explicit SpellMarks(QList<QPair<int, int>> ranges) : ranges(std::move(ranges)) {}
    QList<QPair<int, int>> ranges;
};

// Finds the misspelled words of one document, line by line as it changes.
//
// It sets no text formats: Qt Quick would draw any formatted word with an
// underline in the text's own color. The words are kept as each line's user
// data instead, and SpellUnderline paints the red wave under them. Nothing
// here touches the text, its undo history, or whether it counts as modified.
class SpellHighlighter : public QSyntaxHighlighter {
public:
    SpellHighlighter(SpellChecker *checker, QTextDocument *document)
        : QSyntaxHighlighter(document), m_checker(checker) {}

protected:
    void highlightBlock(const QString &text) override {
        QList<QPair<int, int>> ranges;
        if (m_checker->underline() && m_checker->available() && document()
            && document()->characterCount() <= SpellChecker::MaxUnderlinedCharacters) {
            for (const auto &range : SpellChecker::words(text)) {
                if (!m_checker->isCorrect(text.mid(range.first, range.second)))
                    ranges.append(range);
            }
        }
        const auto *old = static_cast<SpellMarks *>(currentBlockUserData());
        if (old ? old->ranges == ranges : ranges.isEmpty())
            return;
        setCurrentBlockUserData(new SpellMarks(ranges));
        // The layout doesn't change, so tell whoever paints, once a pass.
        if (!m_notifyQueued) {
            m_notifyQueued = true;
            QMetaObject::invokeMethod(this, [this] {
                m_notifyQueued = false;
                if (document() && document()->documentLayout())
                    emit document()->documentLayout()->update();
            }, Qt::QueuedConnection);
        }
    }

private:
    SpellChecker *m_checker;
    bool m_notifyQueued = false;
};

QList<QPair<int, int>> SpellChecker::misspelled(const QTextBlock &block) {
    const auto *marks = static_cast<const SpellMarks *>(block.userData());
    return marks ? marks->ranges : QList<QPair<int, int>>();
}

namespace {

// What Hunspell's affix file says about itself: its encoding and, from the
// TRY line, the letters its language is written in.
struct AffixInfo {
    QByteArray encoding = "ISO8859-1";
    QByteArray tryLetters;
};

AffixInfo readAffix(const QString &path) {
    AffixInfo info;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return info;
    while (!file.atEnd()) {
        const QByteArray line = file.readLine().trimmed();
        if (line.startsWith("SET "))
            info.encoding = line.mid(4).trimmed();
        else if (line.startsWith("TRY "))
            info.tryLetters = line.mid(4).trimmed();
        if (!info.tryLetters.isEmpty() && line.startsWith("SET "))
            break;
    }
    return info;
}

QString decode(const QByteArray &bytes, const QByteArray &encoding) {
    if (encoding.compare("UTF-8", Qt::CaseInsensitive) == 0)
        return QString::fromUtf8(bytes);
    QStringDecoder decoder(encoding.constData());
    return decoder.isValid() ? QString(decoder(bytes)) : QString();
}

QByteArray encodeFor(const QString &text, const QByteArray &encoding) {
    if (encoding.compare("UTF-8", Qt::CaseInsensitive) == 0)
        return text.toUtf8();
    QStringEncoder encoder(encoding.constData());
    return encoder.isValid() ? QByteArray(encoder(text)) : QByteArray();
}

bool isWordLetter(QChar c) {
    return c.isLetter() || c.isMark();
}

// Apostrophes and Hebrew geresh/gershayim sit inside words ("don't", צה״ל).
bool isJoiner(QChar c) {
    return c == u'\'' || c == u'’' || c == u'׳' || c == u'״' || c == u'"';
}

}

SpellChecker::SpellChecker(const QStringList &dictionaryDirectories, const QString &userDictionary, QObject *parent)
    : QObject(parent),
      m_userDictionary(userDictionary.isEmpty()
                           ? QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                                 + "/notepads/dictionary.txt"
                           : userDictionary) {
    QStringList directories = dictionaryDirectories;
    if (directories.isEmpty()) {
        for (const QString &data : QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation))
            directories << data + "/hunspell";
    }
    load(directories);

    QFile file(m_userDictionary);
    if (file.open(QIODevice::ReadOnly)) {
        for (const QByteArray &line : file.readAll().split('\n')) {
            const QString word = QString::fromUtf8(line).trimmed();
            if (!word.isEmpty())
                m_userWords.insert(word);
        }
    }
}

SpellChecker::~SpellChecker() = default;

void SpellChecker::load(const QStringList &directories) {
    QSet<QString> seen;
    for (const QString &directory : directories) {
        const QDir dir(directory);
        for (const QFileInfo &dic : dir.entryInfoList({"*.dic"}, QDir::Files, QDir::Name)) {
            // en_US.dic is often a link to en_US-large.dic: load it once.
            const QString canonical = dic.canonicalFilePath();
            const QString affix = dic.absolutePath() + "/" + dic.completeBaseName() + ".aff";
            if (canonical.isEmpty() || seen.contains(canonical) || !QFileInfo::exists(affix))
                continue;
            seen.insert(canonical);

            const AffixInfo info = readAffix(affix);
            const QString letters = decode(info.tryLetters, info.encoding);
            if (letters.isEmpty())
                continue;
            Dictionary dictionary;
            dictionary.language = dic.completeBaseName();
            dictionary.letters = letters.toLower();
            dictionary.hunspell = std::make_unique<Hunspell>(QFile::encodeName(affix).constData(),
                                                             QFile::encodeName(dic.absoluteFilePath()).constData());
            m_dictionaries.push_back(std::move(dictionary));
        }
    }
}

QStringList SpellChecker::languages() const {
    QStringList result;
    for (const Dictionary &dictionary : m_dictionaries)
        result << dictionary.language;
    return result;
}

void SpellChecker::setUnderline(bool value) {
    if (m_underline == value)
        return;
    m_underline = value;
    emit underlineChanged();
    rehighlightAll();
}

void SpellChecker::rehighlightAll() {
    m_highlighters.removeAll(nullptr);
    for (const auto &highlighter : std::as_const(m_highlighters))
        highlighter->rehighlight();
}

std::vector<const SpellChecker::Dictionary *> SpellChecker::dictionariesFor(const QString &word) const {
    std::vector<const Dictionary *> result;
    if (word.isEmpty())
        return result;
    const QChar first = word.at(0).toLower();
    for (const Dictionary &dictionary : m_dictionaries) {
        if (dictionary.letters.contains(first))
            result.push_back(&dictionary);
    }
    return result;
}

bool SpellChecker::isCorrect(const QString &word) const {
    if (m_userWords.contains(word))
        return true;
    const auto dictionaries = dictionariesFor(word);
    // No dictionary for this alphabet: nothing to judge it by.
    if (dictionaries.empty())
        return true;
    for (const Dictionary *dictionary : dictionaries) {
        if (dictionary->hunspell->spell(encodeFor(word, dictionary->hunspell->get_dict_encoding().c_str()).toStdString()))
            return true;
    }
    return false;
}

QStringList SpellChecker::suggestions(const QString &word, int limit) const {
    QStringList result;
    for (const Dictionary *dictionary : dictionariesFor(word)) {
        const QByteArray encoding = dictionary->hunspell->get_dict_encoding().c_str();
        for (const std::string &suggestion : dictionary->hunspell->suggest(encodeFor(word, encoding).toStdString())) {
            const QString text = decode(QByteArray::fromStdString(suggestion), encoding);
            if (!text.isEmpty() && text != word && !result.contains(text))
                result << text;
            if (result.size() >= limit)
                return result;
        }
    }
    return result;
}

void SpellChecker::addWord(const QString &word) {
    const QString trimmed = word.trimmed();
    if (trimmed.isEmpty() || m_userWords.contains(trimmed))
        return;
    m_userWords.insert(trimmed);

    QStringList sorted(m_userWords.begin(), m_userWords.end());
    sorted.sort(Qt::CaseInsensitive);
    QDir().mkpath(QFileInfo(m_userDictionary).absolutePath());
    Backend::writeAtomically(m_userDictionary, (sorted.join('\n') + '\n').toUtf8());
    rehighlightAll();
}

QList<QPair<int, int>> SpellChecker::words(const QString &text) {
    QList<QPair<int, int>> result;

    // Links and e-mail addresses aren't words.
    static const QRegularExpression skip(QStringLiteral(R"((?:[a-z][a-z0-9+.-]*://|www\.)\S+|\S+@\S+\.\S+)"),
                                         QRegularExpression::CaseInsensitiveOption);
    QList<QPair<int, int>> skipped;
    for (auto it = skip.globalMatch(text); it.hasNext();) {
        const auto match = it.next();
        skipped.append({match.capturedStart(), match.capturedEnd()});
    }

    const int size = text.size();
    int i = 0;
    while (i < size) {
        if (!text.at(i).isLetterOrNumber() && text.at(i) != u'_') {
            ++i;
            continue;
        }
        // A run of letters, digits, underscores, and joiners between them.
        const int start = i;
        bool code = false;
        while (i < size) {
            const QChar c = text.at(i);
            if (isWordLetter(c)) {
                ++i;
            } else if (c.isDigit() || c == u'_') {
                code = true;
                ++i;
            } else if (isJoiner(c) && i + 1 < size && isWordLetter(text.at(i + 1)) && i > start) {
                ++i;
            } else {
                break;
            }
        }
        const int end = i;
        const QString word = text.mid(start, end - start);

        bool inSkipped = false;
        for (const auto &[from, to] : skipped)
            inSkipped = inSkipped || (start < to && end > from);
        // Numbers and identifiers (x2, snake_case), single letters, and
        // anything capitalized past its first letter (ACRONYMS, camelCase,
        // iPhone) are left alone: they're names more often than mistakes.
        int upper = 0;
        for (QChar c : word)
            upper += c.isUpper();
        const bool oddCase = upper > 1 || (upper == 1 && !word.at(0).isUpper());
        if (!code && !inSkipped && word.size() > 1 && !oddCase)
            result.append({start, end - start});
    }
    return result;
}

void SpellChecker::attach(QQuickTextDocument *document) {
    if (document)
        attachTo(document->textDocument());
}

void SpellChecker::attachTo(QTextDocument *document) {
    if (!document || document->findChild<QSyntaxHighlighter *>("notepads-spelling", Qt::FindDirectChildrenOnly))
        return;
    // Keep the modified flag as it was: highlighting isn't an edit.
    const bool modified = document->isModified();
    auto *highlighter = new SpellHighlighter(this, document);
    highlighter->setObjectName("notepads-spelling");
    m_highlighters.append(highlighter);
    document->setModified(modified);
}

QVariantMap SpellChecker::wordAt(QQuickTextDocument *document, int position, int selectionStart,
                                 int selectionEnd) const {
    if (!document)
        return {{"start", -1}};
    return wordIn(document->textDocument(), position, selectionStart, selectionEnd);
}

QVariantMap SpellChecker::wordIn(const QTextDocument *document, int position, int selectionStart,
                                 int selectionEnd) const {
    QVariantMap none{{"start", -1}};
    if (!document)
        return none;

    // A selected word wins when it is one word on one line.
    if (selectionStart >= 0 && selectionEnd > selectionStart) {
        const QTextBlock block = document->findBlock(selectionStart);
        if (block.isValid() && selectionEnd <= block.position() + block.length() - 1) {
            const QString text = block.text();
            const int from = selectionStart - block.position();
            const int to = selectionEnd - block.position();
            for (const auto &[start, length] : words(text)) {
                if (start == from && start + length == to) {
                    const QString word = text.mid(start, length);
                    return {{"start", selectionStart}, {"end", selectionEnd}, {"word", word},
                            {"misspelled", !isCorrect(word)}};
                }
            }
        }
    }

    const QTextBlock block = document->findBlock(position);
    if (!block.isValid())
        return none;
    const QString text = block.text();
    const int offset = position - block.position();
    for (const auto &[start, length] : words(text)) {
        // The click can land just after the word's last letter.
        if (offset >= start && offset <= start + length) {
            const QString word = text.mid(start, length);
            return {{"start", block.position() + start},
                    {"end", block.position() + start + length},
                    {"word", word},
                    {"misspelled", !isCorrect(word)}};
        }
    }
    return none;
}

bool SpellChecker::replace(QQuickTextDocument *document, int start, int end, const QString &expected,
                           const QString &replacement) const {
    return document && replaceIn(document->textDocument(), start, end, expected, replacement);
}

bool SpellChecker::replaceIn(QTextDocument *document, int start, int end, const QString &expected,
                             const QString &replacement) {
    if (!document || start < 0 || end <= start || end >= document->characterCount())
        return false;
    QTextCursor cursor(document);
    cursor.setPosition(start);
    cursor.setPosition(end, QTextCursor::KeepAnchor);
    if (cursor.selectedText() != expected)
        return false;
    cursor.beginEditBlock();
    cursor.insertText(replacement);
    cursor.endEditBlock();
    return true;
}
