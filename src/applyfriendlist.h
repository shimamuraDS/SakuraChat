#pragma once
#include <QAbstractListModel>
#include <QObject>
#include <QtQml/qqml.h>

struct ApplyInfo {
    qint64 applyId = 0;
    int uid = 0;
    QString name;
    QString head;
    QString message;   // 申请附言
    int status = 0;  // 0待处理，1同意，2拒绝，3撤销
};

class ApplyFriendList : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int pendingCount READ pendingCount NOTIFY pendingCountChanged)

public:
    enum ApplyRoles {
        ApplyIdRole = Qt::UserRole + 1,
        UidRole,
        NameRole,
        HeadRole,
        MessageRole,
        StatusRole
    };

    explicit ApplyFriendList(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;
    int pendingCount() const;

    Q_INVOKABLE void upsertItem(const QVariantMap &application);
    Q_INVOKABLE void setStatus(qint64 applyId, int status);
    Q_INVOKABLE void replaceAll(const QVariantList &applications);
    Q_INVOKABLE void clear();

signals:
    void pendingCountChanged();

private:
    // 把网络传来的 QVariantMap 转成一条申请记录
    static bool parseItem(const QVariantMap &application, ApplyInfo &item);
    QList<ApplyInfo> m_items;
};
