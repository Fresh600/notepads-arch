#pragma once

#include <QQuickImageProvider>

// Serves the line icons in :/icons as image://icon/<name>/<color>, painted
// in any color, so one SVG works on light and dark backgrounds and in the
// Omarchy accent. <color> is a QML color without its leading "#".
class IconProvider : public QQuickImageProvider {
public:
    IconProvider();
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
};
