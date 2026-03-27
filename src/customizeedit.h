#ifndef CUSTOMIZEEDIT_H
#define CUSTOMIZEEDIT_H

#include <QObject>

class CustomizeEdit : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString text READ text WRITE setText NOTIFY textChanged)
    Q_PROPERTY(int maxLength READ maxLength WRITE setMaxLength NOTIFY maxLengthChanged)

public:
    explicit CustomizeEdit(QObject *parent = nullptr);

    QString text() const;
    void setText(const QString &text);

    int maxLength() const;
    void setMaxLength(int length);

signals:
    void textChanged(const QString &text);
    void maxLengthChanged(int length);
    void cleared();

public slots:
    void clear();

private:
    QString m_text;
    int m_maxLength = 25;
};

#endif // CUSTOMIZEEDIT_H
