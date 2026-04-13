#include "ApplyFriendModel.h"
#include <QDebug>

ApplyFriendModel::ApplyFriendModel(QObject *parent) : QObject(parent) {}

QStringList ApplyFriendModel::selectedTags() const { return m_selectedTags; }
QStringList ApplyFriendModel::allTags()      const { return m_allTags; }
QString ApplyFriendModel::applyMessage()     const { return m_applyMessage; }

void ApplyFriendModel::setApplyMessage(const QString &msg) {
    if (m_applyMessage != msg) {
        m_applyMessage = msg;
        emit applyMessageChanged();
    }
}

void ApplyFriendModel::initDemoTags() {
    m_allTags = {"同学", "同事", "家人", "朋友", "战友", "邻居"};
    emit allTagsChanged();
}

void ApplyFriendModel::addTag(const QString &tag) {
    if (!tag.isEmpty() && !m_selectedTags.contains(tag)) {
        m_selectedTags.append(tag);
        emit selectedTagsChanged();
    }
}

void ApplyFriendModel::removeTag(const QString &tag) {
    if (m_selectedTags.removeOne(tag))
        emit selectedTagsChanged();
}

void ApplyFriendModel::toggleTag(const QString &tag) {
    m_selectedTags.contains(tag) ? removeTag(tag) : addTag(tag);
}

void ApplyFriendModel::confirmApply() {
    qDebug() << "[ApplyFriend] confirm, tags:" << m_selectedTags
             << "msg:" << m_applyMessage;
    emit applyConfirmed();
}

void ApplyFriendModel::cancelApply() {
    qDebug() << "[ApplyFriend] cancelled";
    emit applyCancelled();
}
