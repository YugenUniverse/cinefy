#include "AisleModel.h"

#include "FilmModel.h"

#include <algorithm>

AisleModel::AisleModel(FilmModel *source, QString title, QString subtitle, QString accent,
                       Filter filter, Less less, int limit, QObject *parent)
    : QAbstractListModel(parent), m_source(source), m_title(std::move(title)),
      m_subtitle(std::move(subtitle)), m_accent(std::move(accent)), m_filter(std::move(filter)),
      m_less(std::move(less)), m_limit(limit)
{
    connectSource();
    rebuild();
}

AisleModel::AisleModel(FilmModel *source, QString title, QString subtitle, QString accent,
                       QVector<int> fixedRows, QObject *parent)
    : QAbstractListModel(parent), m_source(source), m_title(std::move(title)),
      m_subtitle(std::move(subtitle)), m_accent(std::move(accent)), m_fixed(true),
      m_rows(std::move(fixedRows))
{
    connectSource();
    rebuild();
}

void AisleModel::connectSource()
{
    connect(m_source, &QAbstractItemModel::dataChanged, this, &AisleModel::onSourceChanged);
}

void AisleModel::setFilter(Filter filter)
{
    m_filter = std::move(filter);
    rebuild();
}

void AisleModel::rebuild()
{
    beginResetModel();
    const auto &films = m_source->films();
    if (!m_fixed) {
        m_rows.clear();
        for (int i = 0; i < films.size(); ++i) {
            if (m_filter && m_filter(films[i]))
                m_rows << i;
        }
        if (m_less) {
            std::stable_sort(m_rows.begin(), m_rows.end(),
                             [&](int a, int b) { return m_less(films[a], films[b]); });
        }
        if (m_limit > 0 && m_rows.size() > m_limit)
            m_rows.resize(m_limit);
    }
    m_sourceToRow.clear();
    for (int r = 0; r < m_rows.size(); ++r)
        m_sourceToRow.insert(m_rows[r], r);
    endResetModel();
    emit countChanged();
}

int AisleModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_rows.size());
}

QVariant AisleModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_rows.size())
        return {};
    return m_source->data(m_source->index(m_rows[index.row()]), role);
}

QHash<int, QByteArray> AisleModel::roleNames() const
{
    return m_source->roleNames();
}

void AisleModel::onSourceChanged(const QModelIndex &topLeft, const QModelIndex &bottomRight,
                                 const QList<int> &roles)
{
    for (int s = topLeft.row(); s <= bottomRight.row(); ++s) {
        auto it = m_sourceToRow.constFind(s);
        if (it != m_sourceToRow.cend()) {
            const QModelIndex idx = index(*it);
            emit dataChanged(idx, idx, roles);
        }
    }
}
