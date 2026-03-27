#include "chatuserlist.h"

ChatUserList::ChatUserList(QObject *parent) : QAbstractListModel(parent) {}

int ChatUserList::rowCount(const QModelIndex &) const {
    return m_items.count();
}

QVariant ChatUserList::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_items.count())
        return QVariant();

    const ChatUserInfo &info = m_items[index.row()];
    switch (role) {
    case NameRole:    return info.name;
    case HeadRole:    return info.head;
    case LastMsgRole: return info.lastMsg;
    case TimeRole:    return info.time;
    }
    return QVariant();
}

QHash<int, QByteArray> ChatUserList::roleNames() const {
    return {
        {NameRole,    "name"},
        {HeadRole,    "head"},
        {LastMsgRole, "lastMsg"},
        {TimeRole,    "time"}
    };
}

void ChatUserList::addItem(const QString &name, const QString &head,
                           const QString &lastMsg, const QString &time) {
    beginInsertRows(QModelIndex(), m_items.count(), m_items.count());
    m_items.append({name, head, lastMsg, time});
    endInsertRows();
}

void ChatUserList::clear() {
    beginResetModel();
    m_items.clear();
    endResetModel();
}

bool ChatUserList::isLoading() const {
    return m_loading;
}

void ChatUserList::loadMoreItems(int count) {
    if (m_loading) return;

    m_loading = true;
    emit loadingChanged(true);

    qDebug() << "load more chat user";
    for (int i = 0; i < count; ++i) {
        int idx = m_items.count() + 1;
        addItem(
            QString("用户_%1").arg(idx),
            "#5b8ef0",
            "新消息内容...",
            "刚刚"
            );
    }

    m_loading = false;
    emit loadingChanged(false);
}
