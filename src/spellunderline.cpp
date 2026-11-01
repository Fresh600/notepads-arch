#include "spellunderline.h"

#include "spellchecker.h"

#include <QAbstractTextDocumentLayout>
#include <QPainter>
#include <QPainterPath>
#include <QQuickTextDocument>
#include <QTextBlock>
#include <QTextDocument>
#include <QTextLayout>

SpellUnderline::SpellUnderline(QQuickItem *parent) : QQuickPaintedItem(parent) {
    setAntialiasing(true);
}

void SpellUnderline::set(qreal &member, qreal value) {
    if (qFuzzyCompare(member, value))
        return;
    member = value;
    emit changed();
    update();
}

void SpellUnderline::setColor(const QColor &value) {
    if (m_color == value)
        return;
    m_color = value;
    emit changed();
    update();
}

void SpellUnderline::setDocument(QQuickTextDocument *document) {
    if (m_quickDocument == document)
        return;
    if (m_document && m_document->documentLayout())
        disconnect(m_document->documentLayout(), nullptr, this, nullptr);
    m_quickDocument = document;
    m_document = document ? document->textDocument() : nullptr;
    // The highlighter's marks and every edit come through as layout updates.
    if (m_document && m_document->documentLayout())
        connect(m_document->documentLayout(), &QAbstractTextDocumentLayout::update, this, [this] { update(); });
    emit changed();
    update();
}

QList<SpellUnderline::Stretch> SpellUnderline::stretches(QTextDocument *document, qreal left, qreal top,
                                                         qreal height) {
    QList<Stretch> result;
    QAbstractTextDocumentLayout *layout = document ? document->documentLayout() : nullptr;
    if (!layout)
        return result;

    // left and top are where the document's origin sits in this item.
    const int position = layout->hitTest(QPointF(1, qMax<qreal>(0, -top)), Qt::FuzzyHit);
    QTextBlock block = document->findBlock(qMax(0, position));
    if (block.isValid() && block.previous().isValid())
        block = block.previous();

    for (; block.isValid(); block = block.next()) {
        const QRectF rect = layout->blockBoundingRect(block);
        if (rect.top() + top > height)
            break;
        const QTextLayout *textLayout = block.layout();
        if (!block.isVisible() || !textLayout)
            continue;
        for (const auto &[start, length] : SpellChecker::misspelled(block)) {
            const int end = start + length;
            // A wrapped word can run over two lines.
            for (int i = 0; i < textLayout->lineCount(); ++i) {
                const QTextLine line = textLayout->lineAt(i);
                const int from = qMax(start, line.textStart());
                const int to = qMin(end, line.textStart() + line.textLength());
                if (from >= to)
                    continue;
                qreal x1 = line.cursorToX(from);
                qreal x2 = line.cursorToX(to);
                if (x1 > x2)
                    std::swap(x1, x2);
                const qreal y = rect.top() + top + line.y() + line.ascent() + 2;
                if (y < 0 || y > height)
                    continue;
                result.append({rect.left() + left + x1, rect.left() + left + x2, y});
            }
        }
    }
    return result;
}

void SpellUnderline::paint(QPainter *painter) {
    if (!m_document)
        return;
    QPen pen(m_color, 1.2);
    pen.setCapStyle(Qt::RoundCap);
    painter->setPen(pen);
    painter->setBrush(Qt::NoBrush);
    for (const Stretch &stretch : stretches(m_document, m_textLeft - m_contentX, m_textTop - m_contentY, height())) {
        // A gentle wave, two pixels from crest to trough.
        QPainterPath wave(QPointF(stretch.x1, stretch.y));
        const qreal step = 2;
        bool up = true;
        for (qreal x = stretch.x1 + step; x < stretch.x2 + step; x += step, up = !up)
            wave.lineTo(qMin(x, stretch.x2), stretch.y + (up ? -1 : 1));
        painter->drawPath(wave);
    }
}
