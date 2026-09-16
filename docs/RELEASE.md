# Windows 发布与版本提示

## 客户端体验

标题栏右侧“版本与更新”提供当前版本、检查结果、更新说明和 GitHub Releases 页面入口。有新版本时显示提示点，不强制弹窗。每天后台检查一次，可在弹窗关闭自动检查；用户也可主动检查。程序不下载安装包、不执行安装器、不替换自身文件。

使用公共 GitHub API `/repos/shimamuraDS/SakuraChat/releases/latest`，不携带聊天账号、令牌、联系人或消息，只发送应用版本 User-Agent。GitHub 仍会看到正常网络请求的 IP 等连接信息。无需在客户端放置 GitHub Token；仓库或 Releases 不公开时只提示暂未找到公开版本。

只接受正式版本 `1.2.3` 或 `v1.2.3`，按数值比较而非字符串比较，忽略 draft/prerelease。更新说明作为纯文本展示；打开的地址由固定仓库及已校验的版本标签构造，不执行发布说明里的链接。网络超时 10 秒、响应上限 1 MiB；手动检查至少间隔一分钟，403/429 冷却一小时，失败不影响聊天。检查偏好保存到独立的当前用户注册表键，不改变聊天数据路径。

## 构建版本

`SAKURA_RELEASE_VERSION` 同时用于客户端版本显示与 Windows 文件版本；发布标签必须匹配。`SAKURA_GITHUB_REPOSITORY` 默认从本项目仓库确定为 `shimamuraDS/SakuraChat`。配置示例：

```powershell
cmake -S . -B build-release -G Ninja -DCMAKE_BUILD_TYPE=Release -DSAKURA_RELEASE_VERSION=1.0.0 -DCMAKE_PREFIX_PATH='<Qt 6.8.3 MinGW目录>'
```

开发构建仍读取现有 config.ini。正式分发使用 `SAKURA_DISTRIBUTION=ON`，要求 Windows Release 和有效 HTTPS 网关。生产网关编译进客户端，不允许旁置 config.ini 降级为开发 HTTP。生产局域网功能只执行安装目录的 openssl.exe；开发构建保留原有工具查找方式。

## 签名安装包

1. 复制 `release/settings.example.json` 为 `release/settings.local.json`，填写版本、正式 HTTPS 网关、发布者、代码签名证书指纹、时间戳服务及对应源码地址。私钥与密码不要写入 JSON。
2. 准备固定版本的 OpenSSL 3 工具、其依赖、Rust MSVC 桥接所需运行库；将每个文件的名称和 SHA256 写入 `dependencyFiles`。固定 Qt、MinGW、Rust 工具链，不能从用户机器的 PATH 临时拼凑运行依赖。
3. 准备审查后的许可证目录，仅包含 .txt/.md，必须有 `THIRD_PARTY_NOTICES.txt`，包括 Qt、libsignal、OpenSSL、编译器运行库等要求的声明。确认 libsignal AGPLv3 及应用整体的对应源码义务后设置 `licenseReviewComplete=true`。
4. 安装 Inno Setup 6、Windows SDK SignTool，使用当前用户证书存储中的正式代码签名证书。
5. 运行：

```powershell
./tools/build-release.ps1 -SettingsPath ./release/settings.local.json `
  -QtRoot '<Qt MinGW目录>' -MinGWBin '<MinGW bin目录>' `
  -DependencyDirectory '<已校验依赖目录>' -LicenseDirectory '<许可证目录>' `
  -CMake '<cmake.exe>' -Cargo '<cargo.exe>' -SignTool '<signtool.exe>' -ISCC '<ISCC.exe>'
```

脚本先校验发布条件，再创建唯一 release-output 目录，分别进行 Qt/Rust Release 构建与测试、windeployqt 部署、依赖哈希核验、应用及桥接签名、Inno 安装器/卸载器签名。生成文件清单与 SHA256；不会自动上传或发布。默认安装到当前用户 Programs/SakuraChat，不要求管理员权限，安装器要求退出正在使用的客户端。不会删除 AppLocalDataLocation 中的聊天数据、应用锁或身份密钥，也不自动启动安装后的程序。

尚无生产网关、签名证书、依赖及许可证材料时，正式打包会明确失败。版本提示本身无需这些材料，不受影响。现有 appSakuraChat 数据目录和账号/网关环境绑定保持不变；将 localhost 数据迁移到生产环境需要单独规划，不能只复制数据库或重建身份。

## 发布与验收

在 GitHub 创建正式 Release，标签使用与构建匹配的 `v主版本.次版本.补丁`，设置为 Latest，填写用户可读更新说明，上传签名安装器、SHA256 清单、许可证声明及相应源码。下载和运行由用户在浏览器与 Windows 中完成。首次安装来源可信与 Windows 签名验证仍然重要，GitHub 版本提示不是安装包安全认证。

必须在无开发环境的干净 Windows 虚拟机验收：普通/局域网/隐私聊天、TLS 与 SQLite 插件、MSVC 运行库、升级后历史与安全码保持、安装中断和磁盘不足、进程占用、卸载后数据保留、版本降级拒绝。当前脚本不能替代这些发布验收；没有实际证书和正式安装包前，不能宣称已完成签名发行测试。

协议状态升级须保持兼容；没有跨版本迁移与恢复验证时不得发布不兼容格式。全量备份含密钥等敏感信息，应单独保护且不得随安装包分发。

参考：[GitHub Releases API](https://docs.github.com/en/rest/releases/releases#get-the-latest-release)、[Qt Windows 部署](https://doc.qt.io/qt-6/windows-deployment.html)、[Inno Setup](https://jrsoftware.org/ishelp/)。
