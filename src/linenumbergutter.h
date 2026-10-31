#pragma once

#include <QColor>
#include <QFont>
#include <QPointer>
#include <QQuickPaintedItem>
#include <QQuickTextDocument>
#include <QTimer>

class QTextDocument;

// Line numbers beside the editor, read straight from the document's layout,
// so only the visible lines are painted however long the file is.
//
// Each paragraph's number goes on the side its text starts from: the left
// gutter numbers left-to-right lines and the right gutter numbers Hebrew
// ones. A wrapped paragraph is numbered once, on its first line.
class LineNumberGutter : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(QQuickTextDocument *document READ document WRITE setDocument NOTIFY documentChanged)
    // The editor's scroll offset and the space above its first line.
    Q_PROPERTY(qreal contentY READ contentY WRITE setContentY NOTIFY contentYChanged)
    Q_PROPERTY(qreal textTop READ textTop WRITE setTextTop NOTIFY textTopChanged)
    Q_PROPERTY(bool rightSide READ rightSide WRITE setRightSide NOTIFY rightSideChanged)
    Q_PROPERTY(int currentLine READ currentLine WRITE setCurrentLine NOTIFY currentLineChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(QColor currentColor READ currentColor WRITE setCurrentColor NOTIFY colorChanged)
    Q_PROPERTY(QFont font READ font WRITE setFont NOTIFY fontChanged)
    // Whether any paragraph belongs on this side, and how wide the widest
    // number needs the gutter to be.
    Q_PROPERTY(bool hasLines READ hasLines NOTIFY linesChanged)
    Q_PROPERTY(qreal neededWidth READ neededWidth NOTIFY linesChanged)

public:
    explicit LineNumberGutter(QQuickItem *parent = nullptr);

    QQuickTextDocument *document() const { return m_quickDocument; }
    void setDocument(QQuickTextDocument *document);
    qreal contentY() const { return m_contentY; }
    void setContentY(qreal value);
    qreal textTop() const { return m_textTop; }
    void setTextTop(qreal value);
    bool rightSide() const { return m_rightSide; }
    void setRightSide(bool value);
    int currentLine() const { return m_currentLine; }
    void setCurrentLine(int value);
    QColor color() const { return m_color; }
    void setColor(const QColor &value);
    QColor currentColor() const { return m_currentColor; }
    void setCurrentColor(const QColor &value);
    QFont font() const { return m_font; }
    void setFont(const QFont &value);
    bool hasLines() const { return m_hasLines; }
    qreal neededWidth() const { return m_neededWidth; }

    void paint(QPainter *painter) override;

    // Which side a paragraph's number belongs on, and the gutter width for
    // a document with this many lines; separate so tests can check them.
    static bool isRightToLeft(const class QTextBlock &block);
    static qreal widthFor(int lineCount, const QFont &font);

signals:
    void documentChanged();
    void contentYChanged();
    void textTopChanged();
    void rightSideChanged();
    void currentLineChanged();
    void colorChanged();
    void fontChanged();
    void linesChanged();

private:
    void recount();

    QPointer<QQuickTextDocument> m_quickDocument;
    QPointer<QTextDocument> m_document;
    qreal m_contentY = 0;
    qreal m_textTop = 0;
    bool m_rightSide = false;
    int m_currentLine = 1;
    QColor m_color = QColor(128, 128, 128);
    QColor m_currentColor = Qt::white;
    QFont m_font;
    bool m_hasLines = true;
    qreal m_neededWidth = 0;
    QTimer m_recount;
};
