# SakuraChat 项目文档

## 项目概述

SakuraChat 是一个简洁美观的即时通讯应用，提供用户注册和登录功能。应用采用 Qt Quick 技术构建，具有现代化的用户界面和流畅的交互体验。

## 技术栈

- **前端**: Qt Quick/QML
- **后端**: C++ (Qt 网络模块)
- **构建工具**: CMake
- **Qt版本**: 6.8
- **设计模式**: 单例模式、信号槽机制

## 详细文件说明

### 1. 核心文件

#### `main.cpp`
- **功能**: 应用入口点，初始化QML引擎和注册C++类
- **关键组件**:
  - 初始化QGuiApplication
  - 创建QQmlApplicationEngine
  - 注册RegisterController到QML上下文
  - 加载主QML文件

#### `CMakeLists.txt`
- **功能**: 项目构建配置
- **关键配置**:
  - 设置Qt 6.8为最低要求
  - 定义项目名称和版本
  - 添加源文件和资源文件
  - 配置QML模块
  - 设置平台特定属性(Windows图标资源，macOS bundle信息)
  - 定义安装目标

### 2. QML界面文件

#### `Main.qml`
- **功能**: 主窗口和界面切换逻辑
- **特性**:
  - 管理登录和注册对话框的切换
  - 使用showLogin属性控制当前显示的界面
  - 处理来自子组件的切换信号

#### `LoginDialog.qml`
- **功能**: 用户登录界面
- **特性**:
  - 用户名和密码输入框
  - 登录按钮
  - 注册按钮(触发切换到注册界面)
  - 美观的UI设计(渐变色背景、圆角边框)
  - 响应式布局

#### `RegisterDialog.qml`
- **功能**: 用户注册界面
- **特性**:
  - 完整的注册表单(用户名、邮箱、验证码、密码、确认密码)
  - 验证码获取功能
  - 表单验证逻辑
  - 错误提示系统
  - 与RegisterController的交互
  - 返回登录界面功能

### 3. C++核心类

#### `HttpMgr` (httpmgr.h/cpp)
- **功能**: 封装HTTP网络请求
- **关键特性**:
  - 单例模式实现
  - 支持POST请求
  - 异步请求处理
  - 错误处理机制
- **主要方法**:
  - `PostHttpReq`: 发送HTTP POST请求
  - `slot_http_finish`: 处理请求完成信号
- **信号**:
  - `sig_http_finish`: 请求完成信号
  - `sig_reg_mod_finish`: 注册模块特定完成信号

#### `RegisterController` (registercontroller.h/cpp)
- **功能**: 处理注册相关业务逻辑
- **关键特性**:
  - 验证码获取
  - 用户注册
  - 网络响应处理
- **主要方法**:
  - `getVerifyCode`: 获取验证码
  - `registerUser`: 注册用户
  - `initHttpHandlers`: 初始化HTTP响应处理器
  - `slot_reg_mod_finish`: 处理注册模块HTTP完成信号
- **信号**:
  - `verifyCodeResult`: 验证码请求结果
  - `registerResult`: 注册请求结果

#### `Singleton` (singleton.h)
- **功能**: 单例模式模板类
- **关键特性**:
  - 线程安全实现
  - 模板化设计
  - 防止拷贝和赋值
- **主要方法**:
  - `GetInstance`: 获取单例实例

### 4. 辅助文件

#### `global.h/cpp`
- **功能**: 全局枚举定义
- **定义内容**:
  - `ReqId`: 请求ID枚举
  - `ErrorCodes`: 错误代码枚举
  - `Modules`: 模块枚举

#### `README.md`
- **功能**: 项目文档
- **内容**:
  - 项目概述
  - 功能特性
  - 技术栈
  - 项目结构
  - 构建与运行指南
  - 未来计划
  - 贡献指南
  - 许可证信息

## 项目结构

```
SakuraChat/
├── CMakeLists.txt          # 项目构建配置
├── main.cpp               # 应用入口
├── src/
│   ├── global.h           # 全局枚举定义
│   ├── global.cpp         # 全局实现
│   ├── singleton.h        # 单例模式模板
│   ├── httpmgr.h          # HTTP管理器头文件
│   ├── httpmgr.cpp        # HTTP管理器实现
│   ├── registercontroller.h # 注册控制器头文件
│   └── registercontroller.cpp # 注册控制器实现
├── qml/
│   ├── Main.qml           # 主窗口和界面切换逻辑
│   ├── LoginDialog.qml    # 登录界面
│   └── RegisterDialog.qml # 注册界面
└── sakurachat.qrc         # 资源文件
```

## 功能特性详细说明

### 用户注册流程
1. 用户填写邮箱地址
2. 系统验证邮箱格式
3. 请求验证码
4. 用户填写验证码和其他注册信息
5. 系统验证表单完整性
6. 提交注册请求
7. 处理注册结果

### 网络通信流程
1. QML界面触发C++控制器方法
2. 控制器准备请求数据
3. HttpMgr发送HTTP请求
4. 异步处理响应
5. 通过信号槽返回结果
6. 更新界面状态

### UI特性
- 渐变色背景
- 圆角设计
- 响应式布局
- 状态管理(错误/正常状态)
- 平滑过渡动画
- 统一的视觉风格

## 构建与运行

### 前提条件
- Qt 6.8 或更高版本
- CMake 3.16 或更高版本
- C++编译器

### 构建步骤
```bash
mkdir build && cd build
cmake ..
cmake --build .
./appSakuraChat
```

## 未来计划
- 实现完整的聊天功能
- 添加好友系统
- 支持消息通知
- 多平台打包发布
- 增强错误处理和日志系统
- 添加更多UI主题选项

## 贡献指南
欢迎提交Pull Request或Issue报告问题。请确保代码风格与现有代码一致。

## 许可证
MIT License
