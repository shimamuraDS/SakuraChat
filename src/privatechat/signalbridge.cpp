#include "signalbridge.h"
#include <QCoreApplication>
#include <limits>

SignalBridge::SignalBridge()
    : library_(QCoreApplication::applicationDirPath() + "/sakura_signal_bridge") {
    if (!library_.load()) return;
    auto version = reinterpret_cast<Version>(library_.resolve("sakura_signal_abi_version"));
    if (!version || version() != 1) return;
    call_ = reinterpret_cast<Call>(library_.resolve("sakura_signal_call"));
    free_ = reinterpret_cast<Free>(library_.resolve("sakura_signal_free"));
}
bool SignalBridge::available() const { return call_ && free_; }
QByteArray SignalBridge::execute(const QByteArray &request) const {
    if (!available() || request.isEmpty() || request.size() > 16 * 1024 * 1024) return {};
    Buffer response{};
    const auto result = call_(reinterpret_cast<const unsigned char *>(request.constData()),
                              static_cast<size_t>(request.size()), &response);
    QByteArray bytes;
    if (result == 0 && response.data && response.len <= static_cast<size_t>(std::numeric_limits<int>::max()))
        bytes = QByteArray(reinterpret_cast<const char *>(response.data), static_cast<int>(response.len));
    if (response.data) free_(response);
    return bytes;
}
