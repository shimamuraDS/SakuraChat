#pragma once
#include <QObject>
#include <QStringList>
#include <QtQml>

class ApplyFriendModel : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QStringList selectedTags READ selectedTags NOTIFY selectedTagsChanged)
    Q_PROPERTY(QStringList allTags    READ allTags    NOTIFY allTagsChanged)
    Q_PROPERTY(QString applyMessage  READ applyMessage WRITE setApplyMessage NOTIFY applyMessageChanged)
public:
    explicit ApplyFriendModel(QObject *parent = nullptr);
    QStringList selectedTags() const;
    QStringList allTags() const;
    QString applyMessage() const;
    void setApplyMessage(const QString &msg);
    Q_INVOKABLE void addTag(const QString &tag);
    Q_INVOKABLE void removeTag(const QString &tag);
    Q_INVOKABLE void toggleTag(const QString &tag);
    Q_INVOKABLE void confirmApply();
    Q_INVOKABLE void cancelApply();
    Q_INVOKABLE void initDemoTags();
signals:
    void selectedTagsChanged();
    void allTagsChanged();
    void applyMessageChanged();
    void applyConfirmed();
    void applyCancelled();
private:
    QStringList m_selectedTags;
    QStringList m_allTags;
    QString m_applyMessage;
};
