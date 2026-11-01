#pragma once

#include <QColor>
#include <QPointer>
#include <QQuickPaintedItem>
#include <QQuickTextDocument>

class QTextDocument;

// The red wave under misspelled words, drawn over the editor's visible area.
//
// Qt Quick draws a text underline in the text's own color, so SpellChecker
// only marks the words and this paints them, reading the positions straight
// from the document's layout, as LineNumberGutter does for line numbers.
class SpellUnderline : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(QQuickTextDocument *document READ document WRITE setDocument NOTIFY changed)
    // The editor's scroll offsets and the padding around its text.
    Q_PROPERTY(qreal contentX MEMBER m_contentX WRITE setContentX NOTIFY changed)
    Q_PROPERTY(qreal contentY MEMBER m_contentY WRITE setContentY NOTIFY changed)
    Q_PROPERTY(qreal textLeft MEMBER m_textLeft WRITE setTextLeft NOTIFY changed)
    Q_PROPERTY(qreal textTop MEMBER m_textTop WRITE setTextTop NOTIFY changed)
    Q_PROPERTY(QColor color MEMBER m_color WRITE setColor NOTIFY changed)

public:
    explicit SpellUnderline(QQuickItem *parent = nullptr);

    QQuickTextDocument *document() const { return m_quickDocument; }
    void setDocument(QQuickTextDocument *document);
    void setContentX(qreal value) { set(m_contentX, value); }
    void setContentY(qreal value) { set(m_contentY, value); }
    void setTextLeft(qreal value) { set(m_textLeft, value); }
    void setTextTop(qreal value) { set(m_textTop, value); }
    void setColor(const QColor &value);

    void paint(QPainter *painter) override;

    // The visible stretches to underline, in this item's coordinates: each
    // is a line from (x1, y) to (x2, y). Separate so tests can check them.
    struct Stretch {
        qreal x1, x2, y;
    };
    static QList<Stretch> stretches(QTextDocument *document, qreal left, qreal top, qreal height);

signals:
    void changed();

private:
    void set(qreal &member, qreal value);

    QPointer<QQuickTextDocument> m_quickDocument;
    QPointer<QTextDocument> m_document;
    qreal m_contentX = 0;
    qreal m_contentY = 0;
    qreal m_textLeft = 0;
    qreal m_textTop = 0;
    QColor m_color = QColor(0xE5, 0x48, 0x4D);
};
