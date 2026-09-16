#include "messagelistmodel.h"

QString MessageListModel::key(const QVariant &row) {
    const auto item = row.toMap();
    return item.value("senderUid").toString() + ':' + item.value("msgid").toString();
}
QVariant MessageListModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= rows_.size() || role != Qt::UserRole) return {};
    return rows_.at(index.row());
}
void MessageListModel::setRows(const QVariantList &rows) {
    if (rows_ == rows) return;
    // Preserve delegates (and their visibility dwell timers) for existing messages.
    for (int i = 0; i < rows.size(); ++i) {
        int found = i;
        while (found < rows_.size() && key(rows_[found]) != key(rows[i])) ++found;
        if (found == rows_.size()) {
            beginInsertRows({}, i, i); rows_.insert(i, rows[i]); endInsertRows();
        } else {
            if (found != i) {
                beginMoveRows({}, found, found, {}, i); rows_.move(found, i); endMoveRows();
            }
            if (rows_[i] != rows[i]) {
                rows_[i] = rows[i]; emit dataChanged(index(i), index(i), {Qt::UserRole});
            }
        }
    }
    if (rows_.size() > rows.size()) {
        beginRemoveRows({}, rows.size(), rows_.size() - 1);
        rows_.erase(rows_.begin() + rows.size(), rows_.end()); endRemoveRows();
    }
    emit rowsChanged();
}
