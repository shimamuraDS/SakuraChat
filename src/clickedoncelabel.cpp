#include "ClickedOnceLabel.h"
#include <QMouseEvent>

ClickedOnceLabel::ClickedOnceLabel(QQuickItem *parent)
    : QQuickItem(parent) {
    setAcceptedMouseButtons(Qt::LeftButton);
}

QString ClickedOnceLabel::text() const { return m_text; }

void ClickedOnceLabel::setText(const QString &t) {
    if (m_text != t) { m_text = t; emit textChanged(); }
}

bool ClickedOnceLabel::isClicked() const { return m_clicked; }

void ClickedOnceLabel::mousePressEvent(QMouseEvent *event) {
    if (!m_clicked) {
        m_clicked = true;
        emit clickedOnce(m_text);
    }
    QQuickItem::mousePressEvent(event);
}
