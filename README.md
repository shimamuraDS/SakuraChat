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
  - 实时输入验证系统: 用户名非空验证、密码长度验证(6-15字符)
  - 错误提示系统: err_tip显示登录结果，自动清除定时器
  - 密码加密: 调用C++ XOR加密函数保护密码
  - 表单提交验证: 点击登录前完整验证所有字段
  - 网络通信: 与LoginController交互发送登录请求
  - 结果处理: 监听loginResult信号处理登录成功/失败
  - 注册按钮(触发切换到注册界面)
  - 忘记密码标签(触发切换到重置界面)
  - 美观的UI设计(渐变色背景、圆角边框)
  - 响应式布局

#### `RegisterDialog.qml`
- **功能**: 用户注册界面
- **完整特性**:
  - 双页面结构: 注册表单页 + 成功提示页
  - 使用StackLayout管理页面切换
  - **实时输入验证系统**:
    - editingFinished信号触发验证
    - 独立的验证函数: checkUserValid, checkEmailValid, checkPassValid, checkConfirmValid, checkVerifyValid
  - **智能错误提示系统**:
    - tipErrors对象缓存所有错误
    - addTipErr/delTipErr管理错误状态
    - showFirstError显示首个错误
    - 自动清理已修正的错误
  - **表单提交验证**:
    - 点击确认按钮时顺序验证所有字段
    - 验证失败立即中止并显示错误
    - 验证通过后发送注册请求
  - **注册成功流程**:
    - changeTipPage切换到提示页
    - 5秒倒计时定时器
    - 自动或手动返回登录
  - **页面导航**:
    - switchToLogin信号通知父组件
    - 取消按钮立即返回
    - 定时器自动清理
  - 验证码获取功能(与TimerButton配合)
  - 加载状态管理(BusyIndicator)
  - 邮箱格式验证(正则表达式)
  - 密码强度验证(长度和字符合法性)
  - 与RegisterController的完整交互
  
#### `ResetDialog.qml`
- **功能**: 用户密码重置界面(完全QML实现)
- **完整特性**:
  - 完整的重置表单(用户名、邮箱、验证码、新密码)
  - 完整的表单验证逻辑 (QML实现)
  - 用户名非空验证
  - 邮箱格式验证 (正则表达式)
  - 密码强度验证 (长度6-15，特定字符)
  - 验证码验证
  - 错误提示系统 (QML实现)
  - 验证码获取功能 (60秒倒计时)
  - JSON数据构造和发送
  - 重置结果处理和显示
  - 与ResetController的完整交互
  - 自动返回登录界面(重置成功后)

#### `TimerButton.qml`
- **功能**: 独立的倒计时按钮组件
- **特性**:
  - 可配置倒计时时间 (countdownTime属性)
  - 可配置正常状态文本 (normalText属性)
  - 倒计时期间自动禁用按钮
  - 动态文本显示(倒计时数字或按钮文本)
  - 自动重置功能
  - 提供控制方法: startCountdown(), stopCountdown(), resetCountdown()
  - 优雅的动画效果(点击缩放、文本变化动画)
  - 悬浮颜色变化效果
- **用途**:
  - 验证码获取按钮
  - 短信发送按钮
  - 其他需要防重复点击的操作按钮
  
#### `ClickableLabel.qml`
- **功能**: 可点击的标签组件
- **特性**:
  - 支持六种状态: 普通、普通悬浮、普通点击、选中、选中悬浮、选中点击
  - 状态图片切换
  - 鼠标悬浮效果
  - 点击状态切换
  - 鼠标指针样式
- **用途**:
  - 密码显示/隐藏切换
  - 其他需要状态切换的UI元素

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
  - `sig_reset_mod_finish`: 重置模块特定完成信号
  
#### `LoginController` (logincontroller.h/cpp)
- **功能**: 处理登录相关业务逻辑和网络通信
- **关键特性**:
  - 用户登录处理
  - 密码XOR加密
  - 网络响应处理
  - HTTP响应分发
- **主要方法**:
  - `loginUser`: 处理登录请求 (接收QML传递的用户数据)
  - `xorString`: XOR加密算法
  - `initHttpHandlers`: 初始化HTTP响应处理器
  - `slot_login_mod_finish`: 处理登录模块HTTP完成信号
- **信号**:
  - `loginResult`: 登录请求结果 (返回给QML处理)

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
  
#### `ResetController` (resetcontroller.h/cpp)
- **功能**: 处理密码重置相关业务逻辑和网络通信
- **关键特性**:
  - 验证码获取(重置模块)
  - 密码重置处理
  - 网络响应处理
  - HTTP响应分发
- **主要方法**:
  - `getVerifyCode`: 获取验证码
  - `resetPassword`: 重置密码
  - `initHttpHandlers`: 初始化HTTP响应处理器
  - `slot_reset_mod_finish`: 处理重置模块HTTP完成信号
- **信号**:
  - `verifyCodeResult`: 验证码请求结果
  - `resetResult`: 重置请求结果

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
│   ├── RegisterDialog.qml # 注册界面(完整功能实现)
│   ├── TimerButton.qml    # 独立倒计时按钮组件
│   └── ClickableLable.qml # 可点击标签组件
└── sakurachat.qrc         # 资源文件
```

## 功能特性详细说明

### 用户注册流程 (完全QML实现)
1. **实时输入验证** (QML):
   - 输入框失去焦点时自动触发验证(editingFinished信号)
   - 用户名非空检查
   - 邮箱格式验证(正则表达式)
   - 密码长度验证(6-15字符)
   - 密码字符合法性验证(字母、数字、特殊字符)
   - 确认密码匹配验证
   - 验证码非空检查

2. **智能错误提示系统** (QML):
   - 错误缓存机制: 使用tipErrors对象缓存所有输入框错误
   - 单一错误显示: 同时只显示一个错误提示
   - 动态错误更新: 修正输入后自动移除对应错误
   - 错误优先级: 按照验证顺序显示剩余错误

3. **表单提交前完整验证** (QML):
   - 点击确认按钮时按顺序验证所有字段
   - 任一验证失败则中止提交并显示错误
   - 所有验证通过后才发送注册请求

4. **数据提交** (QML):
   - 构造JSON对象
   - 调用C++网络接口发送POST请求
   - 显示加载指示器

5. **注册成功处理** (QML):
   - 自动切换到成功提示页面
   - 5秒倒计时自动返回登录
   - 支持手动立即返回登录
   - 定时器自动管理和清理

6. **页面导航** (QML):
   - 登录页和注册页之间平滑切换
   - 使用StackLayout管理注册表单页和成功提示页
   - 信号槽机制实现页面通信
   - 取消注册或注册成功后返回登录页

7. **网络通信** (C++):
   - HTTP POST请求发送
   - 响应数据解析
   - 结果通过信号回调到QML

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
