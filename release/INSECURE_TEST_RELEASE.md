# SakuraChat 0.1.1 · 未签名网络测试版

**仅使用专用测试账号，不可用于真实隐私通信。**

下载 `SakuraChat-0.1.1-insecure-test.1-windows-x64.zip`，完整解压后运行 `appSakuraChat.exe`。需要 Windows 10/11 x64，无需安装 Qt 或编译器。

## 网络与风险

- HTTPS 网关：`https://sakura-gate.viphk.nnhk.cc`。
- 明文 TCP 聊天：`viphk.nnhk.cc:25890`、`free.idcfengye.com:25891`。
- 聊天连接未启用 TLS，账号令牌和普通消息可能被截获或篡改。Signal 消息加密不能消除令牌泄露风险。
- 此包没有 Windows 代码签名；可能出现未知发布者提示。不要求关闭任何系统安全软件。
- 固定测试端点，仅在独立测试构建启用。正式版的 HTTPS/TLS 规则不变。

## 使用说明

- 启动时需确认风险，窗口底部持续显示测试标识。
- 测试记录使用独立的 `SakuraChat-InsecureTest` 用户数据目录，不与正常版共用本地账号数据。删除解压目录不会自动清理本地记录。
- 不自动下载、安装或替换客户端；此 Pre-release 不作为正式更新推送。
- `SHA256SUMS.txt` 用于检查文件完整性，不能替代发布者签名。

## 验证与源码

已完成 Release 构建、固定端点策略（正常/测试构建）、版本检查、Signal 协议、隐私聊天传输/引擎/控制器测试，以及清洁 PATH 下的便携启动检查。

**尚未使用测试账号完成公网登录和双客户端收发验收，也未在干净虚拟机上完成安装环境验收。**

同页附带客户端与 Rust 依赖源码包、Qt 对应源码、OpenSSL 源码及逐文件清单。第三方许可和归属声明位于便携包的 `licenses/` 与 `THIRD_PARTY_NOTICES.txt`。源码包中的 `SOURCE_BUILD.md` 提供构建说明。
