# 未签名便携测试版

仅限专用测试账号。网关为 `https://sakura-gate.viphk.nnhk.cc`，证书正常验证，不跟随 HTTP 重定向。聊天允许明文 TCP，因此登录令牌和普通聊天内容仍可能被截获、篡改；Signal 消息加密不能消除此风险。

## 连接与数据

- 节点一：`viphk.nnhk.cc:25890`。
- 节点二：`free.idcfengye.com:25891`。
- 服务端若分配 `localhost`、`127.0.0.1` 或 `::1` 的 `8090` / `8091`，按节点映射到上述公网端点；其他地址拒绝连接。
- 地址编译进测试构建，旁置 `config.ini` 不改变它们。
- 使用 `SakuraChat-InsecureTest` 应用数据目录，不读取正常版的本地账号数据。便携指无需安装；本地记录仍保存在 Windows 用户数据目录，并非 ZIP 解压目录。关闭程序不会自动删除记录。
- 启动时提示风险，窗口底部持续显示标识。没有自动下载或安装功能。

## 构建

在 Qt 6.8.3 MinGW 64-bit 环境下使用 PowerShell：

```powershell
cmake -S . -B release-output/test-build -G Ninja `
  '-DCMAKE_BUILD_TYPE=Release' '-DSAKURA_INSECURE_TEST=ON' `
  '-DSAKURA_RELEASE_VERSION=0.1.1' '-DCMAKE_PREFIX_PATH=<Qt目录>'
cmake --build release-output/test-build --target appSakuraChat testbuildpolicy_tests
cargo build --release --locked --manifest-path crypto/signal-bridge/Cargo.toml
```

`SAKURA_INSECURE_TEST` 默认关闭，不能与 `SAKURA_DISTRIBUTION` 同时开启，不能生成 Debug 测试包。正常版仍保持原有本机开发连接与正式 TLS 限制。

仅从新建空目录打包 `appSakuraChat.exe`、Release Signal 桥接 DLL、windeployqt 部署文件、OpenSSL 及必需的 MSVC 运行库。不要复制数据库、配置、私钥、日志或整个开发构建目录。

使用 `windeployqt --release --no-translations --no-opengl-sw --no-system-d3d-compiler --skip-plugin-types platforminputcontexts,qmltooling,sqldrivers --qmldir qml --compiler-runtime <EXE>`，并单独部署 Qt 的 `plugins/sqldrivers/qsqlite.dll`。要求 Windows 10/11 x64；不包含未使用的数据库插件、软件 OpenGL 回退和虚拟键盘。

`tools/package-insecure-test.ps1` 接收构建目录、Qt/MinGW 路径、OpenSSL 运行目录、可再分发的 VCRUNTIME140.dll、许可证目录和全新输出目录；校验构建开关后生成 ZIP 与逐文件清单，不自动发布。许可证目录需包含对应 Qt 模块的 LICENSES、第三方归属声明、Rust 依赖许可、OpenSSL 和 Microsoft 运行库许可。各依赖对应源码需随 Release 提供。

GitHub 版本标记必须是 Pre-release，例如 `v0.1.1-insecure-test.1`，不标记 Latest。随包提供第三方许可、对应源码和 SHA256；没有 Windows 发布者签名，SHA256 只能校验下载完整性，不能替代发布者签名。

## 验证范围

发布前运行固定端点策略（普通与测试两种构建）、版本检测、Signal 协议、私聊传输、引擎与控制器测试；使用不含 Qt/编译器的 PATH 启动便携包验证依赖。

没有提供测试账号时，不能宣称完成公网注册、登录、收发的端到端验收。无开发环境虚拟机与不同电脑之间的实测仍需执行。
