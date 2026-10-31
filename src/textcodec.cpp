#include "textcodec.h"

#include <QCoreApplication>
#include <QStringDecoder>
#include <QStringEncoder>

namespace TextCodec {

namespace {

QString tr(const char *text) {
    return QCoreApplication::translate("TextCodec", text);
}

bool startsWith(const QByteArray &bytes, std::initializer_list<unsigned char> prefix) {
    if (bytes.size() < qsizetype(prefix.size()))
        return false;
    qsizetype i = 0;
    for (unsigned char c : prefix)
        if (static_cast<unsigned char>(bytes.at(i++)) != c)
            return false;
    return true;
}

QString decodeWith(QStringConverter::Encoding encoding, QByteArrayView bytes, bool *failed) {
    QStringDecoder decoder(encoding, QStringConverter::Flag::Stateless);
    QString text = decoder.decode(bytes);
    if (failed)
        *failed = decoder.hasError();
    return text;
}

}

bool isKnownEncoding(const QString &encoding) {
    static const QStringList known{"utf-8", "utf-8-bom", "utf-16le", "utf-16be", "latin1"};
    return known.contains(encoding);
}

bool canEncode(const QString &text, const QString &encoding) {
    if (encoding != "latin1")
        return true;
    for (const QChar c : text)
        if (c.unicode() > 0xFF)
            return false;
    return true;
}

bool isKnownLineEnding(const QString &lineEnding) {
    return lineEnding == "lf" || lineEnding == "crlf" || lineEnding == "cr";
}

QString detectLineEnding(const QString &text) {
    qsizetype crlf = 0, cr = 0, lf = 0;
    for (qsizetype i = 0; i < text.size(); ++i) {
        const QChar c = text.at(i);
        if (c == u'\r') {
            if (i + 1 < text.size() && text.at(i + 1) == u'\n') {
                ++crlf;
                ++i;
            } else {
                ++cr;
            }
        } else if (c == u'\n') {
            ++lf;
        }
    }
    if (crlf == 0 && cr == 0 && lf == 0)
        return {};
    if (crlf >= lf && crlf >= cr)
        return "crlf";
    return lf >= cr ? "lf" : "cr";
}

QString normalizeLineEndings(const QString &text) {
    QString out = text;
    out.replace(QStringLiteral("\r\n"), QStringLiteral("\n"));
    out.replace(u'\r', u'\n');
    return out;
}

Decoded decode(const QByteArray &bytes, const QString &forcedEncoding) {
    Decoded result;
    QString encoding = forcedEncoding;
    QByteArrayView body(bytes);

    // A byte order mark says what the file is; otherwise strict UTF-8 is
    // tried first and Latin-1, which can decode anything, is the fallback.
    if (encoding.isEmpty()) {
        if (startsWith(bytes, {0xEF, 0xBB, 0xBF}))
            encoding = "utf-8-bom";
        else if (startsWith(bytes, {0xFF, 0xFE}))
            encoding = "utf-16le";
        else if (startsWith(bytes, {0xFE, 0xFF}))
            encoding = "utf-16be";
    }

    if ((encoding.isEmpty() || encoding.startsWith("utf-8") || encoding == "latin1")
        && bytes.left(8192).contains('\0')) {
        result.error = tr("This looks like a binary file, so it was not opened.");
        return result;
    }

    bool failed = false;
    if (encoding == "utf-8-bom") {
        if (startsWith(bytes, {0xEF, 0xBB, 0xBF}))
            body = body.sliced(3);
        result.text = decodeWith(QStringConverter::Utf8, body, &failed);
    } else if (encoding == "utf-16le" || encoding == "utf-16be") {
        if (startsWith(bytes, {0xFF, 0xFE}) || startsWith(bytes, {0xFE, 0xFF}))
            body = body.sliced(2);
        result.text = decodeWith(encoding == "utf-16le" ? QStringConverter::Utf16LE : QStringConverter::Utf16BE,
                                 body, &failed);
    } else if (encoding == "latin1") {
        result.text = decodeWith(QStringConverter::Latin1, body, &failed);
    } else if (encoding == "utf-8") {
        result.text = decodeWith(QStringConverter::Utf8, body, &failed);
    } else {
        result.text = decodeWith(QStringConverter::Utf8, body, &failed);
        encoding = "utf-8";
        if (failed) {
            result.text = decodeWith(QStringConverter::Latin1, body, &failed);
            encoding = "latin1";
        }
    }

    result.encoding = encoding;
    result.lineEnding = detectLineEnding(result.text);
    result.text = normalizeLineEndings(result.text);
    return result;
}

QByteArray encode(const QString &text, const QString &encoding, const QString &lineEnding) {
    QString body = normalizeLineEndings(text);
    if (lineEnding == "crlf")
        body.replace(u'\n', QStringLiteral("\r\n"));
    else if (lineEnding == "cr")
        body.replace(u'\n', u'\r');

    if (encoding == "utf-8-bom") {
        QStringEncoder encoder(QStringConverter::Utf8, QStringConverter::Flag::WriteBom);
        return encoder.encode(body);
    }
    if (encoding == "utf-16le" || encoding == "utf-16be") {
        QStringEncoder encoder(encoding == "utf-16le" ? QStringConverter::Utf16LE : QStringConverter::Utf16BE,
                               QStringConverter::Flag::WriteBom);
        return encoder.encode(body);
    }
    if (encoding == "latin1") {
        QStringEncoder encoder(QStringConverter::Latin1);
        return encoder.encode(body);
    }
    return body.toUtf8();
}

}
