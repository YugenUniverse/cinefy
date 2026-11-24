#pragma once

#include <QString>
#include <QStringList>
#include <QVector>

namespace Csv {

// RFC 4180 parser: quoted fields, doubled quotes, commas and newlines inside
// quotes. A blank line becomes an empty record so callers can detect sections
// (Letterboxd list exports have a metadata block, a blank line, then films).
QVector<QStringList> parse(const QString &text);

// A CSV whose first record is the header.
struct Table {
    QStringList header;
    QVector<QStringList> rows;

    static Table fromRecords(const QVector<QStringList> &records, int headerRow = 0);
    QString value(const QStringList &row, const QString &column) const;
};

} // namespace Csv
