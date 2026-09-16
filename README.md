# SakuraChat

Qt 6.8 / C++ / QML 桌面聊天客户端，包含云端聊天、加密局域网房间和基于 Signal 协议的隐私对话。三种模式的数据与安全边界不同，详见功能文档。

## 目录

- `src/`：网络、控制器、数据模型与本地存储；`src/privatechat/` 为独立隐私聊天模块。
- `qml/`：界面和交互组件；`res/`：图片等资源。
- `crypto/signal-bridge/`：固定版本 libsignal 的 Rust 桥接及协议测试。
- `tests/`：C++ / QML 测试；`tools/`：构建、测试和打包脚本。
- `cmake/`、`release/`：发布配置与安装器模板。
- `docs/`：功能与开发文档。
- `build/`：本地构建输出，不提交。

## 构建

使用 Qt Creator 打开 `CMakeLists.txt`，选择 Qt 6.8.3 MinGW 64-bit Kit。隐私聊天还需要 Rust MSVC 工具链和构建好的 Signal 桥接，步骤见 [隐私聊天](docs/PRIVATE_CHAT.md) 与 `tools/build-private-chat.ps1`。

开发环境读取 `config.ini`；不要将生产凭据或私钥写入版本库。正式分发使用单独的 Release 配置，见 [打包与版本提示](docs/RELEASE.md)。客户端只检查 GitHub Releases 并提示，不自动下载安装。

## 功能文档

- [聊天记录与已读回执](docs/CHAT_HISTORY_READ_RECEIPTS.md)
- [局域网聊天](docs/LAN_CHAT.md) · [Signal 隐私聊天](docs/PRIVATE_CHAT.md)
- [安全与隐私](docs/SECURITY_PRIVACY.md) · [应用锁](docs/APP_LOCK.md)
- [本地缓存保护](docs/LOCAL_CACHE_PROTECTION.md) · [消息删除](docs/MESSAGE_DELETION.md)
- [通知隐私](docs/PRIVATE_NOTIFICATIONS.md) · [界面设计](docs/UI_REFRESH.md)
- [开发学习笔记](docs/DEVELOPMENT.md)

服务端与跨端教程位于 [SakuraChatServer](https://github.com/shimamuraDS/SakuraChatServer)，教程目录为 `docs/project/`。早期学习笔记不是当前功能验收清单。

分发前需核对 Qt、libsignal 等依赖的许可证及对应源码义务，不能仅以客户端代码的许可推断整个安装包许可。
