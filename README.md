# SakuraChat

## 项目概述

SakuraChat 是一个简洁美观的即时通讯应用，提供用户注册和登录功能。应用采用 Qt Quick 技术构建，具有现代化的用户界面和流畅的交互体验。

## 功能特性

- **用户登录**：通过用户名和密码进行身份验证
- **用户注册**：提供完整的注册流程，包括：
  - 用户名设置
  - 邮箱验证
  - 密码设置与确认
- **界面切换**：在登录和注册界面间无缝切换
- **响应式设计**：适配不同屏幕尺寸
- **美观UI**：采用渐变色和圆角设计，视觉效果舒适

## 技术栈

- **前端**：Qt Quick/QML
- **构建工具**：CMake
- **Qt版本**：6.8

## 项目结构

```
SakuraChat/
├── CMakeLists.txt          # 项目构建配置
├── main.cpp               # 应用入口
├── global.h               # 全局枚举定义
├── global.cpp             # 全局实现
├── qml/
│   ├── Main.qml           # 主窗口和界面切换逻辑
│   ├── LoginDialog.qml    # 登录界面
│   └── RegisterDialog.qml # 注册界面
└── sakurachat.qrc         # 资源文件
```

## 构建与运行

### 前提条件

- Qt 6.8 或更高版本
- CMake 3.16 或更高版本
- C++编译器

### 构建步骤

1. 创建构建目录并进入：
   ```bash
   mkdir build && cd build
   ```

2. 运行CMake配置：
   ```bash
   cmake ..
   ```

3. 构建项目：
   ```bash
   cmake --build .
   ```

4. 运行应用：
   ```bash
   ./appSakuraChat
   ```

## 界面截图

(此处可添加应用界面截图)

## 未来计划

- 实现完整的聊天功能
- 添加好友系统
- 支持消息通知
- 多平台打包发布

## 贡献指南

欢迎提交Pull Request或Issue报告问题。请确保代码风格与现有代码一致。

## 许可证

MIT License
