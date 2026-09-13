#include "localprotection.h"
#ifdef Q_OS_WIN
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <wincrypt.h>
#endif

namespace {
const QByteArray magic("SakuraDPAPI1:");
}
bool LocalProtection::isProtected(const QByteArray &data) { return data.startsWith(magic); }
QByteArray LocalProtection::protect(const QByteArray &plain, const QByteArray &context) {
#ifdef Q_OS_WIN
    if (plain.isEmpty() || plain.size() > 1024 * 1024 || context.isEmpty()) return {};
    DATA_BLOB input{DWORD(plain.size()), reinterpret_cast<BYTE *>(const_cast<char *>(plain.constData()))};
    DATA_BLOB entropy{DWORD(context.size()), reinterpret_cast<BYTE *>(const_cast<char *>(context.constData()))};
    DATA_BLOB output{};
    if (!CryptProtectData(&input, L"SakuraChat local payload", &entropy, nullptr, nullptr,
                          CRYPTPROTECT_UI_FORBIDDEN, &output)) return {};
    const QByteArray result = magic + QByteArray(reinterpret_cast<const char *>(output.pbData), output.cbData);
    LocalFree(output.pbData);
    return result;
#else
    Q_UNUSED(plain); Q_UNUSED(context);
    return {}; // Never fall back to plaintext on an unsupported platform.
#endif
}
QByteArray LocalProtection::unprotect(const QByteArray &sealed, const QByteArray &context) {
#ifdef Q_OS_WIN
    if (!isProtected(sealed) || sealed.size() > 2 * 1024 * 1024 || context.isEmpty()) return {};
    auto data = sealed.sliced(magic.size());
    DATA_BLOB input{DWORD(data.size()), reinterpret_cast<BYTE *>(data.data())};
    DATA_BLOB entropy{DWORD(context.size()), reinterpret_cast<BYTE *>(const_cast<char *>(context.constData()))};
    DATA_BLOB output{};
    if (!CryptUnprotectData(&input, nullptr, &entropy, nullptr, nullptr,
                            CRYPTPROTECT_UI_FORBIDDEN, &output)) return {};
    const QByteArray result(reinterpret_cast<const char *>(output.pbData), output.cbData);
    SecureZeroMemory(output.pbData, output.cbData);
    LocalFree(output.pbData);
    return result;
#else
    Q_UNUSED(sealed); Q_UNUSED(context);
    return {};
#endif
}
