#pragma once

#include <QObject>

// The desktop-wide key that opens Notepads (or brings it forward).
//
// Wayland apps can't grab keys outside their own window, so the key is a
// Hyprland binding. Notepads keeps it in a file of its own,
// ~/.config/hypr/notepads.lua, which ~/.config/hypr/hyprland.lua loads with
// one line added the first time. The user's other bindings are never touched.
class GlobalShortcut : public QObject {
    Q_OBJECT

public:
    explicit GlobalShortcut(const QString &configDirectory = {}, const QString &hyprctl = {},
                            QObject *parent = nullptr);

    // Writes the binding and reloads Hyprland. An empty combo removes it.
    // Returns an error message, or an empty string on success.
    Q_INVOKABLE QString apply(const QString &combo);
    // What already uses the combo, from Hyprland's live bindings; empty when
    // it is free or Notepads' own.
    Q_INVOKABLE QString conflict(const QString &combo) const;
    // "SUPER + ALT + N" as people read it: "Super+Alt+N".
    Q_INVOKABLE static QString displayName(const QString &combo);

    // "super+alt+n", "ALT + SUPER + N" -> "SUPER + ALT + N"; empty if the
    // combo has no key or no modifier.
    static QString normalize(const QString &combo);
    static int modmask(const QString &combo);
    static QString bindingFile(const QString &combo);
    static bool ensureRequired(const QString &hyprlandLua, QString *error);

private:
    QString runHyprctl(const QStringList &arguments, bool *ok = nullptr) const;

    QString m_directory;
    QString m_hyprctl;
};
