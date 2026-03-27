#include "customizeedit.h"

CustomizeEdit::CustomizeEdit(QObject *parent) : QObject(parent) {}

QString CustomizeEdit::text() const { return m_text; }

void CustomizeEdit::setText(const QString &text) {
    QString limited = text.left(m_maxLength);
    if (m_text != limited) {
        m_text = limited;
        emit textChanged(m_text);
    }
}

int CustomizeEdit::maxLength() const { return m_maxLength; }

void CustomizeEdit::setMaxLength(int length) {
    if (m_maxLength != length) {
        m_maxLength = length;
        emit maxLengthChanged(m_maxLength);
    }
}

void CustomizeEdit::clear() {
    if (!m_text.isEmpty()) {
        m_text.clear();
        emit textChanged(m_text);
        emit cleared();
    }
}
