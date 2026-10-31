#pragma once

#include <QObject>
#include <QPointer>
#include <QTextDocument>

// Gives every paragraph its own reading direction, from its first strong
// character, so a Hebrew line reads right to left while the English line
// below it stays left to right.
//
// Qt Quick's TextEdit picks one direction for the whole document from its
// first letter, which flips English lines (and their punctuation) whenever
// the file starts in Hebrew. A direction set on a block overrides that.
class ParagraphDirection : public QObject {
    Q_OBJECT

public:
    explicit ParagraphDirection(QTextDocument *document);

    // The first strong character's direction; LayoutDirectionAuto when the
    // text has none (empty lines, digits, punctuation).
    static Qt::LayoutDirection directionOf(const QString &text);

    // Sets the direction of the blocks touching [from, to], and of the
    // neutral blocks after them that inherit it. Returns how many changed.
    // The change joins the edit that caused it, so undo takes both back.
    static int update(QTextDocument *document, int from, int to);

    // Every block, for a freshly loaded document: no undo step is left
    // behind and the modified flag is untouched.
    static void updateAll(QTextDocument *document);

private:
    void schedule(int position, int removed, int added);
    void process();

    QPointer<QTextDocument> m_document;
    int m_from = -1;
    int m_to = -1;
    bool m_scheduled = false;
};
