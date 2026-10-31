#pragma once

#include <QByteArray>
#include <QString>

// Turns file bytes into editor text and back. The editor always holds text
// with "\n" line breaks; the file's own encoding and line ending ride along
// beside it so a save writes the file back the way it was found.
//
// Encodings: "utf-8", "utf-8-bom", "utf-16le", "utf-16be", "latin1".
// Line endings: "lf", "crlf", "cr".
namespace TextCodec {

struct Decoded {
    QString text;
    QString encoding;
    // Empty when the text has no line breaks, so the caller can pick its
    // default instead of guessing.
    QString lineEnding;
    QString error;
};

Decoded decode(const QByteArray &bytes, const QString &forcedEncoding = {});
QByteArray encode(const QString &text, const QString &encoding, const QString &lineEnding);

// The most common line ending in the text, or empty when there is none.
QString detectLineEnding(const QString &text);
QString normalizeLineEndings(const QString &text);

// False when the encoding cannot store every character (Latin-1 and
// emoji, say), so a save can refuse instead of writing question marks.
bool canEncode(const QString &text, const QString &encoding);

bool isKnownEncoding(const QString &encoding);
bool isKnownLineEnding(const QString &lineEnding);

}
