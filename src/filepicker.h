#pragma once

#include <QList>
#include <QObject>
#include <QUrl>

// Open and save dialogs behind an interface, so tests can inject a fake.
// Follows Omacut (MIT, David Heinemeier Hansson).
class FilePicker : public QObject {
    Q_OBJECT

public:
    explicit FilePicker(QObject *parent = nullptr) : QObject(parent) {}
    virtual ~FilePicker() = default;

    virtual void openFiles(const QString &folder) = 0;
    // The tag comes back with the answer, so the caller knows which tab the
    // chosen path belongs to.
    virtual void saveFile(const QString &suggestedPath, int tag) = 0;

signals:
    void openSelected(const QList<QUrl> &urls);
    void saveSelected(const QUrl &url, int tag);
    void failed(const QString &message);
};
