# SakuraChat 项目文档

## 项目概述

SakuraChat 是一个简洁美观的即时通讯应用，提供完整的用户注册和登录功能。应用采用 Qt Quick 技术构建，具有现代化的用户界面和流畅的交互体验。项目完全采用QML实现前端逻辑，通过C++后端处理网络通信。

## 技术栈

- **前端**: Qt Quick/QML (完整业务逻辑)
- **后端**: C++ (网络通信和数据处理)
- **构建工具**: CMake
- **Qt版本**: 6.8
- **设计模式**: 单例模式、信号槽机制
- **架构**: QML前端 + C++网络层

## 详细文件说明

### 1. 核心文件

#### `main.cpp`
- **功能**: 应用入口点，初始化QML引擎和注册C++类
- **关键组件**:
  - 初始化QGuiApplication
  - 创建QQmlApplicationEngine
  - 注册RegisterController到QML上下文
  - 加载主QML文件
  - 配置管理: 读取config.ini配置文件，设置gate服务器地址

#### `CMakeLists.txt`
- **功能**: 项目构建配置
- **关键配置**:
  - 设置Qt 6.8为最低要求
  - 定义项目名称和版本
  - 添加源文件和资源文件
  - 配置QML模块
  - 设置平台特定属性(Windows图标资源，macOS bundle信息)
  - 定义安装目标
  - 自动部署: 在Windows Release模式下自动拷贝config.ini到输出目录
  
#### `config.ini`
- **功能**: 应用配置文件
- **配置项**:
  - Gate服务器主机地址 (默认: localhost)
  - Gate服务器端口 (默认: 8081)
  - 用途: 存储网络连接配置，便于部署时修改

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
- **完整特性**:
  - 完整的注册表单(用户名、邮箱、验证码、密码、确认密码)
  - 验证码获取功能
  - **完整的表单验证逻辑** (QML实现)
  - **注册确认功能** (sure_btn点击处理)
  - **错误提示系统** (QML实现)
  - **表单完整性检查** (用户名、邮箱、密码、确认密码、验证码)
  - **密码匹配验证**
  - **JSON数据构造和发送**
  - **注册结果处理和显示**
  - 与RegisterController的完整交互
  - 返回登录界面功能
  - 加载状态管理: 注册过程中显示BusyIndicator
  - 邮箱格式验证: 使用正则表达式验证邮箱格式

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
- **功能**: 处理注册相关业务逻辑和网络通信
- **关键特性**:
  - 验证码获取
  - **用户注册处理** (接收来自QML的注册请求)
  - **网络响应处理** (处理注册成功/失败结果)
  - **HTTP响应分发** (将结果返回给QML)
- **主要方法**:
  - `getVerifyCode`: 获取验证码
  - `registerUser`: 注册用户 (接收QML传递的用户数据)
  - `initHttpHandlers`: 初始化HTTP响应处理器
  - `slot_reg_mod_finish`: 处理注册模块HTTP完成信号
- **信号**:
  - `verifyCodeResult`: 验证码请求结果
  - `registerResult`: 注册请求结果 (返回给QML处理)

#### `Singleton` (singleton.h)
- **功能**: 单例模式模板类
- **关键特性**:
  - 线程安全实现
  - 模板化设计
  - 防止拷贝和赋值
- **主要方法**:
  - `GetInstance`: 获取单例实例
  - `gate_url_prefix`: 全局服务器URL前缀变量

### 4. 辅助文件

#### `global.h/cpp`
- **功能**: 全局枚举定义
- **定义内容**:
  - `ReqId`: 请求ID枚举 (包含ID_REG_USER)
  - `ErrorCodes`: 错误代码枚举 (包含SUCCESS等)
  - `Modules`: 模块枚举 (包含REGISTERMOD)

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
├── CMakeLists.txt         # 项目构建配置
├── main.cpp               # 应用入口
├── config.ini             # 配置文件
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
│   └── RegisterDialog.qml # 注册界面(完整功能实现)
└── sakurachat.qrc         # 资源文件
```

## 功能特性详细说明

### 用户注册流程 (完全QML实现)
1. **表单验证** (QML):
  - 用户名非空检查
  - 邮箱非空检查
  - 密码非空检查
  - 确认密码非空检查
  - 密码匹配验证
  - 验证码非空检查
  - 邮箱格式验证: 使用正则表达式验证邮箱格式

2. **数据提交** (QML):
  - 构造JSON对象
  - 调用C++网络接口发送POST请求

3. **结果处理** (QML):
  - 接收C++返回的注册结果
  - 显示成功/失败提示
  - 错误信息展示
  - 加载状态管理: 注册过程中显示加载指示器
4. **网络通信** (C++):
  - HTTP POST请求发送
  - 响应数据解析
  - 结果回调到QML

### 验证码获取流程
1. 用户填写邮箱地址
2. 系统验证邮箱格式
3. 请求验证码
4. 显示获取结果

### 网络通信架构
```
QML界面 -> RegisterController -> HttpMgr -> 服务器
    ↖                                          ↙
     ← 信号槽回调 ← JSON响应处理 ← HTTP响应 ←
```

1. **QML发起请求**: 表单验证后调用registerUser方法
2. **C++处理请求**: RegisterController接收并发送HTTP请求
3. **异步响应处理**: HttpMgr处理HTTP响应
4. **结果回调**: 通过信号槽将结果返回QML
5. **界面更新**: QML接收结果并更新UI状态

### UI特性
- 渐变色背景
- 圆角设计
- 响应式布局
- **智能状态管理** (错误/正常/加载状态)
- **实时表单验证**
- **用户友好的错误提示**
- 平滑过渡动画
- 统一的视觉风格

### 架构优势
- **前后端分离**: QML处理界面逻辑，C++处理网络通信
- **可维护性强**: 业务逻辑在QML中清晰可见
- **扩展性好**: 易于添加新的验证规则和界面功能
- **性能优化**: C++处理计算密集任务，QML处理界面渲染

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

## 开发特性
- **完整的表单验证**: 所有输入字段的验证都在QML中实现
- **错误处理机制**: 友好的用户提示和错误信息显示
- **异步网络通信**: 非阻塞的HTTP请求处理
- **状态管理**: 完整的注册流程状态跟踪
- **可扩展架构**: 易于添加更多功能模块

## 贡献指南
欢迎提交Pull Request或Issue报告问题。请确保代码风格与现有代码一致，并遵循QML最佳实践。

## 许可证
MIT License
