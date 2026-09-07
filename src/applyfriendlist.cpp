#include "applyFriendList.h"

ApplyFriendList::ApplyFriendList(QObject *parent) : QAbstractListModel(parent) {}

int ApplyFriendList::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return static_cast<int>(m_items.size());
}

QVariant ApplyFriendList::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.model() != this || index.column() != 0 || index.row() < 0 || index.row() >= m_items.size())
        return {};
    const auto &item = m_items.at(index.row());
    switch (role) {
        case ApplyIdRole: return QVariant::fromValue(item.applyId);
        case UidRole:     return item.uid;
        case NameRole:    return item.name;
        case HeadRole:    return item.head;
        case MessageRole: return item.message;
        case StatusRole:  return item.status;
        default:          return {};
    }
}

QHash<int, QByteArray> ApplyFriendList::roleNames() const {
    return {
        { ApplyIdRole, "applyId" },
        { UidRole,     "uid"     },
        { NameRole,    "name"    },
        { HeadRole,    "head"    },
        { MessageRole, "message" },
        { StatusRole,  "status" }
    };
}

bool ApplyFriendList::parseItem(
    const QVariantMap &application, ApplyInfo &item)
{
    bool idOk = false;
    bool uidOk = false;
    bool statusOk = false;

    item.applyId = application.value("applyId").toLongLong(&idOk);
    item.uid = application.value("uid").toInt(&uidOk);
    item.status = application.value("status", 0).toInt(&statusOk);

    if (!idOk || item.applyId <= 0 ||
        !uidOk || item.uid <= 0 ||
        !statusOk || item.status < 0 || item.status > 3) {
        return false;
    }

    item.name = application.value("name").toString();
    item.head = application.value("head").toString();
    item.message = application.value("message").toString();

    return true;
}

void ApplyFriendList::upsertItem(const QVariantMap &application)
{
    ApplyInfo item;
    if (!parseItem(application, item))
        return;

    // 相同 applyId 已经存在：更新该行
    for (int row = 0; row < rowCount(); ++row) {
        if (m_items.at(row).applyId != item.applyId)
            continue;

        m_items[row] = item;

        const QModelIndex changedIndex = index(row, 0);
        emit dataChanged(changedIndex, changedIndex, {
                                                         UidRole, NameRole, HeadRole, MessageRole, StatusRole
                                                     });
        emit pendingCountChanged();
        return;
    }

    // 没有相同 applyId：插入新行
    const int row = rowCount();
    beginInsertRows(QModelIndex(), row, row);
    m_items.append(item);
    endInsertRows();

    emit pendingCountChanged();
}

void ApplyFriendList::setStatus(qint64 applyId, int status)
{
    if (applyId <= 0 || status < 0 || status > 3)
        return;

    for (int row = 0; row < rowCount(); ++row) {
        auto &item = m_items[row];

        if (item.applyId != applyId)
            continue;

        if (item.status == status)
            return;

        item.status = status;

        const QModelIndex changedIndex = index(row, 0);
        emit dataChanged(changedIndex, changedIndex, { StatusRole });
        emit pendingCountChanged();
        return;
    }
}

void ApplyFriendList::replaceAll(const QVariantList &applications)
{
    QList<ApplyInfo> newItems;
    QHash<qint64, int> rowsById;

    // 先转换数据，并消除快照中的重复 applyId
    for (const auto &value : applications) {
        ApplyInfo item;
        if (!parseItem(value.toMap(), item))
            continue;

        const auto it = rowsById.constFind(item.applyId);

        if (it != rowsById.cend()) {
            newItems[it.value()] = item;
        } else {
            rowsById.insert(
                item.applyId, static_cast<int>(newItems.size()));
            newItems.append(item);
        }
    }

    beginResetModel();
    m_items.swap(newItems);
    endResetModel();

    emit pendingCountChanged();
}

void ApplyFriendList::clear() {
    beginResetModel();
    m_items.clear();
    endResetModel();
}

int ApplyFriendList::pendingCount() const
{
    int count = 0;

    for (const auto &item : m_items) {
        if (item.status == 0)
            ++count;
    }

    return count;
}
