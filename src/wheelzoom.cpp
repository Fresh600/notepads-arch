#include "wheelzoom.h"

#include <QGuiApplication>
#include <QWheelEvent>
#include <QWindow>

int WheelZoom::add(int delta) {
    // A change of direction starts over, so a reversal responds at once.
    if ((delta > 0 && m_pending < 0) || (delta < 0 && m_pending > 0))
        m_pending = 0;
    m_pending += delta;
    const int notches = m_pending / 120;
    m_pending -= notches * 120;
    return notches;
}

bool WheelZoom::eventFilter(QObject *watched, QEvent *event) {
    // Only the event as it reaches a window; Qt Quick sends it on to items
    // through the application too, and those copies must not count twice.
    if (event->type() != QEvent::Wheel || !qobject_cast<QWindow *>(watched))
        return QObject::eventFilter(watched, event);
    auto *wheel = static_cast<QWheelEvent *>(event);
    // Some setups leave Ctrl off the wheel event itself, so the keyboard's
    // live state counts as well.
    const bool ctrl = wheel->modifiers().testFlag(Qt::ControlModifier)
                      || QGuiApplication::queryKeyboardModifiers().testFlag(Qt::ControlModifier);
    if (!ctrl)
        return QObject::eventFilter(watched, event);
    const int delta = wheel->angleDelta().y() != 0 ? wheel->angleDelta().y() : wheel->pixelDelta().y();
    if (const int notches = add(delta))
        emit zoomBy(notches * 10);
    return true;
}
