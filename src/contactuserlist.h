#pragma once
#include <QAbstractListModel>
#include <QObject>
#include <QtQml/qqml.h>

struct ContactUserInfo {
    QString name;
    QString head;    // 头像首字母或本地路径
    QString group;   // 分组首字母
};

class ContactUserList : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT

public:
    enum ContactRoles {
        NameRole = Qt::UserRole + 1,
        HeadRole,
        GroupRole
    };

    explicit ContactUserList(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void addItem(const QString &name,
                             const QString &head,
                             const QString &group);
    Q_INVOKABLE void clear();

private:
    QList<ContactUserInfo> m_items;
};
