#include "contactuserlist.h"

ContactUserList::ContactUserList(QObject *parent)
    : QAbstractListModel(parent) {}

int ContactUserList::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_items.size();
}

QVariant ContactUserList::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_items.size())
        return {};
    const auto &item = m_items.at(index.row());
    switch (role) {
    case NameRole:  return item.name;
    case HeadRole:  return item.head;
    case GroupRole: return item.group;
    default:        return {};
    }
}

QHash<int, QByteArray> ContactUserList::roleNames() const {
    return {
        { NameRole,  "name"  },
        { HeadRole,  "head"  },
        { GroupRole, "group" }
    };
}

void ContactUserList::addItem(const QString &name,
                              const QString &head,
                              const QString &group) {
    beginInsertRows({}, m_items.size(), m_items.size());
    m_items.append({ name, head, group });
    endInsertRows();
}

void ContactUserList::clear() {
    beginResetModel();
    m_items.clear();
    endResetModel();
}
