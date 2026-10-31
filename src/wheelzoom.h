#pragma once

#include <QObject>

// Ctrl+wheel zoom for the whole window.
//
// Caught as the event reaches the window, before Qt Quick hands it to the
// editor's scroll view, which would otherwise take it to scroll. A mouse
// wheel sends 120 per notch; a touchpad sends many small steps, which add
// up so one notch's worth zooms one step either way.
class WheelZoom : public QObject {
    Q_OBJECT

public:
    explicit WheelZoom(QObject *parent = nullptr) : QObject(parent) {}

    // Adds a wheel delta and returns the whole notches it completes.
    int add(int delta);

signals:
    // In percent: +10 per notch up, -10 per notch down.
    void zoomBy(int step);

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    int m_pending = 0;
};
