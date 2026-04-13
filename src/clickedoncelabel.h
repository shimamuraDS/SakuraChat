#pragma once
#include <QQuickItem>

class ClickedOnceLabel : public QQuickItem {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString text READ text WRITE setText NOTIFY textChanged)
    Q_PROPERTY(bool clicked READ isClicked NOTIFY clickedOnce)
public:
    explicit ClickedOnceLabel(QQuickItem *parent = nullptr);
    QString text() const;
    void setText(const QString &t);
    bool isClicked() const;
signals:
    void textChanged();
    void clickedOnce(const QString &text);
protected:
    void mousePressEvent(QMouseEvent *event) override;
private:
    QString m_text;
    bool m_clicked = false;
};
