SakuraChat — Windows x64 便携版

解压整个目录，运行 appSakuraChat.exe。不要单独移动 EXE 或 DLL。
此版本未使用 Windows 代码签名，系统可能显示“未知发布者”。
请仅从 https://github.com/shimamuraDS/SakuraChat/releases 下载，并核对 SHA256SUMS.txt。
SHA256 用于完整性核对，不代替发布者签名。

网关：https://47.105.85.58:8443
客户端内置服务器公有 CA，强制验证证书及服务器身份。
网关使用 HTTPS，普通聊天连接使用 TLS，不允许公网明文回退。
无需修改 config.ini，也无需将 CA 安装到 Windows 系统证书库。
CA 证书不是 Windows 代码签名证书。

普通聊天保存在云端，不是端到端加密；隐私对话使用 Signal 协议。
账号缓存与隐私密钥仍保存在当前 Windows 用户的应用数据目录中，
不是保存在解压目录。请勿跨用户复制密钥或删除应用数据来“升级”。
旧测试版的独立数据不会自动导入，隐私身份变化时应重新核对安全码。

版本与更新仅检查 GitHub Releases 并提示，不自动下载或安装。
升级前退出客户端，将新版本解压到新目录。许可证见 licenses 与
THIRD_PARTY_NOTICES.txt；对应源代码随 GitHub Release 提供。
