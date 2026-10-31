#include "linenumbergutter.h"

#include <QAbstractTextDocumentLayout>
#include <QFontMetricsF>
#include <QPainter>
#include <QQuickTextDocument>
#include <QTextBlock>
#include <QTextDocument>
#include <QTextLayout>

namespace {
constexpr qreal outerPadding = 12;
constexpr qreal innerPadding = 8;
}

LineNumberGutter::LineNumberGutter(QQuickItem *parent) : QQuickPaintedItem(parent) {
    setAntialiasing(true);
    // Counting walks every paragraph, so a burst of typing counts once.
    m_recount.setSingleShot(true);
    m_recount.setInterval(30);
    connect(&m_recount, &QTimer::timeout, this, &LineNumberGutter::recount);
    m_neededWidth = widthFor(1, m_font);
}

bool LineNumberGutter::isRightToLeft(const QTextBlock &block) {
    return block.blockFormat().layoutDirection() == Qt::RightToLeft;
}

qreal LineNumberGutter::widthFor(int lineCount, const QFont &font) {
    const int digits = QString::number(qMax(1, lineCount)).size();
    // At least three digits wide, so the editor doesn't shift at line 10
    // and line 100.
    return QFontMetricsF(font).horizontalAdvance(QLatin1Char('9')) * qMax(3, digits) + outerPadding + innerPadding;
}

void LineNumberGutter::setDocument(QQuickTextDocument *document) {
    if (m_quickDocument == document)
        return;
    if (m_document) {
        disconnect(m_document, nullptr, this, nullptr);
        if (m_document->documentLayout())
            disconnect(m_document->documentLayout(), nullptr, this, nullptr);
    }
    m_quickDocument = document;
    m_document = document ? document->textDocument() : nullptr;
    if (m_document) {
        connect(m_document, &QTextDocument::contentsChanged, this, [this] {
            m_recount.start();
            update();
        });
        connect(m_document, &QTextDocument::blockCountChanged, &m_recount, qOverload<>(&QTimer::start));
        if (auto *layout = m_document->documentLayout()) {
            connect(layout, &QAbstractTextDocumentLayout::update, this, [this] { update(); });
            connect(layout, &QAbstractTextDocumentLayout::documentSizeChanged, this, [this] { update(); });
        }
    }
    emit documentChanged();
    recount();
    update();
}

void LineNumberGutter::setContentY(qreal value) {
    if (qFuzzyCompare(m_contentY, value))
        return;
    m_contentY = value;
    emit contentYChanged();
    update();
}

void LineNumberGutter::setTextTop(qreal value) {
    if (qFuzzyCompare(m_textTop, value))
        return;
    m_textTop = value;
    emit textTopChanged();
    update();
}

void LineNumberGutter::setRightSide(bool value) {
    if (m_rightSide == value)
        return;
    m_rightSide = value;
    emit rightSideChanged();
    recount();
    update();
}

void LineNumberGutter::setCurrentLine(int value) {
    if (m_currentLine == value)
        return;
    m_currentLine = value;
    emit currentLineChanged();
    update();
}

void LineNumberGutter::setColor(const QColor &value) {
    if (m_color == value)
        return;
    m_color = value;
    emit colorChanged();
    update();
}

void LineNumberGutter::setCurrentColor(const QColor &value) {
    if (m_currentColor == value)
        return;
    m_currentColor = value;
    emit colorChanged();
    update();
}

void LineNumberGutter::setFont(const QFont &value) {
    if (m_font == value)
        return;
    m_font = value;
    emit fontChanged();
    recount();
    update();
}

void LineNumberGutter::recount() {
    bool hasLines = !m_rightSide;
    int count = 1;
    if (m_document) {
        count = m_document->blockCount();
        hasLines = false;
        for (QTextBlock block = m_document->begin(); block.isValid(); block = block.next()) {
            if (isRightToLeft(block) == m_rightSide) {
                hasLines = true;
                break;
            }
        }
    }
    const qreal width = widthFor(count, m_font);
    if (hasLines != m_hasLines || !qFuzzyCompare(width, m_neededWidth)) {
        m_hasLines = hasLines;
        m_neededWidth = width;
        emit linesChanged();
    }
}

void LineNumberGutter::paint(QPainter *painter) {
    if (!m_document)
        return;
    QAbstractTextDocumentLayout *layout = m_document->documentLayout();
    if (!layout)
        return;

    painter->setFont(m_font);
    const QFontMetricsF metrics(m_font);

    // The top of the view in document coordinates. Start a paragraph early
    // so one that begins above the view but shows its first line is kept.
    const qreal top = m_contentY - m_textTop;
    const int position = layout->hitTest(QPointF(1, qMax<qreal>(0, top)), Qt::FuzzyHit);
    QTextBlock block = m_document->findBlock(qMax(0, position));
    if (block.isValid() && block.previous().isValid())
        block = block.previous();

    for (; block.isValid(); block = block.next()) {
        if (!block.isVisible())
            continue;
        const QRectF rect = layout->blockBoundingRect(block);
        const qreal y = rect.top() - top;
        if (y > height())
            break;
        if (isRightToLeft(block) != m_rightSide)
            continue;

        qreal baseline = y + metrics.ascent();
        if (const QTextLayout *textLayout = block.layout(); textLayout && textLayout->lineCount() > 0) {
            const QTextLine line = textLayout->lineAt(0);
            baseline = y + line.y() + line.ascent();
        }
        if (baseline < 0)
            continue;

        const int number = block.blockNumber() + 1;
        const QString text = QString::number(number);
        painter->setPen(number == m_currentLine ? m_currentColor : m_color);
        // Right-aligned in both gutters: against the text on the left, and
        // against the window's edge on the right, where Hebrew starts.
        const qreal x = m_rightSide ? width() - outerPadding - metrics.horizontalAdvance(text)
                                    : width() - innerPadding - metrics.horizontalAdvance(text);
        painter->drawText(QPointF(x, baseline), text);
    }
}
