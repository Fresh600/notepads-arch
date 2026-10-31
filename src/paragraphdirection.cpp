#include "paragraphdirection.h"

#include <QTextBlock>
#include <QTextCursor>
#include <QTimer>

ParagraphDirection::ParagraphDirection(QTextDocument *document) : QObject(document), m_document(document) {
    // Changing a block inside contentsChange would edit the document while
    // it is still reporting the edit, so the work waits for the event loop.
    connect(document, &QTextDocument::contentsChange, this, &ParagraphDirection::schedule);
}

Qt::LayoutDirection ParagraphDirection::directionOf(const QString &text) {
    for (const QChar c : text) {
        switch (c.direction()) {
        case QChar::DirL:
            return Qt::LeftToRight;
        case QChar::DirR:
        case QChar::DirAL:
            return Qt::RightToLeft;
        default:
            break;
        }
    }
    return Qt::LayoutDirectionAuto;
}

namespace {

// A block with no strong character continues the paragraph before it, so
// an empty line under Hebrew keeps the cursor on the right.
Qt::LayoutDirection wantedDirection(const QTextBlock &block, Qt::LayoutDirection previous) {
    const Qt::LayoutDirection own = ParagraphDirection::directionOf(block.text());
    if (own != Qt::LayoutDirectionAuto)
        return own;
    return previous == Qt::LayoutDirectionAuto ? Qt::LeftToRight : previous;
}

int apply(QTextDocument *document, int from, int to, bool joinUndo) {
    QTextBlock block = document->findBlock(qMax(0, from));
    if (!block.isValid())
        return 0;
    const QTextBlock last = document->findBlock(qMax(0, to));

    QTextBlock before = block.previous();
    Qt::LayoutDirection previous = before.isValid() ? before.blockFormat().layoutDirection() : Qt::LayoutDirectionAuto;

    int changed = 0;
    bool editing = false;
    QTextCursor cursor(document);
    bool pastRange = false;
    for (; block.isValid(); block = block.next()) {
        if (pastRange && ParagraphDirection::directionOf(block.text()) != Qt::LayoutDirectionAuto)
            break;
        const Qt::LayoutDirection wanted = wantedDirection(block, previous);
        if (block.blockFormat().layoutDirection() != wanted) {
            if (!editing) {
                if (joinUndo && document->isUndoAvailable())
                    cursor.joinPreviousEditBlock();
                else
                    cursor.beginEditBlock();
                editing = true;
            }
            cursor.setPosition(block.position());
            QTextBlockFormat format = block.blockFormat();
            format.setLayoutDirection(wanted);
            cursor.setBlockFormat(format);
            ++changed;
        } else if (pastRange) {
            break;
        }
        previous = wanted;
        if (block == last)
            pastRange = true;
    }
    if (editing)
        cursor.endEditBlock();
    return changed;
}

}

int ParagraphDirection::update(QTextDocument *document, int from, int to) {
    if (!document)
        return 0;
    // A direction is layout, not content: it must not make a saved file
    // look edited.
    const bool wasModified = document->isModified();
    const int changed = apply(document, from, to, true);
    if (changed && !wasModified)
        document->setModified(false);
    return changed;
}

void ParagraphDirection::updateAll(QTextDocument *document) {
    if (!document)
        return;
    const bool wasModified = document->isModified();
    if (apply(document, 0, document->characterCount(), false)) {
        document->clearUndoRedoStacks();
        document->setModified(wasModified);
    }
}

void ParagraphDirection::schedule(int position, int removed, int added) {
    Q_UNUSED(removed);
    const int end = position + added;
    m_from = m_from < 0 ? position : qMin(m_from, position);
    m_to = qMax(m_to, end);
    if (!m_scheduled) {
        m_scheduled = true;
        QTimer::singleShot(0, this, &ParagraphDirection::process);
    }
}

void ParagraphDirection::process() {
    m_scheduled = false;
    const int from = m_from, to = m_to;
    m_from = m_to = -1;
    if (m_document)
        update(m_document, from, qMin(to, m_document->characterCount() - 1));
}
