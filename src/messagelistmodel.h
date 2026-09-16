#pragma once
#include <QAbstractListModel>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class MessageListModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QVariantList rows READ rows WRITE setRows NOTIFY rowsChanged)
public:
    explicit MessageListModel(QObject *parent = nullptr) : QAbstractListModel(parent) {}
    int rowCount(const QModelIndex &parent = {}) const override { return parent.isValid() ? 0 : rows_.size(); }
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override { return {{Qt::UserRole, "modelData"}}; }
    QVariantList rows() const { return rows_; }
    void setRows(const QVariantList &rows);
signals:
    void rowsChanged();
private:
    static QString key(const QVariant &row);
    QVariantList rows_;
};
