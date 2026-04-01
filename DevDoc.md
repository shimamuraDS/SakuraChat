# SakuraChat 项目文档

## 项目概述

SakuraChat 是一款基于现代 Qt 6 (C++) 与 QML 技术栈构建的即时通讯客户端。
本项目的核心设计目标是实现前后端极致解耦与现代化 UI 交互。前端完全摒弃传统的 Qt Widgets，采用 QML 声明式语法构建媲美 Telegram 风格的流畅界面；后端采用 C++ 处理高并发网络通信与底层逻辑。项目全面拥抱 Qt 6.8 的现代化架构，通过 CMake 深度集成模块，提供高效、稳定且易于扩展的即时通讯解决方案。

## 技术栈

- **前端**: Qt Quick/QML (完整业务逻辑)
- **后端**: C++ (网络通信和数据处理)
- **构建工具**: CMake (利用 `qt_add_qml_module` 深度集成)
- **Qt版本**: 6.8
- **设计模式**: 单例模式、信号槽机制
- **架构**: 现代 Qt 6 架构 (QML前端 + C++网络层 + `QML_ELEMENT` 声明式注册)

## 详细文件说明

### 1. 核心文件

#### `main.cpp`
- **功能**: 应用入口点（极致瘦身版）
- **关键组件**:
  - 初始化 `QGuiApplication` 和 `QQmlApplicationEngine`
  - 调用 `ConfigManager::instance().loadConfig()` 进行全局配置初始化
  - 直接加载主 QML 模块 (`engine.loadFromModule`)
  - **架构革新**: 废弃了传统的 `setContextProperty` 和 `qmlRegisterType`，将 QML 类型注册工作完全交由现代 Qt 的宏和 CMake 自动处理。

#### `CMakeLists.txt`
- **功能**: 项目构建配置
- **关键配置**:
  - 设置 Qt 6.8 为最低要求
  - 定义项目名称和版本
  - **核心革新**: 使用 `qt_add_qml_module` 自动扫描带有 `QML_ELEMENT` 等宏的 C++ 头文件，自动生成注册代码和 `.qmltypes` 类型定义文件。
  - 自动部署: 在 Windows Release 模式下自动拷贝 `config.ini` 到输出目录。
  
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
  - 表单提交验证: 点击登录前完整验证所有字段
  - **TCP连接状态管理**: 
    - isConnectingTcp 控制UI状态
    - 连接期间禁用所有输入和按钮
    - 显示加载指示器
  - **完整登录流程**: 
    - HTTP登录验证
    - 自动发起TCP连接
    - 发送聊天登录请求
    - 处理各种错误情况
  - 网络通信: 与LoginController交互发送登录请求
  - 结果处理: 监听loginResult信号处理登录成功/失败
  - 注册按钮(触发切换到注册界面)
  - 忘记密码标签(触发切换到重置界面)
  - 美观的UI设计(渐变色背景、圆角边框)
  - 响应式布局
- **信号监听**:
  - `loginController.loginResult`: HTTP登录结果
  - `loginController.sig_connect_tcp`: TCP连接开始
  - `tcpMgr.sig_con_success`: TCP连接结果
  - `tcpMgr.sig_login_failed`: 聊天登录失败
  - `tcpMgr.sig_switch_chatdlg`: 登录成功，切换界面

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
  
#### `ChatDialog.qml`
- **功能**: 聊天主界面，参考 Telegram 视觉风格
- **布局区域**:
  - 区域 1：左侧图标切换栏（侧边功能入口，含头像与四个功能按钮）
  - 区域 2：搜索栏 + 快速创建群聊按钮
  - 区域 3：近期聊天联系人列表（支持动态加载更多 + 加载覆盖层）
  - 区域 4：搜索结果实时过滤（通过 delegate `visible` 绑定 `searchInput.text` 实现）
  - 区域 5：顶部栏（聊天对象名称、头像、在线状态、搜索/更多按钮）
  - 区域 6：聊天记录区域（由独立的 `ChatView` 组件承载）
  - 区域 7：工具栏区域（附件、图片、表情、定位等）
  - 区域 8：文本输入区域（`TextArea` 多行，`Shift+Enter` 换行）
  - 区域 9：发送按钮区域
- **特性**:
  - 整体采用深蓝侧边栏（`#2b5278`）+ 白色面板 + 浅蓝灰聊天背景（`#f0f4f8`）的 Telegram 配色
  - 顶部声明颜色常量（`sidebarBg`、`accentBlue`、`msgBubbleSelf` 等），统一管理全局配色
  - 使用 `RowLayout` + `ColumnLayout` 实现多区域嵌套布局
  - `StackLayout`（`mainStack`）管理聊天区域的双页切换：`currentIndex: 0` 为空白占位页，`currentIndex: 1` 为真实聊天页；点击联系人后自动切换
  - 搜索框使用 `TextField` + 清除按钮实现，`clearBtn` 通过 `visible: searchInput.text.length > 0` 控制显隐，点击后清空输入并重置 `filterText`
  - 聊天列表通过 `delegate` 的 `visible` 属性绑定 `searchInput.text` 实现实时过滤（后续建议迁移至 `QSortFilterProxyModel` 以提升性能）
  - 列表数据由 `ChatUserList`（C++ `QAbstractListModel`）提供，在 `Component.onCompleted` 中调用 `chatModel.addItem()` 填充初始测试数据
  - **动态加载**：`ListView.onAtYEndChanged` 检测滚动到底部，自动调用 `chatModel.loadMoreItems(10)`，替代原 `eventFilter` 滚轮事件捕获方案
  - **加载覆盖层**：联系人面板上方叠加半透明 `Rectangle`（`z: 5`）+ `BusyIndicator` + 文字提示，通过 `visible: chatModel.isLoading()` 绑定加载状态，替代原 `LoadingDlg` 对话框
  - 输入框捕获 `Keys.onPressed`：`Enter` 触发 `sendMessage()`，`Shift+Enter` 正常换行
  - `sendMessage()` 函数向 `messageModel` 插入消息，预留 `TcpMgr` 接口
  - 滚动条通过 `ScrollBar` 组件设置 `policy: ScrollBar.AsNeeded`，参考 Telegram 风格
  - **`sendMessage()` 函数**: 
    - 支持文本消息和图片消息两种类型，
    - 新增 `receiveMessage()` 函数，用于接收对方消息，后续由 `TcpMgr` 的 `sig_recv_message` 信号触发

#### `ChatView.qml`
- **功能**: 滚动聊天消息区域组件
- **对外接口**:
  - appendMessage(msgData): 尾插消息并自动滚动到底部
  - prependMessage(msgData): 头插消息，对应原 prependChatItem()
  - `sendImageMessage(imagePath)` — 图片消息快捷发送方法
- **内部结构**:
  - chatModel（ListModel）：消息数据源
  - listView（ListView）：虚拟化渲染，替代 QScrollArea + QVBoxLayout 组合，天然解决大量消息时的性能问题
  - floatingScrollBar（ScrollBar）：通过 Binding 与 listView.visibleArea 双向联动，policy: ScrollBar.AsNeeded 实现按需显隐，替代原 pVScrollBar->setHidden(true) 的手动管理
  - footer：高度为 4px 的留白 Item，替代原 pVLayout_1 中 stretch 比例为 100000 的空白 QWidget
  - 气泡出现动画: 每条消息 delegate 实例化时触发 scale 从 0.85 到 1.0 的弹性动画（Easing.OutBack，180ms），对应原方案中可在 paintEvent 扩展的自定义绘制入口

#### `SidebarIconBtn.qml`
- **功能**: 左侧图标栏按钮组件
- **特性**:
  - 支持 normal / hover / press 三态，通过 MouseArea 事件驱动，无需 C++ 代码
  - Behavior on color 实现平滑颜色过渡动画（120ms）
  - 激活状态显示左侧白色指示条
  - 支持 ToolTip 悬浮提示
  - cursorShape: Qt.PointingHandCursor 设置手型鼠标指针

#### `SendBtn.qml`
- **功能**: 消息发送按钮（区域 9）
- **特性**:
  - 蓝色圆形按钮，三态颜色变化：normal（`#2ca5e0` Telegram 蓝）、hover（`#36b3f0` 浅蓝）、press（`#1a8bbf` 深蓝）
  - `Behavior on color` 实现 120ms 平滑颜色过渡动画
  - 按下时通过 `Scale` transform 触发图标缩放动画（`xScale/yScale: 0.88`，80ms），提供点击反馈
  - 使用 Unicode 字符 `➤` 作为发送图标，无需外部图片资源
  - 通过 `MouseArea` 的 `onEntered / onExited / onPressed / onReleased` 驱动 `_hovered` 与 `_pressed` 两个私有布尔属性，颜色通过 `readonly property color _bgColor` 计算属性自动响应状态变化
  - `cursorShape: Qt.PointingHandCursor` 设置手型鼠标指针
  - 发射 `clicked()` 信号供 `ChatDialog` 的 `sendMessage()` 函数调用

#### `AddGroupBtn.qml`
- **功能**: 搜索栏旁的快速创建群聊按钮（+），对应原教程中的 add_btn
- **特性**:
  - 支持 normal / hover / press 三态，完全替代原 ClickedBtn + QSS 三态图片方案
  - normal 状态显示灰色边框圆形按钮，hover/press 状态填充蓝色
  - 颜色与文字颜色均有 Behavior 过渡动画
  - 无需外部图片资源，无需 QSS 文件

#### `ContactItem.qml`
- **功能**: 近期聊天联系人列表项组件（区域 3）
- **特性**:
  - 显示头像（彩色圆形首字母）、联系人名称、最后一条消息、时间戳
  - 未读消息角标（蓝色圆形数字）
  - 悬浮高亮背景，Behavior 平滑过渡

#### `ChatUserWid.qml`
- **功能**: 聊天列表 item 组件，替代原 Qt Widgets 中通过 `setItemWidget` 挂载的设计师界面类 `ChatUserWid`
- **特性**:
  - 显示头像（彩色圆形首字母占位）、用户名、最后一条消息、时间戳
  - 悬浮高亮背景（`#e8f4fd`），通过 `MouseArea.containsMouse` + `Behavior on color` 实现平滑过渡
  - 底部分隔线从头像右侧起始，与 Telegram 风格一致
  - 所有文字颜色、字号与原 QSS 规则对应：用户名 14px/#000000，消息预览 12px/#999999，时间 12px/#8c8c8c
  - 无需外部 `.ui` 文件，无需 QSS，样式完全内联在 QML 属性中

#### `MessageBubble.qml`
- **功能**: 统一气泡组件
- **属性接口**:
  - `messageText`：消息正文（文本消息）
  - `imageSource`：图片路径（图片消息，空则视为文本）
  - `isSentByMe`：控制气泡左右对齐（`true` 靠右为己方，`false` 靠左为对方）
  - `senderName`：发送者名称（群聊场景展示，己方消息自动隐藏）
  - `avatarSource`：头像图片路径
  - `timestamp`：右下角时间戳
- **特性**:
  - 己方气泡为深蓝色（`#2B5278`）白字，对方气泡为白色深色文字，风格与 Telegram 一致
  - 使用 `RowLayout` + `layoutDirection` 实现左右镜像布局，无需为两种气泡分别编写布局代码，替代原两套 `QGridLayout`
  - 文本气泡宽度自适应内容，最大不超过聊天区域 72%（`_maxBubbleWidth: 400`），`implicitHeight` 随内容自动伸缩，替代原 `eventFilter` 动态调整高度方案
  - 图片消息尺寸上限对应原 `PIC_MAX_WIDTH=160 / PIC_MAX_HEIGHT=90`，保持宽高比（对应原 `Qt.KeepAspectRatio`），在 `Component.onCompleted` 中计算
  - 气泡出现时触发 `scale` 弹性动画（`0.85 → 1.0`，`Easing.OutBack`，180ms），对应原方案中可在 `paintEvent` 扩展的自定义绘制入口
  - 气泡绘制（原 `QPainter` 先绘矩形再绘三角形）由 `Rectangle` + `radius` + `border` 替代，无需任何 `QPainter` 代码

#### `SendBtn.qml`
- **功能**: 消息发送按钮（区域 9）
- **特性**:
  - 蓝色圆形按钮，三态颜色变化
  - 按下时图标缩放动画（scale 0.88）提供点击反馈
  - 发射 clicked() 信号供 ChatDialog 调用

#### `ToolbarBtn.qml`
- **功能**: 工具栏通用图标按钮（区域 7）
- **特性**:
  - 悬浮时显示浅灰圆角背景
  - 统一尺寸 32×32，支持任意 Unicode 图标

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
  - HTTP响应处理
  - TCP连接管理
  - 聊天服务器登录
- **主要方法**:
  - `loginUser`: 处理登录请求 (接收QML传递的用户数据)
  - `initHttpHandlers`: 初始化HTTP响应处理器
  - `slot_login_mod_finish`: 处理登录模块HTTP完成信号
  - `slot_tcp_con_finish`: 处理TCP连接成功/失败
  - `slot_login_failed`: 处理聊天登录失败
- **信号**:
  - `loginResult`: 登录请求结果 (返回给QML处理)
  - `sig_connect_tcp`: 发起TCP连接 (内部信号，发送给TcpMgr)

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
  
#### `LoginController` / `RegisterController` / `ResetController`
- **功能**: 处理登录、注册、密码重置相关的业务逻辑和网络通信
- **现代 Qt 架构**:
  - 头文件中引入 `<QtQml/qqml.h>`
  - 使用 **`QML_ELEMENT`** 和 **`QML_SINGLETON`** 宏，将其直接声明为 QML 引擎可识别的单例模块。
  - **优势**: 无需在 `main.cpp` 中手动 `new` 对象并注入上下文，引擎会在 QML 端按需自动实例化，生命周期随程序自动安全回收。
- **业务交互**:
  - 发送 HTTP 请求并处理响应
  - 协同 `TcpMgr` 管理聊天服务器的长连接（仅 `LoginController`）
  - 通过信号将结果回调给 QML 端更新 UI
  
#### `TcpMgr` (tcpmgr.h/cpp)
- **功能**: 管理TCP长连接，处理与聊天服务器的通信
- **关键特性**:
  - 单例模式实现
  - TCP连接管理
  - 消息发送和接收
  - 线程安全的数据发送
  - 网络字节序处理
- **主要方法**:
  - `slot_tcp_connect`: 连接到聊天服务器
  - `slot_send_data`: 发送数据到聊天服务器 (线程安全)
  - `slot_connected`: 处理连接成功
  - `slot_disconnected`: 处理连接断开
  - `slot_recv_data`: 接收服务器数据
- **信号**:
  - `sig_con_success`: TCP连接成功/失败信号
  - `sig_send_data`: 发送数据信号 (内部使用，保证线程安全)
  - `sig_switch_chatdlg`: 登录成功，切换到聊天界面
  - `sig_login_failed`: 聊天登录失败信号
  
#### `CustomizeEdit` (customizeedit.h/cpp)
- **功能**: 搜索框逻辑封装，替代原继承 QLineEdit 的同名 Qt Widgets 子类
- **关键特性**:
  - 继承 QObject，通过 `Q_PROPERTY` 暴露 `text` 和 `maxLength` 属性到 QML
  - `maxLength` 默认 25，setText 自动截断超长输入
  - 提供 `clear()` 槽函数，发送 `cleared()` 信号
  - 通过 `qmlRegisterType` 注册为 QML 类型，供后续扩展使用
- **信号**:
  - `textChanged`: 文本变化信号
  - `cleared`: 清除操作信号

#### `ChatUserList` (chatuserlist.h/cpp)
- **功能**: 聊天用户列表数据模型，替代原 `QListWidget + setItemWidget` 方案
- **关键特性**:
  - 继承 `QAbstractListModel`，通过标准 Model/View 机制与 QML `ListView` 绑定
  - 定义 `NameRole / HeadRole / LastMsgRole / TimeRole` 四个自定义角色
  - `roleNames()` 返回 QML 可直接访问的属性名（`name`、`head`、`lastMsg`、`time`）
  - 提供 `Q_INVOKABLE addItem()` 和 `clear()` 方法，可在 QML 中直接调用
  - 提供 `Q_INVOKABLE loadMoreItems(int count = 10)` 方法，QML 滚动到底部时调用以追加数据，替代原 `ChatDialog::slot_loading_chat_user` 槽函数
  - 提供 `Q_INVOKABLE isLoading() const` 方法，供 QML 查询当前加载状态（防重入锁）
  - 发射 `loadingChanged(bool)` 信号，通知 QML 更新加载覆盖层的显隐状态
  - 通过 `QML_ELEMENT` 宏注册为 QML 类型
- **主要方法**:
  - `addItem`: 追加一条聊天用户记录
  - `loadMoreItems`: 防重入追加多条记录，追加前后分别发射 `loadingChanged(true/false)`
  - `isLoading`: 返回当前是否正在加载
  - `clear`: 清空所有记录
- **信号**:
  - `loadingChanged(bool loading)`: 加载状态变更信号

#### `ConfigManager` (configmanager.h/cpp) 
- **功能**: 全局配置管理器
- **关键特性**:
  - 线程安全的单例模式实现
  - 负责解析 `config.ini` 并生成完整的 Gate 服务器 URL
  - 彻底取代了原先在 `main.cpp` 中定义全局变量（如 `gate_url_prefix`）的做法，降低了代码耦合度。

#### `Singleton` (singleton.h)
- **功能**: 单例模式模板类
- **关键特性**:
  - 线程安全实现
  - 模板化设计
  - 防止拷贝和赋值
- **主要方法**:
  - `GetInstance`: 获取单例实例
  - `gate_url_prefix`: 全局服务器URL前缀变量

#### 自定义 C++ 控件 (`CustomizeEdit`, `ChatUserList` 等)
- **架构革新**: 同样采用 `QML_ELEMENT` 宏声明，无需在 `main.cpp` 中使用 `qmlRegisterType` 注册。QML 端可直接通过 `import SakuraChat` 使用对应标签。

### 4. 辅助文件

#### `global.h`
- **功能**: 全局枚举定义和结构体
- **定义内容**:
  - `ReqId`: 请求ID枚举 (包含ID_REG_USER, ID_LOGIN_USER, ID_CHAT_LOGIN等)
  - `ErrorCodes`: 错误代码枚举 (包含SUCCESS, ERR_NETWORK, ERR_JSON等)
  - `Modules`: 模块枚举 (包含REGISTERMOD, LOGINMOD等)
  - `ServerInfo`: 服务器信息结构体
    - `Uid`: 用户ID
    - `Host`: 聊天服务器地址
    - `Port`: 聊天服务器端口
    - `Token`: 认证令牌

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
│   ├── global.h              # 全局枚举定义
│   ├── singleton.h           # 单例模式模板
│   ├── httpmgr.h             # HTTP管理器头文件
│   ├── httpmgr.cpp           # HTTP管理器实现
│   ├── tcpmgr.h              # TCP管理器头文件
│   ├── tcpmgr.cpp            # TCP管理器实现
│   ├── logincontroller.h     # 登录控制器头文件
│   ├── logincontroller.cpp   # 登录控制器实现
│   ├── registercontroller.h  # 注册控制器头文件
│   ├── registercontroller.cpp # 注册控制器实现
│   ├── resetcontroller.h     # 重置控制器头文件
│   ├── resetcontroller.cpp   # 重置控制器实现
│   ├── customizeedit.h       # 搜索框逻辑封装头文件
│   ├── customizeedit.cpp     # 搜索框逻辑封装实现
│   ├── chatuserlist.h        # 聊天用户列表模型头文件
│   └── chatuserlist.cpp      # 聊天用户列表模型实现
├── qml/
│   ├── Main.qml           # 主窗口和界面切换逻辑
│   ├── LoginDialog.qml    # 登录界面(完整TCP连接功能)
│   ├── RegisterDialog.qml # 注册界面(完整功能实现)
│   ├── ResetDialog.qml    # 重置界面(完整功能实现)
│   ├── TimerButton.qml    # 独立倒计时按钮组件
│   ├── ClickableLable.qml # 可点击标签组件
│   ├── ChatDialog.qml     # 聊天主界面（搜索框 + 聊天列表）（含 sendMessage / receiveMessage）
│   ├── ChatView.qml       # 滚动聊天消息区域
│   ├── ChatUserWid.qml    # 聊天列表 item 组件
│   ├── SidebarIconBtn.qml # 侧边栏图标按钮（替代 ClickedBtn C++）
│   ├── AddGroupBtn.qml    # 创建群聊按钮（add_btn 三态）
│   ├── ContactItem.qml    # 联系人列表项
│   ├── MessageBubble.qml  # 统一气泡组件（文本 + 图片，己方 + 对方）
│   ├── SendBtn.qml        # 发送按钮
│   └── ToolbarBtn.qml     # 工具栏按钮
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

### 用户登录流程 (QML + C++协作)
1. **用户输入验证** (QML):
   - 邮箱非空检查
   - 密码长度验证(6-15字符)
   - 验证失败立即显示错误提示

2. **HTTP登录请求** (QML → C++):
   - QML调用xorString加密密码
   - 构造用户数据并调用loginController.loginUser
   - 禁用登录按钮，显示加载状态

3. **HTTP登录处理** (C++):
   - LoginController发送HTTP请求到Gate服务器
   - 接收服务器响应，解析用户信息
   - 提取聊天服务器信息(host, port, uid, token)
   - 保存uid和token到私有成员变量
   - 发送loginResult信号通知QML HTTP登录成功

4. **发起TCP连接** (C++):
   - LoginController发送sig_connect_tcp信号
   - TcpMgr接收信号并连接聊天服务器
   - QML接收信号并更新UI提示

5. **TCP连接建立** (C++):
   - TcpMgr连接成功后发送sig_con_success信号
   - LoginController接收信号，构造聊天登录JSON
   - 使用保存的uid和token构造请求
   - 通过TcpMgr发送聊天登录请求

6. **聊天登录处理** (C++):
   - TcpMgr发送数据到聊天服务器
   - 等待服务器响应
   - 成功: 发送sig_switch_chatdlg信号
   - 失败: 发送sig_login_failed信号

7. **结果反馈** (QML):
   - 监听各种信号更新UI状态
   - 显示相应的提示信息
   - 恢复按钮状态或切换到聊天界面

### 验证码获取流程
1. 用户填写邮箱地址
2. 系统验证邮箱格式
3. 请求验证码
4. 显示获取结果

### 聊天主界面 (ChatDialog)

1. **界面布局与切换**：
  登录成功后，`TcpMgr` 发送 `sig_switch_chatdlg` 信号，`Main.qml` 监听后将 `currentView` 切换为 `"chat"`，通过 `StackLayout` 跳转到 `ChatDialog`。在 `ChatDialog` 内部，`StackLayout`（`mainStack`）进一步管理聊天区域的子页切换：点击联系人列表项后将 `mainStack.currentIndex` 设为 `1`，切换至真实聊天页。
2. **按钮三态实现（替代 ClickedBtn）**：
  原 Qt Widgets 方案需继承 `QPushButton`、重写 `enterEvent / mousePressEvent / mouseReleaseEvent`、编写 QSS 三态样式、在构造函数调用 `SetState()`。QML 方案通过 `MouseArea` 的 `onEntered / onExited / onPressed / onReleased` 驱动 `btnState` 属性，`color` 绑定三态颜色表达式，`Behavior on color` 添加过渡动画，所有逻辑内联在组件文件中，无需任何 C++ 代码和外部样式文件。
3. **搜索框（替代 CustomizeEdit + QSS）**：
  原 Qt Widgets 方案需继承 `QLineEdit`、在 `paintEvent` 中手动绘制清除按钮、在 QSS 中配置样式。QML 方案在 `ChatDialog.qml` 中直接使用 `TextField` + `Image`（清除图标）组合，通过 `visible: searchInput.text.length > 0` 控制清除按钮的显隐，点击后调用 `searchInput.clear()` 清空并重置 `filterText`，输入长度限制通过 `maximumLength: 25` 声明式配置，无需 C++ 继承类，无需 QSS 文件。
4. **聊天列表（替代 QListWidget + setItemWidget）**：
  原 Qt Widgets 方案通过 `QListWidget::addItem()` + `setItemWidget()` 手动挂载自定义 Widget，性能随条目增加而下降，QSS 与 C++ 代码耦合紧密。QML 方案使用 `ChatUserList`（继承 `QAbstractListModel`）作为数据源，`ListView` 作为视图，`ChatUserWid.qml` 作为 delegate，三者通过标准 Model/View 机制解耦。测试数据在 `Component.onCompleted` 中通过 `chatModel.addItem()` 填充，替代原 C++ `addChatUserList()` 函数。搜索过滤通过 delegate 的 `visible` 属性绑定 `searchInput.text` 实现实时过滤，无需重建列表。
5. **动态加载更多（替代 eventFilter + LoadingDlg）**：
  原 Qt Widgets 方案在 `ChatUserList::eventFilter` 中捕获鼠标滚轮事件，当 `maxScrollValue - currentValue <= 0` 时发射 `sig_loading_chat_user` 信号，由 `ChatDialog::slot_loading_chat_user` 槽函数接收，`new LoadingDlg` 显示加载对话框，调用 `addChatUserList()` 追加数据，完成后 `deleteLater()`。QML 方案将上述链路缩短为两步：`ListView.onAtYEndChanged` 检测到 `atYEnd` 为 `true` 时直接调用 `chatModel.loadMoreItems(10)`；C++ 模型内部通过 `m_loading` 布尔标志防止重入，并在加载前后发射 `loadingChanged` 信号；QML 侧联系人面板上叠加半透明遮罩层（`z: 5`），其 `visible` 绑定 `chatModel.isLoading()`，自动管理显隐，无需手动 `new` / `deleteLater`。
6. **StackLayout 管理聊天页（替代 StackedWidget + ChatPage 设计师界面类）**：
  原教程新建 `ChatPage` 设计师界面类，将 `chat_data_wid` 从 `ChatDialog.ui` 迁入，并在 `ChatDialog.ui` 的 `stackedWidget` 中将页面升级为 `ChatPage`；重写 `paintEvent` 以支持 QSS 样式刷新。QML 方案中 `StackLayout`（`mainStack`）直接作为聊天区域容器，子页以内联 `ColumnLayout` / `Item` 形式声明，无需独立文件；QML 属性绑定自动触发重绘，无需重写 `paintEvent`。
7. **滚动聊天布局（替代 C++ ChatView 类）**：
  原方案通过继承 QWidget 手动搭建 QScrollArea + 嵌套 QWidget + QVBoxLayout 的四层嵌套结构，并以 QHBoxLayout 浮动放置自定义 QScrollBar，通过 installEventFilter 监听尺寸变化、重写 paintEvent 支持子类绘制，槽函数 onVScrollBarMoved 在范围变化时自动滚动到底部。QML 方案将上述全部机制收敛至 ChatView.qml：ListView 内置虚拟化渲染替代 QScrollArea 多层嵌套；anchors 定位的 ScrollBar 通过 Binding 与 visibleArea 联动替代浮动 QHBoxLayout；appendMessage() 末尾直接调用 positionViewAtEnd() 替代 onVScrollBarMoved 槽函数；ChatDialog.qml 区域 6 原内联的 Rectangle + ListView 块整体替换为 <ChatView id="chatView">，sendMessage() 改为调用 chatView.appendMessage()，消息存储与滚动逻辑完全封装，外部零感知。
8. **滚动条样式（替代 QSS QScrollBar）**：
  原 QSS 方案通过 `QScrollBar:vertical` 等选择器配置轨道、滑块、箭头样式。QML 方案通过 `ScrollBar` 组件设置 `policy: ScrollBar.AsNeeded`，可按需扩展 `contentItem` 与 `background` 实现细圆角滑块与渐显动画，与 Telegram 风格一致。
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

### TCP连接架构
```
QML LoginDialog          C++ LoginController        C++ TcpMgr
      |                          |                        |
      | handleLogin()            |                        |
      |------------------------->|                        |
      |                          | HTTP Login Request     |
      |                          |----------------------->| Gate Server
      |                          |                        |
      | loginResult(success)     | HTTP Response          |
      |<-------------------------|                        |
      |                          |                        |
      | sig_connect_tcp          |                        |
      |------------------------->|----------------------->| Chat Server
      |                          |                        |
      | sig_con_success(true)    | TCP Connected          |
      |<--------------------------------------------------|
      |                          |                        |
      |                          | Send Chat Login        |
      |                          | (uid + token)          |
      |                          |----------------------->| Chat Server
      |                          |                        |
      | sig_switch_chatdlg       | Login Success          |
      |<--------------------------------------------------|
```


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
- **现代化 QML 注册**: 全面拥抱 Qt 6 的 `QML_ELEMENT` 与 `QML_SINGLETON` 宏。彻底告别手动注入，配合 CMake 的 `qt_add_qml_module`，不仅实现了 C++ 与 QML 的极致解耦，还获得了更安全的类型检查、更完善的代码补全支持以及更优的启动性能。
- **配置集中管理**: 引入独立的 `ConfigManager` 统一管理环境变量与配置文件，消除了全局变量带来的“坏味道”，提高了代码的模块化和可测试性。

## 开发特性
- **完整的表单验证**: 所有输入字段的验证都在QML中实现
- **错误处理机制**: 友好的用户提示和错误信息显示
- **异步网络通信**: 非阻塞的HTTP请求处理
- **状态管理**: 完整的注册流程状态跟踪
- **可扩展架构**: 易于添加更多功能模块
