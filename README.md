# 🌸 SakuraChat 

![Qt Version](https://img.shields.io/badge/Qt-6.8-41CD52?logo=qt&logoColor=white)
![C++](https://img.shields.io/badge/C++-17%2B-00599C?logo=c%2B%2B&logoColor=white)
![CMake](https://img.shields.io/badge/CMake-3.16%2B-064F8C?logo=cmake&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue.svg)

SakuraChat 是一个基于 **Qt 6.8 (C++ & QML)** 构建的现代即时通讯应用。项目采用极致的前后端分离架构，通过 QML 实现媲美原生应用的现代化 UI 与流畅交互，底层依托 C++ 提供高性能的网络通信与数据处理能力。

## ✨ 核心特性

### 🎨 现代化的用户体验 (UI/UX)
* **Telegram 视觉风格**：深蓝侧边栏 + 白色面板 + 浅蓝灰气泡，提供干净、专业的视觉体验。
* **声明式流畅动画**：广泛使用 `Behavior` 与状态机实现平滑的颜色过渡、按钮缩放与悬浮反馈，无需繁琐的 C++ 重写。
* **实时表单验证机制**：内置于 QML 的智能表单系统，支持输入防抖、正则表达式校验、密码强度检测，并提供友好的动态错误提示。
* **自定义精美组件**：高度定制的滚动条、带动画的倒计时按钮（验证码功能）、自适应消息气泡及状态切换标签。

### ⚡ 纯粹的 Qt 6 现代架构
* **告别手动注册**：全面拥抱 `QML_ELEMENT` 与 `QML_SINGLETON` 宏，利用 CMake 的 `qt_add_qml_module` 实现 C++ 与 QML 类型的自动扫描与注册。
* **彻底的关注点分离**：完全摒弃传统 Qt Widgets 的强耦合。C++ 专职处理 TCP/HTTP 通信与状态机，QML 专职处理渲染与交互。
* **单例配置管理**：引入线程安全的 `ConfigManager` 全局配置管理器，杜绝全局变量滥用。

### 🌐 健壮的网络与通信机制
* **HTTP/TCP 双链路协同**：HTTP 用于高并发的注册/登录/重置鉴权，TCP 长连接保障低延迟的即时消息推送。
* **异步与线程安全**：基于 `HttpMgr` 的非阻塞网络请求与 `TcpMgr` 线程安全的数据发送队列。

## 📸 界面预览

> **[TODO: 在此处放置 2-3 张项目的截图，例如：登录/注册界面、聊天主界面等]**
> *示例：`![聊天界面](docs/images/chat_preview.png)`*

## 🏗️ 架构概览

### 网络通信时序 (登录到聊天)
```text
[QML 登录界面]             [C++ LoginController]           [C++ TcpMgr]
      |                             |                           |
      | 1. 发起登录 (HTTP)          |                           |
      |---------------------------->|                           |
      |                             | 2. HTTP 请求鉴权          |
      | 3. HTTP 登录成功反馈        |-------------------------> [Gate Server]
      |<----------------------------|                           |
      |                             |                           |
      |                             | 4. 触发 TCP 连接          |
      |                             |-------------------------> [Chat Server]
      |                             |                           |
      |                             | 5. TCP 连接成功           |
      |                             |<--------------------------|
      |                             |                           |
      |                             | 6. 发送 Chat Token (TCP)  |
      |                             |-------------------------> [Chat Server]
      | 7. 切换至聊天界面 (ChatDialog)|                           |
      |<--------------------------------------------------------|
````

## 🚀 快速开始

### 前置依赖

  * [Qt 6.8](https://www.qt.io/download) 或更高版本 (需安装 Qt Quick 模块)
  * [CMake 3.16](https://cmake.org/download/) 或更高版本
  * 支持 C++17 的编译器 (MSVC / GCC / Clang)

### 编译与运行

```bash
# 1. 克隆仓库
git clone [https://github.com/yourusername/SakuraChat.git](https://github.com/yourusername/SakuraChat.git)
cd SakuraChat

# 2. 创建构建目录
mkdir build && cd build

# 3. 生成构建文件并编译
cmake ..
cmake --build .

# 4. 运行应用
./appSakuraChat
```

*注：在 Windows Release 模式下，CMake 会自动将 `config.ini` 拷贝到输出目录。*

## 📁 核心目录结构

```text
SakuraChat/
├── CMakeLists.txt         # 现代 Qt6 QML 模块化构建配置
├── config.ini             # 全局网络及网关配置文件
├── src/                   # C++ 后端核心逻辑
│   ├── httpmgr.* # HTTP 异步通信层
│   ├── tcpmgr.* # TCP 长连接与消息处理层
│   ├── *controller.* # 业务控制器 (登录/注册/重置)
│   ├── chatuserlist.* # 聊天用户列表 Model (QAbstractListModel)
│   └── configmanager.* # 配置项解析与管理
└── qml/                   # QML 前端界面
    ├── Main.qml           # 全局路由与窗口管理
    ├── *Dialog.qml        # 核心功能视图 (登录/注册/重置/聊天)
    ├── MessageBubble.qml  # 自定义消息气泡组件
    ├── TimerButton.qml    # 自定义倒计时按钮 (验证码)
    └── ...                # 其他自定义 UI 组件
```

## 🤝 贡献指南

欢迎提交 Pull Request 或 Issue 探讨问题！

1.  Fork 本项目
2.  创建您的特性分支 (`git checkout -b feature/AmazingFeature`)
3.  提交您的更改 (`git commit -m 'Add some AmazingFeature'`)
4.  推送到分支 (`git push origin feature/AmazingFeature`)
5.  开启一个 Pull Request

## 📄 许可证

本项目采用 [MIT License](https://www.google.com/search?q=LICENSE) 开源协议。
