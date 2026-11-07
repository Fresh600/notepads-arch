#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QProcess>
#include <QTimer>

class Theme : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString accent READ accent NOTIFY changed)
    Q_PROPERTY(QString accentForeground READ accentForeground NOTIFY changed)
    Q_PROPERTY(int radius READ radius NOTIFY changed)
    // The rest of the Omarchy palette, for the "Use Omarchy theme colors"
    // setting, and whether the theme is light or dark.
    Q_PROPERTY(QString mode READ mode NOTIFY changed)
    Q_PROPERTY(QString background READ background NOTIFY changed)
    Q_PROPERTY(QString foreground READ foreground NOTIFY changed)
    // Optional palette entries; empty when the theme doesn't define them.
    Q_PROPERTY(QString selection READ selection NOTIFY changed)
    Q_PROPERTY(QString muted READ muted NOTIFY changed)
    Q_PROPERTY(QString darkBackground READ darkBackground NOTIFY changed)
    Q_PROPERTY(QString lighterBackground READ lighterBackground NOTIFY changed)
    Q_PROPERTY(QString red READ red NOTIFY changed)

public:
    explicit Theme(const QString &currentDirectory = {}, QObject *parent = nullptr, const QString &hyprctl = {});
    ~Theme() override;

    QString accent() const { return m_accent; }
    QString accentForeground() const;
    int radius() const { return m_radius; }
    QString mode() const { return m_mode; }
    QString background() const { return m_background; }
    QString foreground() const { return m_foreground; }
    QString selection() const { return m_selection; }
    QString muted() const { return m_muted; }
    QString darkBackground() const { return m_darkBackground; }
    QString lighterBackground() const { return m_lighterBackground; }
    QString red() const { return m_red; }

    static QString readAccent(const QString &path);
    static QString readColor(const QString &path, const QString &key, const QString &fallback);
    // "light" or "dark": the theme's own mode line, else the background's
    // brightness decides.
    static QString readMode(const QString &path);

signals:
    void changed();

private:
    void reload();
    void refreshRounding();

    QString m_directory;
    QString m_accent = "#FFD60A";
    QString m_mode = "dark";
    QString m_background = "#1e1e1e";
    QString m_foreground = "#e6e6e6";
    QString m_selection, m_muted, m_darkBackground, m_lighterBackground, m_red;
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
    QString m_hyprctl;
    int m_radius = 0;
    QProcess m_roundingProcess;
    QTimer m_roundingPoll, m_roundingTimeout;
};
