#include "Csv.h"

namespace Csv {

QVector<QStringList> parse(const QString &input)
{
    QVector<QStringList> rows;
    QStringList row;
    QString field;
    bool inQuotes = false;

    const QStringView text = input.startsWith(QChar(0xFEFF)) ? QStringView(input).mid(1)
                                                              : QStringView(input);
    const qsizetype n = text.size();

    auto endField = [&] {
        row << field;
        field.clear();
    };
    auto endRow = [&] {
        endField();
        if (row.size() == 1 && row.first().isEmpty())
            row.clear();
        rows << row;
        row.clear();
    };

    for (qsizetype i = 0; i < n; ++i) {
        const QChar c = text[i];
        if (inQuotes) {
            if (c == u'"') {
                if (i + 1 < n && text[i + 1] == u'"') {
                    field += u'"';
                    ++i;
                } else {
                    inQuotes = false;
                }
            } else {
                field += c;
            }
            continue;
        }
        if (c == u'"' && field.isEmpty()) {
            inQuotes = true;
        } else if (c == u',') {
            endField();
        } else if (c == u'\r') {
            if (i + 1 < n && text[i + 1] == u'\n')
                ++i;
            endRow();
        } else if (c == u'\n') {
            endRow();
        } else {
            field += c;
        }
    }
    if (!field.isEmpty() || !row.isEmpty())
        endRow();
    return rows;
}

Table Table::fromRecords(const QVector<QStringList> &records, int headerRow)
{
    Table t;
    if (headerRow >= records.size())
        return t;
    t.header = records[headerRow];
    for (int i = headerRow + 1; i < records.size(); ++i) {
        if (!records[i].isEmpty())
            t.rows << records[i];
    }
    return t;
}

QString Table::value(const QStringList &row, const QString &column) const
{
    const int i = header.indexOf(column);
    return (i >= 0 && i < row.size()) ? row[i] : QString();
}

} // namespace Csv
