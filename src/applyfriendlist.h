#pragma once
#include <QAbstractListModel>
#include <QObject>
#include <QtQml/qqml.h>

struct ApplyInfo {
    int     uid;
    QString name;
    QString head;
    QString message;   // 申请附言
    bool    isAdded;   // 是否已添加
};

class ApplyFriendList : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT

public:
    enum ApplyRoles {
        UidRole     = Qt::UserRole + 1,
        NameRole,
        HeadRole,
        MessageRole,
        IsAddedRole
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
