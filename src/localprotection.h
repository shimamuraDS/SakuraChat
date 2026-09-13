#pragma once
#include <QByteArray>

namespace LocalProtection {
QByteArray protect(const QByteArray &plain, const QByteArray &context);
QByteArray unprotect(const QByteArray &sealed, const QByteArray &context);
bool isProtected(const QByteArray &data);
}
