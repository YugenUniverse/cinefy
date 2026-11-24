#pragma once

#include "Film.h"

#include <QAbstractListModel>
#include <functional>

class FilmModel;

// One shelf in the shop: a filtered, sorted, optionally capped view of FilmModel.
class AisleModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QString id READ id CONSTANT)
    Q_PROPERTY(QString title READ title CONSTANT)
    Q_PROPERTY(QString subtitle READ subtitle CONSTANT)
    Q_PROPERTY(QString accent READ accent CONSTANT)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
public:
    using Filter = std::function<bool(const Film &)>;
    using Less = std::function<bool(const Film &, const Film &)>;

    AisleModel(FilmModel *source, QString title, QString subtitle, QString accent,
               Filter filter, Less less, int limit, QObject *parent);
    // Fixed order, e.g. a Letterboxd list.
    AisleModel(FilmModel *source, QString title, QString subtitle, QString accent,
               QVector<int> fixedRows, QObject *parent);

    QString id() const { return m_id; }
    void setId(const QString &id) { m_id = id; }
    QString title() const { return m_title; }
    QString subtitle() const { return m_subtitle; }
    QString accent() const { return m_accent; }
    int count() const { return int(m_rows.size()); }
    const QVector<int> &sourceRows() const { return m_rows; }

    void setFilter(Filter filter);
    void rebuild();

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

signals:
    void countChanged();

private:
    void connectSource();
    void onSourceChanged(const QModelIndex &topLeft, const QModelIndex &bottomRight,
                         const QList<int> &roles);

    FilmModel *m_source;
    QString m_id, m_title, m_subtitle, m_accent;
    Filter m_filter;
    Less m_less;
    int m_limit = 0;
    bool m_fixed = false;
    QVector<int> m_rows;
    QHash<int, int> m_sourceToRow;
};
