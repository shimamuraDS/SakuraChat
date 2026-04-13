#include "applyFriendList.h"

ApplyFriendList::ApplyFriendList(QObject *parent)
    : QAbstractListModel(parent) {}

int ApplyFriendList::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_items.size();
}

QVariant ApplyFriendList::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_items.size()) return {};
    const auto &item = m_items.at(index.row());
    switch (role) {
    case UidRole:     return item.uid;
    case NameRole:    return item.name;
    case HeadRole:    return item.head;
    case MessageRole: return item.message;
    case IsAddedRole: return item.isAdded;
    default:          return {};
    }
}

bool ApplyFriendList::setData(const QModelIndex &index,
                              const QVariant &value, int role) {
    if (!index.isValid()) return false;
    if (role == IsAddedRole) {
        m_items[index.row()].isAdded = value.toBool();
        emit dataChanged(index, index, { IsAddedRole });
        return true;
    }
    return false;
}

QHash<int, QByteArray> ApplyFriendList::roleNames() const {
    return {
        { UidRole,     "uid"     },
        { NameRole,    "name"    },
        { HeadRole,    "head"    },
        { MessageRole, "message" },
        { IsAddedRole, "isAdded" }
    };
}

void ApplyFriendList::addItem(int uid, const QString &name,
                              const QString &head, const QString &message) {
    beginInsertRows({}, m_items.size(), m_items.size());
    m_items.append({ uid, name, head, message, false });
    endInsertRows();
}

void ApplyFriendList::setAdded(int uid) {
    for (int i = 0; i < m_items.size(); ++i) {
        if (m_items[i].uid == uid) {
            m_items[i].isAdded = true;
            auto idx = index(i);
            emit dataChanged(idx, idx, { IsAddedRole });
            return;
        }
    }
}

void ApplyFriendList::clear() {
    beginResetModel();
    m_items.clear();
    endResetModel();
}
