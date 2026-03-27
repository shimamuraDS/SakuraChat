#ifndef CHATUSERLIST_H
#define CHATUSERLIST_H

#include <QAbstractListModel>
#include <QList>
#include <QtQml/qqml.h>

struct ChatUserInfo {
    QString name;
    QString head;
    QString lastMsg;
    QString time;
};

class ChatUserList : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        HeadRole,
        LastMsgRole,
        TimeRole
    };

    explicit ChatUserList(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void addItem(const QString &name, const QString &head,
                             const QString &lastMsg, const QString &time);
    Q_INVOKABLE void clear();
    Q_INVOKABLE void loadMoreItems(int count = 10);
    Q_INVOKABLE bool isLoading() const; // 防重入锁查询
signals:
    void loadingChanged(bool loading);

private:
    QList<ChatUserInfo> m_items;
    bool m_loading = false;
};

#endif // CHATUSERLIST_H
