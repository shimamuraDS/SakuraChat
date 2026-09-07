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
    bool setData(const QModelIndex &index, const QVariant &value, int role) override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void addItem(int uid,
                             const QString &name,
                             const QString &head,
                             const QString &message);
    Q_INVOKABLE void setAdded(int uid);
    Q_INVOKABLE void clear();
private:
    QList<ApplyInfo> m_items;
};
