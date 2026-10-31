#include "globalshortcut.h"

#include "backend.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QStandardPaths>

namespace {

const QStringList modifierOrder{"SUPER", "CTRL", "SHIFT", "ALT"};
const QString requireLine = QStringLiteral("pcall(require, \"hypr.notepads\")");

}

GlobalShortcut::GlobalShortcut(const QString &configDirectory, const QString &hyprctl, QObject *parent)
    : QObject(parent),
      // Hyprland reads $XDG_CONFIG_HOME/hypr, as this does.
      m_directory(configDirectory.isEmpty()
                      ? QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + "/hypr"
                      : configDirectory),
      m_hyprctl(!hyprctl.isEmpty() ? hyprctl
                : !qEnvironmentVariableIsEmpty("HYPRLAND_INSTANCE_SIGNATURE")
                    ? QStandardPaths::findExecutable("hyprctl") : QString()) {}

QString GlobalShortcut::normalize(const QString &combo) {
    QStringList modifiers;
    QString key;
    for (QString part : combo.split('+', Qt::SkipEmptyParts)) {
        part = part.trimmed().toUpper();
        if (part == "META" || part == "WIN" || part == "LOGO")
            part = "SUPER";
        if (part == "CONTROL")
            part = "CTRL";
        if (modifierOrder.contains(part)) {
            if (!modifiers.contains(part))
                modifiers.append(part);
        } else if (!part.isEmpty()) {
            if (!key.isEmpty())
                return {};
            key = part;
        }
    }
    if (key.isEmpty() || modifiers.isEmpty())
        return {};
    std::sort(modifiers.begin(), modifiers.end(), [](const QString &a, const QString &b) {
        return modifierOrder.indexOf(a) < modifierOrder.indexOf(b);
    });
    return (modifiers + QStringList{key}).join(" + ");
}

int GlobalShortcut::modmask(const QString &combo) {
    int mask = 0;
    for (const QString &part : normalize(combo).split(" + ")) {
        if (part == "SHIFT") mask |= 1;
        else if (part == "CTRL") mask |= 4;
        else if (part == "ALT") mask |= 8;
        else if (part == "SUPER") mask |= 64;
    }
    return mask;
}

QString GlobalShortcut::displayName(const QString &combo) {
    const QString normalized = normalize(combo);
    if (normalized.isEmpty())
        return {};
    QStringList parts;
    for (const QString &part : normalized.split(" + "))
        parts.append(part.size() > 1 ? part.left(1) + part.mid(1).toLower() : part);
    return parts.join('+');
}

QString GlobalShortcut::bindingFile(const QString &combo) {
    QString text = QStringLiteral(
        "-- Written by Notepads (Settings > Advanced > Global shortcut).\n"
        "-- Change the key there; edits here are replaced the next time it is set.\n");
    const QString normalized = normalize(combo);
    if (!normalized.isEmpty())
        text += QStringLiteral("o.bind(\"%1\", \"Notepads\", { launch = \"notepads\", focus = \"^notepads$\" })\n")
                    .arg(normalized);
    return text;
}

bool GlobalShortcut::ensureRequired(const QString &hyprlandLua, QString *error) {
    QFile file(hyprlandLua);
    if (!file.open(QIODevice::ReadOnly)) {
        if (error)
            *error = tr("Could not read %1.").arg(hyprlandLua);
        return false;
    }
    const QByteArray original = file.readAll();
    file.close();
    if (original.contains(requireLine.toUtf8()))
        return true;

    // Keep a copy of the user's file, as Omarchy does before changing it.
    QFile::copy(hyprlandLua, hyprlandLua + ".bak." + QString::number(QDateTime::currentSecsSinceEpoch()));

    QByteArray updated = original;
    if (!updated.endsWith('\n'))
        updated += '\n';
    // pcall keeps Hyprland's config loading if notepads.lua is ever removed.
    updated += "\n-- Notepads' global shortcut, set in its settings.\n" + requireLine.toUtf8() + "\n";
    const QString failure = Backend::writeAtomically(hyprlandLua, updated);
    if (!failure.isEmpty()) {
        if (error)
            *error = failure;
        return false;
    }
    return true;
}

QString GlobalShortcut::runHyprctl(const QStringList &arguments, bool *ok) const {
    if (ok)
        *ok = false;
    if (m_hyprctl.isEmpty())
        return {};
    QProcess process;
    process.start(m_hyprctl, arguments);
    if (!process.waitForFinished(3000)) {
        process.kill();
        return {};
    }
    if (ok)
        *ok = process.exitStatus() == QProcess::NormalExit && process.exitCode() == 0;
    return QString::fromUtf8(process.readAllStandardOutput());
}

QString GlobalShortcut::conflict(const QString &combo) const {
    const QString normalized = normalize(combo);
    if (normalized.isEmpty())
        return {};
    const QString key = normalized.section(" + ", -1);
    const int mask = modmask(normalized);
    bool ok = false;
    const QString output = runHyprctl({"binds", "-j"}, &ok);
    if (!ok)
        return {};
    for (const QJsonValue &value : QJsonDocument::fromJson(output.toUtf8()).array()) {
        const QJsonObject bind = value.toObject();
        if (bind.value("modmask").toInt() != mask || bind.value("key").toString().toUpper() != key)
            continue;
        const QString description = bind.value("description").toString();
        if (description == "Notepads")
            continue;
        return description.isEmpty() ? bind.value("arg").toString() : description;
    }
    return {};
}

QString GlobalShortcut::apply(const QString &combo) {
    const QString normalized = normalize(combo);
    if (!combo.trimmed().isEmpty() && normalized.isEmpty())
        return tr("A shortcut needs at least one modifier (Super, Ctrl, Alt, or Shift) and a key.");

    const QString hyprlandLua = m_directory + "/hyprland.lua";
    if (!QFileInfo::exists(hyprlandLua))
        return tr("Hyprland's config (%1) was not found, so the shortcut can't be set.").arg(hyprlandLua);

    const QString own = m_directory + "/notepads.lua";
    QString error = Backend::writeAtomically(own, bindingFile(normalized).toUtf8());
    if (!error.isEmpty())
        return error;
    if (!normalized.isEmpty() && !ensureRequired(hyprlandLua, &error))
        return error;

    // Hyprland reloads on its own when its files change; reloading here
    // makes the key work right away and surfaces any config error.
    bool ok = false;
    runHyprctl({"reload"}, &ok);
    if (ok) {
        const QString errors = runHyprctl({"configerrors"}).trimmed();
        if (!errors.isEmpty() && !errors.contains("no errors", Qt::CaseInsensitive))
            return tr("Hyprland reported a config error: %1").arg(errors.left(300));
    }
    return {};
}
